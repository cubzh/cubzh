//
// Cubzh C++ entrypoint for Emscripten
//

// C++
#include <stdio.h>
#include <stdlib.h>

// Emscripten
#include <emscripten/bind.h>
#include <emscripten/emscripten.h>
#include <emscripten/html5.h>

// xptools
#include "inputs.h"
#include "web.hpp"

// Cubzh
#include "VXApplication.hpp"

using namespace vx;

// factor applied to delta of mouse wheel events
#define MOUSE_WHEEL_FACTOR 0.25

// --------------------------------------------------
//
// MARK: - Unexposed functions prototypes -
//
// --------------------------------------------------
std::unordered_map<std::string, Input> translatedCodes;
bool altGr = false;

typedef struct {
    Input input;
    uint8_t pressedChar;
    uint8_t modifiers;
} KeyInputData;

///
KeyInputData handleKeyEvent(const char key[32],
                            const char code[32],
                            const bool ctrlKeyModifier,
                            const bool shiftKeyModifier,
                            const bool altKeyModifier,
                            const bool metaKeyModifier);

///
uint8_t translateModifiers(const bool ctrlKeyModifier,
                           const bool shiftKeyModifier,
                           const bool altKeyModifier,
                           const bool metaKeyModifier);

// --------------------------------------------------
//
// MARK: - JS to C bindings -
//
// --------------------------------------------------
extern "C" {

// C function implemented in JS
EM_JS(void, js_init, (), { 
    init();
});

EM_JS(int, canvas_get_width, (), { 
    return canvas.width;
});

EM_JS(int, canvas_get_height, (), {
    return canvas.height;
});

// EM_JS(void, remove_diacritics, (const char *key, char *baseKey), {
//     str = UTF8ToString(key);
//     // normalize string to decompose base character & diacritics, then remove them
//     str = str.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
//     stringToUTF8(str, baseKey, 5);
// });

EM_JS(char *, path_get_search_parameters, (), {
    var jsString = get_search_parameters_as_jsonstring();
    var lengthBytes = lengthBytesUTF8(jsString) + 1;
    var stringOnWasmHeap = _malloc(lengthBytes);
    stringToUTF8(jsString, stringOnWasmHeap, lengthBytes);
    return stringOnWasmHeap;
});

}

// MARK: - Lifecycle -

void tick();

EM_BOOL mouse_wheel_callback(const int eventType, const EmscriptenWheelEvent *me, void *userData) {

    const double dx = me->deltaX;
    const double dy = -me->deltaY;
    // printf("wheel %f %f\n", dx, dy);

    // send event info to Lua layer
    postPointerEvent(PointerIDMouse,
                     PointerEventTypeWheel,
                     0,
                     0,
                     dx * MOUSE_WHEEL_FACTOR,
                     dy * MOUSE_WHEEL_FACTOR);

    // send event info to C++ layer
    postMouseEvent(0,
                   0,
                   dx * MOUSE_WHEEL_FACTOR,
                   dy * MOUSE_WHEEL_FACTOR,
                   MouseButtonScroll,
                   false,  // down
                   false); // move

    return true;
}

