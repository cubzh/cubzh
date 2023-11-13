// -------------------------------------------------------------
//  Cubzh Core
//  flood_fill_lighting.c
//  Created by Adrien Duermael on August 25, 2019.
// -------------------------------------------------------------

#include "flood_fill_lighting.h"

#include <stdlib.h>

#include "cclog.h"
#include "chunk.h"
#include "int3.h"

struct _LightNode {
    LightNode *next;
    Chunk *chunk;
    SHAPE_COORDS_INT3_T coords; /* 6 bytes */
    char pad[2];
};

struct _LightNodeQueue {
    LightNode *first;
};

LightNode *light_node_new(void) {
    LightNode *ln = (LightNode *)malloc(sizeof(LightNode));
    ln->next = NULL;
    ln->chunk = NULL;
    ln->coords = (SHAPE_COORDS_INT3_T){0, 0, 0};
    return ln;
}

void light_node_free(LightNode *n) {
    free(n);
}

void light_removal_node_free(LightRemovalNode *n) {
    free(n);
}

SHAPE_COORDS_INT3_T light_node_get_coords(const LightNode *n) {
    return n->coords;
}

Chunk *light_node_get_chunk(const LightNode *n) {
    return n->chunk;
}

LightNodeQueue *light_node_recycle_pool(void) {
    static LightNodeQueue p = {NULL};
    return &p;
}

LightNodeQueue *light_node_queue_new(void) {
    LightNodeQueue *q = (LightNodeQueue *)malloc(sizeof(LightNodeQueue));
    q->first = NULL;
    return q;
}

void light_node_queue_free(LightNodeQueue *q) {
    if (q == NULL) {
        return;
    }
    LightNode *n = NULL;
    while (q->first != NULL) {
        n = light_node_queue_pop(q);
        if (n != NULL) {
            light_node_queue_recycle(n);
        }
    }
    free(q);
}

LightNode *light_node_queue_pop(LightNodeQueue *q) {
    if (q->first == NULL)
        return NULL;
    LightNode *r = q->first;
    q->first = r->next;
    r->next = NULL;
    return r;
}

void light_node_queue_push(LightNodeQueue *q, Chunk *chunk, const SHAPE_COORDS_INT3_T coords) {
    // try to get new node from recycle pool first
    LightNode *n = light_node_queue_pop(light_node_recycle_pool());

    if (n == NULL) {
        n = light_node_new();
    }

    if (n == NULL) {
        cclog_error("🔥 can't create light node");
        return;
    }

    n->chunk = chunk;
    n->coords = coords;
    n->next = q->first;
    q->first = n;
}

void light_node_queue_recycle(LightNode *n) {
    LightNodeQueue *rp = light_node_recycle_pool();
    n->next = rp->first;
    rp->first = n;
}

struct _LightRemovalNode {
    LightRemovalNode *next;
    Chunk *chunk;
    SHAPE_COORDS_INT3_T coords;  /* 6 bytes */
    VERTEX_LIGHT_STRUCT_T light; /* 2 bytes */
    // 4 first bits used to flag in which channel [sunlight:R:G:B] removal should propagate
    uint8_t srgb; /* 1 byte */
    // this makes it possible to enqueue an emissive block as removal node
    SHAPE_COLOR_INDEX_INT_T blockID; /* 1 byte */
    char pad[6];
};

struct _LightRemovalNodeQueue {
    LightRemovalNode *first;
};

LightRemovalNode *light_removal_node_new(void) {
    LightRemovalNode *ln = (LightRemovalNode *)malloc(sizeof(LightRemovalNode));
    ln->next = NULL;
    ln->chunk = NULL;
    ln->coords = (SHAPE_COORDS_INT3_T){0, 0, 0};
    ln->light.ambient = 0;
    ln->light.red = 0;
    ln->light.green = 0;
    ln->light.blue = 0;
    ln->srgb = 15;
    ln->blockID = 255;
    return ln;
}

void light_removal_node_queue_free(LightRemovalNodeQueue *q) {
    if (q == NULL) {
        return;
    }
    LightRemovalNode *n = NULL;
    while (q->first != NULL) {
        n = light_removal_node_queue_pop(q);
        if (n != NULL) {
            light_removal_node_queue_recycle(n);
        }
    }
    free(q);
}

SHAPE_COORDS_INT3_T light_removal_node_get_coords(const LightRemovalNode *n) {
    return n->coords;
}

Chunk *light_removal_node_get_chunk(const LightRemovalNode *n) {
    return n->chunk;
}

VERTEX_LIGHT_STRUCT_T light_removal_node_get_light(const LightRemovalNode *n) {
    return n->light;
}

uint8_t light_removal_node_get_srgb(const LightRemovalNode *n) {
    return n->srgb;
}

SHAPE_COLOR_INDEX_INT_T light_removal_node_get_block_id(const LightRemovalNode *n) {
    return n->blockID;
}

LightRemovalNodeQueue *light_removal_node_recycle_pool(void) {
    static LightRemovalNodeQueue p = {NULL};
    return &p;
}

LightRemovalNodeQueue *light_removal_node_queue_new(void) {
    LightRemovalNodeQueue *q = (LightRemovalNodeQueue *)malloc(sizeof(LightRemovalNodeQueue));
    q->first = NULL;
    return q;
}

LightRemovalNode *light_removal_node_queue_pop(LightRemovalNodeQueue *q) {
    if (q->first == NULL) {
        return NULL;
    }
    LightRemovalNode *r = q->first;
    q->first = r->next;
    r->next = NULL;
    return r;
}

void light_removal_node_queue_push(LightRemovalNodeQueue *q,
                                   Chunk *chunk,
                                   const SHAPE_COORDS_INT3_T coords,
                                   VERTEX_LIGHT_STRUCT_T light,
                                   uint8_t srgb,
                                   SHAPE_COLOR_INDEX_INT_T blockID) {

    // try to get new node from recycle pool first
    LightRemovalNode *n = light_removal_node_queue_pop(light_removal_node_recycle_pool());

    if (n == NULL) {
        n = light_removal_node_new();
    }

    if (n == NULL) {
        cclog_error("🔥 can't create light node");
        return;
    }

    n->chunk = chunk;
    n->coords = coords;
    n->light.ambient = light.ambient;
    n->light.red = light.red;
    n->light.green = light.green;
    n->light.blue = light.blue;
    n->srgb = srgb;
    n->blockID = blockID;

    n->next = q->first;
    q->first = n;
}

void light_removal_node_queue_recycle(LightRemovalNode *n) {
    LightRemovalNodeQueue *rp = light_removal_node_recycle_pool();
    n->next = rp->first;
    rp->first = n;
}
