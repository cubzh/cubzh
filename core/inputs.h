// -------------------------------------------------------------
//  Cubzh Core
//  inputs.h
//  Created by Adrien Duermael on February 24, 2020.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>

#include "fifo_list.h"
#include "function_pointers.h"

typedef enum {
    mouseEvent,
    touchEvent,
    keyEvent,
    charEvent,
    dirPadEvent,
    actionPadEvent,
    analogPadEvent
} EventType;
// When using MouseButtonScroll, dx & dy represent the scroll delta
typedef enum {
    MouseButtonNone,
    MouseButtonLeft,
    MouseButtonMiddle,
    MouseButtonRight,
    MouseButtonScroll
} MouseButton;

typedef enum {
    ModifierNone = 0,
    ModifierAlt = 0x01,
    ModifierCtrl = 0x02,
    ModifierShift = 0x04,
    ModifierSuper = 0x08
} Modifier;

typedef enum {
    KeyStateDown = 0,
    KeyStateUp = 1,
    KeyStateUnknown = 2,
} KeyState;

// possible input keys
typedef enum {
    // starting with non printable inputs
    InputNone = 0,
    InputEsc,
    InputReturn,
    InputReturnKP,
    InputTab,
    InputBackspace,
    InputUp,
    InputDown,
    InputLeft,
    InputRight, // 9
    InputInsert,
    InputDelete,
    InputHome,
    InputEnd,
    InputPageUp,
    InputPageDown,
    InputPrint,
    InputClear, // 17
    InputF1,
    InputF2,
    InputF3,
    InputF4,
    InputF5,
    InputF6,
    InputF7,
    InputF8,
    InputF9,
    InputF10,
    InputF11,
    InputF12,
    InputF13,
    InputF14,
    InputF15,
    InputF16,
    InputF17,
    InputF18,
    InputF19,
    InputF20, // 37
    InputGamepadA,
    InputGamepadB,
    InputGamepadX,
    InputGamepadY,
    InputGamepadThumbL,
    InputGamepadThumbR,
    InputGamepadShoulderL,
    InputGamepadShoulderR,
    InputGamepadUp,
    InputGamepadDown,
    InputGamepadLeft,
    InputGamepadRight,
    InputGamepadBack,
    InputGamepadStart,
    InputGamepadGuide,

    // printable inputs
    InputPlus,
    InputNumPadPlus,
    InputMinus,
    InputNumPadMinus, // 56
    InputDivide,
    InputMultiply,
    InputDecimal,
    InputEqual,
    InputNumPadEqual,
    InputLeftBracket,
    InputRightBracket,
    InputSemicolon,
    InputQuote, // 65
    InputComma,
    InputPeriod,
    InputSlash,
    InputBackslash,
    InputTilde,
    InputNumPad0,
    InputNumPad1,
    InputNumPad2,
    InputNumPad3,
    InputNumPad4,
    InputNumPad5,
    InputNumPad6,
    InputNumPad7,
    InputNumPad8,
    InputNumPad9, // 80
    InputKey0,
    InputKey1,
    InputKey2,
    InputKey3,
    InputKey4,
    InputKey5,
    InputKey6,
    InputKey7,
    InputKey8,
    InputKey9, // 90
    InputKeyA,
    InputKeyB,
    InputKeyC,
    InputKeyD,
    InputKeyE,
    InputKeyF,
    InputKeyG,
    InputKeyH,
    InputKeyI,
    InputKeyJ,
    InputKeyK,
    InputKeyL,
    InputKeyM,
    InputKeyN,
    InputKeyO,
    InputKeyP,
    InputKeyQ,
    InputKeyR,
    InputKeyS,
    InputKeyT,
    InputKeyU,
    InputKeyV,
    InputKeyW, // 113
    InputKeyX,
    InputKeyY,
    InputKeyZ, // 116
    InputSpace,

    InputCount // not an input, used to get max value
} Input;

// /!\ ALL values in MouseEvent are in points
typedef struct {
    EventType eventType;
    MouseButton button;
    float x;
    float y;
    float dx;
    float dy;
    bool move; // if true: (x,y) represents a translation, not a position
    bool down; // true if mouse button is down
    char pad[2];
} MouseEvent;

void inputs_accept(const bool b);

void inputs_set_nb_pixels_in_one_point(const float f);

void mouse_event_copy(const MouseEvent *src, MouseEvent *dst);

typedef enum {
    TouchStateNone,
    TouchStateDown,
    TouchStateUp,
    TouchStateCanceled
} TouchState;

typedef enum {
    PointerIDTouch1 = 1,
    PointerIDTouch2 = 2,
    PointerIDTouch3 = 3,
    PointerIDTouchMax = 3,
    PointerIDMouseButtonLeft = 4,
    PointerIDMouseButtonRight = 5,
    PointerIDMouseButtonMax = 5,
    PointerIDWheel = 6,
    // Identifying mouse with no specific button
    PointerIDMouse = 7,
    // Identifying touch with no specific finger
    PointerIDTouch = 8,
} PointerID;

typedef enum {
    PointerEventTypeDown,
    PointerEventTypeUp,
    PointerEventTypeMove,
    PointerEventTypeCancel,
    PointerEventTypeWheel
} PointerEventType;

// /!\ ALL values in TouchEvent are in points
typedef struct {
    EventType eventType;
    TouchState state;
    float x;
    float y;
    float dx;
    float dy;
    uint8_t ID; // 0 for touch #1, 1 for touch #2, etc.
    bool move;  // if true: (x,y) represents a translation, not a position
    char pad[2];
} TouchEvent;

