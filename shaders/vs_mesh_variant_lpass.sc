/*
 * Mesh vertex shader variant: lighting pass
 */

// Multiple render target lighting
#define MESH_VARIANT_MRT_LIGHTING 1
#define MESH_VARIANT_MRT_LINEAR_DEPTH 0
#define MESH_VARIANT_MRT_SHADOW_PACK 0
#define MESH_VARIANT_MRT_SHADOW_SAMPLE 0

#include "./vs_mesh_common.sh"