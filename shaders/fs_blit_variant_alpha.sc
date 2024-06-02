/*
 * Blit final output fragment shader variant: alpha
 */

// No multiple render target
#define BLIT_VARIANT_MRT 0

// Write alpha, used if frame output is read back
#define BLIT_VARIANT_WRITEALPHA 1

// Depth from depth buffer
#define BLIT_VARIANT_LINEAR_DEPTH 0

#include "./fs_blit_common.sh"
