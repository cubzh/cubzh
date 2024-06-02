/*
 * Quad fragment shader variant: lighting pass, textured
 */
 
// Lit
#define QUAD_VARIANT_UNLIT 0

// Multiple render target lighting
#define QUAD_VARIANT_MRT_LIGHTING 1
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 0

// Textured
#define QUAD_VARIANT_TEX 1

#include "./fs_quad_common.sh"