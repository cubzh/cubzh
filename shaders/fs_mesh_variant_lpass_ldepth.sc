/*
 * Mesh fragment shader variant: lighting pass, linear depth
 */

// Multiple render target lighting and linear depth
#define MESH_VARIANT_MRT_LIGHTING 1
#define MESH_VARIANT_MRT_LINEAR_DEPTH 1

// No alpha
#define MESH_VARIANT_ALPHA 0

#include "./fs_mesh_common.sh"