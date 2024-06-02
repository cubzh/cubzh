$input v_texcoord0, v_color0

/*
 * Debug UV fragment shader
 */

#include "./include/bgfx.sh"

void main() {
	gl_FragColor = vec4(v_texcoord0.x, 0.0, v_texcoord0.y, 1.0);
}
