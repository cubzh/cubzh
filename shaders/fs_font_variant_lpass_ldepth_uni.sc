/*
 * Font fragment shader variant: lighting pass, linear depth
 */
 
// Vertex lighting as color uniform
#define FONT_VARIANT_UNLIT 0
#define FONT_VARIANT_LIGHTING_UNIFORM 1

// Multiple render target lighting and linear depth
#define FONT_VARIANT_MRT_LIGHTING 1
#define FONT_VARIANT_MRT_LINEAR_DEPTH 1
#define FONT_VARIANT_MRT_PBR 0

#include "./fs_font_common.sh"