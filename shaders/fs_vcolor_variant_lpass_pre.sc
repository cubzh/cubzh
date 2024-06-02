/*
 * Vertex color fragment shader variant: lighting pass, pre-lit
 */

// Lit
#define VCOLOR_VARIANT_UNLIT 0

// Multiple render target lighting & pre-lit
#define VCOLOR_VARIANT_MRT_LIGHTING 1
#define VCOLOR_VARIANT_MRT_LIGHTING_PRELIT 1
#define VCOLOR_VARIANT_MRT_LINEAR_DEPTH 0

#include "./fs_vcolor_common.sh"
