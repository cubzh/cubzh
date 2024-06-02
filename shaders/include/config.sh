#ifndef __VOXELS_CONFIG_SH__
#define __VOXELS_CONFIG_SH__

#define WHITE vec4(1.0,1.0,1.0,1.0)
#define RED vec4(1.0,0.0,0.0,1.0)
#define GREEN vec4(0.0,1.0,0.0,1.0)
#define BLUE vec4(0.0,0.0,1.0,1.0)
#define MAGENTA vec4(1.0,0.0,1.0,1.0)
#define CYAN vec4(0.0,1.0,1.0,1.0)
#define YELLOW vec4(1.0,1.0,0.0,1.0)
#define BLACK vec4(0.0,0.0,0.0,1.0)
#define CLEAR vec4(0.0,0.0,0.0,0.0)

#define CLAMP01(v) clamp(v, 0.0, 1.0)
#define BLEND_ADDITIVE(a, b) (a + b)
#define BLEND_SOFT_ADDITIVE(a, b) (a * (1.0 - b) + b)
#define BLEND_MULTIPLICATIVE(a, b) (a * b)
#define BLEND_ALPHA(a, b) (a.xyz * a.w + b.xyz * (1.0 - a.w))
#define BLEND_PREMULT_ALPHA(a, b) (a.xyz + b.xyz * (1.0 - a.w))

#define PI 3.14159265
#define AO_HUE_STEP_RAD AO_COLOR_HUE_STEP * PI
#define AO_HUE_THRESHOLD_TARGET_RAD AO_COLOR_HUE_THRESHOLD_TARGET * PI
#define AO_HUE_THRESHOLD_DIR_RAD AO_COLOR_HUE_THRESHOLD_DIR * PI

//// DEBUG
// 0 Disabled
// 1 Draw a different color per face
// 2 Color depth
#define DEBUG_FACE 0
// Use positioning from shader instead of uniform
#define DEBUG_POS_NO_UNIFORM 0
// 0 Disabled
// 1 Global lighting data as color (no unpacking)
// 2 Sunlight as greyscale color
// 3 Red light
// 4 Green light
// 5 Blue light
// 6 combined
#define DEBUG_VERTEX_LIGHTING 0
// 0 Disabled
// 1 Revealage
// 2 Revealage applied to opaque
// 3 Accumulated transparency color
// 4 Weight
// 5 Transparent output
#define DEBUG_TRANSPARENCY 0
// 0 Disabled
// 1 Geometry normals
// 2 Depth (range 0.95-1.0)
// 3 Fragment clip pos
// 4 Fragment world pos (normalized over [-512:512] world units)
// 5 Fragment view vectors (unorm)
// 6 Light range
// 7 Light attenuation
// 8 Fragment depth in light space
// 9 Fragment shadowmap UV
// 10 Fragment shadowmap depth
// 11 Shadows only
// 12 Cutout oversampling
// 13 Shadowmap cascade levels
// 14 Normalized eye-to-far vectors
// 15 Distance normalized on shadows far
#define DEBUG_LIGHTING 0