// returns true if the provided ID is an ID of a touch event
bool isTouchEventID(const uint8_t ID);
bool isFinger1EventID(const uint8_t ID);
bool isFinger2EventID(const uint8_t ID);

bool isMouseLeftButtonID(const uint8_t ID);
bool isMouseRightButtonID(const uint8_t ID);

void touch_event_copy(const TouchEvent *src, TouchEvent *dst);

typedef struct {
    EventType eventType;
    KeyState state; // up/down
    Input input;    // key
    uint8_t modifiers;
    char pad[3];
} KeyEvent;

void key_event_copy(const KeyEvent *src, KeyEvent *dst);

typedef struct {
    EventType eventType;
    unsigned int inputChar;
} CharEvent;

void char_event_copy(const CharEvent *src, CharEvent *dst);

// represents the context of inputs (mouse, touch, & keyboard events)
typedef struct _InputContext InputContext;

// Input listeners can register themselves not to miss any event thay may
// be interested in.
// 2 listeners can listen to similar events, we don't want one to consume the
// event and the other to miss it.
typedef struct _InputListener InputListener;

// Similar to _InputListener but:
// - only for keyboard inputs
// - does not pull events
// C function callback triggered right away when an input comes in.
// /!\ make sure to call it in the main thread
typedef struct _KeyboardInputListener KeyboardInputListener;
typedef void (*keyboard_input_callback_ptr)(void *userdata,
                                            uint32_t charCode,
                                            Input input,
                                            uint8_t modifiers,
                                            KeyState state);

// Similar to _InputListener but:
// - only for pointer events (mouse and touch events)
// - does not pull events
// C function callback triggered right away when an input comes in.
// /!\ make sure to call it in the main thread
typedef struct _PointerEventListener PointerEventListener;
typedef void (*pointer_event_callback_ptr)(void *userdata,
                                           PointerID ID,
                                           PointerEventType type,
                                           float x,
                                           float y,
                                           float dx,
                                           float dy);

///
typedef struct {
    Input input;
    KeyState stateFirst;
    KeyState stateSecond;
    bool seenByImGui;
} InputEventWithHistory;

//
KeyboardInputListener *input_keyboard_listener_new(void *userdata,
                                                   keyboard_input_callback_ptr callback);

//
void input_keyboard_listener_free(KeyboardInputListener *il, pointer_free_function userdata_free);

//
PointerEventListener *pointer_event_listener_new(void *userdata,
                                                 pointer_event_callback_ptr callback);

//
void pointer_event_listener_free(PointerEventListener *il, pointer_free_function userdata_free);

//
InputListener *input_listener_new(bool mouseEvents,
                                  bool touchEvents,
                                  bool keyEvents,
                                  bool charEvents,
                                  bool dirPadEvents,
                                  bool actionPadEvents,
                                  bool analogPadEvents,
                                  bool acceptsRepeatedKeyDown,
                                  bool acceptsRepeatedChar);

//
void input_listener_free(InputListener *il);

// Returns pointer to MouseEvent or NULL if there's no MouseEvent to return
// The pointer is managed by the input listener itself, no need to release it.
//!\\ when popping next item, the previous one is released.
const MouseEvent *input_listener_pop_mouse_event(InputListener *il);

// Returns pointer to TouchEvent or NULL if there's no TouchEvent to return
// The pointer is managed by the input listener itself, no need to release it.
//!\\ when popping next item, the previous one is released.
const TouchEvent *input_listener_pop_touch_event(InputListener *il);

// Returns pointer to KeyEvent or NULL if there's no KeyEvent to return
// The pointer is managed by the input listener itself, no need to release it.
//!\\ when popping next item, the previous one is released.
const KeyEvent *input_listener_pop_key_event(InputListener *il);

// Returns pointer to CharEvent or NULL if there's no CharEvent to return
// The pointer is managed by the input listener itself, no need to release it.
//!\\ when popping next item, the previous one is released.
const CharEvent *input_listener_pop_char_event(InputListener *il);

void postMouseEvent(float x, float y, float dx, float dy, MouseButton button, bool down, bool move);

void postTouchEvent(uint8_t ID, float x, float y, float dx, float dy, TouchState state, bool move);

void postKeyEvent(Input input, uint8_t modifiers, KeyState state);
void postCharEvent(unsigned int inputChar);

bool inputs_is_key_printable(Input i);

void postKeyboardInput(uint32_t charCode, Input input, uint8_t modifiers, KeyState state);

void postPointerEvent(PointerID ID, PointerEventType type, float x, float y, float dx, float dy);

// buf should have enough room (5 bytes),
// NULL char at 5th position for 4 bytes long.
uint8_t input_char_code_to_string(char *buf, uint32_t charCode);

// casts event to MouseEvent, returns NULL if event is not a MouseEvent
MouseEvent *input_event_to_MouseEvent(void *e);

// casts event to TouchEvent, returns NULL if event is not a TouchEvent
TouchEvent *input_event_to_TouchEvent(void *e);

// casts event to KeyEvent, returns NULL if event is not a KeyEvent
KeyEvent *input_event_to_KeyEvent(void *e);

// casts event to CharEvent, returns NULL if event is not a CharEvent
CharEvent *input_event_to_CharEvent(void *e);

bool input_shiftIsOn(void);
bool input_altIsOn(void);
bool input_ctrlIsOn(void);
bool input_superIsOn(void);
bool input_isOn(Input input);

int input_nb_pressed_inputs(void);
const Input *input_pressed_inputs(void);

uint8_t *input_nbPressedInputsImGui(void);
InputEventWithHistory *input_pressedInputsImGui(void);

//
void input_get_cursor(float *x, float *y, bool *btn1, bool *btn2, bool *btn3);

#ifdef __cplusplus
} // extern "C"
#endif
