// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_inputs.h
//  Created by Xavier Legland on November 15, 2022.
// -------------------------------------------------------------

#pragma once

#include "inputs.h"

// functions that are NOT tested:
// inputs_accept
// inputs_set_nb_pixels_in_one_point
// mouse_event_copy
// touch_event_copy
// dir_pad_event_copy
// action_pad_event_copy
// analog_pad_event_copy
// key_event_copy
// char_event_copy
// input_event_to_MouseEvent
// input_event_to_TouchEvent
// input_event_to_KeyEvent
// input_event_to_CharEvent
// input_event_to_DirPadEvent
// input_event_to_ActionPadEvent
// input_event_to_AnalogPadEvent
// input_nb_pressed_inputs
// input_pressed_inputs

// generate a touch event and check if it is considered as one
void test_isTouchEventID(void) {
    InputListener
        *il = input_listener_new(false, true, false, false, false, false, false, false, false);
    postTouchEvent(0, 1.0f, 2.0f, 1.0f, 2.0f, TouchStateDown, true);

    // has to change if more touches are allowed
    TEST_CHECK(isTouchEventID(3) == false);

    const TouchEvent *te = input_listener_pop_touch_event(il);
    TEST_CHECK(isTouchEventID(te->ID));

    input_listener_free(il);
}

// generate 2 touch events and check that only the 1st one is considered as finger1
void test_isFinger1EventID(void) {
    InputListener
        *il = input_listener_new(false, true, false, false, false, false, false, false, false);
    postTouchEvent(0, 1.0f, 2.0f, 1.0f, 2.0f, TouchStateDown, true);
    postTouchEvent(1, 3.0f, 1.0f, 2.0f, -1.0f, TouchStateUp, true);

    const TouchEvent *te1 = input_listener_pop_touch_event(il);
    TEST_CHECK(isFinger1EventID(te1->ID));

    const TouchEvent *te2 = input_listener_pop_touch_event(il);
    TEST_CHECK(isFinger1EventID(te2->ID) == false);

    input_listener_free(il);
}

// generate 2 touch events and check that only the second is considered as finger2
void test_isFinger2EventID(void) {
    InputListener
        *il = input_listener_new(false, true, false, false, false, false, false, false, false);
    postTouchEvent(0, 1.0f, 2.0f, 1.0f, 2.0f, TouchStateDown, true);
    postTouchEvent(1, 3.0f, 1.0f, 2.0f, -1.0f, TouchStateUp, true);

    const TouchEvent *te1 = input_listener_pop_touch_event(il);
    TEST_CHECK(isFinger2EventID(te1->ID) == false);

    const TouchEvent *te2 = input_listener_pop_touch_event(il);
    TEST_CHECK(isFinger2EventID(te2->ID));

    input_listener_free(il);
}

// check that mouse left button ID is 2
void test_isMouseLeftButtonID(void) {
    TEST_CHECK(isMouseLeftButtonID(3));
}

// check that mouse right button ID is 3
void test_isMouseRightButtonID(void) {
    TEST_CHECK(isMouseRightButtonID(4));
}

// create an InputListener  and check that all its lists are empty
void test_input_listener_new(void) {
    InputListener
        *il = input_listener_new(true, false, true, true, false, false, false, false, false);

    TEST_CHECK(input_listener_pop_mouse_event(il) == NULL);
    TEST_CHECK(input_listener_pop_touch_event(il) == NULL);
    TEST_CHECK(input_listener_pop_key_event(il) == NULL);
    TEST_CHECK(input_listener_pop_char_event(il) == NULL);

    input_listener_free(il);
}

