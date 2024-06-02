/*
 * Quad fragment shader variant: unlit, lighting pass, textured
 */

// Unlit
#define QUAD_VARIANT_UNLIT 1

// Multiple render target lighting
#define QUAD_VARIANT_MRT_LIGHTING 1
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 0

// Textured
#define QUAD_VARIANT_TEX 1

#include "./fs_quad_common.sh"