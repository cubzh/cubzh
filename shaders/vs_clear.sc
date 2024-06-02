$input a_position

/*
 * Clear vertex shader
 */

#include "./include/bgfx.sh"

void main() {
	gl_Position = mul(u_modelViewProj, vec4(a_position.xyz, 1.0));
}
