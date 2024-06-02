/*
 * Font vertex shader fallback: uniform vlit
 */
 
// Vertex lighting as color uniform
#define FONT_VARIANT_LIGHTING_UNIFORM 1

// No multiple render target
#define FONT_VARIANT_MRT_LINEAR_DEPTH 0
#define FONT_VARIANT_MRT_TRANSPARENCY 0

#include "./vs_font_common.sh"