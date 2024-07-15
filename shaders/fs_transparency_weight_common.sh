$input v_color0, v_texcoord0, v_texcoord1
#if OIT_VARIANT_FONT
	#define v_uvw v_texcoord0.xyz
	#define v_coloredGlyph CLAMP01(v_texcoord0.w)
	#define v_clipZ v_texcoord1.x
#elif OIT_VARIANT_TEX
	#define v_uv v_texcoord0.xy
	#define v_clipZ v_texcoord0.z
	#define v_cutout v_texcoord0.w
	#define v_9slice v_texcoord1.xyz
#else
	#define v_model v_texcoord0.xyz
	#define v_clipZ v_texcoord0.w
#endif

/*
 * Vertex color weight writer fragment shader
 *
 * From the Weighted Blended Order-Independent Transparency method:
 * https://web.archive.org/web/20181126040455/http://casual-effects.blogspot.com/2014/03/weighted-blended-order-independent.html
 * Paper: http://jcgt.org/published/0002/02/09/
 *
 * Note that we cannot use the blend modes per-render targets like this:
 * 		RT1 ONE, ONE
 *		RT2 ZERO, ONE_MINUS_SRC_ALPHA
 * instead, we use the same, separate blend modes for RGB & A for both render targets:
 *		RT1/2	RGB: 	ONE, ONE
				A:		ZERO, ONE_MINUS_SRC_ALPHA
 * this means that
 * 	(1) we swap the 'reveal' factor with the pre-multiplied weight from RT1.a and RT2.r
 * 	(2) change accordingly the blend in fs_transparency_blit
 *	(3)	swap the clear colors for RT1.a and RT2.r
 *
 * Note: RT2.gba is unused
 */

#include "./include/bgfx.sh"
#include "./include/config.sh"
#include "./include/utils_lib.sh"
#if VOXEL_VARIANT_DRAWMODES
#include "./include/drawmodes_lib.sh"
#include "./include/voxels_uniforms_fs.sh"
#endif
#if OIT_VARIANT_TEX
#include "./include/quad_lib.sh"
#endif

#if OIT_VARIANT_FONT
SAMPLERCUBE(s_texColor, 0);
#elif OIT_VARIANT_TEX
SAMPLER2D(s_fb1, 0);
#endif // OIT_VARIANT_FONT

float w(float z, vec4 color) {
#if WEIGHT_FUNC == 0
	return 1.0;
#elif WEIGHT_FUNC == 1
	return pow(abs(z), -2.5);
#elif WEIGHT_FUNC == 2
	return pow(abs(z), -5.0);
#elif WEIGHT_FUNC == 3
	return color.a * clamp(pow(abs(z), -5.0), 1e-2, 3.0 * 1e3);
#elif WEIGHT_FUNC == 4
	return clamp(0.03 / (1e-5 + pow(abs(z) / 200.0, 4.0) ), 1e-2, 3.0 * 1e3);
#elif WEIGHT_FUNC == 5
	return max(min(1.0, max(max(color.r, color.g), color.b) * color.a), color.a)
		* clamp(0.03 / (1e-5 + pow(abs(z) / 200.0, 4.0) ), 1e-2, 3.0 * 1e3);
#else
	return 1.0;
#endif
}

void main() {
	vec4 color = v_color0;

#if OIT_VARIANT_FONT
	vec4 base = textureCube(s_texColor, v_uvw).bgra;
	base.a = mix(base.a, base.r, v_coloredGlyph);

	color = vec4(mix(base.rgb, color.rgb, v_coloredGlyph), color.a * base.a);
#elif OIT_VARIANT_TEX
	vec2 slice = unpackNormalized2Floats(v_9slice.x);
	vec2 uBorders = unpackNormalized2Floats(v_9slice.y);
	vec2 vBorders = unpackNormalized2Floats(v_9slice.z);

	vec2 uv = vec2(sliceUV(v_uv.x, uBorders, slice.x),
				   sliceUV(v_uv.y, vBorders, slice.y));

	color *= texture2D(s_fb1, uv);

#if OIT_VARIANT_CUTOUT
	if (color.a <= v_cutout) discard;
#endif

#elif VOXEL_VARIANT_DRAWMODES
	color = getGridColor(v_model, color, u_gridRGB, u_gridScaleMag, v_clipZ);
#endif // OIT_VARIANT_FONT

	float weight = w(v_clipZ, color);
	
	gl_FragData[0] = vec4(color.rgb * color.a * weight, color.a);
	gl_FragData[1] = vec4_splat(color.a * weight);
}
