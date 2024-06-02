/*
 * Font vertex shader variant: linear depth
 */

// No lighting
#define FONT_VARIANT_LIGHTING_UNIFORM 0

// Multiple render target linear depth
#define FONT_VARIANT_MRT_LINEAR_DEPTH 1
#define FONT_VARIANT_MRT_TRANSPARENCY 0

#include "./vs_font_common.sh"