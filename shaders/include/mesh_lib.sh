#ifndef __MESH_LIB_SH__
#define __MESH_LIB_SH__

#define MESH_METADATA_ALBEDOFLAG 0
#define MESH_METADATA_NORMALFLAG 1
#define MESH_METADATA_EMISSIVEFLAG 2
#define MESH_METADATA_METALLICFLAG 3
#define MESH_METADATA_METALLIC 4
#define MESH_METADATA_ROUGHNESS 5

void unpackMeshMetadata1(float f, out float metadata[6]) {
	float unpack = f;
	float roughness = floor((unpack + UNPACK_FUDGE) / 4096.0);
	unpack -= roughness * 4096.0;
	float metallic = floor((unpack + UNPACK_FUDGE) / 16.0);
	unpack -= metallic * 16.0;
	float metallicFlag = floor((unpack + UNPACK_FUDGE) / 8.0);
	unpack -= metallicFlag * 8.0;
	float emissiveFlag = floor((unpack + UNPACK_FUDGE) / 4.0);
	unpack -= emissiveFlag * 4.0;
    float normalFlag = floor((unpack + UNPACK_FUDGE) / 2.0);
	float albedoFlag = unpack - normalFlag * 2.0;
	
	metadata[MESH_METADATA_ALBEDOFLAG] = albedoFlag;
	metadata[MESH_METADATA_NORMALFLAG] = normalFlag;
	metadata[MESH_METADATA_EMISSIVEFLAG] = emissiveFlag;
	metadata[MESH_METADATA_METALLICFLAG] = metallicFlag;
	metadata[MESH_METADATA_METALLIC] = metallic / 255.0;
	metadata[MESH_METADATA_ROUGHNESS] = roughness / 255.0;
}

float unpackMeshMetadata1_albedoFlag(float f) {
    float unpack = floor((f + UNPACK_FUDGE) / 2.0);
    return f - unpack * 2.0;
}

vec2 unpackMeshMetadata2(float f) {
	float vlighting = floor((f + UNPACK_FUDGE) / 2.0);
	float unlit = f - vlighting * 2.0;

	return vec2(unlit, vlighting);
}

vec3 decodeNormal(vec3 normal, mat3 tbn) {
    vec3 snormal = unormToNorm3(normal);
    vec3 wnormal = mul(tbn, snormal);
    return normalize(wnormal);
}

#endif // __MESH_LIB_SH__