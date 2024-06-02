/*
 * Quad fragment shader variant: textured
 */
 
// Lit
#define QUAD_VARIANT_UNLIT 0

// No multiple render target
#define QUAD_VARIANT_MRT_LIGHTING 0
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 0

// Textured
#define QUAD_VARIANT_TEX 1

#include "./fs_quad_common.sh"