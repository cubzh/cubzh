/*
 * Font vertex shader fallback
 */

// No lighting
#define FONT_VARIANT_LIGHTING_UNIFORM 0

// No multiple render target
#define FONT_VARIANT_MRT_LINEAR_DEPTH 0
#define FONT_VARIANT_MRT_TRANSPARENCY 0

#include "./vs_font_common.sh"