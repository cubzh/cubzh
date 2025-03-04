#if MESH_VARIANT_MRT_LIGHTING
$input v_color0, v_texcoord0, v_texcoord1, v_texcoord2
    #define v_uv v_texcoord0.xy
    #define v_linearDepth v_texcoord0.z
    #define v_normal v_texcoord1.xyz
    #define v_tangent v_texcoord2.xyz
    #define v_bitangent vec3(v_texcoord0.w, v_texcoord1.w, v_texcoord2.w)
#else
$input v_color0, v_texcoord0
    #define v_uv v_texcoord0.xy
    #define v_cutout v_texcoord0.z
    #define v_albedoFlag bool(v_texcoord0.w)
#endif

#include "./include/bgfx.sh"
#include "./include/config.sh"
#include "./include/utils_lib.sh"
#if MESH_VARIANT_MRT_LIGHTING
#include "./include/mesh_lib.sh"
#endif

SAMPLER2D(s_fb1, 0);
#if MESH_VARIANT_MRT_LIGHTING
SAMPLER2D(s_fb2, 1);
SAMPLER2D(s_fb3, 2);
SAMPLER2D(s_fb4, 3);
#endif

#if MESH_VARIANT_MRT_LIGHTING
uniform vec4 u_lighting;
uniform vec4 u_params;
    #define u_metadata u_params.x
    #define u_emissive u_params.y
    #define u_cutout u_params.z
    #define u_unlit u_params.w
#endif
uniform vec4 u_color1;

void main() {
#if MESH_VARIANT_MRT_LIGHTING
    float metadata[6]; unpackMeshMetadata(u_metadata, metadata);
    mat3 tbn = mtxFromCols(v_tangent, v_bitangent, v_normal);

    vec4 albedo = mix(WHITE, texture2D(s_fb1, v_uv), metadata[MESH_METADATA_ALBEDOFLAG]);
    vec3 normal = mix(v_normal, decodeNormal(texture2D(s_fb2, v_uv).xyz, tbn), metadata[MESH_METADATA_NORMALFLAG]);
    vec2 metallicRoughness = mix(vec2(metadata[MESH_METADATA_METALLIC], metadata[MESH_METADATA_ROUGHNESS]), texture2D(s_fb3, v_uv).xy, metadata[MESH_METADATA_METALLICFLAG]);
    vec3 emissive = mix(unpackFloatToRgb(u_emissive), texture2D(s_fb4, v_uv).xyz, metadata[MESH_METADATA_EMISSIVEFLAG]);

    float unlit = mix(LIGHTING_LIT_FLAG, LIGHTING_UNLIT_FLAG, u_unlit);
#else
    vec4 albedo = v_albedoFlag ? texture2D(s_fb1, v_uv) : BLACK;
#endif

    vec4 color = albedo * v_color0 * u_color1;

#if MESH_VARIANT_CUTOUT
#if MESH_VARIANT_MRT_LIGHTING
    float cutout = u_cutout;
#else
    float cutout = v_cutout;
#endif
    if (color.a <= cutout) discard;
#endif

#if MESH_VARIANT_ALPHA == 0
    color.a = 1.0;
#endif

#if MESH_VARIANT_MRT_LIGHTING
    gl_FragData[0] = color;
    gl_FragData[1] = vec4(encodeNormalUint(normal), unlit);
    gl_FragData[2] = vec4(u_lighting.yzw * VOXEL_LIGHT_RGB_PRE_FACTOR, u_lighting.x);
    gl_FragData[3] = vec4(u_lighting.yzw * VOXEL_LIGHT_RGB_POST_FACTOR + emissive, unlit);
#if MESH_VARIANT_MRT_PBR && MESH_VARIANT_MRT_LINEAR_DEPTH
    gl_FragData[4] = vec4(metallicRoughness.x, metallicRoughness.y, 0.0, 0.0);
    gl_FragData[5] = vec4_splat(v_linearDepth);
#elif MESH_VARIANT_MRT_PBR
    gl_FragData[4] = vec4(metallicRoughness.x, metallicRoughness.y, 0.0, 0.0);
#elif MESH_VARIANT_MRT_LINEAR_DEPTH
    gl_FragData[4] = vec4_splat(v_linearDepth);
#endif // MESH_VARIANT_MRT_PBR + MESH_VARIANT_MRT_LINEAR_DEPTH
#else
    gl_FragColor = color;
#endif
}