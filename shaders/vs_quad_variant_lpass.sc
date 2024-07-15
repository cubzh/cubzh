/*
 * Quad vertex shader variant: lighting pass
 */

// Multiple render target lighting
#define QUAD_VARIANT_MRT_LIGHTING 1
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 0
#define QUAD_VARIANT_MRT_TRANSPARENCY 0
#define QUAD_VARIANT_MRT_SHADOW_PACK 0
#define QUAD_VARIANT_MRT_SHADOW_SAMPLE 0

// No texture
#define QUAD_VARIANT_TEX 0
#define QUAD_VARIANT_CUTOUT 0

#include "./vs_quad_common.sh"