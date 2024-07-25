/*
 * Font fragment shader fallback
 */
 
// Lit
#define FONT_VARIANT_UNLIT 0
#define FONT_VARIANT_LIGHTING_UNIFORM 0

// No multiple render target
#define FONT_VARIANT_MRT_LIGHTING 0
#define FONT_VARIANT_MRT_LINEAR_DEPTH 0

#include "./fs_font_common.sh"