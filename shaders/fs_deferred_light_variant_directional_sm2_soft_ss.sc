/*
 * Deferred light shader variant: directional, shadows
 */

// Directional light
#define LIGHT_VARIANT_TYPE_POINT 0
#define LIGHT_VARIANT_TYPE_SPOT 0
#define LIGHT_VARIANT_TYPE_DIRECTIONAL 1

// Depth from depth buffer
#define LIGHT_VARIANT_LINEAR_DEPTH 0

// Shadows w/ sampler, 2 cascades, soft
#define LIGHT_VARIANT_SHADOW_PACK 0
#define LIGHT_VARIANT_SHADOW_SAMPLE 1
#define LIGHT_VARIANT_SHADOW_CSM 2
#define LIGHT_VARIANT_SHADOW_SOFT 1

#include "./fs_deferred_light_common.sh"