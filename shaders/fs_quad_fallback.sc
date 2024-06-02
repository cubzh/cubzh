/*
 * Quad fragment shader fallback
 */
 
// Lit
#define QUAD_VARIANT_UNLIT 0

// No multiple render target
#define QUAD_VARIANT_MRT_LIGHTING 0
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 0

// No texture
#define QUAD_VARIANT_TEX 0

#include "./fs_quad_common.sh"