/*
 * Quad fragment shader variant: lighting pass, textured, cutout
 */

// Multiple render target lighting
#define QUAD_VARIANT_MRT_LIGHTING 1
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 0
#define QUAD_VARIANT_MRT_PBR 0

// Textured cutout
#define QUAD_VARIANT_TEX 1
#define QUAD_VARIANT_CUTOUT 1

// No alpha
#define QUAD_VARIANT_ALPHA 0

#include "./fs_quad_common.sh"