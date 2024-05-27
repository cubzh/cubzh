//
//  crypto.cpp
//  xptools
//
//  Created by Gaetan de Villele on 04/01/2021.
//  Copyright © 2021 voxowl. All rights reserved.
//

#include "crypto.hpp"

// C++
#include <sstream>
#include <random>
#include <string>
#include <cstdint>
#include <iomanip> // Include for std::setw and std::setfill

using namespace vx::crypto;

//
// Utility functions
//

unsigned int random_char() {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(0, 255);
    return dis(gen);
}

std::string generate_hex(const unsigned int len) {
    std::stringstream ss;
    for (unsigned int i = 0; i < len; i++) {
        const auto rc = random_char();
        std::stringstream hexstream;
        hexstream << std::hex << rc;
        auto hex = hexstream.str();
        ss << (hex.length() < 2 ? '0' + hex : hex);
    }
    return ss.str();
}

//
// Exposed functions
//

// length is number of bytes
std::string vx::crypto::generateRandomHex(const uint16_t length) {
    return generate_hex(length);
}

std::string vx::crypto::generate_uuid_v4() {
    std::random_device rd;
    std::mt19937_64 gen(rd());
    std::uniform_int_distribution<uint64_t> dis;

    uint64_t data1 = dis(gen);
    uint64_t data2 = dis(gen);

    std::stringstream ss;
    ss << std::hex << std::setfill('0');

    // Data1 first segment
    ss << std::setw(8) << (data1 >> 32);
    ss << "-";
    // Data1 second segment
    ss << std::setw(4) << ((data1 >> 16) & 0xFFFF);
    ss << "-";
    // Data1 third segment, version 4 UUID
    ss << std::setw(4) << ((data1 & 0xFFFF) | 0x4000);
    ss << "-";
    // Data2 first segment, variant 1 UUID
    ss << std::setw(4) << (((data2 >> 48) & 0x0FFF) | 0x8000);
    ss << "-";
    // Data2 second segment
    ss << std::setw(12) << (data2 & 0xFFFFFFFFFFFF);

    return ss.str();
}

std::string vx::crypto::empty_uuid_v4() {
    return "00000000-0000-0000-0000-000000000000";
}
