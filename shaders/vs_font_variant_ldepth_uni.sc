/*
 * Font vertex shader variant: uniform vlit, linear depth
 */
 
// Vertex lighting as color uniform
#define FONT_VARIANT_LIGHTING_UNIFORM 1

// Multiple render target linear depth
#define FONT_VARIANT_MRT_LINEAR_DEPTH 1
#define FONT_VARIANT_MRT_TRANSPARENCY 0

#include "./vs_font_common.sh"