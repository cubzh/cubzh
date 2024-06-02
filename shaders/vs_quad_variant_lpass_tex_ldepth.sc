/*
 * Quad vertex shader variant: lighting pass, linear depth, textured
 */

// No lighting
#define QUAD_VARIANT_LIGHTING_UNIFORM 0

// Multiple render target lighting and linear depth
#define QUAD_VARIANT_MRT_LIGHTING 1
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 1
#define QUAD_VARIANT_MRT_TRANSPARENCY 0
#define QUAD_VARIANT_MRT_SHADOW_PACK 0
#define QUAD_VARIANT_MRT_SHADOW_SAMPLE 0

// Textured
#define QUAD_VARIANT_TEX 1

#include "./vs_quad_common.sh"