// -------------------------------------------------------------
//  Cubzh Core
//  octree.c
//  Created by Adrien Duermael on December 19, 2018.
// -------------------------------------------------------------

#include "octree.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cclog.h"
#include "config.h"
#include "zlib.h"

// memory blocks are ordered this way:
// 000, 001, 100, 101, 010, 011, 110, 111

/*
 nodes:
 start of each level:
 0 + (8 * (grand parent level - 1)) + (8 * (parent level - 1))
 0 + 8 ^ 0 + 8 ^ 1 + 8 ^ 2...
 0, 1, 9, 73...

 branch at each level considering parent:

 (start of level) + (8 * (node index - start of parent level))
 e.g. 73 + 8 * (12 - 9)
 */
static const int startIndexForLevel[11] =
    {0, 1, 9, 73, 585, 4681, 37449, 299593, 2396745, 19173961, 153391689};

///
struct _Octree {
    void *nodes;         // memory area containing all nodes // 4/8 bytes
    void *elements;      // memory area for all elements (kind of a flat 3d array based on octree
                         // indexes) // 4/8 bytes
    size_t element_size; // size of one element, small + power of two is ideal // 4/8 bytes
    size_t nodes_size_in_memory;    // 4/8 bytes
    size_t elements_size_in_memory; // 4/8 bytes
    size_t width_height_depth;      // 4/8 bytes
    uint32_t nb_nodes;              // 4 bytes
    uint32_t nb_elements;           // 4 bytes
    uint8_t levels;                 // 1 byte
    uint8_t nbDrawSlices;           // 1 byte
    char pad[6];                    // 6 bytes
};

///
struct _OctreeNode {
    // 0: node doesn't contain anything
    // 1: node contains children
    uint8_t n000 : 1;
    uint8_t n100 : 1;
    uint8_t n101 : 1;
    uint8_t n001 : 1;
    uint8_t n010 : 1;
    uint8_t n110 : 1;
    uint8_t n111 : 1;
    uint8_t n011 : 1;
};

///
struct _OctreeNodeValue {
    uint8_t v;
};

uint32_t nb_nodes_for_levels(const size_t levels);
uint32_t nb_elements_for_levels(const size_t levels);
size_t octree_element_index_1d(const Octree *octree, size_t x, size_t y, size_t z);
void *_octree_set_element(const Octree *octree, const void *element, size_t x, size_t y, size_t z);
static Octree *_octree_new(void);

Octree *octree_new_with_default_element(const OctreeLevelsForSize levels,
                                        const void *element,
                                        const size_t elementSize) {
    Octree *tree = _octree_new();
    tree->levels = (uint8_t)levels;
    tree->nb_nodes = nb_nodes_for_levels(levels);
    tree->nb_elements = nb_elements_for_levels(levels);
    const double cubicRoot = cbrt(tree->nb_elements);
    tree->width_height_depth = (size_t)cubicRoot;

    //    if (tree->width_height_depth == upper_power_of_two(tree->width_height_depth)) {
    //        cclog_info("👍 octree size is a power of 2");
    //    } else {
    //        cclog_info("⚠️ octree size is NOT a power of 2");
    //    }

    // const int systemPageSize = getpagesize();

    tree->element_size = elementSize;

    tree->nodes_size_in_memory = tree->nb_nodes * sizeof(OctreeNode);

    tree->nodes = malloc(tree->nodes_size_in_memory);
    if (tree->nodes == NULL) {
        octree_free(tree);
        return NULL;
    }

    memset(tree->nodes, 0, tree->nb_nodes); // setting everything to 0

    tree->elements_size_in_memory = tree->nb_elements * tree->element_size;

    tree->elements = malloc(tree->elements_size_in_memory);
    if (tree->elements == NULL) {
        octree_free(tree);
        return NULL;
    }

    void *cursor = tree->elements;
    for (uint32_t i = 0; i < tree->nb_elements; i++) {
        memcpy(cursor, element, elementSize);
        cursor = ((char *)cursor) + elementSize;
    }

    return tree;
}

void octree_flush(Octree *tree) {
    memset(tree->nodes, 0, tree->nb_nodes);
    memset(tree->elements, 0, tree->nb_elements * tree->element_size);
}

void octree_free(Octree *const tree) {
    if (tree != NULL) {
        free(tree->nodes);
        tree->nodes = NULL;
        free(tree->elements);
        tree->elements = NULL;
        free(tree);
    }
}

// utils

uint32_t nb_nodes_for_levels(const size_t levels) {
    uint8_t currentLevel = (uint8_t)levels;
    uint32_t nodes = 0;
    while (currentLevel > 0) {
        const double power = pow(8.0, (double)currentLevel - 1.0);
        nodes += (uint32_t)power;
        currentLevel--;
    }
    return nodes;
}

