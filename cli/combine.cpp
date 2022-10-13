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
// ...

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
    std::string output_path = parseResult["output"].as<std::string>();;

    std::cout << "* Combining voxel files..." << std::endl;
    for (std::string input_path : input_paths) {
        std::cout << "    - " << input_path << std::endl;
    }
    std::cout << "  output: " << output_path << std::endl;

    //
    // add code here...
    //
    
    return true;
}
