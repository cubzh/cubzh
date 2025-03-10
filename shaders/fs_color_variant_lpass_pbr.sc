/*
 * Color fragment shader variant: lighting pass, pbr
 */

// Multiple render target lighting w/ pbr
#define COLOR_VARIANT_MRT_LIGHTING 1
#define COLOR_VARIANT_MRT_LINEAR_DEPTH 0
#define COLOR_VARIANT_MRT_PBR 1

#include "./fs_color_common.sh"
