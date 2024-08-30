//
//  json.hpp
//  xptools
//
//  Created by Xavier Legland on 1/28/22.
//

#pragma once

// C
#include <cstdint>
// C++
#include <string>
#include <vector>
#include <unordered_map>

// cJSON lib
#include "cJSON.h"

namespace vx {

class json final {
    
public:
    
    // returns true if found
    static bool readStringField(const cJSON * const src, const std::string& field, std::string& value, bool canBeOmitted = false);
    // returns true on success
    static bool writeStringField(cJSON * const obj, const std::string& field, const std::string& value, bool omitIfEmpty = true);

    // returns true if found
    static bool readIntField(const cJSON *src, const std::string &field, int& value, bool canBeOmitted = false);
    static bool readUInt8Field(const cJSON *src, const std::string &field, uint8_t& value, bool canBeOmitted = false);
    static void writeIntField(cJSON *dest, const std::string& field, const int value);
    static void writeInt64Field(cJSON *dest, const std::string& field, const int64_t value);

    // returns true if found
    static bool readDoubleField(const cJSON *src, const std::string& field, double& value, bool canBeOmitted = false);
    static void writeDoubleField(cJSON *dest, const std::string& field, const double value);
    
    // returns true if found
    static bool readBoolField(const cJSON *src, const std::string& field, bool &value, bool canBeOmitted = false);
    static void writeBoolField(cJSON *dest, const std::string& field, const bool value);

    static void writeNullField(cJSON *dest, const std::string &field);

    /// Returns true on success, false otherwise.
    static bool readStringArray(const cJSON *const src, std::vector<std::string>& value);
    // static bool readStringArrayField(const cJSON *const src, const std::string& field, std::vector<std::string>& value, bool canBeOmitted = false);

    static bool readMapStringString(const cJSON * const src, std::unordered_map<std::string, std::string>& value);
};

}
