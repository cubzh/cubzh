$input a_position
$output v_color0

/*
 * Position vertex shader
 */

#include "./include/bgfx.sh"

#define v_position v_color0

void main() {
	gl_Position = mul(u_modelViewProj, vec4(a_position.xyz, 1.0));
	v_position = gl_Position;
}