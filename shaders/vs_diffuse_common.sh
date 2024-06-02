$input a_position, a_texcoord0
#if DIFFUSE_VARIANT_MRT_TRANSPARENCY
$output v_color0, v_texcoord0, v_texcoord1
	#define v_model v_texcoord1.xyz
	#define v_clipZ v_texcoord1.w
#else
$output v_color0, v_texcoord0
#endif

/*
 * Diffuse vertex shader
 */

#include "./include/bgfx.sh"

uniform vec4 u_color1;

void main() {
	vec4 model = vec4(a_position.xyz, 1.0);
	vec4 clip = mul(u_modelViewProj, model);

	gl_Position = clip;
	v_texcoord0 = a_texcoord0;
	v_color0 = a_position.w * u_color1;
#if DIFFUSE_VARIANT_MRT_TRANSPARENCY
	v_model = model.xyz;
	v_clipZ = clip.z;
#endif
}
