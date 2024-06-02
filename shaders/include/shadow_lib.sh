#ifndef __SHADOW_LIB_SH__
#define __SHADOW_LIB_SH__

float sampleShadow(Sampler s, vec2 uv, float depth, float bias) {
#if LIGHT_VARIANT_SHADOW_SAMPLE
	return shadow2D(s, vec3(uv, depth - bias));
#else
	return step(depth - bias, unpackRgbaToFloat(texture2D(s, uv)));
#endif
}

// Average 2x2 texels
float PCF4(Sampler s, vec2 uv, float depth, float bias, vec2 texelSize, vec2 blur) {
	float result = 0.0;
	vec2 scale = texelSize * blur;

	result += sampleShadow(s, uv + vec2(-1.0, 0.0) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(0.0, -1.0) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(0.0, 1.0) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(1.0, 0.0) * scale, depth, bias);

	return result / 4.0;
}

// Average 3x3 texels
float PCF9(Sampler s, vec2 uv, float depth, float bias, vec2 texelSize, vec2 blur) {
	float result = 0.0;
	vec2 scale = texelSize * blur;

	result += sampleShadow(s, uv + vec2(-1.0, -1.0) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(-1.0, 0.0) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(-1.0, 1.0) * scale, depth, bias);

	result += sampleShadow(s, uv + vec2(0.0, -1.0) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(0.0, 0.0) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(0.0, 1.0) * scale, depth, bias);

	result += sampleShadow(s, uv + vec2(1.0, -1.0) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(1.0, 0.0) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(1.0, 1.0) * scale, depth, bias);

	return result / 9.0;
}

// Average 4x4 unaligned texels
float PCF16(Sampler s, vec2 uv, float depth, float bias, vec2 texelSize, vec2 blur) {
	float result = 0.0;
	vec2 scale = texelSize * blur;

	result += sampleShadow(s, uv + vec2(-1.5, -1.5) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(-1.5, -0.5) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(-1.5,  0.5) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(-1.5,  1.5) * scale, depth, bias);

	result += sampleShadow(s, uv + vec2(-0.5, -1.5) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(-0.5, -0.5) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(-0.5,  0.5) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(-0.5,  1.5) * scale, depth, bias);

	result += sampleShadow(s, uv + vec2(0.5, -1.5) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(0.5, -0.5) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(0.5,  0.5) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(0.5,  1.5) * scale, depth, bias);

	result += sampleShadow(s, uv + vec2(1.5, -1.5) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(1.5, -0.5) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(1.5,  0.5) * scale, depth, bias);
	result += sampleShadow(s, uv + vec2(1.5,  1.5) * scale, depth, bias);

	return result / 16.0;
}

// PCF16 using fewer samples, based on screen position
// See here: https://developer.nvidia.com/gpugems/gpugems/part-ii-lighting-and-shadows/chapter-11-shadow-map-antialiasing
float PCF16_4(Sampler s, vec2 uv, float depth, float bias, vec2 texelSize, vec2 blur) {
	float result = 0.0;
	vec2 scale = texelSize * blur;

	vec2 f = fract(uv / texelSize * 0.5);
	vec2 offset = vec2(float(f.x > 0.25), float(f.y > 0.25));
	//offset.y += offset.x;
	//if (offset.y > 1.1) offset.y = 0.0;

	result += sampleShadow(s, uv + (offset + vec2(-1.5,  0.5)) * scale, depth, bias);
	result += sampleShadow(s, uv + (offset + vec2( 0.5,  0.5)) * scale, depth, bias);
	result += sampleShadow(s, uv + (offset + vec2(-1.5, -1.5)) * scale, depth, bias);
	result += sampleShadow(s, uv + (offset + vec2( 0.5, -1.5)) * scale, depth, bias);

	return result / 4.0;
}

float getShadow(Sampler s, vec2 uv, float depth, float bias, float texelSize) {
#if LIGHT_VARIANT_SHADOW_SOFT
#if SHADOWMAP_FILTERING == 1
	return PCF4(s, uv, depth, bias, vec2_splat(texelSize), SHADOWMAP_FILTERING_BLUR);
#elif SHADOWMAP_FILTERING == 2
	return PCF9(s, uv, depth, bias, vec2_splat(texelSize), SHADOWMAP_FILTERING_BLUR);
#elif SHADOWMAP_FILTERING == 3
	return PCF16(s, uv, depth, bias, vec2_splat(texelSize), SHADOWMAP_FILTERING_BLUR);
#elif SHADOWMAP_FILTERING == 4
	return PCF16_4(s, uv, depth, bias, vec2_splat(texelSize), SHADOWMAP_FILTERING_BLUR);
#else
	return sampleShadow(s, uv, depth, bias);
#endif // SHADOWMAP_FILTERING
#else
	return sampleShadow(s, uv, depth, bias);
#endif
}

#endif // __SHADOW_LIB_SH__