#if LIGHT_VARIANT_LINEAR_DEPTH
$input v_texcoord0, v_texcoord1
#else
$input v_texcoord0
#endif

#include "./include/bgfx.sh"
#include "./include/utils_lib.sh"
#include "./include/config.sh"
#include "./include/game_uniforms.sh"

#define HAS_SHADOWS LIGHT_VARIANT_SHADOW_PACK || LIGHT_VARIANT_SHADOW_SAMPLE

SAMPLER2D(s_fb1, 0);
SAMPLER2D(s_fb2, 1);
#if LIGHT_VARIANT_SHADOW_SAMPLE
SAMPLER2DSHADOW(s_fb3, 2);
#if LIGHT_VARIANT_TYPE_DIRECTIONAL
#if LIGHT_VARIANT_SHADOW_CSM >= 2
SAMPLER2DSHADOW(s_fb4, 3);
#endif
#if LIGHT_VARIANT_SHADOW_CSM >= 3
SAMPLER2DSHADOW(s_fb5, 4);
#endif
#if LIGHT_VARIANT_SHADOW_CSM >= 4
SAMPLER2DSHADOW(s_fb6, 5);
#endif
#endif // LIGHT_VARIANT_TYPE_DIRECTIONAL
	#define Sampler sampler2DShadow
	#include "./include/shadow_lib.sh"
#elif LIGHT_VARIANT_SHADOW_PACK
SAMPLER2D(s_fb3, 2);
#if LIGHT_VARIANT_TYPE_DIRECTIONAL
#if LIGHT_VARIANT_SHADOW_CSM >= 2
SAMPLER2D(s_fb4, 3);
#endif
#if LIGHT_VARIANT_SHADOW_CSM >= 3
SAMPLER2D(s_fb5, 4);
#endif
#if LIGHT_VARIANT_SHADOW_CSM >= 4
SAMPLER2D(s_fb6, 5);
#endif
#endif // LIGHT_VARIANT_TYPE_DIRECTIONAL
	#define Sampler sampler2D
	#include "./include/shadow_lib.sh"
#endif

uniform vec4 u_lightParams[5];
#if LIGHT_VARIANT_LINEAR_DEPTH == 0
uniform mat4 u_mtx;
#endif
#if HAS_SHADOWS
uniform mat4 u_lightVP1;
#if LIGHT_VARIANT_SHADOW_CSM >= 2
uniform mat4 u_lightVP2;
#endif
#if LIGHT_VARIANT_SHADOW_CSM >= 3
uniform mat4 u_lightVP3;
#endif
#if LIGHT_VARIANT_SHADOW_CSM >= 4
uniform mat4 u_lightVP4;
#endif
uniform vec4 u_shadowParams;
#endif // HAS_SHADOWS

#define uv v_texcoord0.xy
#define pos v_texcoord0.zw
#define eyeToFar v_texcoord1.xyz

#define u_origin u_lightParams[0].xyz
#define u_range u_lightParams[0].w
#define u_color u_lightParams[1].xyz
#define u_hardness u_lightParams[1].w
#define u_viewPos u_lightParams[2].xyz
#define u_angle u_lightParams[2].w
#define u_lightForward u_lightParams[3].xyz
#define u_lightIntensity u_lightParams[3].w
#if LIGHT_VARIANT_LINEAR_DEPTH == 0
	#define u_invVP u_mtx
	#define u_uvMax u_lightParams[4].xy
#endif
#if HAS_SHADOWS
	#define u_shadowBias u_shadowParams.x
	#define u_shadowmapSize u_shadowParams.y
	#define u_shadowNormalOffset u_shadowParams.z
	#define u_shadowFar u_shadowParams.w
#endif

