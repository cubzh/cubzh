#ifndef __VOXELS_LIB_SH__
#define __VOXELS_LIB_SH__

#include "./utils_lib.sh"

#ifndef DEBUG_FACE
	#define DEBUG_FACE 0
#endif
#ifndef DEBUG_POS_NO_UNIFORM
	#define DEBUG_POS_NO_UNIFORM 0
#endif

/* vec4 unpackMetadata(float f) {
	const vec4 shift = vec4(1.0, 255.0, 65025.0, 160581375.0);
	const vec4 mask = vec4(255.0, 255.0, 255.0, 0.0);
	float fudged = f + UNPACK_FUDGE;
	vec4 res = floor(fudged / shift);
	res -= res.yzww * mask;
	return res;
} */

void unpackFullMetadata(float f, out float metadata[6]) {
	float unpack = f;
	float b = floor((unpack + UNPACK_FUDGE) / 131072.0);
	unpack -= b * 131072.0;
	float g = floor((unpack + UNPACK_FUDGE) / 8192.0);
	unpack -= g * 8192.0;
	float r = floor((unpack + UNPACK_FUDGE) / 512.0);
	unpack -= r * 512.0;
	float s = floor((unpack + UNPACK_FUDGE) / 32.0);
	unpack -= s * 32.0;
	float face = floor((unpack + UNPACK_FUDGE) / 4.0);
	float aoIdx = unpack - face * 4.0;
	
	metadata[0] = aoIdx;
	metadata[1] = face;
	metadata[2] = s;
	metadata[3] = r;
	metadata[4] = g;
	metadata[5] = b;
}

vec3 unpackMetadata(float f) {
	float unpack = f;
	float srgb = floor((unpack + UNPACK_FUDGE) / 32.0);
	unpack -= srgb * 32.0;
	float face = floor((unpack + UNPACK_FUDGE) / 4.0);
	float aoIdx = unpack - face * 4.0;
	
	return vec3(aoIdx, face, srgb);
}

void unpackQuadFullMetadata(float f, out float metadata[5]) {
	float unpack = f;
	float b = floor((unpack + UNPACK_FUDGE) / 8192.0);
	unpack -= b * 8192.0;
	float g = floor((unpack + UNPACK_FUDGE) / 512.0);
	unpack -= g * 512.0;
	float r = floor((unpack + UNPACK_FUDGE) / 32.0);
	unpack -= r * 32.0;
	float s = floor((unpack + UNPACK_FUDGE) / 2.0);
	float unlit = unpack - s * 2.0;

	metadata[0] = unlit;
	metadata[1] = s / VOXEL_LIGHT_MAX;
	metadata[2] = r / VOXEL_LIGHT_MAX;
	metadata[3] = g / VOXEL_LIGHT_MAX;
	metadata[4] = b / VOXEL_LIGHT_MAX;
}

vec2 unpackQuadMetadata(float f) {
	float unpack = f;
	float srgb = floor((unpack + UNPACK_FUDGE) / 2.0);
	float unlit = unpack - srgb * 2.0;

	return vec2(unlit, srgb);
}

vec4 unpackAO(float f) {
	const vec4 shift = vec4(1.0, 4.0, 4.0 * 4.0, 4.0 * 4.0 * 4.0);
	const vec4 mask = vec4(4.0, 4.0, 4.0, 0.0);
	float fudged = f * 255.0 + UNPACK_FUDGE;
	vec4 res = floor(fudged / shift);
	res -= res.yzww * mask;
	return res;
}

vec4 unpackVoxelLight(float f) {
#if DEBUG_VERTEX_LIGHTING == 1
	return f;
#else
	float unpack = f;
	float b = floor((unpack + UNPACK_FUDGE) / 4096.0);
	unpack -= b * 4096.0;
	float g = floor((unpack + UNPACK_FUDGE) / 256.0);
	unpack -= g * 256.0;
	float r = floor((unpack + UNPACK_FUDGE) / 16.0);
	float sun = unpack - r * 16.0;
	return vec4(sun, r, g, b) / VOXEL_LIGHT_MAX;
#endif // DEBUG_VERTEX_LIGHTING
}

