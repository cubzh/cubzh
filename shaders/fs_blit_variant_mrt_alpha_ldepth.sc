/*
 * Blit final output fragment shader variant: lighting pass, alpha, linear depth
 *
 * Check shader fs_transparency_weight.sc for details on the transparency blending
 */

// Multiple render target lighting
#define BLIT_VARIANT_MRT 1

// Write alpha, used if frame output is read back
#define BLIT_VARIANT_WRITEALPHA 1

// Linear depth from g-buffer
#define BLIT_VARIANT_LINEAR_DEPTH 1

#include "./fs_blit_common.sh"
