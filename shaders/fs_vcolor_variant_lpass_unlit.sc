/*
 * Vertex color fragment shader variant: unlit, lighting pass
 */

// Unlit
#define VCOLOR_VARIANT_UNLIT 1

// Multiple render target lighting
#define VCOLOR_VARIANT_MRT_LIGHTING 1
#define VCOLOR_VARIANT_MRT_LIGHTING_PRELIT 0
#define VCOLOR_VARIANT_MRT_LINEAR_DEPTH 0

#include "./fs_vcolor_common.sh"