EM_BOOL mouse_callback(const int eventType, const EmscriptenMouseEvent *me, void *userData) {

    // coords {0,0} correspond to the top left corner
    const uint32_t pixelX = me->targetX;
    const uint32_t pixelY = me->targetY;
    const uint32_t reversedPixelY = Screen::heightInPixels - pixelY;

    const float deltaX = static_cast<float>(me->movementX);
    const float deltaY = static_cast<float>(-me->movementY);

    // mouse button (0 is left / 2 is right)
    MouseButton button = MouseButtonNone;
    switch (me->button) {
        case 0:
            button = MouseButtonLeft;
            break;
        case 1:
            button = MouseButtonMiddle;
            break;
        case 2:
            button = MouseButtonRight;
            break;
    }

    PointerID pointerID = PointerIDMouse;
    switch (button) {
        case MouseButtonLeft:
            pointerID = PointerIDMouseButtonLeft;
            break;
        case MouseButtonRight:
            pointerID = PointerIDMouseButtonRight;
            break;
        default:
            break;
    }

    // mouse button which is held down (used for mouse drag)
    MouseButton buttonHeldDown = MouseButtonNone;
    PointerID pointerIDHeldDown = PointerIDMouse;
    switch (me->buttons) {
        case 1:
            buttonHeldDown = MouseButtonLeft;
            pointerIDHeldDown = PointerIDMouseButtonLeft;
            break;
        case 2:
            buttonHeldDown = MouseButtonRight;
            pointerIDHeldDown = PointerIDMouseButtonRight;
            break;
    }

    switch (eventType) {
        case EMSCRIPTEN_EVENT_MOUSEDOWN: {
            postPointerEvent(pointerID, PointerEventTypeDown, pixelX, reversedPixelY, 0, 0);

            postMouseEvent(pixelX,
                           reversedPixelY,
                           0,
                           0,
                           button,
                           true,   // down
                           false); // move
            break;
        }
        case EMSCRIPTEN_EVENT_MOUSEUP: {
            postPointerEvent(pointerID, PointerEventTypeUp, pixelX, reversedPixelY, 0, 0);

            postMouseEvent(pixelX,
                           reversedPixelY,
                           0,
                           0,
                           button,
                           false,  // down
                           false); // move
            break;
        }
        case EMSCRIPTEN_EVENT_MOUSEMOVE: {
            postPointerEvent(pointerIDHeldDown,
                             PointerEventTypeMove,
                             pixelX,
                             reversedPixelY,
                             deltaX,
                             deltaY);

            postMouseEvent(pixelX,
                           reversedPixelY,
                           deltaX,
                           deltaY,
                           MouseButtonNone,
                           false, // down
                           true); // move
            break;
        }
    }

    return false;
}

EM_BOOL keyDownCallback(int eventType, const EmscriptenKeyboardEvent *ke, void *userData) {
    // printf("-------- DOWN --------\n");
    KeyInputData i = handleKeyEvent(ke->key,
                                    ke->code,
                                    ke->ctrlKey,
                                    ke->shiftKey,
                                    ke->altKey,
                                    ke->metaKey);

    // keep track of AltGr modifier
    if (strcmp(ke->key, "AltGraph") == 0) {
        altGr = true;
        return false; // do not consume event
    }

    bool result = false; // do not consume event
    if (i.pressedChar > 0) {
        // printf("postCharEvent %d %c\n", i.pressedChar, i.pressedChar);
        postCharEvent(i.pressedChar);
        result = true; // consume event
    }

    // Note: do not post input events if AltGr modifier is active, because our Input enum do not
    // contain all possible inputs, and Emscripten fires a DOWN event w/ transformed character, then
    // UP w/ base character, which triggers an error in VX when one character maps to an Input enum
    // value, and the other does not We don't need input events on these characters anyways, we only
    // care about having a character event
    if (altGr == false && i.input != InputNone) {
        // printf("postKeyEvent DOWN (2) %d %d\n", i.input, i.modifiers);
        postKeyEvent(i.input, i.modifiers, KeyStateDown);
        postKeyboardInput(i.pressedChar, i.input, i.modifiers, KeyStateDown);
        result = true; // consume event
    }

    return result;
}

EM_BOOL keyUpCallback(int eventType, const EmscriptenKeyboardEvent *ke, void *userData) {
    // printf("-------- UP --------\n");

    KeyInputData i = handleKeyEvent(ke->key,
                                    ke->code,
                                    ke->ctrlKey,
                                    ke->shiftKey,
                                    ke->altKey,
                                    ke->metaKey);

    // keep track of AltGr modifier
    if (strcmp(ke->key, "AltGraph") == 0) {
        altGr = false;
        return false; // do not consume event
    }

    // Note: see note in keyDownCallback
    if (altGr == false && i.input != InputNone) {
        // printf("postKeyEvent UP %d %d\n", i.input, i.modifiers);
        postKeyEvent(i.input, i.modifiers, KeyStateUp);
        postKeyboardInput(i.pressedChar, i.input, i.modifiers, KeyStateUp);
        return true; // consume event
    }

    return false;
}

// =========================================================================

bool disable = false;

