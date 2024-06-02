/*
 * Quad fragment shader variant: lighting pass, linear depth, textured
 */
 
// Lit
#define QUAD_VARIANT_UNLIT 0

// Multiple render target lighting and linear depth
#define QUAD_VARIANT_MRT_LIGHTING 1
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 1

// Textured
#define QUAD_VARIANT_TEX 1

#include "./fs_quad_common.sh"