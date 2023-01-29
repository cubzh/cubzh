//
//  shape_point.cpp
//  cli
//
//  Created by Gaetan de Villele on 12/01/2023.
//

#include "shape_point.hpp"

// Core
#include "serialization.h"
#include "serialization_v6.h"

bool commandSetPoint(cxxopts::ParseResult parseResult, std::string& err) {

    // validation

    if (parseResult.count("input") != 1) {
        err.assign("exactly one input file expected");
        return false;
    }

    if (parseResult.count("output") != 0 && parseResult.count("output") != 1) {
        err.assign("no more that 1 output file expected");
        return false;
    }

    // processing

    const std::string inputPath = parseResult["input"].as<std::vector<std::string>>().front();
    std::string outputPath = inputPath;
    if (parseResult.count("output") > 0) {
        outputPath = parseResult["output"].as<std::string>();
    }

    const std::vector<std::string>& args = parseResult.unmatched();

    const std::string pointName = args[0];
    // printf("point name: %s\n", pointName.c_str());

    float x = std::stof(args[1]);
    float y = std::stof(args[2]);
    float z = std::stof(args[3]);
    // printf("point pos: %f %f %f\n", x, y, z);

    float rx = std::stof(args[4]);
    float ry = std::stof(args[5]);
    float rz = std::stof(args[6]);
    // printf("point rot: %f %f %f\n", rx, ry, rz);

    // Read input file
    FILE *fd = fopen(inputPath.c_str(), "rb");
    if (fd == nullptr) {
        // TODO: handle error
        return false;
    }

    // The file descriptor is owned by the stream, which will fclose it in the future.
    Stream *stream = stream_new_file_read(fd);
    ColorAtlas *colorAtlas = color_atlas_new();

    LoadShapeSettings settings;
    settings.isMutable = true;
    settings.octree = true;

    Shape *shape = serialization_load_shape(stream, // frees stream, closing fd
                                            "",
                                            colorAtlas,
                                            &settings,
                                            false); // allowLegacy
    float3 posf3 = {x, y, z};
    shape_set_point_of_interest(shape, pointName.c_str(), &posf3);

    float3 rotf3 = {rx, ry, rz};
    shape_set_point_rotation(shape, pointName.c_str(), &rotf3);

    FILE *outfd = fopen(outputPath.c_str(), "wb");
    if (fd == nullptr) {
        // TODO: handle error
        return false;
    }

    // bool ok =
    serialization_save_shape(shape, nullptr /*preview data*/, 0, outfd);
    // printf("Write file: %s\n", ok ? "OK" : "FAILED");

    color_atlas_free(colorAtlas);
    return true;
}
