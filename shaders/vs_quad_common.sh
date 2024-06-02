#if QUAD_VARIANT_TEX

$input a_position, a_texcoord0, a_color0
#if QUAD_VARIANT_MRT_LIGHTING && QUAD_VARIANT_MRT_LINEAR_DEPTH
$output v_color0, v_color1, v_texcoord0, v_texcoord1
	#define v_lighting v_color1
	#define v_linearDepth v_texcoord1.x
#elif QUAD_VARIANT_MRT_LIGHTING
$output v_color0, v_color1, v_texcoord0
	#define v_lighting v_color1
#elif QUAD_VARIANT_MRT_TRANSPARENCY
$output v_color0, v_texcoord0, v_texcoord1
	#define v_model v_texcoord1.xyz
	#define v_clipZ v_texcoord1.w
#else
$output v_color0, v_texcoord0
#endif

#else // QUAD_VARIANT_TEX

$input a_position, a_color0
#if QUAD_VARIANT_MRT_LIGHTING && QUAD_VARIANT_MRT_LINEAR_DEPTH
$output v_color0, v_color1, v_texcoord0
	#define v_lighting v_color1
	#define v_linearDepth v_texcoord0.x
#elif QUAD_VARIANT_MRT_LIGHTING
$output v_color0, v_color1
	#define v_lighting v_color1
#elif QUAD_VARIANT_MRT_TRANSPARENCY
$output v_color0, v_texcoord0
	#define v_model v_texcoord0.xyz
	#define v_clipZ v_texcoord0.w
#elif QUAD_VARIANT_MRT_SHADOW_SAMPLE == 0
$output v_color0
#endif

#endif // QUAD_VARIANT_TEX

#include "./include/bgfx.sh"
#include "./include/config.sh"
#if QUAD_VARIANT_LIGHTING_UNIFORM
#include "./include/game_uniforms.sh"
#include "./include/voxels_uniforms.sh"
#include "./include/global_lighting_uniforms.sh"
#include "./include/voxels_lib.sh"
#endif

#define IS_SHADOW_PASS (QUAD_VARIANT_MRT_SHADOW_PACK || QUAD_VARIANT_MRT_SHADOW_SAMPLE)

#if QUAD_VARIANT_LIGHTING_UNIFORM || QUAD_VARIANT_MRT_LIGHTING
uniform vec4 u_lighting;
	#define lightValue u_lighting.x
	#define emissive u_lighting.yzw
	#define ambient u_sunColor.xyz
#endif

void main() {
	vec4 model = vec4(a_position.xyz, 1.0);
	vec4 clip = mul(u_modelViewProj, model);

#if IS_SHADOW_PASS

	gl_Position = clip;
#if QUAD_VARIANT_MRT_SHADOW_PACK
	v_color0 = clip;
#endif

#else // IS_SHADOW_PASS

#if QUAD_VARIANT_MRT_LINEAR_DEPTH
	vec4 view = mul(u_modelView, model);
#endif

	vec4 color = a_color0;
#if QUAD_VARIANT_LIGHTING_UNIFORM && QUAD_VARIANT_MRT_LIGHTING == 0
	color = getNonVolumeVertexLitColor(color, lightValue, emissive, ambient, clip.z);
#endif

	gl_Position = clip;
	v_color0 = color;
#if QUAD_VARIANT_TEX
	v_texcoord0 = a_texcoord0;
#endif
#if QUAD_VARIANT_MRT_LIGHTING
#if QUAD_VARIANT_LIGHTING_UNIFORM
	v_lighting = u_lighting;
#else
	v_lighting = VOXEL_LIGHT_DEFAULT_SRGB;
#endif // QUAD_VARIANT_LIGHTING_UNIFORM
#if QUAD_VARIANT_MRT_LINEAR_DEPTH
	v_linearDepth = view.z;
#endif // QUAD_VARIANT_MRT_LINEAR_DEPTH
#elif QUAD_VARIANT_MRT_TRANSPARENCY
	v_model = model.xyz;
	v_clipZ = clip.z;
#endif // QUAD_VARIANT_MRT_LIGHTING

#endif // IS_SHADOW_PASS
}