vec4 getDebugColor(vec4 color, int face, vec3 clip) {
#if DEBUG_FACE == 1
	if(face == 0) { // right
		return RED;
	} else if(face == 1) { // left
		return WHITE;
	} else if(face == 2) { // front
		return BLUE;
	} else if(face == 3) { // back
		return MAGENTA;
	} else if(face == 4) { // top
		return GREEN;
	} else if(face == 5) { // down
		return CYAN;
	} else {
		return BLACK;
	}
#elif DEBUG_FACE == 2
	return vec4(1.0 - clip.z, 0.0, 0.0, 1.0);
#else
	return color;
#endif // DEBUG_FACE
}

vec4 getVertexPosition(vec3 centerPos, int offsetIdx) {
	vec3 res = centerPos;
#if DEBUG_POS_NO_UNIFORM
	if(face == 0) {
		if(mod4 == 0) {
			res += vec3(0.0, 0.5, -.5);
		} else if(mod4 == 1) {
			res += vec3(0.0, -.5, -.5);
		} else if(mod4 == 2) {
			res += vec3(0.0, -.5, 0.5);
		} else if(mod4 == 3) {
			res += vec3(0.0, 0.5, 0.5);
		}
	} else if(face == 1) {
		if(mod4 == 0) {
			res += vec3(0.0, -.5, -.5);
		} else if(mod4 == 1) {
			res += vec3(0.0, 0.5, -.5);
		} else if(mod4 == 2) {
			res += vec3(0.0, 0.5, 0.5);
		} else if(mod4 == 3) {
			res += vec3(0.0, -.5, 0.5);
		}
	} else if(face == 2) {
		if(mod4 == 0) {
			res += vec3(-.5, 0.5, 0.0);
		} else if(mod4 == 1) {
			res += vec3(-.5, -.5, 0.0);
		} else if(mod4 == 2) {
			res += vec3(0.5, -.5, 0.0);
		} else if(mod4 == 3) {
			res += vec3(0.5, 0.5, 0.0);
		}
	} else if(face == 3) {
		if(mod4 == 0) {
			res += vec3(-.5, -.5, 0.0);
		} else if(mod4 == 1) {
			res += vec3(-.5, 0.5, 0.0);
		} else if(mod4 == 2) {
			res += vec3(0.5, 0.5, 0.0);
		} else if(mod4 == 3) {
			res += vec3(0.5, -.5, 0.0);
		}
	} else if(face == 4) {
		if(mod4 == 0) {
			res += vec3(0.5, 0.0, -.5);
		} else if(mod4 == 1) {
			res += vec3(0.5, 0.0, 0.5);
		} else if(mod4 == 2) {
			res += vec3(-.5, 0.0, 0.5);
		} else if(mod4 == 3) {
			res += vec3(-.5, 0.0, -.5);
		}
	} else if(face == 5) {
		if(mod4 == 0) {
			res += vec3(-.5, 0.0, -.5);
		} else if(mod4 == 1) {
			res += vec3(-.5, 0.0, 0.5);
		} else if(mod4 == 2) {
			res += vec3(0.5, 0.0, 0.5);
		} else if(mod4 == 3) {
			res += vec3(0.5, 0.0, -.5);
		}
	}
#else
	res += u_facesOffsets[offsetIdx].xyz;
#endif // DEBUG_POS_NO_UNIFORM
	return vec4(res, 1.0);
}

vec4 getVertexNormal(int face) {
	int offsetIdx = 4 * face;
	vec3 normal = vec3(
		u_facesOffsets[offsetIdx].w,
		u_facesOffsets[offsetIdx + 1].w,
		u_facesOffsets[offsetIdx + 2].w
	);
	return vec4(normalize(normal), 0.0);
}

vec2 getUV(float idx, float width, float height) {
	float fudgedIdx = idx + IDX_FUDGE;
	return vec2(
		(mod(fudgedIdx, width) + TEXEL_OFFSET) / width,
		(floor(fudgedIdx / width) + TEXEL_OFFSET) / height
	);
}