// create a MouseEvent and check that the values are the provided ones
void test_input_listener_pop_mouse_event(void) {
    InputListener
        *il = input_listener_new(true, false, false, false, false, false, false, false, false);
    postMouseEvent(1.0f, 2.0f, 1.0f, 2.0f, MouseButtonNone, false, true);
    postMouseEvent(3.0f, 1.0f, 2.0f, -1.0f, MouseButtonNone, false, true);

    const MouseEvent *me1 = input_listener_pop_mouse_event(il);
    TEST_CHECK(me1->eventType == mouseEvent);
    TEST_CHECK(me1->x == 1.0f);
    TEST_CHECK(me1->y == 2.0f);
    TEST_CHECK(me1->dx == 1.0f);
    TEST_CHECK(me1->dy == 2.0f);
    TEST_CHECK(me1->button == MouseButtonNone);
    TEST_CHECK(me1->down == false);
    TEST_CHECK(me1->move == true);

    const MouseEvent *me2 = input_listener_pop_mouse_event(il);
    TEST_CHECK(me2->eventType == mouseEvent);
    TEST_CHECK(me2->x == 3.0f);
    TEST_CHECK(me2->y == 1.0f);
    TEST_CHECK(me2->dx == 2.0f);
    TEST_CHECK(me2->dy == -1.0f);
    TEST_CHECK(me2->button == MouseButtonNone);
    TEST_CHECK(me2->down == false);
    TEST_CHECK(me2->move == true);

    input_listener_free(il);
}

// create a TouchEvent and check that the values are the provided ones
void test_input_listener_pop_touch_event(void) {
    InputListener
        *il = input_listener_new(false, true, false, false, false, false, false, false, false);
    postTouchEvent(0, 1.0f, 2.0f, 1.0f, 2.0f, TouchStateDown, true);
    postTouchEvent(1, 3.0f, 1.0f, 2.0f, -1.0f, TouchStateUp, true);

    const TouchEvent *te1 = input_listener_pop_touch_event(il);
    TEST_CHECK(te1->eventType == touchEvent);
    TEST_CHECK(te1->ID == 0);
    TEST_CHECK(te1->x == 1.0f);
    TEST_CHECK(te1->y == 2.0f);
    TEST_CHECK(te1->dx == 1.0f);
    TEST_CHECK(te1->dy == 2.0f);
    TEST_CHECK(te1->state == TouchStateDown);
    TEST_CHECK(te1->move == true);

    const TouchEvent *te2 = input_listener_pop_touch_event(il);
    TEST_CHECK(te2->eventType == touchEvent);
    TEST_CHECK(te2->ID == 1);
    TEST_CHECK(te2->x == 3.0f);
    TEST_CHECK(te2->y == 1.0f);
    TEST_CHECK(te2->dx == 2.0f);
    TEST_CHECK(te2->dy == -1.0f);
    TEST_CHECK(te2->state == TouchStateUp);
    TEST_CHECK(te2->move == true);

    input_listener_free(il);
}

// create a KeyEvent and check that the values are the provided ones
void test_input_listener_pop_key_event(void) {
    InputListener
        *il = input_listener_new(false, false, true, false, false, false, false, false, false);
    postKeyEvent(InputKeyA, ModifierNone, KeyStateDown);
    postKeyEvent(InputKeyA, ModifierNone, KeyStateUp);

    const KeyEvent *ke1 = input_listener_pop_key_event(il);
    TEST_CHECK(ke1->eventType == keyEvent);
    TEST_CHECK(ke1->state == KeyStateDown);
    TEST_CHECK(ke1->input == InputKeyA);
    TEST_CHECK(ke1->modifiers == 0);

    const KeyEvent *ke2 = input_listener_pop_key_event(il);
    TEST_CHECK(ke2->eventType == keyEvent);
    TEST_CHECK(ke2->state == KeyStateUp);
    TEST_CHECK(ke2->input == InputKeyA);
    TEST_CHECK(ke2->modifiers == 0);

    input_listener_free(il);
}

// create a CharEvent and check that the values are the provided ones
void test_input_listener_pop_char_event(void) {
    InputListener
        *il = input_listener_new(false, false, false, true, false, false, false, false, false);
    postCharEvent(65);
    postCharEvent(66);

    const CharEvent *ce1 = input_listener_pop_char_event(il);
    TEST_CHECK(ce1->eventType == charEvent);
    TEST_CHECK(ce1->inputChar == 65);

    const CharEvent *ce2 = input_listener_pop_char_event(il);
    TEST_CHECK(ce2->eventType == charEvent);
    TEST_CHECK(ce2->inputChar == 66);

    input_listener_free(il);
}

