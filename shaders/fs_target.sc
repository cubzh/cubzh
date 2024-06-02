$input v_texcoord0

/*
 * Target fragment shader
 */

#include "./include/bgfx.sh"

#define uv v_texcoord0.xy

SAMPLER2D(s_fb1, 0);

void main() {
	gl_FragColor = texture2D(s_fb1, uv);
}
