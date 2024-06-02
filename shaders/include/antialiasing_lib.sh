#ifndef __ANTIALIASING_LIB_SH__
#define __ANTIALIASING_LIB_SH__

#include "./utils_lib.sh"

//// Fast Approximate Anti-Aliasing (FXAA)
// Source: https://developer.download.nvidia.com/assets/gamedev/files/sdk/11/FXAA_WhitePaper.pdf
//
// FXAA_EDGE_THRESHOLD: minimum amount of local contrast required to apply algorithm,
// 	1/3 – too little
// 	1/4 – low quality
// 	1/8 – high quality
// 	1/16 – overkill
// FXAA_EDGE_THRESHOLD_MIN: trims the algorithm from processing dark areas,
// 	1/32 – visible limit
// 	1/16 – high quality
// 	1/12 – upper limit (start of visible unfiltered edges)
// FXAA_SEARCH_STEPS: controls the maximum number of search steps,
// 	multiplied by FXAA_SEARCH_ACCELERATION for filtering radius (when using aniso filtering)
#if POST_VARIANT_QUALITY == 3
	#define FXAA_EDGE_THRESHOLD 0.125
	#define FXAA_EDGE_THRESHOLD_MIN 0.0625
	#define FXAA_SEARCH_STEPS 32
#elif POST_VARIANT_QUALITY == 2
	#define FXAA_EDGE_THRESHOLD 0.125
	#define FXAA_EDGE_THRESHOLD_MIN 0.0625
	#define FXAA_SEARCH_STEPS 16
#else
	#define FXAA_EDGE_THRESHOLD 0.25
	#define FXAA_EDGE_THRESHOLD_MIN 0.03125
	#define FXAA_SEARCH_STEPS 1
#endif
// Amount of sub-pixel filtering (0 disabled)
#define FXAA_SUBPIX_TRIM_SCALE 1.0
// Controls removal of sub-pixel aliasing,
// 	1/2 – low removal
// 	1/3 – medium removal
// 	1/4 – default removal
// 	1/8 – high removal
// 	0 – complete removal
#define FXAA_SUBPIX_TRIM 0.25
// 	Insures fine detail is not completely removed, partly overrides FXAA_SUBPIX_TRIM,
// 	3/4 – default amount of filtering
// 	7/8 – high amount of filtering
// 	1 – no capping of filtering
#define FXAA_SUBPIX_CAP 1.0
// 	How much to accelerate search using anisotropic filtering,
// 	1 – no acceleration
// 	2 – skip by 2 pixels
// 	3 – skip by 3 pixels
// 	4 – skip by 4 pixels (hard upper limit)
#define FXAA_SEARCH_ACCELERATION 1
#define FXAA_SEARCH_THRESHOLD 0.5
// Debug modes,
// 1 - pixels detected as edge
// 2 - pixels detected as edge, w/ mix towards yellow where sub-pixel aliasing is detected
// 3 - horizontal/vertical edges
// 4 - highest contrast pixel pairs along edges (simple FXAA: highlight blur areas)
// 5 - closest end-of-edge is on the negative (red) or positive (blue) side
// 6 - end-of-edge distance ratio
#define FXAA_DEBUG 0

float fxaaLuma(vec3 rgb) {
	return rgb.y * (0.587 / 0.299) + rgb.x;
}