// same tests as before
void test_postMouseEvent(void) {
    InputListener
        *il = input_listener_new(true, false, false, false, false, false, false, false, false);
    postMouseEvent(1.0f, 2.0f, 1.0f, 2.0f, MouseButtonNone, false, true);
    postMouseEvent(3.0f, 1.0f, 2.0f, -1.0f, MouseButtonNone, false, true);

    const MouseEvent *me1 = input_listener_pop_mouse_event(il);
    TEST_CHECK(me1->eventType == mouseEvent);
    TEST_CHECK(me1->x == 1.0f);
    TEST_CHECK(me1->y == 2.0f);
    TEST_CHECK(me1->dx == 1.0f);
    TEST_CHECK(me1->dy == 2.0f);
    TEST_CHECK(me1->button == MouseButtonNone);
    TEST_CHECK(me1->down == false);
    TEST_CHECK(me1->move == true);

    const MouseEvent *me2 = input_listener_pop_mouse_event(il);
    TEST_CHECK(me2->eventType == mouseEvent);
    TEST_CHECK(me2->x == 3.0f);
    TEST_CHECK(me2->y == 1.0f);
    TEST_CHECK(me2->dx == 2.0f);
    TEST_CHECK(me2->dy == -1.0f);
    TEST_CHECK(me2->button == MouseButtonNone);
    TEST_CHECK(me2->down == false);
    TEST_CHECK(me2->move == true);

    input_listener_free(il);
}

// same tests as before
void test_postTouchEvent(void) {
    InputListener
        *il = input_listener_new(false, true, false, false, false, false, false, false, false);
    postTouchEvent(0, 1.0f, 2.0f, 1.0f, 2.0f, TouchStateDown, true);
    postTouchEvent(1, 3.0f, 1.0f, 2.0f, -1.0f, TouchStateUp, true);

    const TouchEvent *te1 = input_listener_pop_touch_event(il);
    TEST_CHECK(te1->eventType == touchEvent);
    TEST_CHECK(te1->ID == 0);
    TEST_CHECK(te1->x == 1.0f);
    TEST_CHECK(te1->y == 2.0f);
    TEST_CHECK(te1->dx == 1.0f);
    TEST_CHECK(te1->dy == 2.0f);
    TEST_CHECK(te1->state == TouchStateDown);
    TEST_CHECK(te1->move == true);

    const TouchEvent *te2 = input_listener_pop_touch_event(il);
    TEST_CHECK(te2->eventType == touchEvent);
    TEST_CHECK(te2->ID == 1);
    TEST_CHECK(te2->x == 3.0f);
    TEST_CHECK(te2->y == 1.0f);
    TEST_CHECK(te2->dx == 2.0f);
    TEST_CHECK(te2->dy == -1.0f);
    TEST_CHECK(te2->state == TouchStateUp);
    TEST_CHECK(te2->move == true);

    input_listener_free(il);
}

// same tests as before
void test_postKeyEvent(void) {
    InputListener
        *il = input_listener_new(false, false, true, false, false, false, false, false, false);
    postKeyEvent(InputKeyA, ModifierNone, KeyStateDown);
    postKeyEvent(InputKeyA, ModifierNone, KeyStateUp);

    const KeyEvent *ke1 = input_listener_pop_key_event(il);
    TEST_CHECK(ke1->eventType == keyEvent);
    TEST_CHECK(ke1->state == KeyStateDown);
    TEST_CHECK(ke1->input == InputKeyA);
    TEST_CHECK(ke1->modifiers == 0);

    const KeyEvent *ke2 = input_listener_pop_key_event(il);
    TEST_CHECK(ke2->eventType == keyEvent);
    TEST_CHECK(ke2->state == KeyStateUp);
    TEST_CHECK(ke2->input == InputKeyA);
    TEST_CHECK(ke2->modifiers == 0);

    input_listener_free(il);
}

// same tests as before
void test_postCharEvent(void) {
    InputListener
        *il = input_listener_new(false, false, false, true, false, false, false, false, false);
    postCharEvent(65);
    postCharEvent(66);

    const CharEvent *ce1 = input_listener_pop_char_event(il);
    TEST_CHECK(ce1->eventType == charEvent);
    TEST_CHECK(ce1->inputChar == 65);

    const CharEvent *ce2 = input_listener_pop_char_event(il);
    TEST_CHECK(ce2->eventType == charEvent);
    TEST_CHECK(ce2->inputChar == 66);

    input_listener_free(il);
}

