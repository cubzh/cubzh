// -------------------------------------------------------------
//  Cubzh Core
//  flood_fill_lighting.h
//  Created by Adrien Duermael on August 25, 2019.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdio.h>

#include "config.h"

typedef struct _LightNode LightNode;
typedef struct _LightRemovalNode LightRemovalNode;
typedef struct _LightNodeQueue LightNodeQueue;
typedef struct _LightRemovalNodeQueue LightRemovalNodeQueue;

void light_node_get_coords(const LightNode *n, SHAPE_COORDS_INT3_T *coords);

LightNodeQueue *light_node_queue_new(void);
void light_node_free(LightNode *n);
void light_node_queue_free(LightNodeQueue *q);
LightNode *light_node_queue_pop(LightNodeQueue *q);
void light_node_queue_push(LightNodeQueue *q, const SHAPE_COORDS_INT3_T *coords);
void light_node_queue_recycle(LightNode *n);

void light_removal_node_get_coords(const LightRemovalNode *n, SHAPE_COORDS_INT3_T *coords);
void light_removal_node_get_light(const LightRemovalNode *n, VERTEX_LIGHT_STRUCT_T *light);
uint8_t light_removal_node_get_srgb(const LightRemovalNode *n);
SHAPE_COLOR_INDEX_INT_T light_removal_node_get_block_id(const LightRemovalNode *n);

LightRemovalNodeQueue *light_removal_node_queue_new(void);
void light_removal_node_queue_free(LightRemovalNodeQueue *q);
LightRemovalNode *light_removal_node_queue_pop(LightRemovalNodeQueue *q);
void light_removal_node_queue_push(LightRemovalNodeQueue *q,
                                   const SHAPE_COORDS_INT3_T *coords,
                                   VERTEX_LIGHT_STRUCT_T light,
                                   uint8_t srgb,
                                   SHAPE_COLOR_INDEX_INT_T blockID);
void light_removal_node_queue_recycle(LightRemovalNode *n);

#ifdef __cplusplus
} // extern "C"
#endif