uint32_t nb_elements_for_levels(const size_t levels) {
    const double power = pow(8.0, (double)levels);
    return (uint32_t)power;
}

bool octree_set_element(const Octree *octree, const void *element, size_t x, size_t y, size_t z) {

    if (x >= octree->width_height_depth || y >= octree->width_height_depth ||
        z >= octree->width_height_depth) {
        cclog_error("🌳 octree can't store element beyond edges: (%zu, %zu, %zu)", x, y, z);
        return false;
    }

    const size_t original_x = x;
    const size_t original_y = y;
    const size_t original_z = z;

    uint8_t current_level = 0;
    uint16_t size_at_level = (uint16_t)octree->width_height_depth;
    uint16_t half_size_at_level;

    OctreeNode *node = (OctreeNode *)octree->nodes;
    int index_in_branch = 0;
    int node_index = 0;

    while (current_level < octree->levels) {

        half_size_at_level = size_at_level >> 1;

        if (x >= half_size_at_level) {
            if (y >= half_size_at_level) {
                if (z >= half_size_at_level) {
                    node->n111 = 1;
                    index_in_branch = 6;
                    z = z ^ half_size_at_level; // diff
                } else {
                    node->n110 = 1;
                    index_in_branch = 5;
                }
                y = y ^ half_size_at_level; // diff
            } else {
                if (z >= half_size_at_level) {
                    node->n101 = 1;
                    index_in_branch = 2;
                    z = z ^ half_size_at_level; // diff
                } else {
                    node->n100 = 1;
                    index_in_branch = 1;
                }
            }
            x = x ^ half_size_at_level; // diff
        } else {
            if (y >= half_size_at_level) {
                if (z >= half_size_at_level) {
                    node->n011 = 1;
                    index_in_branch = 7;
                    z = z ^ half_size_at_level; // diff
                } else {
                    node->n010 = 1;
                    index_in_branch = 4;
                }
                y = y ^ half_size_at_level; // diff
            } else {
                if (z >= half_size_at_level) {
                    node->n001 = 1;
                    index_in_branch = 3;
                    z = z ^ half_size_at_level; // diff
                } else {
                    node->n000 = 1;
                    index_in_branch = 0;
                }
            }
        }

        size_at_level = size_at_level >> 1;
        current_level++;

        // compute index of next node
        node_index = startIndexForLevel[current_level] +
                     8 * (node_index - startIndexForLevel[current_level - 1]) + index_in_branch;
        node = (OctreeNode *)(octree->nodes) + node_index;
    }

    _octree_set_element(octree, element, original_x, original_y, original_z);

    return true;
}

