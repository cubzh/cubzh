#ifndef __LIGHTING_LIB_SH__
#define __LIGHTING_LIB_SH__

vec3 schlickFresnel(float sVdotH, vec3 albedo, float metallic) {
	vec3 F0 = mix(vec3_splat(0.04), albedo, metallic);
    return F0 + (1.0 - F0) * pow(clamp(1.0 - sVdotH, 0.0, 1.0), 5.0);
}

float ggxDistribution(float sNdotH, float roughness) {
    float alpha2 = roughness * roughness * roughness * roughness;
    float denom = sNdotH * sNdotH * (alpha2 - 1.0) + 1.0;
    return alpha2 / (PI * denom * denom);
}

float geomSmith(float dp, float roughness) {
    float k = (roughness + 1.0) * (roughness + 1.0) / 8.0;
    return dp / (dp * (1.0 - k) + k);
}

#endif // __LIGHTING_LIB_SH__