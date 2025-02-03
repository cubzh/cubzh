#if MESH_VARIANT_MRT_LIGHTING
$input v_color0, v_texcoord0, v_texcoord1
    #define v_uv v_texcoord0.xy
    #define v_linearDepth v_texcoord0.z
    #define v_normal v_texcoord1.xyz
#else
$input v_color0, v_texcoord0
    #define v_uv v_texcoord0.xy
    #define v_cutout v_texcoord0.z
#endif

#include "./include/bgfx.sh"
#include "./include/config.sh"
#include "./include/utils_lib.sh"

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
    vec4 color = v_color0 * u_color1;

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
    float unlit = mix(LIGHTING_LIT_FLAG, LIGHTING_UNLIT_FLAG, u_unlit);
    vec3 emissive = unpackFloatToRgb(u_emissive);
#if MESH_VARIANT_MRT_PBR
    vec3 metadata = unpackFloatToRgb(u_metadata);
    float metallic = metadata.x;
    float roughness = metadata.y;
#endif

    gl_FragData[0] = color;
    gl_FragData[1] = vec4(encodeNormalUint(v_normal), unlit);
    gl_FragData[2] = vec4(u_lighting.yzw * VOXEL_LIGHT_RGB_PRE_FACTOR, u_lighting.x);
    gl_FragData[3] = vec4(u_lighting.yzw * VOXEL_LIGHT_RGB_POST_FACTOR + emissive, unlit);
#if MESH_VARIANT_MRT_PBR && MESH_VARIANT_MRT_LINEAR_DEPTH
    gl_FragData[4] = vec4(metallic, roughness, 0.0, 0.0);
    gl_FragData[5] = vec4_splat(v_linearDepth);
#elif MESH_VARIANT_MRT_PBR
    gl_FragData[4] = vec4(metallic, roughness, 0.0, 0.0);
#elif MESH_VARIANT_MRT_LINEAR_DEPTH
    gl_FragData[4] = vec4_splat(v_linearDepth);
#endif // MESH_VARIANT_MRT_PBR + MESH_VARIANT_MRT_LINEAR_DEPTH
#else
    gl_FragColor = color;
#endif
}