bool octree_remove_element(const Octree *octree, size_t x, size_t y, size_t z, void *emptyElement) {
    if (x >= octree->width_height_depth || y >= octree->width_height_depth ||
        z >= octree->width_height_depth) {
        cclog_error("🌳 octree can't remove element from beyond edges: (%zu, %zu, %zu)", x, y, z);
        return false;
    }

    size_t _x = x;
    size_t _y = y;
    size_t _z = z;

    uint8_t current_level = 0;
    uint16_t size_at_level = (uint16_t)octree->width_height_depth;
    uint16_t half_size_at_level;

    OctreeNode *node = (OctreeNode *)octree->nodes;
    int index_in_branch = 0;
    int node_index = 0;

    int *index_in_branch_at_level = (int *)malloc(sizeof(int) * octree->levels);
    if (index_in_branch_at_level == NULL) {
        return false;
    }
    int *node_index_at_level = (int *)malloc(sizeof(int) * octree->levels);
    if (node_index_at_level == NULL) {
        free(index_in_branch_at_level);
        return false;
    }

    node_index_at_level[0] = node_index;

    while (current_level < octree->levels) {

        half_size_at_level = size_at_level >> 1;

        if (_x >= half_size_at_level) {
            if (_y >= half_size_at_level) {
                if (_z >= half_size_at_level) {
                    if (node->n111 == 0) {
                        free(index_in_branch_at_level);
                        free(node_index_at_level);
                        return false;
                    }
                    index_in_branch = 6;
                    _z = _z ^ half_size_at_level; // diff
                } else {
                    if (node->n110 == 0) {
                        free(index_in_branch_at_level);
                        free(node_index_at_level);
                        return false;
                    }
                    index_in_branch = 5;
                }
                _y = _y ^ half_size_at_level; // diff
            } else {
                if (_z >= half_size_at_level) {
                    if (node->n101 == 0) {
                        free(index_in_branch_at_level);
                        free(node_index_at_level);
                        return false;
                    }
                    index_in_branch = 2;
                    _z = _z ^ half_size_at_level; // diff
                } else {
                    if (node->n100 == 0) {
                        free(index_in_branch_at_level);
                        free(node_index_at_level);
                        return false;
                    }
                    index_in_branch = 1;
                }
            }
            _x = _x ^ half_size_at_level; // diff
        } else {
            if (_y >= half_size_at_level) {
                if (_z >= half_size_at_level) {
                    if (node->n011 == 0) {
                        free(index_in_branch_at_level);
                        free(node_index_at_level);
                        return false;
                    }
                    index_in_branch = 7;
                    _z = _z ^ half_size_at_level; // diff
                } else {
                    if (node->n010 == 0) {
                        free(index_in_branch_at_level);
                        free(node_index_at_level);
                        return false;
                    }
                    index_in_branch = 4;
                }
                _y = _y ^ half_size_at_level; // diff
            } else {
                if (_z >= half_size_at_level) {
                    if (node->n001 == 0) {
                        free(index_in_branch_at_level);
                        free(node_index_at_level);
                        return false;
                    }
                    index_in_branch = 3;
                    _z = _z ^ half_size_at_level; // diff
                } else {
                    index_in_branch = 0;
                    if (node->n000 == 0) {
                        free(index_in_branch_at_level);
                        free(node_index_at_level);
                        return false;
                    }
                }
            }
        }

        index_in_branch_at_level[current_level] = index_in_branch;

        size_at_level = size_at_level >> 1;
        current_level++;

        // compute index of next node
        node_index = startIndexForLevel[current_level] +
                     8 * (node_index - startIndexForLevel[current_level - 1]) + index_in_branch;
        node = (OctreeNode *)(octree->nodes) + node_index;

        if (current_level < octree->levels) {
            node_index_at_level[current_level] = node_index;
        }
    }

    // reaching this point means the node is found
    // set bit to 0 and propagate to parent nodes if node == 0

    size_at_level = (uint16_t)(size_at_level << 1);
    current_level -= 1;

    index_in_branch = index_in_branch_at_level[current_level];
    node_index = node_index_at_level[current_level];

    node = (OctreeNode *)(octree->nodes) + node_index;

    // no need to check for (current_level >= 0) because current_level is
    // unsigned, so condition is always true.
    while (true) {
        switch (index_in_branch) {
            case 0:
                node->n000 = 0;
                break;
            case 1:
                node->n100 = 0;
                break;
            case 2:
                node->n101 = 0;
                break;
            case 3:
                node->n001 = 0;
                break;
            case 4:
                node->n010 = 0;
                break;
            case 5:
                node->n110 = 0;
                break;
            case 6:
                node->n111 = 0;
                break;
            case 7:
                node->n011 = 0;
                break;
            default:
                break;
        }

        OctreeNodeValue *nv = (OctreeNodeValue *)node;

        if (nv->v == 0 && current_level > 0) {
            size_at_level = (uint16_t)(size_at_level << 1);
            current_level -= 1;

            index_in_branch = index_in_branch_at_level[current_level];
            node_index = node_index_at_level[current_level];

            node = (OctreeNode *)(octree->nodes) + node_index;
        } else {
            break;
        }
    }

    // printf("size_at_level: %d\n", size_at_level);
    // printf("current_level: %d\n", current_level);
    // printf("octree->levels: %d\n", octree->levels);
    // printf("node value after: %d\n", nv->v);

    free(index_in_branch_at_level);
    free(node_index_at_level);

    if (emptyElement != NULL) {
        _octree_set_element(octree, emptyElement, x, y, z);
    }

    return true;
}

// looks level per level to see if the element exists and returns it if it does, NULL otherwise.
void *octree_get_element(const Octree *octree, const size_t x, const size_t y, const size_t z) {

    // check if element exists
    size_t _x = x;
    size_t _y = y;
    size_t _z = z;

    uint8_t current_level = 0;
    uint16_t size_at_level = (uint16_t)octree->width_height_depth;
    uint16_t half_size_at_level;

    OctreeNode *node = (OctreeNode *)octree->nodes;
    int index_in_branch = 0;
    int node_index = 0;

    while (current_level < octree->levels) {

        half_size_at_level = size_at_level >> 1;

        if (_x >= half_size_at_level) {
            if (_y >= half_size_at_level) {
                if (_z >= half_size_at_level) {
                    if (node->n111 == 0) {
                        return NULL;
                    }
                    index_in_branch = 6;
                    _z = _z ^ half_size_at_level; // diff
                } else {
                    if (node->n110 == 0) {
                        return NULL;
                    }
                    index_in_branch = 5;
                }
                _y = _y ^ half_size_at_level; // diff
            } else {
                if (_z >= half_size_at_level) {
                    if (node->n101 == 0) {
                        return NULL;
                    }
                    index_in_branch = 2;
                    _z = _z ^ half_size_at_level; // diff
                } else {
                    if (node->n100 == 0) {
                        return NULL;
                    }
                    index_in_branch = 1;
                }
            }
            _x = _x ^ half_size_at_level; // diff
        } else {
            if (_y >= half_size_at_level) {
                if (_z >= half_size_at_level) {
                    if (node->n011 == 0) {
                        return NULL;
                    }
                    index_in_branch = 7;
                    _z = _z ^ half_size_at_level; // diff
                } else {
                    if (node->n010 == 0) {
                        return NULL;
                    }
                    index_in_branch = 4;
                }
                _y = _y ^ half_size_at_level; // diff
            } else {
                if (_z >= half_size_at_level) {
                    if (node->n001 == 0) {
                        return NULL;
                    }
                    index_in_branch = 3;
                    _z = _z ^ half_size_at_level; // diff
                } else {
                    index_in_branch = 0;
                    if (node->n000 == 0) {
                        return NULL;
                    }
                }
            }
        }

        size_at_level = size_at_level >> 1;
        current_level++;

        // compute index of next node
        node_index = startIndexForLevel[current_level] +
                     8 * (node_index - startIndexForLevel[current_level - 1]) + index_in_branch;
        node = (OctreeNode *)(octree->nodes) + node_index;
    }

    return octree_get_element_without_checking(octree, x, y, z);
}

