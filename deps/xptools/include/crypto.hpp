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

// Random

std::string generateRandomHex(const uint16_t length);

// UUID

std::string generate_uuid_v4();
std::string empty_uuid_v4();

// Checksum

uint32_t crc32(const uint32_t crc, const void * const buf, const uint32_t len);

}
}
