// -------------------------------------------------------------
//  Cubzh Core
//  map_string_float3.c
//  Created by Adrien Duermael on August 7, 2019.
// -------------------------------------------------------------

#include "map_string_float3.h"

#include <stdio.h>
#include <string.h>

#include "cclog.h"

struct node {
    char *key;
    float3 *value;
    struct node *next;
};

struct _MapStringFloat3 {
    struct node *list;
};

struct _MapStringFloat3Iterator {
    struct node *currentNode;
};

MapStringFloat3 *map_string_float3_new(void) {
    MapStringFloat3 *m = (MapStringFloat3 *)malloc(sizeof(MapStringFloat3));
    m->list = NULL;
    return m;
}

void map_string_float3_free(MapStringFloat3 *m) {
    if (m == NULL) {
        return;
    }
    // free m->list
    struct node *currentNode;
    while (m->list != NULL) {
        currentNode = m->list;
        m->list = currentNode->next;
        float3_free(currentNode->value);
        free(currentNode->key);
        free(currentNode);
    }
    // free m
    free(m);
}

MapStringFloat3Iterator *map_string_float3_iterator_new(const MapStringFloat3 *m) {
    if (m == NULL) {
        return NULL;
    }
    MapStringFloat3Iterator *i = (MapStringFloat3Iterator *)malloc(sizeof(MapStringFloat3Iterator));
    i->currentNode = m->list;
    return i;
}

void map_string_float3_iterator_free(MapStringFloat3Iterator *i) {
    free(i);
}

void map_string_float3_iterator_next(MapStringFloat3Iterator *i) {
    if (i->currentNode != NULL) {
        i->currentNode = i->currentNode->next;
    }
}

const char *map_string_float3_iterator_current_key(const MapStringFloat3Iterator *i) {
    if (i != NULL) {
        if (i->currentNode != NULL) {
            return i->currentNode->key;
        }
    }
    return NULL;
}

float3 *map_string_float3_iterator_current_value(const MapStringFloat3Iterator *i) {
    if (i != NULL) {
        if (i->currentNode != NULL) {
            return i->currentNode->value;
        }
    }
    return NULL;
}

void map_string_float3_iterator_replace_current_value(const MapStringFloat3Iterator *i,
                                                      float3 *f3) {
    if (i->currentNode != NULL) {
        float3_free(i->currentNode->value);
        i->currentNode->value = f3;
    }
}

bool map_string_float3_iterator_is_done(const MapStringFloat3Iterator *i) {
    return (i->currentNode == NULL);
}

void map_string_float3_set_key_value(MapStringFloat3 *m, const char *key, float3 *f3) {
    // see if node exists
    MapStringFloat3Iterator *it = map_string_float3_iterator_new(m);

    while (map_string_float3_iterator_is_done(it) == false) {
        if (strcmp(key, map_string_float3_iterator_current_key(it)) == 0) {
            // key exists, update value
            map_string_float3_iterator_replace_current_value(it, f3);
            map_string_float3_iterator_free(it);
            return;
        }
        map_string_float3_iterator_next(it);
    }
    map_string_float3_iterator_free(it);

    struct node *newNode = (struct node *)malloc(sizeof(struct node));

    newNode->key = (char *)malloc(strlen(key) + 1);
    strcpy(newNode->key, key);
    newNode->value = f3;

    newNode->next = m->list;
    m->list = newNode;

    return;
}

void map_string_float3_debug(MapStringFloat3 *m) {
    MapStringFloat3Iterator *it = map_string_float3_iterator_new(m);
    while (map_string_float3_iterator_is_done(it) == false) {
        const float3 *r = map_string_float3_iterator_current_value(it);
        cclog_debug("KEY: %s - VALUE: %.2f, %.2f, %.2f",
                    map_string_float3_iterator_current_key(it),
                    (double)r->x,
                    (double)r->y,
                    (double)r->z);
        map_string_float3_iterator_next(it);
    }
    map_string_float3_iterator_free(it);
}

const float3 *map_string_float3_value_for_key(MapStringFloat3 *m, const char *key) {
    MapStringFloat3Iterator *it = map_string_float3_iterator_new(m);
    while (map_string_float3_iterator_is_done(it) == false) {
        if (strcmp(key, map_string_float3_iterator_current_key(it)) == 0) {
            const float3 *r = map_string_float3_iterator_current_value(it);
            map_string_float3_iterator_free(it);
            return r;
        }
        map_string_float3_iterator_next(it);
    }
    map_string_float3_iterator_free(it);
    return NULL;
}

float3 *map_string_mutable_float3_value_for_key(MapStringFloat3 *m, const char *key) {
    MapStringFloat3Iterator *it = map_string_float3_iterator_new(m);
    while (map_string_float3_iterator_is_done(it) == false) {
        if (strcmp(key, map_string_float3_iterator_current_key(it)) == 0) {
            float3 *r = map_string_float3_iterator_current_value(it);
            map_string_float3_iterator_free(it);
            return r;
        }
        map_string_float3_iterator_next(it);
    }
    map_string_float3_iterator_free(it);
    return NULL;
}

void map_string_float3_remove_key(MapStringFloat3 *m, const char *key) {

    struct node *previousNode = NULL;

    MapStringFloat3Iterator *it = map_string_float3_iterator_new(m);
    while (map_string_float3_iterator_is_done(it) == false) {
        if (strcmp(key, map_string_float3_iterator_current_key(it)) == 0) {
            if (previousNode == NULL) { // removing first node
                m->list = it->currentNode->next;
            } else {
                previousNode->next = it->currentNode->next;
            }
            // free node
            float3_free(it->currentNode->value);
            free(it->currentNode->key);
            free(it->currentNode);
            break;
        }
        previousNode = it->currentNode;
        map_string_float3_iterator_next(it);
    }
    map_string_float3_iterator_free(it);
    return;
}