void octree_get_element_or_empty_value(const Octree *octree,
                                       const size_t x,
                                       const size_t y,
                                       const size_t z,
                                       void **element,
                                       void **empty) {

    void *el = octree_get_element(octree, x, y, z);

    if (el != NULL) {
        if (element != NULL) {
            *element = el;
        }
        if (empty != NULL) {
            *empty = NULL;
        }
        return;
    }

    if (empty != NULL) {
        *empty = octree_get_element_without_checking(octree, x, y, z);
    }
}

void *_octree_set_element(const Octree *octree, const void *element, size_t x, size_t y, size_t z) {
    // no need to check for negative x, y or z: unsigned so always positive
    // if (x < 0 || y < 0 || z < 0) {
    //    printf("🌳 octree can't store element at (%zu, %zu, %zu), x, y & z should be > 0\n", x, y,
    //    z); return NULL;
    //}
    size_t index_1d = octree_element_index_1d(octree, x, y, z);
    if (index_1d > octree->nb_elements) {
        cclog_error("🌳 octree not big enough to store element at (%zu, %zu, %zu)", x, y, z);
        return NULL;
    }

    void *destination = ((char *)octree->elements + octree->element_size * index_1d);
    memcpy(destination, element, octree->element_size);
    return NULL;
}

void *octree_get_element_without_checking(const Octree *octree,
                                          const size_t x,
                                          const size_t y,
                                          const size_t z) {
    // no need to check for negative x, y or z: unsigned so always positive
    // if (x < 0 || y < 0 || z < 0) {
    //    return NULL;
    //}
    if (x >= octree->width_height_depth || y >= octree->width_height_depth ||
        z >= octree->width_height_depth) {
        return NULL;
    }
    return ((char *)octree->elements +
            octree->element_size * octree_element_index_1d(octree, x, y, z));
}

void octree_log(const Octree *octree) {
    cclog_trace("----- OCTREE -----");
    cclog_info("- levels: %hhu", octree->levels);
    cclog_info("- width_height_depth: %zu", octree->width_height_depth);
    cclog_info("- element_size: %zu", octree->element_size);
    cclog_trace("--");
    cclog_info("- nb_nodes: %u", octree->nb_nodes);
    cclog_info("- nodes_size_in_memory: %zu", octree->nodes_size_in_memory);
    cclog_trace("--");
    cclog_info("- nb_elements: %u", octree->nb_elements);
    cclog_info("- elements_size_in_memory: %zu", octree->elements_size_in_memory);
    cclog_trace("------------------");
}

