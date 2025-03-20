#ifndef __FONT_LIB_SH__
#define __FONT_LIB_SH__

#include "./config.sh"

vec3 unpackFontUniformMetadata(float f) {
	float unpack = f;
	float outlineWeight = floor((unpack + UNPACK_FUDGE) / 65536.0);
	unpack -= outlineWeight * 65536.0;
	float softness = floor((unpack + UNPACK_FUDGE) / 256.0);
	float weight = unpack - softness * 256.0;

	return vec3(weight, softness, outlineWeight) / 255.0;
}

vec2 unpackFontAttributesMetadata(float f) {
	float unpack = f * 32767.0;
	float filtering = floor((unpack + UNPACK_FUDGE) / 2.0);
	float colored = unpack - filtering * 2.0;

	return vec2(colored, filtering);
}

#endif // __FONT_LIB_SH__