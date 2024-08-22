/*
 * Quad fragment shader variant: alpha
 */

// No multiple render target
#define QUAD_VARIANT_MRT_LIGHTING 0
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 0

// No texture
#define QUAD_VARIANT_TEX 0
#define QUAD_VARIANT_CUTOUT 0

// Use alpha
#define QUAD_VARIANT_ALPHA 1

#include "./fs_quad_common.sh"