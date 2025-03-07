/*
 * Mesh vertex shader variant: shadow pass w/ shadow sampler
 */

// Multiple render target shadow pass w/ depth sampling
#define MESH_VARIANT_MRT_LIGHTING 0
#define MESH_VARIANT_MRT_LINEAR_DEPTH 0
#define MESH_VARIANT_MRT_SHADOW_PACK 0
#define MESH_VARIANT_MRT_SHADOW_SAMPLE 1

#include "./vs_mesh_common.sh"