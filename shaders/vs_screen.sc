$input a_position, a_texcoord0
$output v_texcoord0

/*
 * Screen coordinates vertex shader
 */

#include "./include/bgfx.sh"

void main() {
	gl_Position = mul(u_modelViewProj, vec4(a_position.xy, 0.0, 1.0));
	v_texcoord0 = vec4(a_position.zw, a_position.xy);
}