void octree_non_recursive_iteration(const Octree *octree) {

    uint16_t x = 0;
    uint16_t y = 0;
    uint16_t z = 0;

    OctreeNode *allNodes = (OctreeNode *)octree->nodes;

    OctreeNode *current_nodes[11]; // there's only one node by level maximum at any time when
                                   // exploring the tree
    int node_index_in_level[11];   // index of node in its own level (global index minus start of
                                   // level)
    uint8_t child_index_processed[11]; // child index being processed for each level

    int current_level = 0;          // level being processed
    int current_level_plus_one = 1; // level being processed

    current_nodes[current_level] = &allNodes[0];
    node_index_in_level[current_level] = 0;
    child_index_processed[current_level] = 0;

    bool goingToNextLevel = false;
    bool found = false;

    // loop while last child of first node (first level) hasn't been processed
    while (true) {

        if (child_index_processed[current_level] == 8) {
            if (current_level == 0) {
                break;
            }

            current_level -= 1;
            current_level_plus_one -= 1;

            uint16_t mask = (uint16_t)(~(1 << (octree->levels - current_level_plus_one)));
            x &= mask;
            y &= mask;
            z &= mask;
            continue;
        }

        if (current_level == octree->levels - 1) { // reached last level

            found = false;

            switch (child_index_processed[current_level]) {
                case 0:
                    if (current_nodes[current_level]->n000 == 1) {
                        found = true;
                    }
                    break;
                case 1:
                    if (current_nodes[current_level]->n100 == 1) {
                        x |= 1 << (octree->levels - current_level_plus_one);
                        found = true;
                    }
                    break;
                case 2:
                    if (current_nodes[current_level]->n101 == 1) {
                        x |= 1 << (octree->levels - current_level_plus_one);
                        z |= 1 << (octree->levels - current_level_plus_one);
                        found = true;
                    }
                    break;
                case 3:
                    if (current_nodes[current_level]->n001 == 1) {
                        z |= 1 << (octree->levels - current_level_plus_one);
                        found = true;
                    }
                    break;
                case 4:
                    if (current_nodes[current_level]->n010 == 1) {
                        y |= 1 << (octree->levels - current_level_plus_one);
                        found = true;
                    }
                    break;
                case 5:
                    if (current_nodes[current_level]->n110 == 1) {
                        x |= 1 << (octree->levels - current_level_plus_one);
                        y |= 1 << (octree->levels - current_level_plus_one);
                        found = true;
                    }
                    break;
                case 6:
                    if (current_nodes[current_level]->n111 == 1) {
                        x |= 1 << (octree->levels - current_level_plus_one);
                        y |= 1 << (octree->levels - current_level_plus_one);
                        z |= 1 << (octree->levels - current_level_plus_one);
                        found = true;
                    }
                    break;
                case 7:
                    if (current_nodes[current_level]->n011 == 1) {
                        y |= 1 << (octree->levels - current_level_plus_one);
                        z |= 1 << (octree->levels - current_level_plus_one);
                        found = true;
                    }
                    break;
                default:
                    cclog_error("a node can't have more than 8 children\n;");
                    break;
            }

            if (found) {
                cclog_info("element: %d, %d, %d", x, y, z);

                uint16_t mask = (uint16_t)(~(1 << (octree->levels - current_level_plus_one)));
                x &= mask;
                y &= mask;
                z &= mask;
            }

            child_index_processed[current_level] += 1;

        } else {

            goingToNextLevel = false;

            switch (child_index_processed[current_level]) {
                case 0:
                    if (current_nodes[current_level]->n000 == 1) {
                        node_index_in_level[current_level +
                                            1] = 8 * node_index_in_level[current_level] + 0;
                        goingToNextLevel = true;
                    }
                    break;
                case 1:
                    if (current_nodes[current_level]->n100 == 1) {
                        node_index_in_level[current_level +
                                            1] = 8 * node_index_in_level[current_level] + 1;
                        goingToNextLevel = true;

                        x |= 1 << (octree->levels - current_level_plus_one);
                    }
                    break;
                case 2:
                    if (current_nodes[current_level]->n101 == 1) {
                        node_index_in_level[current_level +
                                            1] = 8 * node_index_in_level[current_level] + 2;
                        goingToNextLevel = true;

                        x |= 1 << (octree->levels - current_level_plus_one);
                        z |= 1 << (octree->levels - current_level_plus_one);
                    }
                    break;
                case 3:
                    if (current_nodes[current_level]->n001 == 1) {
                        node_index_in_level[current_level +
                                            1] = 8 * node_index_in_level[current_level] + 3;
                        goingToNextLevel = true;

                        z |= 1 << (octree->levels - current_level_plus_one);
                    }
                    break;
                case 4:
                    if (current_nodes[current_level]->n010 == 1) {
                        node_index_in_level[current_level +
                                            1] = 8 * node_index_in_level[current_level] + 4;
                        goingToNextLevel = true;

                        y |= 1 << (octree->levels - current_level_plus_one);
                    }
                    break;
                case 5:
                    if (current_nodes[current_level]->n110 == 1) {
                        node_index_in_level[current_level +
                                            1] = 8 * node_index_in_level[current_level] + 5;
                        goingToNextLevel = true;

                        x |= 1 << (octree->levels - current_level_plus_one);
                        y |= 1 << (octree->levels - current_level_plus_one);
                    }
                    break;
                case 6:
                    if (current_nodes[current_level]->n111 == 1) {
                        node_index_in_level[current_level +
                                            1] = 8 * node_index_in_level[current_level] + 6;
                        goingToNextLevel = true;

                        x |= 1 << (octree->levels - current_level_plus_one);
                        y |= 1 << (octree->levels - current_level_plus_one);
                        z |= 1 << (octree->levels - current_level_plus_one);
                    }
                    break;
                case 7:
                    if (current_nodes[current_level]->n011 == 1) {
                        node_index_in_level[current_level +
                                            1] = 8 * node_index_in_level[current_level] + 7;
                        goingToNextLevel = true;

                        y |= 1 << (octree->levels - current_level_plus_one);
                        z |= 1 << (octree->levels - current_level_plus_one);
                    }
                    break;
                default:
                    cclog_error("a node can't have more than 8 children\n;");
                    break;
            }

            child_index_processed[current_level] += 1;

            if (goingToNextLevel) {
                current_level += 1;
                current_level_plus_one += 1;
                current_nodes[current_level] = &allNodes[startIndexForLevel[current_level] +
                                                         node_index_in_level[current_level]];
                child_index_processed[current_level] = 0;
            }
        }
    }
}

