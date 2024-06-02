/*
 * Instanced clouds vertex shader variant: compute
 */

// Instances are animated w/ compute
#define SKY_VARIANT_COMPUTE 1

// No multiple render target
#define SKY_VARIANT_MRT_LIGHTING 0
#define SKY_VARIANT_MRT_LINEAR_DEPTH 0

#include "./vs_clouds_instancing_common.sh"