EM_JS (void, js_text_input_request, (const char *str,
                                    size_t strLen,
                                    bool strDidChange,
                                    size_t cursorStart,
                                    size_t cursorEnd,
                                    bool multiline,
                                    int keyboardType,
                                    int returnKeyType), {
    if (cursorStart < 0 || cursorEnd < 0) {
        return;
    }

    // Convert the C string (UTF-8) to a JavaScript string
    let js_str = UTF8ToString(str, strLen);
    // Obtain a Uint8Array from the Emscripten HEAPU8 buffer
    let utf8Array = new Uint8Array(HEAPU8.buffer, str, strLen);
    // Create a copy of the Uint8Array to avoid potential memory issues
    let utf8ArrayCopy = new Uint8Array(utf8Array);

    let textInput = document.getElementById("text-input");
    textInput.value = js_str;

    // Convert cursor position from UTF8 bytes to JS string
    console.log("[REQUEST] STR->", js_str, cursorStart, cursorEnd);
    let cursorPosition = convertSelectionFromUTF8BytesToString(utf8ArrayCopy, cursorStart, cursorEnd);
    textInput.setSelectionRange(cursorPosition[0], cursorPosition[1]);
    
    // Focus the text field to make sure the cursor is visible
    textInput.focus();
});

// C++ signature and JS implementation
EM_JS (void, js_text_input_update, (const char *str,
                                    size_t strLen,
                                    bool strDidChange,
                                    size_t cursorStart,
                                    size_t cursorEnd), {
    if (cursorStart < 0 || cursorEnd < 0) {
        return;
    }

    // Convert the C string (UTF-8) to a JavaScript string
    let js_str = UTF8ToString(str, strLen);
    // Obtain a Uint8Array from the Emscripten HEAPU8 buffer
    let utf8Array = new Uint8Array(HEAPU8.buffer, str, strLen);
    // Create a copy of the Uint8Array to avoid potential memory issues
    let utf8ArrayCopy = new Uint8Array(utf8Array);

    let textInput = document.getElementById("text-input");
    textInput.value = js_str;
    
    // Convert cursor position from UTF8 bytes to JS string
    console.log("[UPDATE] STR->", js_str, cursorStart, cursorEnd);
    let cursorPosition = convertSelectionFromUTF8BytesToString(utf8ArrayCopy, cursorStart, cursorEnd);
    textInput.setSelectionRange(cursorPosition[0], cursorPosition[1]);

    // Focus the text field to make sure the cursor is visible
    textInput.focus();
});

// C++ calling JS
EM_JS (void, js_text_input_action, (int action), {
    const ACTION = Object.freeze({
        CLOSE: 0,
        COPY: 1,
        PASTE: 2,
        CUT: 3,
        UNDO: 4,
        REDO: 5
    });

    var textInput = document.getElementById("text-input");

    switch (action)
    {
    case ACTION.CLOSE:
        textInput.blur();
        break;
    case ACTION.COPY:
        // TODO: test me
        // textInput.copy();
        break;
    case ACTION.PASTE:
        // TODO: test me
        // textInput.paste();
        break;
    case ACTION.CUT:
        // TODO: test me
        // textInput.cut();
        break;
    case ACTION.UNDO:
        // TODO: test me
        // textInput.undo();
        break;
    case ACTION.REDO:
        // TODO: test me
        // textinput.redo();
        break;
    default:
        console.log("[js_text_input_action] unknown action");
        break;
    }
});

// =========================================================================

void textinputRequestCallbackPtr(const char *str,
                                 size_t strLen,
                                 bool strDidChange,
                                 size_t cursorStart,
                                 size_t cursorEnd,
                                 bool multiline,
                                 TextInputKeyboardType keyboardType,
                                 TextInputReturnKeyType returnKeyType) {
    printf("⭐️[INPUT][REQUEST] C++ ➡️ JS\n");
    js_text_input_request(str,
                          strLen,
                          strDidChange,
                          cursorStart,
                          cursorEnd,
                          multiline,
                          static_cast<int>(keyboardType),
                          static_cast<int>(returnKeyType));
}

void textinputUpdateCallbackPtr(const char *str,
                                size_t strLen,
                                bool strDidChange,
                                size_t cursorStart,
                                size_t cursorEnd) {
    printf("⭐️[INPUT][UPDATE] C++ ➡️ JS %s %zu %zu\n", str, cursorStart, cursorEnd);
    js_text_input_update(str, strLen, strDidChange, cursorStart, cursorEnd);    
}

