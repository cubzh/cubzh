/*
 * Font fragment shader variant: unlit, lighting pass, cutout
 */

// Unlit
#define FONT_VARIANT_UNLIT 1

// Multiple render target lighting
#define FONT_VARIANT_MRT_LIGHTING 1
#define FONT_VARIANT_MRT_LINEAR_DEPTH 0

// Cutout
#define FONT_VARIANT_CUTOUT 1

#include "./fs_font_common.sh"