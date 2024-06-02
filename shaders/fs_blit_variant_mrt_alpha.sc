/*
 * Blit final output fragment shader variant: lighting/transparency pass, alpha
 *
 * Check shader fs_transparency_weight.sc for details on the transparency blending
 */

// Multiple render target lighting/transparency
#define BLIT_VARIANT_MRT 1

// Write alpha, used if frame output is read back
#define BLIT_VARIANT_WRITEALPHA 1

// Depth from depth buffer
#define BLIT_VARIANT_LINEAR_DEPTH 0

#include "./fs_blit_common.sh"
