/*
 * Blit final output fragment shader fallback
 */

// No multiple render target
#define BLIT_VARIANT_MRT 0

// No alpha, used for backbuffer
#define BLIT_VARIANT_WRITEALPHA 0

// Depth from depth buffer
#define BLIT_VARIANT_LINEAR_DEPTH 0

#include "./fs_blit_common.sh"
