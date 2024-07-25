/*
 * Quad vertex shader variant: shadow pass w/ depth packing, texture cutout
 */

// Multiple render target shadow w/ depth packing
#define QUAD_VARIANT_MRT_LIGHTING 0
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 0
#define QUAD_VARIANT_MRT_TRANSPARENCY 0
#define QUAD_VARIANT_MRT_SHADOW_PACK 1
#define QUAD_VARIANT_MRT_SHADOW_SAMPLE 0

// Texture cutout
#define QUAD_VARIANT_TEX 1
#define QUAD_VARIANT_CUTOUT 1

#include "./vs_quad_common.sh"