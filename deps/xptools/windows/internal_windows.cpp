//
//  internal_windows.cpp
//  xptools
//
//  Created by Adrien Duermael on 04/20/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#include "internal_windows.hpp"

// C++
#include <sstream>
#include <vector>

// Win32
#include <wtypes.h>

bool vx::windows::getProductVersion(std::string& appVersion, uint16_t& buildNumber) {
    // get the filename of the executable containing the version resource
    TCHAR szFilename[MAX_PATH + 1] = { 0 };
    if (GetModuleFileName(NULL, szFilename, MAX_PATH) == 0) {
        return false;
    }

    // allocate a block of memory for the version info
    DWORD dummy;
    DWORD dwSize = GetFileVersionInfoSize(szFilename, &dummy);
    if (dwSize == 0) {
        return false;
    }
    std::vector<BYTE> data(dwSize);

    // load the version info
    if (GetFileVersionInfo(szFilename, NULL, dwSize, &data[0]) == false) {
        return false;
    }

    UINT length;
    VS_FIXEDFILEINFO* verInfo = NULL;
    const bool ok = VerQueryValueA(&data[0], LPCSTR("\\"), reinterpret_cast<LPVOID*>(&verInfo), &length);
    if (ok == false) {
        return false;
    }

    const uint16_t major = HIWORD(verInfo->dwProductVersionMS);
    const uint16_t minor = LOWORD(verInfo->dwProductVersionMS);
    const uint16_t build = HIWORD(verInfo->dwProductVersionLS);
    const uint16_t revision = LOWORD(verInfo->dwProductVersionLS);
     
    std::ostringstream oss;
    oss << std::to_string(major) << "." << std::to_string(minor) << "." << std::to_string(build);    
    appVersion.assign(oss.str());

    buildNumber = revision;

    return true;
}