// create KeyEvents with and without ModifierShift and check the value of shiftIsOn
void test_input_shiftIsOn(void) {
    InputListener
        *il = input_listener_new(false, false, true, false, false, false, false, false, false);
    uint8_t modAll = ModifierAlt | ModifierCtrl | ModifierShift | ModifierSuper;
    uint8_t modAllButShift = ModifierAlt | ModifierCtrl | ModifierSuper;

    postKeyEvent(InputKeyA, modAll, KeyStateDown);
    TEST_CHECK(input_shiftIsOn());

    postKeyEvent(InputKeyA, modAllButShift, KeyStateUp);
    TEST_CHECK(input_shiftIsOn() == false);

    input_listener_free(il);
}

// create KeyEvents with and without ModifierAlt and check the value of altIsOn
void test_input_altIsOn(void) {
    InputListener
        *il = input_listener_new(false, false, true, false, false, false, false, false, false);
    uint8_t modAll = ModifierAlt | ModifierCtrl | ModifierShift | ModifierSuper;
    uint8_t modAllButAlt = ModifierCtrl | ModifierShift | ModifierSuper;

    postKeyEvent(InputKeyA, modAll, KeyStateDown);
    TEST_CHECK(input_altIsOn());

    postKeyEvent(InputKeyA, modAllButAlt, KeyStateUp);
    TEST_CHECK(input_altIsOn() == false);

    input_listener_free(il);
}

// create KeyEvents with and without ModifierCtrl and check the value of ctrlIsOn
void test_input_ctrlIsOn(void) {
    InputListener
        *il = input_listener_new(false, false, true, false, false, false, false, false, false);
    uint8_t modAll = ModifierAlt | ModifierCtrl | ModifierShift | ModifierSuper;
    uint8_t modAllButCtrl = ModifierAlt | ModifierShift | ModifierSuper;

    postKeyEvent(InputKeyA, modAll, KeyStateDown);
    TEST_CHECK(input_ctrlIsOn());

    postKeyEvent(InputKeyA, modAllButCtrl, KeyStateUp);
    TEST_CHECK(input_ctrlIsOn() == false);

    input_listener_free(il);
}

// create KeyEvents with and without ModifierSuper and check the value of superIsOn
void test_input_superIsOn(void) {
    InputListener
        *il = input_listener_new(false, false, true, false, false, false, false, false, false);
    uint8_t modAll = ModifierAlt | ModifierCtrl | ModifierShift | ModifierSuper;
    uint8_t modAllButSuper = ModifierAlt | ModifierCtrl | ModifierShift;

    postKeyEvent(InputKeyA, modAll, KeyStateDown);
    TEST_CHECK(input_superIsOn());

    postKeyEvent(InputKeyA, modAllButSuper, KeyStateUp);
    TEST_CHECK(input_superIsOn() == false);

    input_listener_free(il);
}

// check if InputKeyA is one before, during and after a press
void test_input_isOn(void) {
    InputListener
        *il = input_listener_new(false, false, true, false, false, false, false, false, false);

    TEST_CHECK(input_isOn(InputKeyA) == false);

    postKeyEvent(InputKeyA, ModifierNone, KeyStateDown);
    TEST_CHECK(input_isOn(InputKeyA) == true);
    TEST_CHECK(input_isOn(InputKeyB) == false);

    postKeyEvent(InputKeyA, ModifierNone, KeyStateUp);
    TEST_CHECK(input_isOn(InputKeyA) == false);

    input_listener_free(il);
}