size_t octree_element_index_1d(const Octree *octree,
                               const size_t x,
                               const size_t y,
                               const size_t z) {
    return (octree->width_height_depth * octree->width_height_depth * z +
            octree->width_height_depth * y + x);
}

// getters

void *octree_get_nodes(const Octree *octree) {
    return octree->nodes;
}

size_t octree_get_nodes_size(const Octree *octree) {
    return octree->nodes_size_in_memory;
}

void *octree_get_elements(const Octree *octree) {
    return octree->elements;
}

size_t octree_get_elements_size(const Octree *octree) {
    return octree->elements_size_in_memory;
}

uint8_t octree_get_levels(const Octree *octree) {
    return octree->levels;
}

size_t octree_get_dimension(const Octree *octree) {
    return octree->width_height_depth;
}

uint64_t octree_get_hash(const Octree *octree, uint64_t crc) {
    return crc32((uLong)crc, octree->elements, (uInt)octree->elements_size_in_memory);
}

// MARK: Octree iterator

struct _OctreeIterator {
    const Octree *octree;
    OctreeNode *current_nodes[11]; // there's only one node by level maximum at any time when
                                   // exploring the tree
    int node_index_in_level[11];   // index of node in its own level (global index minus start of
                                   // level)
    int branch_index[10]; // index of first child for node at given level (8 children for each node)

    uint8_t child_index_processed[11]; // child index being processed for each level
    char pad[1];

    int current_level;          // level being processed
    int current_level_plus_one; // level being processed

    uint16_t current_node_x;
    uint16_t current_node_y;
    uint16_t current_node_z;
    uint16_t current_node_size;

    bool done;
    bool foundLeaf;
    char pad2[6];
};

OctreeIterator *octree_iterator_new(const Octree *octree) {
    OctreeIterator *oi = (OctreeIterator *)malloc(sizeof(OctreeIterator));
    if (oi == NULL) {
        return NULL;
    }

    oi->octree = octree;

    oi->current_level = 0;
    oi->current_level_plus_one = 1;

    OctreeNode *allNodes = (OctreeNode *)octree->nodes;

    oi->current_nodes[oi->current_level] = &allNodes[0];
    oi->node_index_in_level[oi->current_level] = 0;
    oi->child_index_processed[oi->current_level] = 0;
    oi->branch_index[oi->current_level] = 1;

    oi->current_node_x = 0;
    oi->current_node_y = 0;
    oi->current_node_z = 0;
    oi->current_node_size = (uint16_t)octree->width_height_depth;

    oi->done = false;
    oi->foundLeaf = false;

    return oi;
}

void octree_iterator_free(OctreeIterator *oi) {
    free(oi);
}

bool octree_iterator_is_at_last_level(OctreeIterator *oi) {
    return oi->current_level == oi->octree->levels - 1;
}

void octree_iterator_get_node_box(const OctreeIterator *oi, Box *box) {
    box->min.x = (float)oi->current_node_x;
    box->min.y = (float)oi->current_node_y;
    box->min.z = (float)oi->current_node_z;

    float s = (float)oi->current_node_size;

    box->max.x = box->min.x + s;
    box->max.y = box->min.y + s;
    box->max.z = box->min.z + s;
}

void *octree_iterator_get_element(const OctreeIterator *oi) {
    return octree_get_element_without_checking(oi->octree,
                                               oi->current_node_x,
                                               oi->current_node_y,
                                               oi->current_node_z);
}

uint16_t octree_iterator_get_current_node_size(const OctreeIterator *oi) {
    return oi->current_node_size;
}

void octree_iterator_get_current_position(const OctreeIterator *oi,
                                          uint16_t *x,
                                          uint16_t *y,
                                          uint16_t *z) {
    *x = oi->current_node_x;
    *y = oi->current_node_y;
    *z = oi->current_node_z;
    return;
}

