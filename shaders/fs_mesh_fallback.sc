/*
 * Mesh fragment shader fallback
 */

// No multiple render target
#define MESH_VARIANT_MRT_LIGHTING 0
#define MESH_VARIANT_MRT_LINEAR_DEPTH 0

// No alpha
#define MESH_VARIANT_ALPHA 0

#include "./fs_mesh_common.sh"