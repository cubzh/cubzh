/*
 * Quad fragment shader variant: textured
 */

// No multiple render target
#define QUAD_VARIANT_MRT_LIGHTING 0
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 0

// Textured
#define QUAD_VARIANT_TEX 1
#define QUAD_VARIANT_CUTOUT 0

// No alpha
#define QUAD_VARIANT_ALPHA 0

#include "./fs_quad_common.sh"