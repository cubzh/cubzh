/*
 * Vertex color fragment shader fallback
 */

// Lit
#define VCOLOR_VARIANT_UNLIT 0

// No multiple render target
#define VCOLOR_VARIANT_MRT_LIGHTING 0
#define VCOLOR_VARIANT_MRT_LIGHTING_PRELIT 0
#define VCOLOR_VARIANT_MRT_LINEAR_DEPTH 0
#define VCOLOR_VARIANT_MRT_PBR 0

#include "./fs_vcolor_common.sh"
