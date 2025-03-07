/*
 * Font vertex shader variant: unlit, lighting pass, pbr, linear depth
 */

// Unlit
#define FONT_VARIANT_UNLIT 1

// Multiple render target lighting w/ pbr and linear depth
#define FONT_VARIANT_MRT_LIGHTING 1
#define FONT_VARIANT_MRT_LINEAR_DEPTH 1
#define FONT_VARIANT_MRT_PBR 1

#include "./fs_font_common.sh"