vec3 getNeighbourVoxelUVW(vec3 centerPos, int face) {
	int offsetIdx = 4 * face;
	vec3 offset = vec3(
		u_facesOffsets[offsetIdx].w,
		u_facesOffsets[offsetIdx + 1].w,
		u_facesOffsets[offsetIdx + 2].w
	);
	vec4 world = u_mapInverseScale * mul(u_model[0], vec4(floor(centerPos + offset), 1.0));
	return world.xyz / u_mapSize;
}

vec2 getPaletteUV(float idx) {
	float fudgedIdx = idx + IDX_FUDGE;
	return vec2(
		(mod(fudgedIdx, u_paletteSize) + TEXEL_OFFSET) / u_paletteSize,
		(floor(fudgedIdx / u_paletteSize) * 2.0 + TEXEL_OFFSET) / u_paletteSize
	);
}

float _getFaceShading(int faceIdx) {
	return faceIdx == 4 ? mix(1.0, FACE_SHADING_TOP, u_faceShading) :
		faceIdx == 5 ? mix(1.0, FACE_SHADING_DOWN, u_faceShading) :
		1.0f;
}

// source: adjustHue in shaderlib
vec3 _getHueAdjustedAOColor(vec3 base) {
	vec3 yiq = convertRGB2YIQ(base);
	float angle = atan2(yiq.z, yiq.y);
	float len = length(yiq.yz);

#if AO_COLOR_HUE_CLAMP_TARGET
	angle = mix(
		mix(min(angle + AO_HUE_STEP_RAD, AO_HUE_THRESHOLD_TARGET_RAD),
			max(angle - AO_HUE_STEP_RAD, -2.0 * PI + AO_HUE_THRESHOLD_TARGET_RAD),
			step(angle, AO_HUE_THRESHOLD_DIR_RAD)),
		max(angle - AO_HUE_STEP_RAD, AO_HUE_THRESHOLD_TARGET_RAD),
		step(AO_HUE_THRESHOLD_TARGET_RAD, angle)
	);
	// equivalent to doing this:
	/*
	if (angle >= AO_HUE_THRESHOLD_TARGET_RAD) {
		angle = max(angle - AO_HUE_STEP_RAD, AO_HUE_THRESHOLD_TARGET_RAD);
	} else if (angle <= AO_HUE_THRESHOLD_DIR_RAD) {
		angle = max(angle - AO_HUE_STEP_RAD, -2.0 * PI + AO_HUE_THRESHOLD_TARGET_RAD);
	} else {
		angle = min(angle + AO_HUE_STEP_RAD, AO_HUE_THRESHOLD_TARGET_RAD);
	}
	*/
#else
	angle += mix(AO_HUE_STEP_RAD, -AO_HUE_STEP_RAD, CLAMP01(step(AO_HUE_THRESHOLD_TARGET_RAD, angle) + step(angle, AO_HUE_THRESHOLD_DIR_RAD)));
#endif

	return convertYIQ2RGB(vec3(yiq.x, len * cos(angle), len * sin(angle)));
}

vec3 _aoBlend(vec3 color, vec3 comp, float aoValue) {
#if AO_COLOR == 0
	vec4 ao = vec4(1.0 - color, aoValue * AO_BLEND_COEF);
	return mix(color, ao.xyz, ao.w);
#elif AO_COLOR == 1
	vec4 ao = vec4(adjustHue(color, AO_HUE_STEP_RAD), aoValue * AO_BLEND_COEF);
	return mix(color, ao.xyz, ao.w);
#elif AO_COLOR == 2
	float ao = aoValue * AO_BLEND_COEF;
	return adjustHue(color, ao * AO_HUE_STEP_RAD);
#elif AO_COLOR == 3
	vec4 ao = vec4(_getHueAdjustedAOColor(color), aoValue * AO_BLEND_COEF);
	return mix(color, ao.xyz, ao.w);
#elif AO_COLOR == 4
	float ao = aoValue * AO_BLEND_COEF;
	return mix(color, comp, ao);
#else
	return color;
#endif
}

float _RGB2Luma(vec3 rgb) {
	return dot(vec3(0.2126729, 0.7151522, 0.0721750), rgb);
}

vec3 _litBlend(vec3 color, float lightValue, vec3 lightRGB, vec3 skybox, vec3 ambient) {
	float illumination = max(_RGB2Luma(lightRGB), lightValue);
	vec3 tint = BLEND_SOFT_ADDITIVE(skybox, lightRGB);
	return color * (tint * illumination + ambient);
}

