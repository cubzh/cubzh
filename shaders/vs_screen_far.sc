$input a_position, a_texcoord0
$output v_texcoord0, v_texcoord1

/*
 * Screen coordinates vertex shader w/ eye distance to far points
 */

#include "./include/bgfx.sh"

void main() {
	gl_Position = mul(u_modelViewProj, vec4(a_position.xy, 0.0, 1.0));
	v_texcoord0 = vec4(a_position.zw, a_position.xy);
	v_texcoord1 = vec4(a_texcoord0.xyz, 0.0);
}
