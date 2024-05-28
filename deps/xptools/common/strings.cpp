//
//  strings.cpp
//  xptools
//
//  Created by Adrien Duermael on 5/13/20.
//  Copyright © 2020 voxowl. All rights reserved.
//

#include "strings.hpp"

#include <algorithm>

// C
#include "strings.h"

// Convert UTF-8 to 32-bit character, process single character input.
// Based on stb_from_utf8() from github.com/nothings/stb/
// We handle UTF-8 decoding error by skipping forward.
int vx::str::char32fromUTF8(unsigned int* out_char, const char* in_text, const char* in_text_end)
{
    unsigned int c = (unsigned int)-1;
    const unsigned char* str = (const unsigned char*)in_text;
    if (!(*str & 0x80))
    {
        c = (unsigned int)(*str++);
        *out_char = c;
        return 1;
    }
    if ((*str & 0xe0) == 0xc0)
    {
        *out_char = 0xFFFD; // invalid unicode code point (standard)
        if (in_text_end && in_text_end - (const char*)str < 2) return 1;
        if (*str < 0xc2) return 2;
        c = (unsigned int)((*str++ & 0x1f) << 6);
        if ((*str & 0xc0) != 0x80) return 2;
        c += (*str++ & 0x3f);
        *out_char = c;
        return 2;
    }
    if ((*str & 0xf0) == 0xe0)
    {
        *out_char = 0xFFFD; // invalid unicode code point (standard)
        if (in_text_end && in_text_end - (const char*)str < 3) return 1;
        if (*str == 0xe0 && (str[1] < 0xa0 || str[1] > 0xbf)) return 3;
        if (*str == 0xed && str[1] > 0x9f) return 3; // str[1] < 0x80 is checked below
        c = (unsigned int)((*str++ & 0x0f) << 12);
        if ((*str & 0xc0) != 0x80) return 3;
        c += (unsigned int)((*str++ & 0x3f) << 6);
        if ((*str & 0xc0) != 0x80) return 3;
        c += (*str++ & 0x3f);
        *out_char = c;
        return 3;
    }
    if ((*str & 0xf8) == 0xf0)
    {
        *out_char = 0xFFFD; // invalid unicode code point (standard)
        if (in_text_end && in_text_end - (const char*)str < 4) return 1;
        if (*str > 0xf4) return 4;
        if (*str == 0xf0 && (str[1] < 0x90 || str[1] > 0xbf)) return 4;
        if (*str == 0xf4 && str[1] > 0x8f) return 4; // str[1] < 0x80 is checked below
        c = (unsigned int)((*str++ & 0x07) << 18);
        if ((*str & 0xc0) != 0x80) return 4;
        c += (unsigned int)((*str++ & 0x3f) << 12);
        if ((*str & 0xc0) != 0x80) return 4;
        c += (unsigned int)((*str++ & 0x3f) << 6);
        if ((*str & 0xc0) != 0x80) return 4;
        c += (*str++ & 0x3f);
        // utf-8 encodings of values used in surrogate pairs are invalid
        if ((c & 0xFFFFF800) == 0xD800) return 4;
        // If codepoint does not fit in ImWchar, use replacement character U+FFFD instead
        if (c > 0x10FFFF /* max */) c = 0xFFFD; // invalid unicode code point (standard)
        *out_char = c;
        return 4;
    }
    *out_char = 0;
    return 0;
}

/// Replaces <pattern> by <replacement> in string <base>.
/// This function modifies <base>.
bool vx::str::replaceStringInString(std::string &base,
                                    const std::string &pattern,
                                    const std::string &replacement) {
    // find pattern
    const size_t pos = base.find(pattern);
    if (pos == std::string::npos) {
        // pattern not found
        return false;
    }
    
    // replace pattern
    base = base.replace(pos, pattern.size(), replacement);
    return true;
}

std::vector<std::string> vx::str::splitString(const std::string& input,
                                              const std::string& delimiter) {
    std::vector<std::string> result;
    if (input.empty() || delimiter.empty()) {
        return result;
    }
    std::string s(input);
    size_t pos = 0;
    std::string token;
    while (true) {
        pos = s.find(delimiter);
        token = s.substr(0, pos);
        result.push_back(token);
        s.erase(0, pos + delimiter.length());
        if (pos == std::string::npos) {
            break;
        }
    }
    return result;
}

std::string vx::str::strToHex(const std::string& input)
{
    static const char hex_digits[] = "0123456789ABCDEF";

    std::string output;
    output.reserve(input.length() * 2);
    for (unsigned char c : input)
    {
        output.push_back(hex_digits[c >> 4]);
        output.push_back(hex_digits[c & 15]);
    }
    return output;
}

bool vx::str::hasPrefix(const std::string& str, const std::string& prefix) {
    if (prefix.length() > str.length()) {
        return false;
    }
    const std::pair<std::string::const_iterator, std::string::const_iterator> res = std::mismatch(prefix.begin(), prefix.end(), str.begin());
    return res.first == prefix.end();
}

std::string vx::str::trimPrefix(const std::string& str, const std::string& prefix) {
    if (str.length() >= prefix.length() && str.find(prefix) == 0) {
        return str.substr(prefix.length());
    } else {
        return str;
    }
}

bool vx::str::hasSuffix(const std::string& str, const std::string& suffix) {
    if (str.length() >= suffix.length()) {
       return (str.rfind(suffix) == (str.length() - suffix.length()));
   } else {
       return false;
   }
}

std::string vx::str::trimSuffix(const std::string& str, const std::string& suffix) {
    if (str.length() >= suffix.length() &&
        str.rfind(suffix) == (str.length() - suffix.length())) {
        return str.substr(0, str.length() - suffix.length());
    } else {
        return str;
    }
}

void vx::str::toLower(std::string& str) {
    // Convert each character to lowercase using std::transform and a lambda function
    std::transform(str.begin(), str.end(), str.begin(), [](unsigned char c) { return std::tolower(c); });
}

bool vx::str::contains(const std::string& str, const std::string& subStr) {
    return str.find(subStr) != std::string::npos;
}

/// --------------------------------------------------
///
/// C-style functions
///
/// --------------------------------------------------

extern "C" {

int c_char32fromUTF8(unsigned int* out_char, const char* in_text, const char* in_text_end) {   
    return vx::str::char32fromUTF8(out_char, in_text, in_text_end);
}

} // extern "C"