vec3 _fogBlend(vec3 lit, vec3 lightRGB, float d) {
	vec3 emission = mix(lightRGB, u_fogColor.xyz, CLAMP01(d * u_emissiveFog));
	vec3 fogged = mix(lit, u_fogColor.xyz, CLAMP01(d));
	return BLEND_SOFT_ADDITIVE(fogged, emission);
}

float _getVoxelLightValue(vec4 voxelLight, float aoValue) {
#if VOXEL_VARIANT_LIGHTING_UNIFORM
	// AO value must be applied to final light value
	float lightAO = aoValue * AO_LIGHT_COEF;
	float lightValue = max(0.0, (voxelLight.x * 0.9 + 0.1) - lightAO);
#else
	// AO value was applied to light value engine-side
	float lightValue = voxelLight.x;
#endif
	return lightValue;
}

vec4 getVertexDebugColor(vec4 voxelLight, vec3 ambient, float aoValue, vec4 color, vec3 comp, int face) {
#if VOXEL_VARIANT_LIGHTING_UNIFORM
// AO value must be applied to final light value

	float lightAO = aoValue * AO_LIGHT_COEF;
#if DEBUG_VERTEX_LIGHTING == 1 // voxelLight as color (no unpacking)
	float dimmed = max(0, 1.0 - lightAO);
	return voxelLight * dimmed;
#elif DEBUG_VERTEX_LIGHTING == 2 // sunlight as greyscale
	float lightValue = voxelLight.x;
	float dimmed = max(0, lightValue - lightAO);
	return vec4(lightValue * WHITE.xyz, 1.0) * dimmed;
#elif DEBUG_VERTEX_LIGHTING == 3 // red light
	float dimmed = max(0, 1.0 - lightAO);
	return vec4(voxelLight.y, 0.0, 0.0, 1.0) * dimmed;
#elif DEBUG_VERTEX_LIGHTING == 4 // green light
	float dimmed = max(0, 1.0 - lightAO);
	return vec4(0.0, voxelLight.z, 0.0, 1.0) * dimmed;
#elif DEBUG_VERTEX_LIGHTING == 5 // blue light
	float dimmed = max(0, 1.0 - lightAO);
	return vec4(0.0, 0.0, voxelLight.w, 1.0) * dimmed;
#elif DEBUG_VERTEX_LIGHTING == 6 // combined
	float lightValue = voxelLight.x;
	float dimmed = max(0, lightValue - lightAO);
	return vec4(voxelLight.yzw, 1.0) * dimmed;
#else
	return vec4_splat(0.0);
#endif // DEBUG_VERTEX_LIGHTING

#else // VOXEL_VARIANT_LIGHTING_UNIFORM
// AO value was applied to light value engine-side

#if DEBUG_VERTEX_LIGHTING == 1 // voxelLight as color (no unpacking)
	return voxelLight;
#elif DEBUG_VERTEX_LIGHTING == 2 // sunlight as greyscale
	float lightValue = voxelLight.x;
	return vec4(lightValue * WHITE.xyz, 1.0) * lightValue;
#elif DEBUG_VERTEX_LIGHTING == 3 // red light
	float lightValue = voxelLight.x;
	return vec4(voxelLight.y, 0.0, 0.0, 1.0) * lightValue;
#elif DEBUG_VERTEX_LIGHTING == 4 // green light
	float lightValue = voxelLight.x;
	return vec4(0.0, voxelLight.z, 0.0, 1.0) * lightValue;
#elif DEBUG_VERTEX_LIGHTING == 5 // blue light
	float lightValue = voxelLight.x;
	return vec4(0.0, 0.0, voxelLight.w, 1.0) * lightValue;
#elif DEBUG_VERTEX_LIGHTING == 6 // combined
	float lightValue = voxelLight.x;
	return vec4(voxelLight.yzw, 1.0) * lightValue;
#else
	return vec4_splat(0.0);
#endif // DEBUG_VERTEX_LIGHTING

#endif // VOXEL_VARIANT_LIGHTING_UNIFORM
}

