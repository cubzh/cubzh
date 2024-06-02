/*
 * Quad vertex shader variant: uniform vlit, lighting pass, textured
 */
 
// Vertex lighting as color uniform
#define QUAD_VARIANT_LIGHTING_UNIFORM 1

// Multiple render target lighting
#define QUAD_VARIANT_MRT_LIGHTING 1
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 0
#define QUAD_VARIANT_MRT_TRANSPARENCY 0
#define QUAD_VARIANT_MRT_SHADOW_PACK 0
#define QUAD_VARIANT_MRT_SHADOW_SAMPLE 0

// Textured
#define QUAD_VARIANT_TEX 1

#include "./vs_quad_common.sh"