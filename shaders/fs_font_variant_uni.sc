/*
 * Font fragment shader variant: uniform vlit
 */
 
// Vertex lighting as color uniform
#define FONT_VARIANT_UNLIT 0
#define FONT_VARIANT_LIGHTING_UNIFORM 1

// No multiple render target
#define FONT_VARIANT_MRT_LIGHTING 0
#define FONT_VARIANT_MRT_LINEAR_DEPTH 0

// Cutout
#define FONT_VARIANT_CUTOUT 0

#include "./fs_font_common.sh"