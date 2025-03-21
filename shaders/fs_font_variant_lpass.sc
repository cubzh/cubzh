/*
 * Font fragment shader variant: lighting pass
 */
 
// Lit
#define FONT_VARIANT_UNLIT 0

// Multiple render target lighting
#define FONT_VARIANT_MRT_LIGHTING 1
#define FONT_VARIANT_MRT_LINEAR_DEPTH 0
#define FONT_VARIANT_MRT_PBR 0

#include "./fs_font_common.sh"