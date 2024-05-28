
#include "web.hpp"

#include <emscripten/html5.h>

extern "C" {

EM_JS(void, window_open, (const char *url), {
    window.open(UTF8ToString(url), "_blank", "popup");
});

EM_JS(void, window_open_tab, (const char *url), {
    window.open(UTF8ToString(url), "_blank");
});

}

void vx::Web::openModal(const std::string &url) {
    window_open(url.c_str());
}

void vx::Web::open(const std::string &url) {
    window_open_tab(url.c_str());
}
