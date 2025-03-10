/*
 * Mesh fragment shader variant: cutout
 */

// No multiple render target
#define MESH_VARIANT_MRT_LIGHTING 0
#define MESH_VARIANT_MRT_LINEAR_DEPTH 0
#define MESH_VARIANT_MRT_PBR 0

// No alpha
#define MESH_VARIANT_ALPHA 0

// Cutout
#define MESH_VARIANT_CUTOUT 1

#include "./fs_mesh_common.sh"