vec3 fxaa(sampler2D s, vec2 uv, vec2 texelSize, vec3 rgb) {
	// (1) Local contrast check
	// Luma range with the 4 neighbors is used to detect visible aliasing

	vec3 rgbN = texture2D(s, vec2(uv.x, uv.y - texelSize.y)).xyz;
	vec3 rgbW = texture2D(s, vec2(uv.x - texelSize.x, uv.y)).xyz;
	vec3 rgbE = texture2D(s, vec2(uv.x + texelSize.x, uv.y)).xyz;
	vec3 rgbS = texture2D(s, vec2(uv.x, uv.y + texelSize.y)).xyz;

	float lumaN = fxaaLuma(rgbN);
	float lumaW = fxaaLuma(rgbW);
	float lumaM = fxaaLuma(rgb);
	float lumaE = fxaaLuma(rgbE);
	float lumaS = fxaaLuma(rgbS);

	float rangeMin = min(lumaM, min(min(lumaN, lumaW), min(lumaS, lumaE)));
	float rangeMax = max(lumaM, max(max(lumaN, lumaW), max(lumaS, lumaE)));
	float range = rangeMax - rangeMin;

	if(range < max(FXAA_EDGE_THRESHOLD_MIN, rangeMax * FXAA_EDGE_THRESHOLD)) {
		//return vec3(0.0, 0.0, 0.0);
		return rgb;
	}

#if FXAA_DEBUG == 1
	return vec3(1.0, 0.0, 0.0);
#endif

	// (2) Sub-pixel aliasing test
	// Pixel contrast from average neighbors luma to indicate how many pixels contribute to an edge

	vec3 rgbNW = texture2D(s, vec2(uv.x - texelSize.x, uv.y - texelSize.y)).xyz;
	vec3 rgbNE = texture2D(s, vec2(uv.x + texelSize.x, uv.y - texelSize.y)).xyz;
	vec3 rgbSW = texture2D(s, vec2(uv.x - texelSize.x, uv.y + texelSize.y)).xyz;
	vec3 rgbSE = texture2D(s, vec2(uv.x + texelSize.x, uv.y + texelSize.y)).xyz;

	float lumaNW = fxaaLuma(rgbNW);
	float lumaNE = fxaaLuma(rgbNE);
	float lumaSW = fxaaLuma(rgbSW);
	float lumaSE = fxaaLuma(rgbSE);

	//float lumaFilter = (lumaN + lumaW + lumaE + lumaS) * 0.25;
	float lumaFilter = (2.0 * (lumaN + lumaW + lumaE + lumaS) + lumaNW + lumaNE + lumaSW + lumaSE) / 12.0;
	float rangeFilter = abs(lumaFilter - lumaM);
	float blend = max(0.0, (rangeFilter / range) - FXAA_SUBPIX_TRIM) * FXAA_SUBPIX_TRIM_SCALE;
	blend = min(FXAA_SUBPIX_CAP, blend);
	//float blend = smoothstep(0, 1, saturate(rangeFilter / range));
	//blend = blend * blend *  * FXAA_SUBPIX_TRIM_SCALE;

#if FXAA_DEBUG == 2
	return mix(vec3(1.0, 0.0, 0.0), vec3(1.0, 1.0, 0.0), blend);
#endif

	// (3) Vertical/horizontal edge test
	// Weighted average of the 3x3 neighborhood as an indication of local edge amount

	float edgeVert = abs((0.25 * lumaNW) + (-0.5 * lumaN) + (0.25 * lumaNE)) +
					 abs((0.50 * lumaW ) + (-1.0 * lumaM) + (0.50 * lumaE )) +
					 abs((0.25 * lumaSW) + (-0.5 * lumaS) + (0.25 * lumaSE));
	float edgeHorz = abs((0.25 * lumaNW) + (-0.5 * lumaW) + (0.25 * lumaSW)) +
					 abs((0.50 * lumaN ) + (-1.0 * lumaM) + (0.50 * lumaS )) +
					 abs((0.25 * lumaNE) + (-0.5 * lumaE) + (0.25 * lumaSE));
	bool horzSpan = edgeHorz >= edgeVert;

#if FXAA_DEBUG == 3
	return horzSpan ? vec3(1.0, 1.0, 0.0) : vec3(0.0, 1.0, 1.0);
#endif

	// Choose side of edge with highest gradient to get start UV & luma, and gradient threshold for the search
	float pixelStep = horzSpan ? -texelSize.y : -texelSize.x;
	float luma1 = horzSpan ? lumaN : lumaW; // negative side
	float luma2 = horzSpan ? lumaS : lumaE; // positive side
	float grad1 = abs(luma1 - lumaM);
	float grad2 = abs(luma2 - lumaM);
#if FXAA_DEBUG == 4
	return grad2 > grad1 ? vec3(1.0, 1.0, 1.0) : vec3(1.0, 0.0, 0.0);
#endif
	if (grad2 > grad1) {
		luma1 = luma2;
		grad1 = grad2;
		pixelStep *= -1.0f;
	}
	vec2 startUV = uv + (horzSpan ? vec2(0.0, pixelStep) : vec2(pixelStep, 0.0)) * 0.5;
	float startLuma = (luma1 + lumaM) * 0.5;
	float gradThreshold = grad1 * FXAA_SEARCH_THRESHOLD;

	// (4) End-of-edge search
	// Pair the pixels with highest contrast along the edge in both directions until we find end-of-edge, or max/threshold reached

	vec2 offset = horzSpan ? vec2(texelSize.x, 0.0) : vec2(0.0, texelSize.y);
	vec2 uvP = uv + offset;
	vec2 uvN = uv - offset;

	bool doneP = false, doneN = false;
	float lumaEndN, lumaEndP;
	for(int i = 0; i < FXAA_SEARCH_STEPS; ++i) {
#if FXAA_SEARCH_ACCELERATION == 1
		if(!doneN) lumaEndN = fxaaLuma(texture2D(s, uvN).xyz);
		if(!doneP) lumaEndP = fxaaLuma(texture2D(s, uvP).xyz);
#else
		if(!doneN) lumaEndN = fxaaLuma(texture2DGrad(s, uvN, offset.x, offset.y).xyz);
		if(!doneP) lumaEndP = fxaaLuma(texture2DGrad(s, uvP, offset.x, offset.y).xyz);
#endif

		doneN = doneN || (abs(lumaEndN - startLuma) >= gradThreshold);
		doneP = doneP || (abs(lumaEndP - startLuma) >= gradThreshold);
		if(doneN && doneP) break;

		if(!doneN) uvN -= offset;
		if(!doneP) uvP += offset;
 	}

	float distN = horzSpan ? uv.x - uvN.x : uv.y - uvN.y;
	float distP = horzSpan ? uvP.x - uv.x : uvP.y - uv.y;
	float minDist = min(distN, distP);
	float totalDist = distN + distP;
	float lumaEnd = distN < distP ? lumaEndN : lumaEndP;

#if FXAA_DEBUG == 5
	return distN < distP ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 0.0, 1.0);
