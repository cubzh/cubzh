/*
 * Mesh vertex shader variant: lighting pass, linear depth
 */

// Multiple render target lighting and linear depth
#define MESH_VARIANT_MRT_LIGHTING 1
#define MESH_VARIANT_MRT_LINEAR_DEPTH 1
#define MESH_VARIANT_MRT_SHADOW_PACK 0
#define MESH_VARIANT_MRT_SHADOW_SAMPLE 0

#include "./vs_mesh_common.sh"