//// Vertex lighting model
/// - LIGHT VALUE: dim factor, includes AO dimming based of substracting AO value * AO_COEF from sun light
/// - AO BLENDING: applied on base color, based of AO value & complementary color
/// - SKYBOX COLOR: multiplicative after AO blending applied
/// - VOXEL RGB (pre-lit): as soft additive on skybox color + luma from voxel RGB can override light value
/// - AMBIENT COLOR: small portion of skybox color added as a baseline lighting
/// - EMISSIVE FOG: if enabled, pre-apply voxel RGB on lit color by fog voxel RGB factor
/// - FACE SHADING: if enabled, multiply by per-face shade factor
/// - FOG: if enabled, distance fog applied to lit color
/// - VOXEL RGB (post-lit): as soft additive on final color
/// - ALPHA: from base color
vec4 getVertexLitColor(vec4 voxelLight, vec3 skybox, float aoValue, vec4 color, vec3 comp, float clipZ, int face) {
	float lightValue = _getVoxelLightValue(voxelLight, aoValue);
	vec3 lightRGB = voxelLight.yzw;

	vec3 ao = _aoBlend(color.xyz, comp, aoValue);
	vec3 ambient = skybox * u_skyAmbientFactor;
	vec3 lit = _litBlend(ao, lightValue, lightRGB * VOXEL_LIGHT_RGB_PRE_FACTOR, skybox, ambient);

#if ENABLE_FACE_SHADING
	lit = CLAMP01(lit * _getFaceShading(face));
#endif

#if ENABLE_FOG
	float fog = (clipZ - u_fogStart) / u_fogLength;
	vec3 final = _fogBlend(lit, lightRGB * VOXEL_LIGHT_RGB_POST_FACTOR, fog);
#else
	vec3 final = BLEND_SOFT_ADDITIVE(lit, lightRGB * VOXEL_LIGHT_RGB_POST_FACTOR);
#endif

	return vec4(final, color.w);
}

/// Deferred lighting variant: albedo w/ AO and face shading applied
vec4 getVertexDeferredAlbedo(float aoValue, vec4 color, vec3 comp, int face) {
	vec3 albedo = _aoBlend(color.xyz, comp, aoValue);

#if ENABLE_FACE_SHADING
	albedo = CLAMP01(albedo * _getFaceShading(face));
#endif

	return vec4(albedo, color.w);
}

/// Deferred lighting variant: voxel light
vec4 getVertexDeferredLighting(vec4 voxelLight, float aoValue) {
	float lightValue = _getVoxelLightValue(voxelLight, aoValue);

	return vec4(lightValue, voxelLight.yzw);
}

/// Deferred lighting variant: compute final color for deferred-lit geometry
vec3 getVertexDeferredLitColor(vec3 albedo, vec3 skybox, vec3 ambient, vec3 illumination, vec3 emission, float lightValue, float fog) {
	vec3 lit = _litBlend(albedo, lightValue, illumination, skybox, ambient);

#if ENABLE_FOG
	vec3 final = _fogBlend(lit, emission, fog);
#else
	vec3 final = BLEND_SOFT_ADDITIVE(lit, emission);
#endif

	return final;
}

/// Deferred lighting variant: compute final color for pre-lit geometry
vec3 getDeferredPreLitColor(vec3 opaque, vec3 lights) {
	return opaque + lights;
}

/// Non-volume (quad, font) variant: no AO, no face shading
vec4 getNonVolumeVertexLitColor(vec4 color, float lightValue, vec3 lightRGB, vec3 skybox, float clipZ) {
	vec3 ambient = skybox * u_skyAmbientFactor;
	vec3 lit = _litBlend(color.xyz, lightValue, lightRGB * VOXEL_LIGHT_RGB_PRE_FACTOR, skybox, ambient);

#if ENABLE_FOG
	float fog = (clipZ - u_fogStart) / u_fogLength;
	vec3 final = _fogBlend(lit, lightRGB * VOXEL_LIGHT_RGB_POST_FACTOR, fog);
#else
	vec3 final = BLEND_SOFT_ADDITIVE(lit, lightRGB * VOXEL_LIGHT_RGB_POST_FACTOR);
#endif

	return vec4(final, color.w);
}

#endif // __VOXELS_LIB_SH__
