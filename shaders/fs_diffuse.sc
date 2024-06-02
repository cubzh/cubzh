$input v_color0, v_texcoord0

/*
 * Diffuse fragment shader
 */

#include "./include/bgfx.sh"

#define uv v_texcoord0.xy
#define tiling v_texcoord0.z
#define offset v_texcoord0.w

SAMPLER2D(s_diffuse, 0);

void main() {
	gl_FragColor = v_color0 * texture2D(s_diffuse, tiling * uv + offset);
}
