/*
 * Font vertex shader variant: transparency pass
 */

// No lighting
#define FONT_VARIANT_LIGHTING_UNIFORM 0

// Multiple render target transparency
#define FONT_VARIANT_MRT_LINEAR_DEPTH 0
#define FONT_VARIANT_MRT_TRANSPARENCY 1

#include "./vs_font_common.sh"