void textinputActionCallbackPtr(TextInputAction action) {
    printf("⭐️[INPUT][ACTION]\n");
    js_text_input_action(static_cast<int>(action));
}

int main() {
    js_init();

    emscripten_set_window_title("Cubzh");

    // Context config
    EmscriptenWebGLContextAttributes attrs;
    emscripten_webgl_init_context_attributes(&attrs);
    attrs.alpha = false; // we don't want to blend the canvas w/ background content
    attrs.depth = false;
    attrs.stencil = false;
    attrs.antialias = false; // we don't want browser-specified AA
    attrs.premultipliedAlpha = false;
    attrs.preserveDrawingBuffer = false;
    attrs.powerPreference = EM_WEBGL_POWER_PREFERENCE_LOW_POWER;
    attrs.failIfMajorPerformanceCaveat = false;
    attrs.majorVersion = 2;
    attrs.minorVersion = 0; // someday we'll have WebGL2.1 = GLES3.1 :'(
    attrs.enableExtensionsByDefault = true;
    attrs.explicitSwapControl = false;
    attrs.renderViaOffscreenBackBuffer = false;
    attrs.proxyContextToMainThread = EMSCRIPTEN_WEBGL_CONTEXT_PROXY_DISALLOW;
    EMSCRIPTEN_WEBGL_CONTEXT_HANDLE context = emscripten_webgl_create_context("canvas", &attrs);
    if (context > 0) {
        emscripten_webgl_make_context_current(context);
    } else {
        printf("vx-wrapper could not create context\n");
    }

    // using canvas dimensions, already in points
    const int width = canvas_get_width();
    const int height = canvas_get_height();
    const double ratio = 1.0;
    const char *canvasTarget = "#canvas";
    void *nwh = (void *)"#canvas";
    void *ch = (void *)context;

    char *environment = path_get_search_parameters();
    printf("Environment: %s\n", environment);

    printf("vx-wrapper main (size: %dx%d ratio: %.2f)\n", width, height, ratio);

    // Init text input interface
    vx::textinput::hostPlatformTextInputRegisterDelegate(
        textinputRequestCallbackPtr,
        textinputUpdateCallbackPtr,
        textinputActionCallbackPtr);

    Insets insets = {0, 0, 0, 0};
    VXApplication::getInstance()->didResize(width, height, ratio, insets);
    VXApplication::getInstance()->didFinishLaunching(nwh, ch, width, height, ratio, insets, environment);

    free(environment);

    emscripten_set_mousedown_callback(canvasTarget, nullptr, true, mouse_callback);
    emscripten_set_mouseup_callback(canvasTarget, nullptr, true, mouse_callback);
    emscripten_set_mousemove_callback(canvasTarget, nullptr, true, mouse_callback);
    emscripten_set_wheel_callback(canvasTarget, nullptr, true, mouse_wheel_callback);

    // emscripten_set_click_callback("#canvas", nullptr, true, mouse_callback);
    // emscripten_set_dblclick_callback("#canvas", nullptr, true, mouse_callback);

    emscripten_set_keydown_callback(canvasTarget, nullptr, true, keyDownCallback);
    emscripten_set_keyup_callback(canvasTarget, nullptr, true, keyUpCallback);

    emscripten_set_main_loop(tick, 0, false);

    // RAF: request animation frame, akin to vsync in browser, is typically 60fps and is the
    // preferred approach for rendering apps, setting a fixed rate might apparently cause stuttering
    // depending on browsers We can use scd parameter to specify vsync interval (eg. 2 for half
    // rate)
    emscripten_set_main_loop_timing(EM_TIMING_RAF, 1);

    return 0;
}

