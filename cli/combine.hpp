//
//  combine.hpp
//  cli
//
//  Created by Gaetan de Villele on 13/10/2022.
//

#pragma once

// C++
#include <string>

// cxxopts
#include <cxxopts.hpp>

/// Returns true on success, false otherwise.
/// When an error occured, the `err` argument is filled with an error message.
bool command_combine(cxxopts::ParseResult parseResult, std::string& err);
