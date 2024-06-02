$input a_position, a_color0
$output v_color0

/*
 * Vertex color vertex shader
 */

#include "./include/bgfx.sh"

void main() {
	gl_Position = mul(u_modelViewProj, vec4(a_position.xyz, 1.0) );
	v_color0 = a_position.w * a_color0;
}
