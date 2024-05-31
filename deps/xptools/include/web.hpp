//
//  web.hpp
//  xptools
//
//  Created by Adrien Duermael on 29/10/2021.
//  Copyright © 2021 voxowl. All rights reserved.
//

#pragma once

// C++
#include <string>

namespace vx {

class Web final {

public:
    // Opens url in modal web view if possible,
    // uses default web browser otherwise.
    static void openModal(const std::string &url);
    
    // Opens url in default web browser
    static void open(const std::string &url);
};
}
