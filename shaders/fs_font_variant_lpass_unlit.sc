/*
 * Font fragment shader variant: unlit, lighting pass
 */

// Unlit
#define FONT_VARIANT_UNLIT 1

// Multiple render target lighting
#define FONT_VARIANT_MRT_LIGHTING 1
#define FONT_VARIANT_MRT_LINEAR_DEPTH 0
#define FONT_VARIANT_MRT_PBR 0

#include "./fs_font_common.sh"