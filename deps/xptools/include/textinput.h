//
//  textinput.h
//  xptools
//
//  Created by Adrien Duermael on 08/04/2024.
//  Copyright © 2024 voxowl. All rights reserved.
//

#pragma once

#include <stddef.h>
//#include <string>

// NOTE: all text buffers have to be UTF8 format,
// and cursors need to use byte precision.

typedef enum {
    TextInputReturnKeyType_Default,
    TextInputReturnKeyType_Next,
    TextInputReturnKeyType_Done,
    TextInputReturnKeyType_Send,
} TextInputReturnKeyType;

typedef enum {
    TextInputKeyboardType_Default,
    TextInputKeyboardType_Email,
    TextInputKeyboardType_Phone,
    TextInputKeyboardType_OneTimeDigicode,
    TextInputKeyboardType_Numbers,
    TextInputKeyboardType_URL,
    TextInputKeyboardType_ASCII,
} TextInputKeyboardType;

typedef enum {
    TextInputAction_Close,
    TextInputAction_Copy,
    TextInputAction_Paste,
    TextInputAction_Cut,
    TextInputAction_Undo,
    TextInputAction_Redo,
} TextInputAction;

typedef void (*HostPlatormTextInput_RequestCallback)(const char *str,
                                                     size_t strLen,
                                                     bool strDidchange,
                                                     size_t cursorStart,
                                                     size_t cursorEnd,
                                                     bool multiline,
                                                     TextInputKeyboardType keyboardType,
                                                     TextInputReturnKeyType returnKeyType,
                                                     bool suggestions);
typedef void (*HostPlatormTextInput_UpdateCallback)(const char *str,
                                                    size_t strLen,
                                                    bool strDidchange,
                                                    size_t cursorStart,
                                                    size_t cursorEnd);
typedef void (*HostPlatormTextInput_ActionCallback)(TextInputAction action);

#ifdef __cplusplus
extern "C" {
#endif

void hostPlatformTextInputRegisterDelegate(HostPlatormTextInput_RequestCallback request,
                                           HostPlatormTextInput_UpdateCallback update,
                                           HostPlatormTextInput_ActionCallback action);
void hostPlatformTextInputUpdate(const char *str,
                                 size_t strLen,
                                 size_t cursorStart,
                                 size_t cursorEnd );
void hostPlatformTextInputClose();
void hostPlatformTextInputDone();
void hostPlatformTextInputNext();

#ifdef __cplusplus
} // extern "C"
#endif
