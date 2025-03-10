/*
 * Vertex color fragment shader variant: lighting pass
 */

// Lit
#define VCOLOR_VARIANT_UNLIT 0

// Multiple render target lighting
#define VCOLOR_VARIANT_MRT_LIGHTING 1
#define VCOLOR_VARIANT_MRT_LIGHTING_PRELIT 0
#define VCOLOR_VARIANT_MRT_LINEAR_DEPTH 0
#define VCOLOR_VARIANT_MRT_PBR 0

#include "./fs_vcolor_common.sh"
