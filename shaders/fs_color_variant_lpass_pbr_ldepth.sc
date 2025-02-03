/*
 * Color fragment shader variant: lighting pass, pbr, linear depth
 */

// Multiple render target lighting w/ pbr and linear depth
#define COLOR_VARIANT_MRT_LIGHTING 1
#define COLOR_VARIANT_MRT_LINEAR_DEPTH 1
#define COLOR_VARIANT_MRT_PBR 1

#include "./fs_color_common.sh"
