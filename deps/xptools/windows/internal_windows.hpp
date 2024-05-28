//
//  internal_windows.hpp
//  xptools
//
//  Created by Adrien Duermael on 04/20/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//


// C++
#include <string>

// Win32
// #include <atlstr.h>
// #include <strsafe.h>
#include <tchar.h>
// #include <wtypes.h>
// #include <WinUser.h>

namespace vx {
namespace windows {

    /// Returns true on success, false otherwise.
    /// example : "Particubes" and "0.0.18"
    bool getProductVersion(std::string& appVersion, uint16_t& buildNumber);

}
}