#elif FXAA_DEBUG == 6
	return vec3(1.0 - minDist / totalDist, 0.0, 0.0);
#endif

	// (5) Final pixel color
	// Apply offset if end-of-edge luma variations are different from the one at current pixel

	bool sameVariation = (lumaM - startLuma < 0.0) == (lumaEnd - startLuma < 0.0);
	float subPixelOffset = sameVariation ? 0.0 : (0.5 - minDist / totalDist) * pixelStep;
	
	vec2 uvF = uv + (horzSpan ? vec2(0.0, subPixelOffset) : vec2(subPixelOffset, 0.0));
	vec3 rgbF = texture2D(s, uvF).xyz;

	vec3 rgbLowpass = (rgbN + rgbW + rgb + rgbE + rgbS + rgbNW + rgbNE + rgbSW + rgbSE) / 9.0;

	return mix(rgbLowpass, rgbF, blend);
}

//// Simple FXAA (edge detection + blur)
#define FXAA_SPAN_MAX   8.0
#define FXAA_REDUCE_MUL 1.0 / 8.0
#define FXAA_REDUCE_MIN 1.0 / 128.0

vec3 simpleFxaa(sampler2D s, vec2 uv, vec2 texelSize, vec3 rgb) {
	// (1) Local contrast check
	// Luma range from pairs of the diagonal neighbors is used to detect visible aliasing

	vec3 rgbNW = texture2D(s, vec2(uv.x - texelSize.x, uv.y - texelSize.y)).xyz;
	vec3 rgbNE = texture2D(s, vec2(uv.x + texelSize.x, uv.y - texelSize.y)).xyz;
	vec3 rgbSW = texture2D(s, vec2(uv.x - texelSize.x, uv.y + texelSize.y)).xyz;
	vec3 rgbSE = texture2D(s, vec2(uv.x + texelSize.x, uv.y + texelSize.y)).xyz;

	float lumaNW = rgb2PerceivedLuma(rgbNW);
	float lumaNE = rgb2PerceivedLuma(rgbNE);
	float lumaSW = rgb2PerceivedLuma(rgbSW);
	float lumaSE = rgb2PerceivedLuma(rgbSE);
	float lumaM = rgb2PerceivedLuma(rgb);

	vec2 dir;
    dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
    dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));
    
    float lumaSum   = lumaNW + lumaNE + lumaSW + lumaSE;
    float dirReduce = max(lumaSum * 0.25 * FXAA_REDUCE_MUL, FXAA_REDUCE_MIN);
    float rcpDirMin = 1. / (min(abs(dir.x), abs(dir.y)) + dirReduce);

    dir = min(vec2_splat(FXAA_SPAN_MAX), max(vec2_splat(-FXAA_SPAN_MAX), dir * rcpDirMin)) * texelSize;

#if FXAA_DEBUG == 1 || FXAA_DEBUG == 4
	float norm = sqrt(dir.x * dir.x + dir.y * dir.y);
	float maxNorm = sqrt(FXAA_SPAN_MAX * FXAA_SPAN_MAX * texelSize.x * texelSize.x + FXAA_SPAN_MAX * FXAA_SPAN_MAX * texelSize.y * texelSize.y);
#endif

#if FXAA_DEBUG == 1
	return mix(rgb * 0.5, vec3(1.0, 0.0, 0.0), norm / maxNorm);
#elif FXAA_DEBUG == 3
	if (dir.x == 0.0 && dir.y == 0.0) {
		return rgb;
	} else {
		return abs(dir.x) > abs(dir.y) ? vec3(1.0, 1.0, 0.0) : vec3(0.0, 1.0, 1.0);
	}
#endif

	// (2) Blur along edge gradient

	vec3 blur = ((rgbNW + rgbNE + rgbSW + rgbSE)
		+ 2.0 * (texture2D(s, uv + dir * (0./3. - .5)).xyz
			   + texture2D(s, uv + dir * (1./3. - .5)).xyz
			   + texture2D(s, uv + dir * (2./3. - .5)).xyz
			   + texture2D(s, uv + dir * (3./3. - .5)).xyz)) / 12.0;
    
    float lumaBlur = rgb2PerceivedLuma(blur);
    
    float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));

#if FXAA_DEBUG == 4
	return ((lumaBlur < lumaMin) || (lumaBlur > lumaMax)) ? vec3(0.0, 0.0, 0.0) : vec3(norm / maxNorm, 0.0, 0.0);
#endif

	return ((lumaBlur < lumaMin) || (lumaBlur > lumaMax)) ? rgb : blur;
}

#endif // __ANTIALIASING_LIB_SH__