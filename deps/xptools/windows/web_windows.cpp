
#include "web.hpp"

// windows
#include <windows.h>
#include <shellapi.h>

void vx::Web::openModal(const std::string &url) {
    vx::Web::open(url);
}

void vx::Web::open(const std::string &url) {
    ShellExecuteA(0, 0, url.c_str(), 0, 0, SW_SHOW);
}
