//
//  device_linux.cpp
//  xptools
//
//  Created by Adrien Duermael on 04/20/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#include "device.hpp"

// Returns platform type
vx::device::Platform vx::device::platform() {
    return Platform_Desktop;
}

std::string vx::device::osName() {
    // NOTE: maybe there's something better
    return "Linux";
}

std::string vx::device::osVersion() {
    // TODO: implement
    return "";
}

std::string vx::device::appVersion() {
    // TODO: implement
    return "";
}

uint16_t vx::device::appBuildNumber() {
    // TODO: implement
    return 0;
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

void vx::device::terminate() {

}

bool vx::device::hasTouchScreen() {
    return false;
}

bool vx::device::hasMouseAndKeyboard() {
    return true;
}

bool vx::device::isMobile() {
    return false;
}

bool vx::device::isPC() {
    return true;
}

bool vx::device::isConsole() {
    return false;
}

void vx::device::setClipboardText(const std::string &text) {
    // nothing for now
}

std::string vx::device::getClipboardText() {
    // nothing for now
    return "";
}

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

void vx::device::cancelLocalNotification(const std::string &identifier) {
    // local notifications not supported (yet?)
}

void vx::device::openApplicationSettings() {
    // local notifications not supported (yet?)
}

std::vector<std::string> vx::device::preferredLanguages() {
    std::vector<std::string> languages{"en"};
    return languages;
}