void tick() {
    static double t = emscripten_get_now();
    const double now = emscripten_get_now();
    const double dt = (now - t) / 1000;

    VXApplication::getInstance()->tick(dt);
    VXApplication::getInstance()->render();

    // IT'S UNFORTUNATLY NOT A GOOD THING TO LOCK / UNLOCK POINTER HERE
    // Browser require user inputs to interract with that, but here's what happens
    // in our case:
    // - USER INPUT
    // - TICK asks for pointer to be hidden (but input in the past)
    // - waiting for next event to actually hide cursor...

    // Also, Browser catches ESC inputs when pointer is locked
    // but we could look for pointer lock change events not coming from
    // game requests to simulate ESC input and show pause menu when expected.

    // hide/show mouse cursor when needed
    {
        const bool shouldMouseCursorBeHidden = GameCoordinator::shouldMouseCursorBeHidden();
        EmscriptenPointerlockChangeEvent currentPointerlockStatus;
        emscripten_get_pointerlock_status(&currentPointerlockStatus);
        if (shouldMouseCursorBeHidden) {
            if (currentPointerlockStatus.isActive == false) {
                // Lock cursor
                // printf("POINTER LOCK\n");
                emscripten_request_pointerlock("canvas", true); // "canvas" is HTML id
            }
        } else {
            if (currentPointerlockStatus.isActive == true) {
                // Unlock cursor
                // printf("POINTER EXIT LOCK\n");
                emscripten_exit_pointerlock();
            }
        }
    }

    t = now;
}

//
// MARK: - C/C++ to JS bindings -
//

std::string getExceptionMessage(intptr_t exceptionPtr) {
    return std::string(reinterpret_cast<std::exception *>(exceptionPtr)->what());
}

void didResize() {
    // using canvas dimensions, already in points
    const int width = canvas_get_width();
    const int height = canvas_get_height();
    const double ratio = 1.0;

    printf("vx-wrapper didResize (size: %dx%d ratio: %.2f) \n", width, height, ratio);

    Insets insets = {0, 0, 0, 0};
    VXApplication::getInstance()->didResize(width, height, ratio, insets);
}

void didBecomeActive() {
    printf("vx-wrapper didBecomeActive\n");
    VXApplication::getInstance()->didBecomeActive();
}

void willResignActive() {
    printf("vx-wrapper willResignActive\n");
    VXApplication::getInstance()->willResignActive();
}

void willTerminate() {
    printf("vx-wrapper willTerminate\n");
    VXApplication::getInstance()->willTerminate();
}

void textInputUpdate(std::string str, int jsCursorStart, int jsCursorEnd) {
    printf("⭐️[INPUT] [UPDATE] JS -> C++ >> %s %d %d\n", str.c_str(), jsCursorStart, jsCursorEnd);
    // OperationQueue::getMain()->dispatch([str, jsCursorStart, jsCursorEnd](){
    // disable = true;
    hostPlatformTextInputUpdate(str.c_str(), str.size(), jsCursorStart, jsCursorEnd);
    // disable = false;
    //});
}

void textInputAction(int action) {
    printf("⭐️[INPUT] [ACTION] JS -> C++ >> %d\n", action);
    hostPlatformTextInputDone();
}

void handleKeyEventJSDown(std::string key, std::string code, bool ctrlKeyModifier, bool shiftKeyModifier, bool altKeyModifier, bool metaKeyModifier) {
    printf("⚡️ keyEvent [DOWN] %s %s ctrl:%d shift:%d alt:%d meta:%d\n", key.c_str(), code.c_str(), ctrlKeyModifier, shiftKeyModifier, altKeyModifier, metaKeyModifier);
    
    KeyInputData i = handleKeyEvent(key.c_str(), 
                                    code.c_str(), 
                                    ctrlKeyModifier, 
                                    shiftKeyModifier, 
                                    altKeyModifier, 
                                    metaKeyModifier);

    printf("🐞 KeyInputData: %d %d %d\n", i.input, i.pressedChar, i.modifiers);

    // keep track of AltGr modifier
    if (strcmp(key.c_str(), "AltGraph") == 0) {
        altGr = true;
        return; // do not consume event
    }

    // bool result = false; // do not consume event
    // if (i.pressedChar > 0) {
    //     // printf("postCharEvent %d %c\n", i.pressedChar, i.pressedChar);
    //     postCharEvent(i.pressedChar);
    //     // result = true; // consume event
    // }

    // Note: do not post input events if AltGr modifier is active, because our Input enum do not
    // contain all possible inputs, and Emscripten fires a DOWN event w/ transformed character, then
    // UP w/ base character, which triggers an error in VX when one character maps to an Input enum
    // value, and the other does not We don't need input events on these characters anyways, we only
    // care about having a character event
    if (/*altGr == false &&*/ i.input != InputNone) {
        printf("⚡️ postKeyEvent DOWN (2) %d %d\n", i.input, i.modifiers);
        postKeyEvent(i.input, i.modifiers, KeyStateDown);
        postKeyboardInput(i.pressedChar, i.input, i.modifiers, KeyStateDown);
        // result = true; // consume event
    }

    return;
}

