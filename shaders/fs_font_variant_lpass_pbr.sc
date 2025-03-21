/*
 * Font fragment shader variant: lighting pass, pbr
 */
 
// Lit
#define FONT_VARIANT_UNLIT 0

// Multiple render target lighting w/ pbr
#define FONT_VARIANT_MRT_LIGHTING 1
#define FONT_VARIANT_MRT_LINEAR_DEPTH 0
#define FONT_VARIANT_MRT_PBR 1

#include "./fs_font_common.sh"