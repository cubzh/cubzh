$input v_texcoord0

#include "./include/bgfx.sh"
#include "./include/config.sh"
#include "./include/antialiasing_lib.sh"
#if POST_DITHERING
#include "./include/dithering_lib.sh"
#endif

#define uv v_texcoord0.xy
#define pos v_texcoord0.zw

SAMPLER2D(s_fb1, 0);

uniform vec4 u_params;
#define texelSize u_params.xy

void main() {
	vec4 color = texture2D(s_fb1, uv);

#if POST_VARIANT_FXAA
	color.rgb = simpleFxaa(s_fb1, uv, texelSize, color.rgb);
#endif

#if POST_DITHERING
	color.xyz = dither(pos, uv, color.xyz);
#endif

	gl_FragColor = color;
}