void handleKeyEventJSUp(std::string key, std::string code, bool ctrlKeyModifier, bool shiftKeyModifier, bool altKeyModifier, bool metaKeyModifier) {
    printf("⚡️ keyEvent [UP] %s %s ctrl:%d shift:%d alt:%d meta:%d\n", key.c_str(), code.c_str(), ctrlKeyModifier, shiftKeyModifier, altKeyModifier, metaKeyModifier);
    
    KeyInputData i = handleKeyEvent(key.c_str(), 
                                    code.c_str(), 
                                    ctrlKeyModifier, 
                                    shiftKeyModifier, 
                                    altKeyModifier, 
                                    metaKeyModifier);

    printf("🐞 KeyInputData: %d %d %d\n", i.input, i.pressedChar, i.modifiers);

    // keep track of AltGr modifier
    //if (strcmp(ke->key, "AltGraph") == 0) {
    //    altGr = false;
        // return false; // do not consume event
    //}

    // Note: see note in keyDownCallback
    if (/*altGr == false &&*/ i.input != InputNone) {
        printf("⚡️ postKeyEvent UP (2) %d %d\n", i.input, i.modifiers);
        postKeyEvent(i.input, i.modifiers, KeyStateUp);
        postKeyboardInput(i.pressedChar, i.input, i.modifiers, KeyStateUp);
        // return true; // consume event
    }

    // return false;
}

EMSCRIPTEN_BINDINGS(Bindings) {
    emscripten::function("getExceptionMessage", &getExceptionMessage);
    emscripten::function("didResize", &didResize);
    emscripten::function("didBecomeActive", &didBecomeActive);
    emscripten::function("willResignActive", &willResignActive);
    emscripten::function("willTerminate", &willTerminate);
    // Text input
    emscripten::function("textInputUpdate", &textInputUpdate);
    emscripten::function("keyEventDown", &handleKeyEventJSDown);
    emscripten::function("keyEventUp", &handleKeyEventJSUp);
};

extern "C" {

EMSCRIPTEN_KEEPALIVE void openDocs(int argc, char **argv) {
    vx::Web::open("https://docs.cu.bzh/");
}

EMSCRIPTEN_KEEPALIVE void openDocsModal(int argc, char **argv) {
    vx::Web::openModal("https://docs.cu.bzh/");
}
}

// --------------------------------------------------
//
// MARK: - Unexposed functions -
//
// --------------------------------------------------

