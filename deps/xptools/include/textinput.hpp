//
//  textinput.hpp
//  xptools
//
//  Created by Adrien Duermael on 22/04/2024.
//  Copyright © 2024 voxowl. All rights reserved.
//

#pragma once

#include <string>
#include "textinput.h"

namespace vx {
namespace textinput {

typedef void (*UpdateCallback)(std::string str,
                               bool strDidchange,
                               size_t cursorStart,
                               size_t cursorEnd);
typedef void (*CloseCallback)(void);
typedef void (*DoneCallback)(void);
typedef void (*NextCallback)(void);

// NATIVE PLATFORM SETUP
// (functions called from iOS, Android & other platforms specific code)

/// Allows each platform to register its own native text input delegate.
/// Engine text inputs get correspondant native text input for all events
/// to be managed exactly like users would expect on each particular platform.
void hostPlatformTextInputRegisterDelegate(HostPlatormTextInput_RequestCallback request,
                                           HostPlatormTextInput_UpdateCallback update,
                                           HostPlatormTextInput_ActionCallback close);
void hostPlatformTextInputUpdate(const char *str,
                                 size_t strLen,
                                 size_t cursorStart,
                                 size_t cursorEnd );
void hostPlatformTextInputClose();
void hostPlatformTextInputDone();
void hostPlatformTextInputNext();

// ENGINE SETUP

void textInputRegisterDelegate(vx::textinput::UpdateCallback update,
                               vx::textinput::CloseCallback close,
                               vx::textinput::DoneCallback done,
                               vx::textinput::NextCallback next);
void textInputRequest(std::string str, // it's safer to use copies (no const ref)
                      size_t cursorStart,
                      size_t cursorEnd,
                      bool multiline,
                      TextInputKeyboardType keyboardType,
                      TextInputReturnKeyType returnKeyType,
                      bool suggestions);
void textInputUpdate(std::string str, // it's safer to use copies (no const ref)
                     size_t cursorStart,
                     size_t cursorEnd );
void textInputAction(TextInputAction action);

}
}
