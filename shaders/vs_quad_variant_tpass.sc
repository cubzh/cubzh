/*
 * Quad vertex shader variant: transparency pass
 */

// No lighting
#define QUAD_VARIANT_LIGHTING_UNIFORM 0

// Multiple render target transparency
#define QUAD_VARIANT_MRT_LIGHTING 0
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 0
#define QUAD_VARIANT_MRT_TRANSPARENCY 1
#define QUAD_VARIANT_MRT_SHADOW_PACK 0
#define QUAD_VARIANT_MRT_SHADOW_SAMPLE 0

// No texture
#define QUAD_VARIANT_TEX 0

#include "./vs_quad_common.sh"