/*
 * Quad vertex shader variant: shadow pass w/ shadow sampler
 */

// Multiple render target shadow w/ depth sampling
#define QUAD_VARIANT_MRT_LIGHTING 0
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 0
#define QUAD_VARIANT_MRT_TRANSPARENCY 0
#define QUAD_VARIANT_MRT_SHADOW_PACK 0
#define QUAD_VARIANT_MRT_SHADOW_SAMPLE 1

// No texture
#define QUAD_VARIANT_TEX 0

#include "./vs_quad_common.sh"