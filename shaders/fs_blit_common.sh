$input v_texcoord0

#include "./include/bgfx.sh"
#include "./include/config.sh"
#include "./include/game_uniforms.sh"
#include "./include/global_lighting_uniforms.sh"
#include "./include/dithering_lib.sh"
#include "./include/voxels_lib.sh"

#define uv v_texcoord0.xy
#define pos v_texcoord0.zw

SAMPLER2D(s_fb1, 0);
SAMPLER2D(s_fb2, 1);
SAMPLER2D(s_fb3, 2);
SAMPLER2D(s_fb4, 3);
SAMPLER2D(s_fb5, 4);
SAMPLER2D(s_fb6, 5);

uniform vec4 u_params;
uniform vec4 u_color1;
uniform vec4 u_color2;

#define u_fog (u_params.x == 1.0f)
#if BLIT_VARIANT_LINEAR_DEPTH == 0
#define u_fogClipNear u_params.y
#define u_fogClipLength u_params.z
#endif
#define u_skyboxColor u_sunColor.xyz
#define u_ambientColor u_color2.xyz

void main() {
	vec4 opaque = texture2D(s_fb1, uv);
#if BLIT_VARIANT_MRT
	vec4 illumination = texture2D(s_fb2, uv);
	vec4 emission = texture2D(s_fb3, uv);
	float depth = texture2D(s_fb4, uv).x;
	vec4 accum = texture2D(s_fb5, uv);
    float weight = texture2D(s_fb6, uv).x;

#if BLIT_VARIANT_LINEAR_DEPTH
	float fog = u_fog ? (depth - u_fogStart) / u_fogLength : 0.0f;
#else
	float fog = u_fog ? (depth - u_fogClipNear) / u_fogClipLength : 0.0f;
#endif

#if DEBUG_LIGHTING >= 1 && DEBUG_LIGHTING <= 5 || DEBUG_LIGHTING >= 14 && DEBUG_LIGHTING <= 15
	vec3 lit = illumination.xyz;
#else
	vec3 lit = fequal(emission.w, LIGHTING_UNLIT_FLAG, FLAG_EPSILON) ?
			opaque.xyz :
			(fequal(emission.w, LIGHTING_PRELIT_FLAG, FLAG_EPSILON) ?
				getDeferredPreLitColor(opaque.xyz, illumination.xyz) :
				getVertexDeferredLitColor(opaque.xyz, u_skyboxColor, u_ambientColor, illumination.xyz, emission.xyz, illumination.w, fog));
#endif

	float reveal = accum.w;
	vec3 transparent = accum.xyz / clamp(weight, 1e-4, 5e4);

#if DEBUG_TRANSPARENCY == 1
	vec4 final = vec4(reveal, reveal, reveal, opaque.w);
#elif DEBUG_TRANSPARENCY == 2
	vec4 final = vec4(opaque.xyz * reveal, opaque.w);
#elif DEBUG_TRANSPARENCY == 3
	vec4 final = vec4(accum.xyz, opaque.w);
#elif DEBUG_TRANSPARENCY == 4
	vec4 final = vec4(weight, weight, weight, opaque.w);
#elif DEBUG_TRANSPARENCY == 5
	vec4 final = vec4(transparent, opaque.w);
#else
	vec4 final = vec4((lit * reveal + transparent * (1.0 - reveal)) * u_color1.xyz, 1.0);
#if BLIT_VARIANT_WRITEALPHA
	final.xyz *= u_color1.w; // pre-multiply alpha for target blending
	final.w = (opaque.w * reveal + 1.0 - reveal) * u_color1.w;
#endif
#endif // DEBUG_TRANSPARENCY

#else

	vec4 final = vec4(opaque.xyz * u_color1.xyz, 1.0);
#if BLIT_VARIANT_WRITEALPHA
	final.xyz *= u_color1.w; // pre-multiply alpha for target blending
	final.w = opaque.w * u_color1.w;
#endif

#endif // BLIT_VARIANT_MRT

	gl_FragColor = final;
}
