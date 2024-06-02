#ifndef __DITHERING_LIB_SH__
#define __DITHERING_LIB_SH__

// Nrand + srand dithering from source in bgfx example: http://www.loopit.dk/banding_in_games.pdf
// screen pos in pixels
float nrand(vec2 pos) {
	return fract(sin(dot(pos, vec2(12.9898, 78.233)))* 43758.5453);
}

// screen pos in pixels
float n4rand_ss(vec2 pos) {
	float nrnd0 = nrand(pos + 0.07 * fract(u_time));
	float nrnd1 = nrand(pos + 0.11 * fract(u_time + 0.573953));
	return 0.23 * sqrt(-log(nrnd0 + 0.00001)) * cos(2.0 * 3.141592 * nrnd1) + 0.5;
}

// from: http://alex.vlachos.com/graphics/Alex_Vlachos_Advanced_VR_Rendering_GDC2015.pdf
// screen pos in pixels
vec3 ssValveDither(vec2 pos, float colorDepth) {
    vec3 vDither = vec3_splat(dot(vec2(131.0, 312.0), pos + u_time));
    vDither.rgb = fract(vDither.rgb / vec3(103.0, 71.0, 97.0));
    return (vDither.rgb / colorDepth);
}

// from: http://advances.realtimerendering.com/s2014/index.html
// normalized screen pos
float interleavedGradientNoise(vec2 uv) {
    const vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
	vec2 seed = uv + 1e5 * fract(u_time);
    return fract(magic.z * fract(dot(seed, magic.xy)));
}

vec3 dither(vec2 pos, vec2 uv, vec3 color) {
#if DITHERING_FUNC == 1
	float r = n4rand_ss(pos);
	return color + vec3(r, r, r) / 40.0;
#elif DITHERING_FUNC == 2
	float r = nrand(pos);
	return color + vec3(r, r, r) / 80.0;
#elif DITHERING_FUNC == 3
	return color + ssValveDither(pos, 255.0);
#elif DITHERING_FUNC == 4
	float r = interleavedGradientNoise(uv);
	return color + vec3(r, 1.0 - r, r) / 255.0;
#else
	return color;
#endif
}

#endif // __DITHERING_LIB_SH__
