/*
 * Mesh vertex shader variant: shadow pass w/ depth packing
 */

// Multiple render target shadow pass w/ depth packing
#define MESH_VARIANT_MRT_LIGHTING 0
#define MESH_VARIANT_MRT_LINEAR_DEPTH 0
#define MESH_VARIANT_MRT_SHADOW_PACK 1
#define MESH_VARIANT_MRT_SHADOW_SAMPLE 0

#include "./vs_mesh_common.sh"