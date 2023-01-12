//
//  main.cpp
//  cli
//
//  Created by Gaetan de Villele on 13/10/2022.
//

// C++
#include <iostream>

// cxxopts
#include <cxxopts.hpp>

// cli
#include "combine.hpp"
#include "shape_point.hpp"

// 1 2 3 are position xyz
// 4 5 6 are rotation xyz
//
// cli setpoint -i wizard_hair.3zh <point name> posX posY posZ rotX rotY rotZ

// cli setpoint -i wizard_hair.3zh -o wizard_hair.3zh origin 5 5 7 0 0 0

int main(int argc, const char * argv[]) {

    cxxopts::Options options("Cubzh", "Tools for voxels.");

    options.add_options()
    ("command", "command to use", cxxopts::value<std::string>())
    ("i,input", "input files", cxxopts::value<std::vector<std::string>>())
    // ("n,name", "input file name", cxxopts::value<std::vector<std::string>>())
    ("o,output", "output file", cxxopts::value<std::string>())
    ;

    options.parse_positional({"command"});

    auto result = options.parse(argc, argv);
    
    if (result.count("command") == 0) {
        std::cout << options.help() << std::endl;
        exit(0);
    }

    // ---------------------------------------------------------------
    const std::string command = result["command"].as<std::string>();
    bool success = false;
    std::string err = "";

    if (command == "combine") {
        success = command_combine(result, err);
    } else if (command == "setpoint") {
        success = commandSetPoint(result, err);
    } else {
        err = "command not supported.";
    }

    if (err.empty() == false) {
        std::cout << "ERROR: " << err << std::endl;
    }

    return success ? 0 : 1;
}
