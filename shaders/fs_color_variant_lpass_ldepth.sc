/*
 * Color fragment shader variant: lighting pass, linear depth
 */

// Multiple render target lighting and linear depth
#define COLOR_VARIANT_MRT_LIGHTING 1
#define COLOR_VARIANT_MRT_LINEAR_DEPTH 1
#define COLOR_VARIANT_MRT_PBR 0

#include "./fs_color_common.sh"