// return value : (input: Input, pressedChar: UInt8, modifiers: UInt8)
KeyInputData handleKeyEvent(const char key[32],
                            const char code[32],
                            const bool ctrlKeyModifier,
                            const bool shiftKeyModifier,
                            const bool altKeyModifier,
                            const bool metaKeyModifier) {

    // - 'key' is the output character
    // - 'code' is the physical key pressed, not affected by the current keyboard layout
    // and can correspond to multiple characters depending on modifiers and layout.
    // For result.input, we want to only use what comes from 'code'
    // while 'key' should be used to defined pressedChar

    // printf("handleKeyEvent %s %s ctrl:%d shift:%d alt:%d meta:%d altGr:%d\n",
    //        key,
    //        code,
    //        ctrlKeyModifier,
    //        shiftKeyModifier,
    //        altKeyModifier,
    //        metaKeyModifier,
    //        altGr);

    KeyInputData result;
    result.input = InputNone;
    result.pressedChar = 0;
    result.modifiers = 0;

    if (translatedCodes.empty()) {

        translatedCodes["Enter"] = InputReturn;
        translatedCodes["Tab"] = InputTab;
        translatedCodes["Space"] = InputSpace;
        translatedCodes["Backspace"] = InputBackspace;
        translatedCodes["Delete"] = InputDelete;
        translatedCodes["Escape"] = InputEsc;

        translatedCodes["F1"] = InputF1;
        translatedCodes["F2"] = InputF2;
        translatedCodes["F3"] = InputF3;
        translatedCodes["F4"] = InputF4;
        translatedCodes["F5"] = InputF5;
        translatedCodes["F6"] = InputF6;
        translatedCodes["F7"] = InputF7;
        translatedCodes["F8"] = InputF8;
        translatedCodes["F9"] = InputF9;
        translatedCodes["F10"] = InputF10;
        translatedCodes["F11"] = InputF11;
        translatedCodes["F12"] = InputF12;
        translatedCodes["F13"] = InputF13;
        translatedCodes["F14"] = InputF14;
        translatedCodes["F15"] = InputF15;
        translatedCodes["F16"] = InputF16;
        translatedCodes["F17"] = InputF17;
        translatedCodes["F18"] = InputF18;
        translatedCodes["F19"] = InputF19;
        translatedCodes["F20"] = InputF20;

        translatedCodes["Home"] = InputHome;
        translatedCodes["End"] = InputEnd;
        translatedCodes["PageUp"] = InputPageUp;
        translatedCodes["PageDown"] = InputPageDown;

        translatedCodes["ArrowUp"] = InputUp;
        translatedCodes["ArrowDown"] = InputDown;
        translatedCodes["ArrowLeft"] = InputLeft;
        translatedCodes["ArrowRight"] = InputRight;

        translatedCodes["KeyQ"] = InputKeyQ;
        translatedCodes["KeyW"] = InputKeyW;
        translatedCodes["KeyE"] = InputKeyE;
        translatedCodes["KeyR"] = InputKeyR;
        translatedCodes["KeyT"] = InputKeyT;
        translatedCodes["KeyY"] = InputKeyY;
        translatedCodes["KeyU"] = InputKeyU;
        translatedCodes["KeyI"] = InputKeyI;
        translatedCodes["KeyO"] = InputKeyO;
        translatedCodes["KeyP"] = InputKeyP;
        translatedCodes["KeyA"] = InputKeyA;
        translatedCodes["KeyS"] = InputKeyS;
        translatedCodes["KeyD"] = InputKeyD;
        translatedCodes["KeyF"] = InputKeyF;
        translatedCodes["KeyG"] = InputKeyG;
        translatedCodes["KeyH"] = InputKeyH;
        translatedCodes["KeyJ"] = InputKeyJ;
        translatedCodes["KeyK"] = InputKeyK;
        translatedCodes["KeyL"] = InputKeyL;
        translatedCodes["KeyZ"] = InputKeyZ;
        translatedCodes["KeyX"] = InputKeyX;
        translatedCodes["KeyC"] = InputKeyC;
        translatedCodes["KeyV"] = InputKeyV;
        translatedCodes["KeyB"] = InputKeyB;
        translatedCodes["KeyN"] = InputKeyN;
        translatedCodes["KeyM"] = InputKeyM;

        translatedCodes["Digit0"] = InputKey0;
        translatedCodes["Digit1"] = InputKey1;
        translatedCodes["Digit2"] = InputKey2;
        translatedCodes["Digit3"] = InputKey3;
        translatedCodes["Digit4"] = InputKey4;
        translatedCodes["Digit5"] = InputKey5;
        translatedCodes["Digit6"] = InputKey6;
        translatedCodes["Digit7"] = InputKey7;
        translatedCodes["Digit8"] = InputKey8;
        translatedCodes["Digit9"] = InputKey9;

        translatedCodes["Numpad0"] = InputNumPad0;
        translatedCodes["Numpad1"] = InputNumPad1;
        translatedCodes["Numpad2"] = InputNumPad2;
        translatedCodes["Numpad3"] = InputNumPad3;
        translatedCodes["Numpad4"] = InputNumPad4;
        translatedCodes["Numpad5"] = InputNumPad5;
        translatedCodes["Numpad6"] = InputNumPad6;
        translatedCodes["Numpad7"] = InputNumPad7;
        translatedCodes["Numpad8"] = InputNumPad8;
        translatedCodes["Numpad9"] = InputNumPad9;

        translatedCodes["Equal"] = InputEqual;
        translatedCodes["Minus"] = InputMinus;

        translatedCodes["NumpadSubtract"] = InputNumPadMinus;
        translatedCodes["NumpadAdd"] = InputNumPadPlus;
        translatedCodes["NumLock"] = InputClear;
        translatedCodes["NumpadDecimal"] = InputDecimal;
        translatedCodes["NumpadMultiply"] = InputMultiply;
        translatedCodes["NumpadDivide"] = InputDivide;
        translatedCodes["NumpadEqual"] = InputNumPadEqual;
        translatedCodes["NumpadEnter"] = InputReturnKP;

        translatedCodes["BracketRight"] = InputRightBracket;
        translatedCodes["BracketLeft"] = InputLeftBracket;

        translatedCodes["Quote"] = InputQuote;
        translatedCodes["Semicolon"] = InputSemicolon;
        translatedCodes["Backslash"] = InputBackslash;

        translatedCodes["Comma"] = InputComma;
        translatedCodes["Slash"] = InputSlash;
        translatedCodes["Period"] = InputPeriod;

        translatedCodes["Backquote"] = InputTilde;
    }

    // ignore event, these keys are passed through KeyInputData.modifiers,
    // we do not use their direct key up/down events
    if (strcmp(key, "Shift") == 0 || strcmp(key, "Control") == 0 || strcmp(key, "Alt") == 0 ||
        strcmp(key, "AltRight") == 0 || strcmp(key, "Meta") == 0 || strcmp(key, "AltGraph") == 0) {
        return result;
    }

    if (translatedCodes.find(code) != translatedCodes.end()) {
        result.input = translatedCodes[code];
    }

    result.modifiers = translateModifiers(ctrlKeyModifier,
                                          shiftKeyModifier,
                                          altKeyModifier,
                                          metaKeyModifier);

    // set if char if single character (no wide characters)
    // TODO: support wide chars, using c_char32fromUTF8
    if (key[1] == '\0') {
        result.pressedChar = static_cast<uint8_t>(key[0]);
    }

    if (ctrlKeyModifier || metaKeyModifier) {
        switch (result.pressedChar) {
            case static_cast<uint8_t>('a'):
                result.input = InputKeyA;
                break;
            case static_cast<uint8_t>('v'):
                result.input = InputKeyV;
                break;
            case static_cast<uint8_t>('c'):
                result.input = InputKeyC;
                break;
            case static_cast<uint8_t>('z'): // undo
                result.input = InputKeyZ;
                break;
            case static_cast<uint8_t>('Z'): // redo
                result.input = InputKeyZ;
                break;
            case static_cast<uint8_t>('x'):
                result.input = InputKeyX;
                break;
            default:
                break;
        }
        // do not consider pressed char, only input
        result.pressedChar = 0;
        return result;
    }

    // replace pressedChar in some cases, when alt is pressed
    if (altKeyModifier) {
        switch (result.input) {
            case InputKeyN:
                result.pressedChar = static_cast<uint8_t>('~');
                break;
            case InputTilde:
                result.pressedChar = static_cast<uint8_t>('`');
                break;

            // TODO: these chars are too large for uint8
            // we should use uint32 and support wide chars

            // case InputKeyE:
            //     result.pressedChar = static_cast<uint8_t>('´');
            //     break;
            // case InputKeyU:
            //     result.pressedChar = static_cast<uint8_t>('¨');
            //     break;
            // case InputKeyI:
            //     result.pressedChar = static_cast<uint8_t>('ˆ');
            //     break;
            default:
                break;
        }
    }

    return result;
}

uint8_t translateModifiers(const bool ctrlKeyModifier,
                           const bool shiftKeyModifier,
                           const bool altKeyModifier,
                           const bool metaKeyModifier) {
    return 0 | (shiftKeyModifier ? ModifierShift : 0) | (altKeyModifier ? ModifierAlt : 0) |
           (ctrlKeyModifier ? ModifierCtrl : 0) | (metaKeyModifier ? ModifierSuper : 0);
}