// press 3 keys and check that we have 3 keys pressed
void test_input_nbPressedInputsImGui(void) {
    InputListener
        *il = input_listener_new(false, false, true, false, false, false, false, false, true);

    // reset possible registered inputs
    postKeyEvent(InputKeyA, ModifierNone, KeyStateDown);
    postKeyEvent(InputKeyB, ModifierNone, KeyStateDown);
    postKeyEvent(InputKeyC, ModifierNone, KeyStateDown);
    // mimic what is done in ImguiContext::beginFrame
    uint8_t n = *input_nbPressedInputsImGui();
    InputEventWithHistory *in;
    for (uint8_t i = 0; i < n; i += 1) {
        in = &(input_pressedInputsImGui()[i]);
        in->seenByImGui = true;
    }
    postKeyEvent(InputKeyA, ModifierNone, KeyStateUp);
    postKeyEvent(InputKeyB, ModifierNone, KeyStateUp);
    postKeyEvent(InputKeyC, ModifierNone, KeyStateUp);
    TEST_CHECK(*input_nbPressedInputsImGui() == 0);

    n = *input_nbPressedInputsImGui();
    for (uint8_t i = 0; i < n; i += 1) {
        in = &(input_pressedInputsImGui()[i]);
        in->seenByImGui = true;
    }
    postKeyEvent(InputKeyA, ModifierNone, KeyStateDown);
    postKeyEvent(InputKeyB, ModifierNone, KeyStateDown);
    postKeyEvent(InputKeyC, ModifierNone, KeyStateDown);
    TEST_CHECK(*input_nbPressedInputsImGui() == 3);

    n = *input_nbPressedInputsImGui();
    for (uint8_t i = 0; i < n; i += 1) {
        in = &(input_pressedInputsImGui()[i]);
        in->seenByImGui = true;
    }
    postKeyEvent(InputKeyA, ModifierNone, KeyStateUp);
    postKeyEvent(InputKeyB, ModifierNone, KeyStateUp);
    postKeyEvent(InputKeyC, ModifierNone, KeyStateUp);
    TEST_CHECK(*input_nbPressedInputsImGui() == 0);

    input_listener_free(il);
}

// press A, B and C and check that the hostory is in the correct order
void test_input_pressedInputsImGui(void) {
    InputListener
        *il = input_listener_new(false, false, true, false, false, false, false, false, false);
    postKeyEvent(InputKeyA, ModifierNone, KeyStateDown);
    postKeyEvent(InputKeyB, ModifierNone, KeyStateDown);
    postKeyEvent(InputKeyC, ModifierNone, KeyStateDown);
    InputEventWithHistory *ie = input_pressedInputsImGui();

    TEST_CHECK(ie[0].input == InputKeyA);
    TEST_CHECK(ie[0].stateFirst == KeyStateDown);
    TEST_CHECK(ie[0].stateSecond == KeyStateUnknown);
    TEST_CHECK(ie[0].seenByImGui == false);

    TEST_CHECK(ie[1].input == InputKeyB);
    TEST_CHECK(ie[1].stateFirst == KeyStateDown);
    TEST_CHECK(ie[1].stateSecond == KeyStateUnknown);
    TEST_CHECK(ie[1].seenByImGui == false);

    TEST_CHECK(ie[2].input == InputKeyC);
    TEST_CHECK(ie[2].stateFirst == KeyStateDown);
    TEST_CHECK(ie[2].stateSecond == KeyStateUnknown);
    TEST_CHECK(ie[2].seenByImGui == false);

    input_listener_free(il);
}

// check cursor position after that we post a MouseEvent
void test_input_get_cursor(void) {
    float x = 0.0f, y = 0.0f;
    bool b1 = false, b2 = false, b3 = false;
    InputListener
        *il = input_listener_new(true, false, false, false, false, false, false, false, false);
    inputs_set_nb_pixels_in_one_point(1.0f);

    postMouseEvent(1.0f, 2.0f, 1.0f, 2.0f, MouseButtonLeft, true, true);
    input_get_cursor(&x, &y, &b1, &b2, &b3);
    TEST_CHECK(x == 1.0f);
    TEST_CHECK(y == 2.0f);
    TEST_CHECK(b1);
    TEST_CHECK(b2 == false);
    TEST_CHECK(b3 == false);

    postMouseEvent(3.0f, 1.0f, 2.0f, -1.0f, MouseButtonLeft, false, true);
    input_get_cursor(&x, &y, &b1, &b2, &b3);
    TEST_CHECK(x == 3.0f);
    TEST_CHECK(y == 1.0f);
    TEST_CHECK(b1 == false);
    TEST_CHECK(b2 == false);
    TEST_CHECK(b3 == false);

    input_listener_free(il);
}
