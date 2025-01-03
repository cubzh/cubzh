//
//  combine.cpp
//  cli
//
//  Created by Gaetan de Villele on 13/10/2022.
//

#include "combine.hpp"

// C++
#include <iostream>
#include <vector>

// Cubzh Core
#include "shape.h"
#include "stream.h"
#include "color_atlas.h"
#include "serialization_vox.h"

bool command_combine(cxxopts::ParseResult parseResult, std::string& err) {

    // validation

    if (parseResult.count("input") <= 0) {
        err.assign("no input files");
        return false;
    }

    if (parseResult.count("output") == 0) {
        err.assign("no output file path");
        return false;
    } else if (parseResult.count("output") != 1) {
        err.assign("only 1 output file is allowed");
        return false;
    }

    // processing

    std::vector<std::string> input_paths = parseResult["input"].as<std::vector<std::string>>();
    std::string output_path = parseResult["output"].as<std::string>();

    std::cout << "* Combining voxel files..." << std::endl;
    for (std::string input_path : input_paths) {
        std::cout << "    - " << input_path << std::endl;
    }
    std::cout << "  output: " << output_path << std::endl;
    
    ColorAtlas *colorAtlas = color_atlas_new();
    
    Shape **shapes = (Shape**)malloc(sizeof(Shape*) * input_paths.size());
    int index = 0;
    
    for (std::string input_path : input_paths) {
        
        FILE *fd = fopen(input_path.c_str(), "rw");
        if (fd == nullptr) {
            err = std::string("can't open ") + input_path;
            break;
        }
        
        Stream *s = stream_new_file_read(fd);
        
        Shape *shape = nullptr;
        
        enum serialization_vox_error error = serialization_vox_load(s,
                                                                    &shape,
                                                                    true,
                                                                    colorAtlas);
        
        if (shape != nullptr) {
            shapes[index] = shape;
            ++index;
        }
        
        stream_free(s);
        
        if (error != no_error) {
            err = std::string("can't parse ") + input_path;
            break;
        }
    }
    
    if (err.empty() && index > 0) {
        
        FILE *dst = fopen(output_path.c_str(), "wb");
        if (dst == nullptr) {
            err = std::string("can't create ") + output_path;
        } else {
            const bool success = serialization_vox_save_shapes(shapes, (size_t) index, dst);
            if (success == false) {
                err = std::string("can't export to ") + output_path;
            }
            // serialization_vox_save(shapes.at(0), dst);
            fclose(dst);
        }
    }
    
    for (int i = 0; i < index; ++i) {
        shape_release(shapes[i]);
    }
    free(shapes);
    
    color_atlas_free(colorAtlas);
    
    if (err.empty() == false) {
        return false;
    }
    
    return true;
}
