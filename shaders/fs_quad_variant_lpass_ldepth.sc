/*
 * Quad fragment shader variant: lighting pass, linear depth
 */

// Multiple render target lighting and linear depth
#define QUAD_VARIANT_MRT_LIGHTING 1
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 1

// No texture
#define QUAD_VARIANT_TEX 0
#define QUAD_VARIANT_CUTOUT 0

#include "./fs_quad_common.sh"