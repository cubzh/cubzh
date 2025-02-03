#if MESH_VARIANT_MRT_LIGHTING
$input v_color0, v_texcoord0, v_texcoord1
    #define v_uv v_texcoord0.xy
    #define v_linearDepth v_texcoord0.z
    #define v_normal v_texcoord1.xyz
#else
$input v_color0, v_texcoord0
    #define v_uv v_texcoord0.xy
#endif

#include "./include/bgfx.sh"
#include "./include/config.sh"
#include "./include/utils_lib.sh"

#if MESH_VARIANT_MRT_LIGHTING
uniform vec4 u_lighting;
#endif
uniform vec4 u_color1;
uniform vec4 u_params;
    #define u_metadata u_params.x
    #define u_emissive u_params.y
    #define u_cutout u_params.z
    #define u_unlit u_params.w

void main() {
    vec4 color = v_color0 * u_color1;

#if MESH_VARIANT_CUTOUT
    if (color.a <= u_cutout) discard;
#endif

#if MESH_VARIANT_ALPHA == 0
    color.a = 1.0;
#endif

#if MESH_VARIANT_MRT_LIGHTING
    float unlit = mix(LIGHTING_LIT_FLAG, LIGHTING_UNLIT_FLAG, u_unlit);
    vec3 emissive = unpackFloatToRgb(u_emissive);

    gl_FragData[0] = color;
    gl_FragData[1] = vec4(encodeNormalUint(v_normal), unlit + u_metadata);
    gl_FragData[2] = vec4(u_lighting.yzw * VOXEL_LIGHT_RGB_PRE_FACTOR, u_lighting.x);
    gl_FragData[3] = vec4(u_lighting.yzw * VOXEL_LIGHT_RGB_POST_FACTOR + emissive, unlit);
#if MESH_VARIANT_MRT_LINEAR_DEPTH
    gl_FragData[4] = vec4_splat(v_linearDepth);
#endif
#else
    gl_FragColor = color;
#endif
}