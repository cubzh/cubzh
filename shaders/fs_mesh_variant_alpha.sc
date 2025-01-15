/*
 * Mesh fragment shader variant: alpha
 */

// No multiple render target
#define MESH_VARIANT_MRT_LIGHTING 0
#define MESH_VARIANT_MRT_LINEAR_DEPTH 0

// Use alpha
#define MESH_VARIANT_ALPHA 1

#include "./fs_mesh_common.sh"