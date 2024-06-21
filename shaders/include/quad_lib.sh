#ifndef __QUAD_LIB_SH__
#define __QUAD_LIB_SH__

float sliceUV(float uv, vec2 borders, float slice) {
	if (uv < borders[0]) {
		return uv / borders[0] * slice;
	} else if (uv > borders[1]) {
		return slice + (uv - borders[1]) / (1.0 - borders[1]) * (1.0 - slice);
	} else {
		return slice;
	}
}

#endif // __QUAD_LIB_SH__