/*
 * Quad fragment shader variant: unlit, lighting pass
 */

// Unlit
#define QUAD_VARIANT_UNLIT 1

// Multiple render target lighting
#define QUAD_VARIANT_MRT_LIGHTING 1
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 0

// No texture
#define QUAD_VARIANT_TEX 0

#include "./fs_quad_common.sh"