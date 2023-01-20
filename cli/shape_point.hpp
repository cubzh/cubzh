//
//  shape_point.hpp
//  cli
//
//  Created by Gaetan de Villele on 12/01/2023.
//

#pragma once

// C++
#include <string>

// cxxopts
#include <cxxopts.hpp>

/// Returns true on success, false otherwise.
/// When an error occured, the `err` argument is filled with an error message.
bool commandSetPoint(cxxopts::ParseResult parseResult, std::string& err);
