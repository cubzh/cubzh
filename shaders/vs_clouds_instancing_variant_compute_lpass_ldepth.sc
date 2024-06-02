/*
 * Instanced clouds vertex shader variant: compute, lighting pass, linear depth
 */

// Instances are animated w/ compute
#define SKY_VARIANT_COMPUTE 1

// Multiple render target lighting and linear depth
#define SKY_VARIANT_MRT_LIGHTING 1
#define SKY_VARIANT_MRT_LINEAR_DEPTH 1

#include "./vs_clouds_instancing_common.sh"
