#ifndef __QUAD_LIB_SH__
#define __QUAD_LIB_SH__

#include "./config.sh"

void unpackQuadFullMetadata(float f, out float metadata[7]) {
	float unpack = f;
	float b = floor((unpack + UNPACK_FUDGE) / 32768.0);
	unpack -= b * 32768.0;
	float g = floor((unpack + UNPACK_FUDGE) / 2048.0);
	unpack -= g * 2048.0;
	float r = floor((unpack + UNPACK_FUDGE) / 128.0);
	unpack -= r * 128.0;
	float s = floor((unpack + UNPACK_FUDGE) / 8.0);
	unpack -= s * 8.0;
	float cutout = floor((unpack + UNPACK_FUDGE) / 4.0);
	unpack -= cutout * 4.0;
	float unpack9SliceNormal = floor((unpack + UNPACK_FUDGE) / 2.0);
	float unlit = unpack - unpack9SliceNormal * 2.0;

	metadata[0] = unlit;
	metadata[1] = unpack9SliceNormal;
	metadata[2] = cutout;
	metadata[3] = s / VOXEL_LIGHT_MAX;
	metadata[4] = r / VOXEL_LIGHT_MAX;
	metadata[5] = g / VOXEL_LIGHT_MAX;
	metadata[6] = b / VOXEL_LIGHT_MAX;
}

float unpackQuadMetadata_Cutout(float f) {
	float unpack = f - floor((f + UNPACK_FUDGE) / 8.0);
	return floor((unpack + UNPACK_FUDGE) / 4.0);
}

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