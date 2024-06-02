/*
 * Vertex color fragment shader variant: lighting pass, pre-lit, linear depth
 */

// Lit
#define VCOLOR_VARIANT_UNLIT 0

// Multiple render target lighting, pre-lit and linear depth
#define VCOLOR_VARIANT_MRT_LIGHTING 1
#define VCOLOR_VARIANT_MRT_LIGHTING_PRELIT 1
#define VCOLOR_VARIANT_MRT_LINEAR_DEPTH 1

#include "./fs_vcolor_common.sh"
