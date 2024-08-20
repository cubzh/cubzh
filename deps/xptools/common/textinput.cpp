//
//  textinput.cpp
//  xptools
//
//  Created by Adrien Duermael on 08/04/2024.
//  Copyright © 2024 voxowl. All rights reserved.
//

#include "textinput.h"
#include "textinput.hpp"

// C
#include <cstdint>
// C++
#include <iostream>
#include <string>
#include <codecvt>
#include <locale>
#include "zlib.h"

// do not use 0, getting CRC of 0 with empty strings,
// so considering the string didn't change.
#define CRC_START 42

static uint64_t platformToEngineBufferChecksum = 0;
static HostPlatormTextInput_RequestCallback hostPlatformTextInputRequestCallback = nullptr;
static HostPlatormTextInput_UpdateCallback hostPlatformTextInputUpdateCallback = nullptr;
static HostPlatormTextInput_ActionCallback hostPlatformTextInputActionCallback = nullptr;

static vx::textinput::UpdateCallback textInputUpdateCallback = nullptr;
static vx::textinput::CloseCallback textInputCloseCallback = nullptr;
static vx::textinput::DoneCallback textInputDoneCallback = nullptr;
static vx::textinput::NextCallback textInputNextCallback = nullptr;

void vx::textinput::hostPlatformTextInputRegisterDelegate(HostPlatormTextInput_RequestCallback request,
                                                          HostPlatormTextInput_UpdateCallback update,
                                                          HostPlatormTextInput_ActionCallback action) {
    hostPlatformTextInputRequestCallback = request;
    hostPlatformTextInputUpdateCallback = update;
    hostPlatformTextInputActionCallback = action;
}

void vx::textinput::hostPlatformTextInputUpdate(const char *str, size_t strLen, size_t cursorStart, size_t cursorEnd ) {
    if (textInputUpdateCallback == nullptr) {
        return;
    }
    if (str != nullptr) {
        textInputUpdateCallback(std::string(str, strLen), true, cursorStart, cursorEnd);
    } else {
        // only cursor did change
        textInputUpdateCallback("", false, cursorStart, cursorEnd);
    }
}

void vx::textinput::hostPlatformTextInputClose() {
    if (textInputCloseCallback == nullptr) {
        return;
    }
    textInputCloseCallback();
}

void vx::textinput::hostPlatformTextInputDone() {
    if (textInputDoneCallback == nullptr) {
        return;
    }
    textInputDoneCallback();
}

void vx::textinput::hostPlatformTextInputNext() {
    if (textInputNextCallback == nullptr) {
        return;
    }
    textInputNextCallback();
}

void vx::textinput::textInputRegisterDelegate(vx::textinput::UpdateCallback update,
                                              vx::textinput::CloseCallback close,
                                              vx::textinput::DoneCallback done,
                                              vx::textinput::NextCallback next) {
    textInputUpdateCallback = update;
    textInputCloseCallback = close;
    textInputDoneCallback = done;
    textInputNextCallback = next;
}

void vx::textinput::textInputRequest(std::string str, size_t cursorStart, size_t cursorEnd, bool multiline , TextInputKeyboardType keyboardType, TextInputReturnKeyType returnKeyType, bool suggestions) {
    if (hostPlatformTextInputRequestCallback == nullptr) {
        return;
    }
    uint64_t c = crc32(static_cast<uLong>(CRC_START),
                       reinterpret_cast<const Bytef *>(str.c_str()),
                       static_cast<uInt>(str.size()));
    // printf("** textInputRequest - %s\n", c != platformToEngineBufferChecksum ? "STR DID CHANGE" : "STR DID NOT CHANGE");
    if (c != platformToEngineBufferChecksum) {
        platformToEngineBufferChecksum = c;
        hostPlatformTextInputRequestCallback(str.c_str(), str.size(), true, cursorStart, cursorEnd, multiline, keyboardType, returnKeyType, suggestions);
    } else {
        hostPlatformTextInputRequestCallback(str.c_str(), str.size(), false /* strDidChange */, cursorStart, cursorEnd, multiline, keyboardType, returnKeyType, suggestions);
    }
}

void vx::textinput::textInputUpdate(std::string str, size_t cursorStart, size_t cursorEnd ) {
    if (hostPlatformTextInputUpdateCallback == nullptr) {
        return;
    }
    uint64_t c = crc32(static_cast<uLong>(CRC_START),
                       reinterpret_cast<const Bytef *>(str.c_str()),
                       static_cast<uInt>(str.size()));
    // printf("** textInputUpdate - %s\n", c != platformToEngineBufferChecksum ? "STR DID CHANGE" : "STR DID NOT CHANGE");
    if (c != platformToEngineBufferChecksum) {
        platformToEngineBufferChecksum = c;
        hostPlatformTextInputUpdateCallback(str.c_str(), str.size(), true, cursorStart, cursorEnd);
    } else {
        hostPlatformTextInputUpdateCallback(str.c_str(), str.size(), false, cursorStart, cursorEnd);
    }
}

void vx::textinput::textInputAction(TextInputAction action) {
    if (hostPlatformTextInputActionCallback == nullptr) {
        return;
    }
    hostPlatformTextInputActionCallback(action);
}

// extern C

extern "C" {

void hostPlatformTextInputRegisterDelegate(HostPlatormTextInput_RequestCallback request,
                                           HostPlatormTextInput_UpdateCallback update,
                                           HostPlatormTextInput_ActionCallback action) {
    vx::textinput::hostPlatformTextInputRegisterDelegate(request, update, action);
}

void hostPlatformTextInputUpdate(const char *str, size_t strLen, size_t cursorStart, size_t cursorEnd ) {
    platformToEngineBufferChecksum = crc32(static_cast<uLong>(CRC_START),
                                           reinterpret_cast<const Bytef *>(str),
                                           static_cast<uInt>(strLen));
    // printf("** hostPlatformTextInputUpdate\n");
    vx::textinput::hostPlatformTextInputUpdate(str, strLen, cursorStart, cursorEnd);
}

void hostPlatformTextInputClose() {
    vx::textinput::hostPlatformTextInputClose();
}

void hostPlatformTextInputDone() {
    vx::textinput::hostPlatformTextInputDone();
}

void hostPlatformTextInputNext() {
    vx::textinput::hostPlatformTextInputNext();
}

}
