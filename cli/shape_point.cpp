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
    printf("point name: %s\n", pointName.c_str());

    float x = std::stof(args[1]);
    float y = std::stof(args[2]);
    float z = std::stof(args[3]);
    printf("point pos: %f %f %f\n", x, y, z);

    float rx = std::stof(args[4]);
    float ry = std::stof(args[5]);
    float rz = std::stof(args[6]);
    printf("point rot: %f %f %f\n", rx, ry, rz);

    // Read input file
    FILE *fd = fopen(inputPath.c_str(), "rb");
    if (fd == nullptr) {
        // TODO: !
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

    printf("Loaded shape %p", shape);

    float3 posf3 = {x, y, z};
    shape_set_point_of_interest(shape, pointName.c_str(), &posf3);

    float3 rotf3 = {rx, ry, rz};
    shape_set_point_rotation(shape, pointName.c_str(), &rotf3);

    FILE *outfd = fopen(outputPath.c_str(), "wb");
    if (fd == nullptr) {
        // TODO: !
        return false;
    }

    bool ok = serialization_save_shape(shape, nullptr /*preview data*/, 0, outfd);
    printf("Write file: %s\n", ok ? "OK" : "FAILED");

    color_atlas_free(colorAtlas);

//    std::vector<std::string> input_paths = parseResult["input"].as<std::vector<std::string>>();
//    std::string output_path = parseResult["output"].as<std::string>();
//
//    std::cout << "* Combining voxel files..." << std::endl;
//    for (std::string input_path : input_paths) {
//        std::cout << "    - " << input_path << std::endl;
//    }
//    std::cout << "  output: " << output_path << std::endl;
//
//    ColorAtlas *colorAtlas = color_atlas_new();
//
//    Shape **shapes = (Shape**)malloc(sizeof(Shape*) * input_paths.size());
//    int index = 0;
//
//    for (std::string input_path : input_paths) {
//
//        FILE *fd = fopen(input_path.c_str(), "rw");
//        if (fd == nullptr) {
//            err = std::string("can't open ") + input_path;
//            break;
//        }
//
//        Stream *s = stream_new_file_read(fd);
//
//        Shape *shape = nullptr;
//
//        enum serialization_magicavoxel_error error = serialization_vox_to_shape(s,
//                                                                              &shape,
//                                                                              true,
//                                                                              colorAtlas,
//                                                                              true);
//
//        if (shape != nullptr) {
//            shapes[index] = shape;
//            ++index;
//        }
//
//        stream_free(s);
//
//        if (error != no_error) {
//            err = std::string("can't parse ") + input_path;
//            break;
//        }
//    }
//
//    if (err.empty() && index > 0) {
//
//        FILE *dst = fopen(output_path.c_str(), "wb");
//        if (dst == nullptr) {
//            err = std::string("can't create ") + output_path;
//        } else {
//            const bool success = serialization_shapes_to_vox(shapes, (size_t)index, dst);
//            if (success == false) {
//                err = std::string("can't export to ") + output_path;
//            }
//            // serialization_save_vox(shapes.at(0), dst);
//            fclose(dst);
//        }
//    }
//
//    for (int i = 0; i < index; ++i) {
//        shape_release(shapes[i]);
//    }
//    free(shapes);
//
//    color_atlas_free(colorAtlas);
//
//    if (err.empty() == false) {
//        return false;
//    }

    return true;
}
