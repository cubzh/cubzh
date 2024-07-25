/*
 * Font vertex shader variant: unlit, lighting pass, linear depth
 */

// Unlit
#define FONT_VARIANT_UNLIT 1

// Multiple render target lighting and linear depth
#define FONT_VARIANT_MRT_LIGHTING 1
#define FONT_VARIANT_MRT_LINEAR_DEPTH 1

#include "./fs_font_common.sh"