// Jumps to next element, skipping current branch if skip_current_branch is true.
// Stops at each intermediate node to test collisions.
void octree_iterator_next(OctreeIterator *oi, bool skip_current_branch, bool *found) {

    bool goingToNextLevel;
    *found = false;

    OctreeNode *allNodes = (OctreeNode *)oi->octree->nodes;

    while (oi->done == false) {

        // check if all nodes have been processed at current level
        if (skip_current_branch || oi->child_index_processed[oi->current_level] == 8) {
            if (oi->current_level == 0) {
                oi->done = true;
                return;
            }

            // if found leaf during last iteration
            if (oi->foundLeaf) {
                uint16_t mask = (uint16_t)(~(1
                                             << (oi->octree->levels - oi->current_level_plus_one)));
                oi->current_node_x &= mask;
                oi->current_node_y &= mask;
                oi->current_node_z &= mask;
                oi->current_node_size = (uint16_t)(oi->current_node_size << 1);
                oi->foundLeaf = false;
            }

            oi->current_level -= 1;
            oi->current_level_plus_one -= 1;

            uint16_t mask = (uint16_t)(~(1 << (oi->octree->levels - oi->current_level_plus_one)));
            oi->current_node_x &= mask;
            oi->current_node_y &= mask;
            oi->current_node_z &= mask;
            oi->current_node_size = (uint16_t)(oi->current_node_size << 1);

            // do not skip all branches!
            skip_current_branch = false;

            continue;
        }

        // check if last level has been reached
        if (oi->current_level == oi->octree->levels - 1) {

            // if found leaf during last iteration
            if (oi->foundLeaf) {
                uint16_t mask = (uint16_t)(~(1
                                             << (oi->octree->levels - oi->current_level_plus_one)));
                oi->current_node_x &= mask;
                oi->current_node_y &= mask;
                oi->current_node_z &= mask;
                oi->current_node_size = (uint16_t)(oi->current_node_size << 1);
                oi->foundLeaf = false;
            }

            switch (oi->child_index_processed[oi->current_level]) {
                case 0:
                    if (oi->current_nodes[oi->current_level]->n000 == 1) {
                        oi->foundLeaf = true;
                    }
                    break;
                case 1:
                    if (oi->current_nodes[oi->current_level]->n100 == 1) {
                        oi->current_node_x |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->foundLeaf = true;
                    }
                    break;
                case 2:
                    if (oi->current_nodes[oi->current_level]->n101 == 1) {
                        oi->current_node_x |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->current_node_z |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->foundLeaf = true;
                    }
                    break;
                case 3:
                    if (oi->current_nodes[oi->current_level]->n001 == 1) {
                        oi->current_node_z |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->foundLeaf = true;
                    }
                    break;
                case 4:
                    if (oi->current_nodes[oi->current_level]->n010 == 1) {
                        oi->current_node_y |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->foundLeaf = true;
                    }
                    break;
                case 5:
                    if (oi->current_nodes[oi->current_level]->n110 == 1) {
                        oi->current_node_x |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->current_node_y |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->foundLeaf = true;
                    }
                    break;
                case 6:
                    if (oi->current_nodes[oi->current_level]->n111 == 1) {
                        oi->current_node_x |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->current_node_y |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->current_node_z |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->foundLeaf = true;
                    }
                    break;
                case 7:
                    if (oi->current_nodes[oi->current_level]->n011 == 1) {
                        oi->current_node_y |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->current_node_z |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->foundLeaf = true;
                    }
                    break;
                default:
                    cclog_error("a node can't have more than 8 children\n;");
                    break;
            }

            oi->child_index_processed[oi->current_level] += 1;

            if (oi->foundLeaf) {
                *found = true;
                oi->current_node_size = oi->current_node_size >> 1;
                return; // return now for collisions to be tested with the node
                // to be continued...
            }

        } else { // not last level

            // stop if going to next level == true
            goingToNextLevel = false;

            switch (oi->child_index_processed[oi->current_level]) {
                case 0:
                    if (oi->current_nodes[oi->current_level]->n000 == 1) {
                        oi->node_index_in_level
                            [oi->current_level +
                             1] = 8 * oi->node_index_in_level[oi->current_level] + 0;
                        oi->branch_index[oi->current_level +
                                         1] = startIndexForLevel[oi->current_level + 2] +
                                              8 * oi->node_index_in_level[oi->current_level + 1];
                        goingToNextLevel = true;
                    }
                    break;
                case 1:
                    if (oi->current_nodes[oi->current_level]->n100 == 1) {
                        oi->node_index_in_level
                            [oi->current_level +
                             1] = 8 * oi->node_index_in_level[oi->current_level] + 1;
                        oi->branch_index[oi->current_level +
                                         1] = startIndexForLevel[oi->current_level + 2] +
                                              8 * oi->node_index_in_level[oi->current_level + 1];
                        goingToNextLevel = true;

                        oi->current_node_x |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                    }
                    break;
                case 2:
                    if (oi->current_nodes[oi->current_level]->n101 == 1) {
                        oi->node_index_in_level
                            [oi->current_level +
                             1] = 8 * oi->node_index_in_level[oi->current_level] + 2;
                        oi->branch_index[oi->current_level +
                                         1] = startIndexForLevel[oi->current_level + 2] +
                                              8 * oi->node_index_in_level[oi->current_level + 1];
                        goingToNextLevel = true;

                        oi->current_node_x |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->current_node_z |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                    }
                    break;
                case 3:
                    if (oi->current_nodes[oi->current_level]->n001 == 1) {
                        oi->node_index_in_level
                            [oi->current_level +
                             1] = 8 * oi->node_index_in_level[oi->current_level] + 3;
                        oi->branch_index[oi->current_level +
                                         1] = startIndexForLevel[oi->current_level + 2] +
                                              8 * oi->node_index_in_level[oi->current_level + 1];
                        goingToNextLevel = true;

                        oi->current_node_z |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                    }
                    break;
                case 4:
                    if (oi->current_nodes[oi->current_level]->n010 == 1) {
                        oi->node_index_in_level
                            [oi->current_level +
                             1] = 8 * oi->node_index_in_level[oi->current_level] + 4;
                        oi->branch_index[oi->current_level +
                                         1] = startIndexForLevel[oi->current_level + 2] +
                                              8 * oi->node_index_in_level[oi->current_level + 1];
                        goingToNextLevel = true;

                        oi->current_node_y |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                    }
                    break;
                case 5:
                    if (oi->current_nodes[oi->current_level]->n110 == 1) {
                        oi->node_index_in_level
                            [oi->current_level +
                             1] = 8 * oi->node_index_in_level[oi->current_level] + 5;
                        oi->branch_index[oi->current_level +
                                         1] = startIndexForLevel[oi->current_level + 2] +
                                              8 * oi->node_index_in_level[oi->current_level + 1];
                        goingToNextLevel = true;

                        oi->current_node_x |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->current_node_y |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                    }
                    break;
                case 6:
                    if (oi->current_nodes[oi->current_level]->n111 == 1) {
                        oi->node_index_in_level
                            [oi->current_level +
                             1] = 8 * oi->node_index_in_level[oi->current_level] + 6;
                        oi->branch_index[oi->current_level +
                                         1] = startIndexForLevel[oi->current_level + 2] +
                                              8 * oi->node_index_in_level[oi->current_level + 1];
                        goingToNextLevel = true;

                        oi->current_node_x |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->current_node_y |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->current_node_z |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                    }
                    break;
                case 7:
                    if (oi->current_nodes[oi->current_level]->n011 == 1) {
                        oi->node_index_in_level
                            [oi->current_level +
                             1] = 8 * oi->node_index_in_level[oi->current_level] + 7;
                        oi->branch_index[oi->current_level +
                                         1] = startIndexForLevel[oi->current_level + 2] +
                                              8 * oi->node_index_in_level[oi->current_level + 1];
                        goingToNextLevel = true;

                        oi->current_node_y |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                        oi->current_node_z |= 1
                                              << (oi->octree->levels - oi->current_level_plus_one);
                    }
                    break;
                default:
                    cclog_error("a node can't have more than 8 children\n;");
                    break;
            }

            oi->child_index_processed[oi->current_level] += 1;

            if (goingToNextLevel) {
                oi->current_level += 1;
                oi->current_level_plus_one += 1;
                oi->current_nodes
                    [oi->current_level] = &allNodes[startIndexForLevel[oi->current_level] +
                                                    oi->node_index_in_level[oi->current_level]];
                oi->child_index_processed[oi->current_level] = 0;
                oi->current_node_size = oi->current_node_size >> 1;
                return; // return now for collisions to be tested with the node
                // to be continued...
            }

        } // not last level condition

    } // end of while loop
}

// returns true when done iterating
bool octree_iterator_is_done(const OctreeIterator *oi) {
    return oi->done;
}

//
// MARK: - static functions -
//

/// Allocates an Octree structure and return its address.
static Octree *_octree_new(void) {
    Octree *o = (Octree *)malloc(sizeof(Octree));
    if (o == NULL) {
        return NULL;
    }
    o->nodes = NULL;
    o->elements = NULL;
    o->element_size = 0;
    o->nodes_size_in_memory = 0;
    o->elements_size_in_memory = 0;
    o->width_height_depth = 0;
    o->nb_nodes = 0;
    o->nb_elements = 0;
    o->levels = 0;
    o->nbDrawSlices = 0;
    return o;
}
