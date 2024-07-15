$input v_color0, v_texcoord0
	#define v_uv v_color0.yz
	#define v_normal v_texcoord0.xyz

/*
 * Clear fragment shader w/ texture cutout
 */

#include "./include/bgfx.sh"
#include "./include/utils_lib.sh"
#include "./include/quad_lib.sh"

SAMPLER2D(s_fb1, 0);

uniform vec4 u_params;
	#define u_slice u_params.xy
	#define u_uBorders u_params.zw
uniform vec4 u_color1;
	#define u_vBorders u_color1.xy
	#define u_cutout u_color1.z

void main() {
	vec2 uv = vec2(sliceUV(v_uv.x, u_uBorders, u_slice.x),
				   sliceUV(v_uv.y, u_vBorders, u_slice.y));
	
	float alpha = texture2D(s_fb1, uv).a;

	if (alpha <= u_cutout) discard;

	gl_FragColor = vec4_splat(0.0);
}
