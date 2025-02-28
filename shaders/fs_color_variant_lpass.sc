/*
 * Color fragment shader variant: lighting pass
 */

// Multiple render target lighting
#define COLOR_VARIANT_MRT_LIGHTING 1
#define COLOR_VARIANT_MRT_LINEAR_DEPTH 0
#define COLOR_VARIANT_MRT_PBR 0

#include "./fs_color_common.sh"
