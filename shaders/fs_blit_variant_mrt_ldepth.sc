/*
 * Blit final output fragment shader variant: lighting/transparency pass, linear depth
 *
 * Check shader fs_transparency_weight.sc for details on the transparency blending
 */

// Multiple render target lighting/transparency
#define BLIT_VARIANT_MRT 1

// No alpha, used for backbuffer
#define BLIT_VARIANT_WRITEALPHA 0

// Linear depth from g-buffer
#define BLIT_VARIANT_LINEAR_DEPTH 1

#include "./fs_blit_common.sh"
