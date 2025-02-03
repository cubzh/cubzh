$input v_texcoord0, v_color0

#include "./include/bgfx.sh"
#include "./include/config.sh"

uniform vec4 u_color1;

void main() {
#if COLOR_VARIANT_MRT_LIGHTING
	gl_FragData[0] = u_color1;
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, LIGHTING_UNLIT_FLAG);
	gl_FragData[2] = VOXEL_LIGHT_DEFAULT_RGBS;
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, LIGHTING_UNLIT_FLAG);
#if COLOR_VARIANT_MRT_PBR && COLOR_VARIANT_MRT_LINEAR_DEPTH
    gl_FragData[4] = vec4_splat(0.0);
    gl_FragData[5] = vec4_splat(0.0);
#elif COLOR_VARIANT_MRT_PBR
    gl_FragData[4] = vec4_splat(0.0);
#elif COLOR_VARIANT_MRT_LINEAR_DEPTH
    gl_FragData[4] = vec4_splat(0.0);
#endif // COLOR_VARIANT_MRT_PBR + COLOR_VARIANT_MRT_LINEAR_DEPTH
#else
	gl_FragColor = u_color1;
#endif // COLOR_VARIANT_MRT_LIGHTING
}