//// LIGHTING
#define ENABLE_FOG 1
#define ENABLE_FACE_SHADING 1
#define ENABLE_AO 1
// Face shading multipliers
#define FACE_SHADING_TOP 1.05f
#define FACE_SHADING_DOWN 0.96f
// Factor for AO applied to light value, should match engine AO_COEF
#define AO_LIGHT_COEF 0.23
// AO gradient values, should match engine AO_GRADIENT_BASE_F
#define AO_GRADIENT vec4(0.0f, 0.6f, 0.8f, 1.0f)
// Factor for AO color blending, used based on the AO_COLOR mode
#define AO_BLEND_COEF 0.31
// 0 Inverse base color, mixed with base color
// 1 Step hue color, mixed with base color
// 2 Step hue, mixed with base hue
// 3 Step hue color in a direction based on hue thresholds, mixed with base color
// 4 From complementary palette, mixed with base color (same as (3) but offline calculation)
#define AO_COLOR 4
// AO hue step is then multiplied by PI and is added/substracted to base color hue, it corresponds to the AO maximum hue
#define AO_COLOR_HUE_STEP 0.25
// AO hue thresholds are then multiplied by PI and determines the rotation direction ie. whether to substract or add AO hue step
// note: values go from 0 (brown-red) to PI/2 (magenta-purple), -PI (blue-cyan), -PI/2 (green-yellow) back to 0 (brown-red)
// hue is [-PI:-PI] because it is obtained from an atan2 function
// - values in between the thresholds (from 'target' to 'dir' clockwise) use substraction (ie. clockwise)
// - other values use addition (ie. counter-clockwise)
#define AO_COLOR_HUE_THRESHOLD_DIR -0.75 // green
#define AO_COLOR_HUE_THRESHOLD_TARGET 0.75 // blue
// Whether AO_COLOR_HUE_THRESHOLD_TARGET should also min/max hue value to never go past that threshold
#define AO_COLOR_HUE_CLAMP_TARGET 1
// Portion of the light values used in illumination blend (light block effect)
#define VOXEL_LIGHT_RGB_PRE_FACTOR 1.0
#define LIGHT_PRE_FACTOR 1.0
// Portion of the light values added after blend (emissive block effect)
#define VOXEL_LIGHT_RGB_POST_FACTOR 0.2
#define LIGHT_POST_FACTOR 0.8
// 0 Diffuse
// 1 Phong
// 2 Blinn-phong
#define LIGHT_MODEL 2
// Specular parameters (unused for Diffuse), until we have a concept of material per shape, these remain internal constants
#define LIGHT_SPECULAR 0.1f
#define LIGHT_PHONG_SHININESS 16
#define LIGHT_BLINN_SHININESS 32 // for equivalence, 2 to 4 times shininess in Phong
// Condition encoded in normal.xy to set a fragment as translucent (light affects it from any direction)
// Translucency factor (portion of light used) is encoded in normal.y
#define LIGHT_FRAGMENT_TRANSLUCENT vec2(1.0, 1.0)
#define LIGHT_IS_FRAGMENT_TRANSLUCENT(v) step(1.0, normal.x * normal.y)
#define LIGHT_TRANSLUCENCY_FACTOR(v) v.z
// These flags are encoded in g-buffer
#define LIGHTING_LIT_FLAG 0.0
// For deferred lighting, pre-lit fragments already have applied their individual lighting,
// and only need the additive lights contribution
#define LIGHTING_PRELIT_FLAG 0.5
#define LIGHTING_UNLIT_FLAG 1.0
// Minimum amount of light colors used for shadows
#define SHADOWS_AMBIENT_FACTOR 0.17
// Epsilon between fragment depth & shadowmap depth when checking for shadows, it goes from a minimum when NdotL is 1
// to a maximum when NdotL is 0, which is passed as a light property
#define SHADOWMAP_BIAS_ANGLE 0
#define SHADOWMAP_BIAS_MIN 0.0005
// Step up shadow bias at each cascade level
#define SHADOWMAP_BIAS_CASCADE_MULTIPLIER 1.0
// Scale shadow bias proportionnally to fragment distance
#define SHADOWMAP_DISTANCE_BIAS 0
#define SHADOWMAP_BIAS_DIST_MULTIPLIER 1.0
// Scale shadow bias inversely proportional to shadowmap reference size
#define SHADOWMAP_REF_SIZE 4096.0
// 0 No filtering (hard shadows)
// 1 Percentage-Closer Filtering (PCF) 4 samples : 2x2 texels
// 2 PCF 9 samples : 3x3 texels
// 3 PCF 16 samples : 4x4 unaligned texels
// 4 PCF 16 / 4 samples : 2x2 texels based on screen pos
#define SHADOWMAP_FILTERING 2
#define SHADOWMAP_FILTERING_BLUR vec2(1.0, 1.0)
// Fades shadows out instead of cutting when outside shadowmap
#define SHADOWMAP_SOFT_OVERSAMPLING 1
#define SHADOWMAP_SOFT_OVERSAMPLING_EDGE_MAX 0.9
#define SHADOWMAP_SOFT_OVERSAMPLING_EDGE_MIN 0.1

//// SKYBOX/SKY
#define SKYBOX_FOV 45.0
#define SKYBOX_COLOURING_ENABLED 0
#define CLOUDS_EPSILON 0.05
// Clouds lit color blend factor with background color (sky color)
#define CLOUDS_BLEND_COLOR 0.3
#define CLOUDS_NEAR_ZFIGHT_ENABLED 0
#define CLOUDS_TRANSLUCENCY 0.5

//// TRANSPARENCY
// 0 No weight
// 1+ see functions in fs_transparency_weight
#define WEIGHT_FUNC 4

//// DITHERING
// 0 Disabled
// 1 Nrand+Srand (clean but expensive)
// 2 Nrand
// 3 Screenspace dithering from Valve
// 4 Interleaved gradient noise from COD:Advanced Warfare
#define DITHERING_FUNC 2
#define SKYBOX_DITHERING 1
// Note: may be too late to dither in post if the banding occured before quantisation into textures,
// as it seems to be the case currently, banding occurs in skybox & voxels colouring
#define POST_DITHERING 0

//// GRID
// Grid distance is expressed in model space
// Note: depth is normalized by lossy scale to keep consistent look w.r.t. world scaling
#define GRID_FADE_DISTANCE 60.0
#define GRID_MAX_DISTANCE 100.0
#define GRID_FADE_LENGTH 40.0 // GRID_MAX_DISTANCE - GRID_FADE_DISTANCE
#define GRID_COLOR vec3(.9, .9, .9)
// Corresponds to the tangent of the desired thickness angle for grid lines, currently tan(0.1),
// from the legacy shader & iOS app =)
#define GRID_THICKNESS_FACTOR .001745331024

//// GENERAL
// UV go from 0 to 1, edge to edge of the texture ; when computing texel index, we need to apply an offset
#define TEXEL_OFFSET 0.5
// Fudging the index helps to avoid precision errors, observed on GLES
#define IDX_FUDGE 0.1
#define UNPACK_FUDGE 0.5
// Compute worker group size, 128 is the minimum for GLES/Vulkan (GL = 256, DX/Metal/etc = 512)
#define COMPUTE_GROUP_SIZE 128
// Where applicable will compare floats in the range provided by this epsilon (inclusive)
#define EPSILON 0.01
#define FLAG_EPSILON 0.05
// Engine-side max value for vertex lighting
#define VOXEL_LIGHT_MAX 15.0
#define VOXEL_LIGHT_DEFAULT_SRGB vec4(1.0, 0.0, 0.0, 0.0)
#define VOXEL_LIGHT_DEFAULT_RGBS vec4(0.0, 0.0, 0.0, 1.0)

#endif // __VOXELS_CONFIG_SH__
