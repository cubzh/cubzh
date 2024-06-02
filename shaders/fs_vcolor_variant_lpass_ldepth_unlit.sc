/*
 * Vertex color fragment shader variant: unlit, lighting pass, linear depth
 */

// Unlit
#define VCOLOR_VARIANT_UNLIT 1

// Multiple render target lighting and linear depth
#define VCOLOR_VARIANT_MRT_LIGHTING 1
#define VCOLOR_VARIANT_MRT_LIGHTING_PRELIT 0
#define VCOLOR_VARIANT_MRT_LINEAR_DEPTH 1

#include "./fs_vcolor_common.sh"
