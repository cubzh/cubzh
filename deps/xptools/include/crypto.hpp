//
//  crypto.hpp
//  xptools
//
//  Created by Gaetan de Villele on 04/01/2021.
//  Copyright © 2021 voxowl. All rights reserved.
//

#pragma once

// C++
#include <string>
#include <cstdint>

namespace vx {
namespace crypto {

///
std::string generateRandomHex(const uint16_t length);
std::string generate_uuid_v4();
std::string empty_uuid_v4();

}
}
