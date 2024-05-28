//
//  strings.hpp
//  xptools
//
//  Created by Adrien Duermael on 5/13/20.
//  Copyright © 2020 voxowl. All rights reserved.
//

#pragma once

// C++
#include <memory>
#include <string>
#include <stdexcept>
#include <vector>

namespace vx {
namespace str {

int char32fromUTF8(unsigned int *out_char, const char *in_text, const char *in_text_end);

template<typename ... Args>
std::string string_format( const std::string& format, Args ... args ) {
    size_t size = snprintf( nullptr, 0, format.c_str(), args ... ) + 1; // Extra space for '\0'
    if( size <= 0 ){ throw std::runtime_error( "Error during formatting." ); }
    std::unique_ptr<char[]> buf( new char[ size ] );
    snprintf( buf.get(), size, format.c_str(), args ... );
    return std::string( buf.get(), buf.get() + size - 1 ); // We don't want the '\0' inside
}

// trim from end of string (right)
inline std::string& rtrim(std::string& s, const char* t = " \t\n\r\f\v")
{
    s.erase(s.find_last_not_of(t) + 1);
    return s;
}

// trim from beginning of string (left)
inline std::string& ltrim(std::string& s, const char* t = " \t\n\r\f\v")
{
    s.erase(0, s.find_first_not_of(t));
    return s;
}

// trim from both ends of string (right then left)
inline std::string& trim(std::string& s, const char* t = " \t\n\r\f\v")
{
    return ltrim(rtrim(s, t), t);
}

/// Replaces <pattern> by <replacement> in string <base>.
/// This function modifies <base>.
bool replaceStringInString(std::string &base,
                           const std::string &pattern,
                           const std::string &replacement);

///
std::vector<std::string> splitString(const std::string& input,
                                     const std::string& delimiter);

///
std::string strToHex(const std::string& input);

/// Returns true if `prefix` is a prefix of `str`, false otherwise.
bool hasPrefix(const std::string& str, const std::string& prefix);

///
std::string trimPrefix(const std::string& str, const std::string& prefix);

/// Returns true if `suffix` is a suffix of `str`, false otherwise.
bool hasSuffix(const std::string& str, const std::string& suffix);

/// removes `suffix` from `str` if found, returns modified string.
std::string trimSuffix(const std::string& str, const std::string& suffix);

/// transform a string to lowercase
void toLower(std::string& str);

/// Returns true if `str` contains at least one occurence of `subStr`.
bool contains(const std::string& str, const std::string& subStr);

} // namespace str
} // namespace vx
