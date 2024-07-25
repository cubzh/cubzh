/*
 * Quad fragment shader fallback
 */

// No multiple render target
#define QUAD_VARIANT_MRT_LIGHTING 0
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 0

// No texture
#define QUAD_VARIANT_TEX 0

// No cutout
#define QUAD_VARIANT_CUTOUT 0

#include "./fs_quad_common.sh"