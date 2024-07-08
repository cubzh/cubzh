
#include "web.hpp"

// windows
#include <windows.h>
#include <shellapi.h>

// xptools
#include "strings.hpp"

void vx::Web::openModal(const std::string &url) {
    vx::Web::open(url);
}

void vx::Web::open(const std::string &url) {
    // Make sure the url string is a web URL
    // (and not the path to a local executable for example)
    if (vx::str::hasPrefix(url, "http://") || vx::str::hasPrefix(url, "https://")) {
        ShellExecuteA(NULL, "open", url.c_str(), NULL, NULL, SW_SHOWNORMAL);
    }
}
