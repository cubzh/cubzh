#define IS_SHADOW_PASS (VOXEL_VARIANT_MRT_SHADOW_PACK || VOXEL_VARIANT_MRT_SHADOW_SAMPLE)
#define IS_DRAWMODES (VOXEL_VARIANT_DRAWMODE_OVERRIDES || VOXEL_VARIANT_DRAWMODE_OUTLINE)

$input a_position, a_texcoord0
#if VOXEL_VARIANT_MRT_LIGHTING
$output v_color0, v_color1, v_texcoord0, v_texcoord1
	#define v_lighting v_color1
	#define v_normal v_texcoord0.xyz
	#define v_clipZ v_texcoord0.w
	#define v_model v_texcoord1.xyz
	#define v_linearDepth v_texcoord1.w
#elif VOXEL_VARIANT_MRT_TRANSPARENCY || IS_DRAWMODES
$output v_color0, v_texcoord0, v_texcoord1
	#define v_model v_texcoord0.xyz
	#define v_clipZ v_texcoord0.w
#elif VOXEL_VARIANT_MRT_SHADOW_SAMPLE == 0
$output v_color0
	#define v_depth v_color0.x
#endif

#include "./include/bgfx.sh"
#include "./include/config.sh"
#include "./include/game_uniforms.sh"
#include "./include/voxels_uniforms.sh"
#include "./include/global_lighting_uniforms.sh"
#include "./include/voxels_lib.sh"

#if IS_SHADOW_PASS == 0 && VOXEL_VARIANT_DRAWMODE_OUTLINE == 0
SAMPLER2D(s_palette, 0);
#endif

#define a_colorIdx a_position.w
#define a_metadata a_texcoord0.x

void main() {
	vec3 meta = unpackMetadata(a_metadata);

	int aoIdx = int(meta.x);
	int face = int(meta.y);

	vec4 model = vec4(a_position.xyz, 1.0);
	vec4 clip = mul(u_modelViewProj, model);
	//float depth = fromClipSpaceDepth(clip.z / clip.w);

#if IS_SHADOW_PASS

	gl_Position = clip;
#if VOXEL_VARIANT_MRT_SHADOW_PACK
	v_depth = clip.z / clip.w;
#endif

#else // IS_SHADOW_PASS

#if VOXEL_VARIANT_DRAWMODE_OUTLINE
	vec3 cnormal = normalize(mul(u_modelViewProj, vec4(getVertexNormal(face), 0.0)).xyz);
	vec2 offset = 2.0 * u_outlineThickness / u_projSize;
	clip.xy += cnormal.xy * offset * clip.w;
#endif

#if VOXEL_VARIANT_MRT_LIGHTING
#if VOXEL_VARIANT_UNLIT == 0
	vec3 wnormal = normalize(mul(u_model[0], vec4(getVertexNormal(face), 0.0)).xyz);
#endif // VOXEL_VARIANT_UNLIT == 0
#if VOXEL_VARIANT_MRT_LINEAR_DEPTH
	vec4 view = mul(u_modelView, model);
#endif // VOXEL_VARIANT_MRT_LINEAR_DEPTH
#endif // VOXEL_VARIANT_MRT_LIGHTING

#if VOXEL_VARIANT_DRAWMODE_OUTLINE

	float aoValue = 0.0;
	vec4 color = u_outlineRGBA;
	vec4 comp = CLEAR;

#else // VOXEL_VARIANT_DRAWMODE_OUTLINE

#if ENABLE_AO
	float aoValue = AO_GRADIENT[aoIdx];
#else
	float aoValue = 0.0;
#endif // ENABLE_AO

	vec2 paletteUV = getPaletteUV(a_colorIdx);
	vec4 color = texture2DLod(s_palette, paletteUV, 0.0);
#if DEBUG_FACE > 0
	color = getDebugColor(color, face, clip.xyz / clip.w);
#endif

#if AO_COLOR == 4
	vec4 comp = texture2DLod(s_palette, vec2(paletteUV.x, paletteUV.y + 1.0 / u_paletteSize), 0.0);
#else
	vec4 comp = CLEAR;
#endif

#endif // VOXEL_VARIANT_DRAWMODE_OUTLINE

#if VOXEL_VARIANT_UNLIT
	vec4 voxelLight = VOXEL_LIGHT_DEFAULT_SRGB;
#elif VOXEL_VARIANT_LIGHTING_ATTRIBUTES
	vec4 voxelLight = unpackVoxelLight(meta.z);
#elif VOXEL_VARIANT_LIGHTING_UNIFORM
	vec4 voxelLight = u_lighting;
#else
	vec4 voxelLight = VOXEL_LIGHT_DEFAULT_SRGB;
#endif

#if VOXEL_VARIANT_LIGHTING_UNIFORM == 0 && VOXEL_VARIANT_UNLIT == 0
	voxelLight.x *= u_bakedIntensity;
#endif

#if VOXEL_VARIANT_DRAWMODE_OVERRIDES
	float aStep = step(1.0, u_alphaOverride);
	color.w = mix(u_alphaOverride, color.w, aStep);
	aoValue = mix(0.0, aoValue, aStep);

	color.xyz *= u_multRGB;
	color.xyz += u_addRGB;
#endif

#if VOXEL_VARIANT_UNLIT
	vec3 skybox = vec3_splat(1.0);
#else
	vec3 skybox = u_sunColor.xyz;
#endif

#if DEBUG_VERTEX_LIGHTING > 0
	vec4 vcolor = getVertexDebugColor(voxelLight, skybox, aoValue, color, comp.xyz, face);
#elif VOXEL_VARIANT_MRT_LIGHTING
	vec4 vcolor = getVertexDeferredAlbedo(aoValue, color, comp.xyz, face);
	voxelLight = getVertexDeferredLighting(voxelLight, aoValue);
#else
	vec4 vcolor = getVertexLitColor(voxelLight, skybox, aoValue, color, comp.xyz, clip.z, face);
#endif

	gl_Position = clip;
	v_color0 = vcolor;
#if VOXEL_VARIANT_DRAWMODE_OVERRIDES || VOXEL_VARIANT_MRT_TRANSPARENCY
	v_model = model.xyz;
	v_clipZ = clip.z;
#endif
#if VOXEL_VARIANT_MRT_LIGHTING
#if VOXEL_VARIANT_UNLIT
	v_normal = vec3_splat(0.0);
#else
	v_normal = wnormal;
#endif // VOXEL_VARIANT_UNLIT
	v_lighting = voxelLight;
#if VOXEL_VARIANT_MRT_LINEAR_DEPTH
	v_linearDepth = view.z;
#endif // VOXEL_VARIANT_MRT_LINEAR_DEPTH
#endif

#endif // IS_SHADOW_PASS
}