void main() {
	vec4 fb1 = texture2D(s_fb1, uv);
	float unlit = fb1.w;

	if (unlit == LIGHTING_UNLIT_FLAG) discard;

	vec3 normal = decodeNormalUint(fb1.xyz);

#if LIGHT_VARIANT_LINEAR_DEPTH
	float viewZ = texture2D(s_fb2, uv).x;
	float depth = viewZ / u_far;
	
	//vec3 world = u_viewPos + normalize(eyeToFar) * viewZ;
	vec3 world = u_viewPos + depth * eyeToFar;
#else
	float depth = texture2D(s_fb2, uv).x;

	vec3 clip = uvDepthToClip(uv / u_uvMax, depth);
	vec3 world = transformH(u_invVP, clip).xyz;
#endif
	
#if LIGHT_VARIANT_TYPE_DIRECTIONAL
	vec3 L = -u_lightForward;
	float attn = 1.0;

#if HAS_SHADOWS
	vec3 V = u_viewPos - world;
	float dist = length(V);
#endif

#else
	vec3 L = u_origin - world;
	float attn = 1.0 - smoothstep(u_hardness, 1.0, length(L) / u_range);
	L = normalize(L);

#if (LIGHT_MODEL > 0) || HAS_SHADOWS
	vec3 V = u_viewPos - world;
	float dist = length(V);
#endif
#if LIGHT_MODEL > 0
	V = V / dist;
#endif

#endif // LIGHT_VARIANT_TYPE_DIRECTIONAL
	
#if LIGHT_VARIANT_TYPE_SPOT
	float FdotL = dot(u_lightForward, -L);
	float minCos = cos(u_angle);
	float maxCos = mix(minCos, 1.0, 1.0 - u_hardness);

	attn *= smoothstep(minCos, maxCos, FdotL);
#endif

	float isTranslucent = LIGHT_IS_FRAGMENT_TRANSLUCENT(normal);
	normal = normalize(normal);

#if LIGHT_VARIANT_TYPE_DIRECTIONAL
	float sNdotL = mix(saturate(dot(normal, L)), 1.0, isTranslucent);
#else
	float sNdotL = mix(saturate(dot(normal, L)), LIGHT_TRANSLUCENCY_FACTOR(normal), isTranslucent);
#endif
	vec3 diffuse = sNdotL * u_color;

#if LIGHT_VARIANT_TYPE_DIRECTIONAL
	vec3 lit = diffuse * attn;
#else

#if LIGHT_MODEL == 1
	vec3 R = reflect(-L, normal);
	float VdotR = mix(dot(V, R), 0.0, isTranslucent);
	float specular = LIGHT_SPECULAR * pow(saturate(VdotR), LIGHT_PHONG_SHININESS);

	vec3 lit = (diffuse + specular) * attn;
#elif LIGHT_MODEL == 2
	vec3 H = normalize(L + V);
	float NdotH = mix(dot(normal, H), 0.0, isTranslucent);
	float specular = LIGHT_SPECULAR * pow(saturate(NdotH), LIGHT_BLINN_SHININESS);

	vec3 lit = (diffuse + specular) * attn;
#else
	vec3 lit = diffuse * attn;
#endif // LIGHT_MODEL

#endif // LIGHT_VARIANT_TYPE_DIRECTIONAL

float illumination = clamp(u_lightIntensity, -1.0, 1.0);
float emission = u_lightIntensity - illumination;

#if HAS_SHADOWS

	float texelSize = 1.0 / u_shadowmapSize;
	float texelScale = SHADOWMAP_REF_SIZE / u_shadowmapSize;
	vec3 smWorld = world + normal * u_shadowNormalOffset * texelScale;
#if SHADOWMAP_BIAS_ANGLE
	float bias = mix(SHADOWMAP_BIAS_MIN, u_shadowBias, 1.0 - sNdotL);
#else
	float bias = u_shadowBias;
#endif
#if SHADOWMAP_DISTANCE_BIAS
	float fragBias = bias * (1.0 + dist / u_shadowFar * SHADOWMAP_BIAS_DIST_MULTIPLIER);
#else
	float fragBias = bias;
#endif

#if LIGHT_VARIANT_TYPE_DIRECTIONAL
	vec3 smUvDepth = clipToUvDepth(transformH(u_lightVP1, smWorld).xyz);
#if LIGHT_VARIANT_SHADOW_CSM >= 2
	bool cascade1 = all(lessThanEqual(smUvDepth, vec3_splat(1.0))) && all(greaterThanEqual(smUvDepth, vec3_splat(0.0)));
	smUvDepth = cascade1 ? smUvDepth : clipToUvDepth(transformH(u_lightVP2, smWorld).xyz);
#endif
#if LIGHT_VARIANT_SHADOW_CSM >= 3
	bool cascade2 = all(lessThanEqual(smUvDepth, vec3_splat(1.0))) && all(greaterThanEqual(smUvDepth, vec3_splat(0.0)));
	smUvDepth = cascade1 || cascade2 ? smUvDepth : clipToUvDepth(transformH(u_lightVP3, smWorld).xyz);
#endif
#if LIGHT_VARIANT_SHADOW_CSM >= 4
	bool cascade3 = all(lessThanEqual(smUvDepth, vec3_splat(1.0))) && all(greaterThanEqual(smUvDepth, vec3_splat(0.0)));
	smUvDepth = cascade1 || cascade2 || cascade3 ? smUvDepth : clipToUvDepth(transformH(u_lightVP4, smWorld).xyz);
#endif
#else
	vec3 smUvDepth = clipToUvDepth(transformH(u_lightVP1, smWorld).xyz);
#endif // LIGHT_VARIANT_TYPE_DIRECTIONAL

	bool overSampling = any(greaterThan(smUvDepth, vec3_splat(1.0))) || any(lessThan(smUvDepth, vec3_splat(0.0)));

#if LIGHT_VARIANT_TYPE_DIRECTIONAL && LIGHT_VARIANT_SHADOW_CSM >= 2
	float shadow = overSampling ? 1.0 :
			cascade1 ? getShadow(s_fb3, smUvDepth.xy, smUvDepth.z, bias, texelSize) :
#if LIGHT_VARIANT_SHADOW_CSM == 2
			getShadow(s_fb4, smUvDepth.xy, smUvDepth.z, fragBias + bias * SHADOWMAP_BIAS_CASCADE_MULTIPLIER, texelSize);
#else
			cascade2 ? getShadow(s_fb4, smUvDepth.xy, smUvDepth.z, fragBias + bias * SHADOWMAP_BIAS_CASCADE_MULTIPLIER, texelSize) :
#if LIGHT_VARIANT_SHADOW_CSM == 3
			getShadow(s_fb5, smUvDepth.xy, smUvDepth.z, fragBias + bias * SHADOWMAP_BIAS_CASCADE_MULTIPLIER * 2.0, texelSize);
#else
			cascade3 ? getShadow(s_fb5, smUvDepth.xy, smUvDepth.z, fragBias + bias * SHADOWMAP_BIAS_CASCADE_MULTIPLIER * 2.0, texelSize) :
			getShadow(s_fb6, smUvDepth.xy, smUvDepth.z, fragBias + bias * SHADOWMAP_BIAS_CASCADE_MULTIPLIER * 3.0, texelSize);
#endif // LIGHT_VARIANT_SHADOW_CSM == 3
#endif // LIGHT_VARIANT_SHADOW_CSM == 2
#else
	float shadow = overSampling ? 1.0 : getShadow(s_fb3, smUvDepth.xy, smUvDepth.z, fragBias, texelSize);
#endif

#if SHADOWMAP_SOFT_OVERSAMPLING
	shadow = dist >= u_shadowFar ? mix(shadow, 1.0, smoothstep(SHADOWMAP_SOFT_OVERSAMPLING_EDGE_MAX, 1.0, max(smUvDepth.z, max(smUvDepth.x, smUvDepth.y)))) : shadow;
	shadow = dist >= u_shadowFar ? mix(shadow, 1.0, 1.0 - smoothstep(0.0, SHADOWMAP_SOFT_OVERSAMPLING_EDGE_MIN, min(smUvDepth.z, min(smUvDepth.x, smUvDepth.y)))) : shadow;
#endif

	lit *= max(shadow, SHADOWS_AMBIENT_FACTOR);

#endif // HAS_SHADOWS

#if DEBUG_LIGHTING > 0
	gl_FragData[1] = vec4_splat(0.0);
#endif

#if DEBUG_LIGHTING == 1
	gl_FragData[0] = vec4(normal, 1.0);
#elif DEBUG_LIGHTING == 2
#if LIGHT_VARIANT_LINEAR_DEPTH
	gl_FragData[0] = vec4(depth, 0.0, 0.0, 1.0);
#else
	gl_FragData[0] = vec4((depth - 0.95) / 0.05, 0.0, 0.0, 1.0);
#endif // LIGHT_VARIANT_LINEAR_DEPTH
#elif DEBUG_LIGHTING == 3
	gl_FragData[0] = vec4(clip.xy * 0.5 + 0.5, (depth - 0.95) / 0.05, 1.0);
#elif DEBUG_LIGHTING == 4
	//gl_FragData[0] = vec4(clamp(world / 512.0, -1.0, 1.0) * 0.5 + 0.5, 1.0);
	gl_FragData[0] = vec4(0.0, clamp(world / 256.0, -1.0, 1.0).y * 0.5 + 0.5, 0.0, 1.0);
	//gl_FragData[0] = vec4(0.0, 0.0, clamp(world / 512.0, 0.0, 1.0).z, 1.0);
#elif DEBUG_LIGHTING == 5
	gl_FragData[0] = vec4(-V * 0.5 + 0.5, 1.0);
#elif DEBUG_LIGHTING == 6
	float r = 1.0 - CLAMP01(length(world - u_origin) / u_range);
	gl_FragData[0] = vec4(r, r, r, 1.0);
#elif DEBUG_LIGHTING == 7
	gl_FragData[0] = vec4(attn, attn, attn, 1.0);
#elif DEBUG_LIGHTING == 8 && HAS_SHADOWS
	gl_FragData[0] = vec4(linearizeDepth(smUvDepth.z, 1.0, u_shadowFar), 0.0, 0.0, 1.0);
#elif DEBUG_LIGHTING == 9 && HAS_SHADOWS
	gl_FragData[0] = vec4(smUvDepth.xy, 0.0, 1.0);
#elif DEBUG_LIGHTING == 10 && HAS_SHADOWS
	gl_FragData[0] = vec4(unpackRgbaToFloat(texture2D(s_fb3, smUvDepth.xy)), 0.0, 0.0, 1.0);
#elif DEBUG_LIGHTING == 11 && HAS_SHADOWS
	gl_FragData[0] = vec4(shadow, shadow, shadow, 1.0);
#elif DEBUG_LIGHTING == 12 && HAS_SHADOWS
	gl_FragData[0] = vec4(lit * overSampling, 1.0);
#elif DEBUG_LIGHTING == 13 && HAS_SHADOWS
#if LIGHT_VARIANT_TYPE_DIRECTIONAL
	if (cascade1) {
		gl_FragData[0] = BLEND_SOFT_ADDITIVE(vec4(lit, 1.0), RED);
	} else if (cascade2) {
		gl_FragData[0] = BLEND_SOFT_ADDITIVE(vec4(lit, 1.0), GREEN);
	} else if (cascade3) {
		gl_FragData[0] = BLEND_SOFT_ADDITIVE(vec4(lit, 1.0), BLUE);
	} else {
		gl_FragData[0] = BLEND_SOFT_ADDITIVE(vec4(lit, 1.0), YELLOW);
	}
#else
	gl_FragData[0] = BLEND_SOFT_ADDITIVE(vec4(lit, 1.0), RED);
#endif // LIGHT_VARIANT_TYPE_DIRECTIONAL
#elif DEBUG_LIGHTING == 14
	gl_FragData[0] = vec4(normalize(eyeToFar) * 0.5 + 0.5, 1.0);
#elif DEBUG_LIGHTING == 15 && HAS_SHADOWS
	gl_FragData[0] = vec4(dist / u_shadowFar, 0.0, 0.0, 1.0);
#else // DEBUG_LIGHTING

lit = mix(lit, vec3_splat(0.0), step(1.0, depth));

gl_FragData[0] = vec4(lit * illumination, 0.0);
gl_FragData[1] = vec4(lit * emission, 0.0);

#endif // DEBUG_LIGHTING
}
