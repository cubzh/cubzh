/*
 * Font vertex shader variant: uniform vlit, transparency pass
 */
 
// Vertex lighting as color uniform
#define FONT_VARIANT_LIGHTING_UNIFORM 1

// Multiple render target transparency
#define FONT_VARIANT_MRT_LINEAR_DEPTH 0
#define FONT_VARIANT_MRT_TRANSPARENCY 1

#include "./vs_font_common.sh"