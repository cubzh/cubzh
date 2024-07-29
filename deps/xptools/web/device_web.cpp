
#include "device.hpp"

#include <emscripten/html5.h>

extern "C" {

// Note: we have to use userAgent, not appName or appVersion which are deprecated
// See notes section: https://developer.mozilla.org/en-US/docs/Web/API/Navigator/appVersion
EM_JS(void, navigator_get_browser_name, (char *result), {
    var userAgent = navigator.userAgent;
    var browserName;
    // Regroup similar user agent names for each browser,
    // browsers put multiple browser names in their user agent value so the order matters,
    // eg. testing Chrome before Safari because Chrome user agent contains both "Chrome/... Safari/..."
    // eg. testing Edge at the beginning because Edge user agent can be like "Chrome/... Safari/... Edg/..."
    if (userAgent.match(/opr|opera/i)) {
        browserName = "Opera";
    } else if(userAgent.match(/edg/i)) {
        browserName = "Edge";
    } else if (userAgent.match(/chrome|chromium|crios/i)) {
        browserName = "Chrome";
    } else if (userAgent.match(/safari/i)) {
        browserName = "Safari";
    } else if (userAgent.match(/firefox|fxios/i)) {
        browserName = "Firefox";
    } else if(userAgent.match(/msie|trident/i) || (typeof document !== 'undefined' && !!document.documentMode)) {
        browserName = "IE";
    }else {
        browserName="Other";
    }
    stringToUTF8(browserName, result, 16);
});

EM_JS(void, navigator_get_agent, (char *result), {
    stringToUTF8(navigator.userAgent, result, 128);
});

// Combining as many options as possible as none of them are 100% reliable or supported
// Ref: https://developer.mozilla.org/en-US/docs/Web/HTTP/Browser_detection_using_the_user_agent
EM_JS(bool, navigator_has_touch, (), {
    if (typeof document !== 'undefined' && 'ontouchstart' in document.documentElement) {
        return true;
    } else if ("maxTouchPoints" in navigator) {
        return navigator.maxTouchPoints > 0;
    } else if ("msMaxTouchPoints" in navigator) {
        return navigator.msMaxTouchPoints > 0;
    } else if ("userAgentData" in navigator && navigator.userAgentData.mobile) {
        return true; // this field is experimental, not supported everywhere
    } else {
        if (typeof window !== 'undefined' && typeof screen !== 'undefined') {
           var mQ = window.matchMedia && matchMedia("(pointer:coarse)");
            if (mQ && mQ.media === "(pointer:coarse)") {
                return !!mQ.matches;
            } else if ('orientation' in screen || 'orientation' in window) {
                return true; // deprecated, but good fallback
            } 
        } else {
            // Only as a last resort, fall back to user agent sniffing
            return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini|Mobi/i.test(navigator.userAgent);
        }
    }
});

EM_JS(bool, navigator_has_mouse_and_keyboard, (), {
    if ("userAgentData" in navigator && navigator.userAgentData.mobile) {
        return false; // this field is experimental, not supported everywhere
    } else {
        return /Linux|Unix|Windows|Win|Mac/i.test(navigator.userAgent);
    }
});

EM_JS(void, copy, (const char* str), {
    Asyncify.handleAsync(async () => {
        document.getElementById("clipboard").focus();
        // 'clipboard-write' permission is automatically granted, no need to check
        const rtn = await navigator.clipboard.writeText(UTF8ToString(str));
        document.getElementById("canvas").focus();
    });
});

EM_JS(char*, paste, (), {
    return Asyncify.handleAsync(async () => {
        // 'clipboard-write' permission required and will be asked on first call to Clipboard.readText() ;
        // Permissions.request() isn't supported by any browser, so if permission is denied by user,
        // we can only catch an exception
        try {
            document.getElementById("clipboard").focus();
            const str = await navigator.clipboard.readText();
            document.getElementById("canvas").focus();
            const size = lengthBytesUTF8(str) + 1;
            const rtn = _malloc(size);
            stringToUTF8(str, rtn, size);
            return rtn;
        } catch(e) {
            document.getElementById("canvas").focus();
            return "";
        }
    });
});

}

vx::device::Platform vx::device::platform() {
    return Platform_Wasm;
}

std::string vx::device::osName() {
    char result[16]; navigator_get_browser_name(result);
    return std::string(result);
}

std::string vx::device::osVersion() {
    // Output the entire string in user agent to have as much info as possible instead of trying to parse it,
    // may include OS name, version, archi & browser name and version but none of it is guaranteed to be consistent
    char result[128]; navigator_get_agent(result);
    return std::string(result);
}

std::string vx::device::appVersion() {
    return PARTICUBES_VERSION;
}

uint16_t vx::device::appBuildNumber() {
    const uint16_t buildNumber = atoi(CUBZH_BUILD);
    return buildNumber;
}

std::string vx::device::hardwareBrand() {
    return "";
}

std::string vx::device::hardwareModel() {
    return "";
}

std::string vx::device::hardwareProduct() {
    return "";
}

uint64_t vx::device::hardwareMemory() {
    return 0;
}

bool vx::device::hasTouchScreen() {
    return navigator_has_touch();
}

bool vx::device::hasMouseAndKeyboard() {
    return navigator_has_mouse_and_keyboard();
}

bool vx::device::isMobile() {
    return false;
}

// web browsers only supported on PC
bool vx::device::isPC() {
    return true;
}

bool vx::device::isConsole() {
    return false;
}

void vx::device::setClipboardText(const std::string &text) {
    copy(text.c_str());
}

std::string vx::device::getClipboardText() {
    char *result = paste();
    return std::string(result);
}

void vx::device::terminate() {}

/// Haptic feedback
void vx::device::hapticImpactLight() {}

void vx::device::hapticImpactMedium() {}

void vx::device::hapticImpactHeavy() {}

// Notifications

void vx::device::scheduleLocalNotification(const std::string &title,
                                           const std::string &body,
                                           const std::string &identifier,
                                           int days,
                                           int hours,
                                           int minutes,
                                           int seconds) {
    // local notifications not supported (yet?)
}

// void cancelLocalNotification(const std::string &identifier) {
//     // local notifications not supported (yet?)
// }

void vx::device::openApplicationSettings() {}

std::vector<std::string> vx::device::preferredLanguages() {
    std::vector<std::string> languages;
    languages.push_back("en-US");
    return languages;
}

void vx::device::refreshScreenOrientation() {
    // does nothing on web
}
