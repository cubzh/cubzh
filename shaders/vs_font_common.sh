$input a_position, a_color0, a_texcoord0
#if FONT_VARIANT_MRT_TRANSPARENCY
$output v_color0, v_texcoord0, v_texcoord1
	#define v_clipZ v_texcoord1.x
#elif FONT_VARIANT_LIGHTING_UNIFORM || FONT_VARIANT_MRT_LINEAR_DEPTH
$output v_color0, v_texcoord0, v_texcoord1
	#define v_linearDepth v_texcoord1.x
	#define v_clipZ v_texcoord1.y
#else
$output v_color0, v_texcoord0
#endif

#include "./include/bgfx.sh"
#include "./include/config.sh"

void main() {
	vec4 model = vec4(a_position.xy, 0.0, 1.0);
	vec4 clip = mul(u_modelViewProj, model);
#if FONT_VARIANT_MRT_LINEAR_DEPTH
	vec4 view = mul(u_modelView, model);
#endif

	gl_Position = clip;
	v_texcoord0 = a_texcoord0;
	v_color0 = a_color0;
#if FONT_VARIANT_MRT_TRANSPARENCY
	v_clipZ = clip.z;
#else
#if FONT_VARIANT_MRT_LINEAR_DEPTH
	v_linearDepth = view.z;
#endif
#if FONT_VARIANT_LIGHTING_UNIFORM
	v_clipZ = clip.z;
#endif
#endif // FONT_VARIANT_MRT_TRANSPARENCY
}
