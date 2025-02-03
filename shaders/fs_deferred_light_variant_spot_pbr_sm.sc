/*
 * Deferred light shader variant: spot, shadows, PBR
 */

// Spot light
#define LIGHT_VARIANT_TYPE_POINT 0
#define LIGHT_VARIANT_TYPE_SPOT 1
#define LIGHT_VARIANT_TYPE_DIRECTIONAL 0

// Depth from depth buffer
#define LIGHT_VARIANT_LINEAR_DEPTH 0

// Shadows w/ depth packing
#define LIGHT_VARIANT_SHADOW_PACK 1
#define LIGHT_VARIANT_SHADOW_SAMPLE 0
#define LIGHT_VARIANT_SHADOW_CSM 0
#define LIGHT_VARIANT_SHADOW_SOFT 0

// PBR model
#define LIGHT_VARIANT_PBR 1

#include "./fs_deferred_light_common.sh"