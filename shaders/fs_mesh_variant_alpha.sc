/*
 * Mesh fragment shader variant: alpha
 */

// No multiple render target
#define MESH_VARIANT_MRT_LIGHTING 0
#define MESH_VARIANT_MRT_LINEAR_DEPTH 0
#define MESH_VARIANT_MRT_PBR 0

// Use alpha
#define MESH_VARIANT_ALPHA 1

// No cutout
#define MESH_VARIANT_CUTOUT 0

#include "./fs_mesh_common.sh"