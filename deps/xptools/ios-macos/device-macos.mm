//
//  device-macos.mm
//  xptools
//
//  Created by Adrien Duermael on 04/20/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#include "device.hpp"

// Obj-C
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// C
#import <sys/sysctl.h>

/// Returns platform type
vx::device::Platform vx::device::platform() {
    return Platform_Desktop;
}

std::string vx::device::osName() {
    return "macOS";
}

std::string vx::device::osVersion() {
    NSOperatingSystemVersion v = [[NSProcessInfo processInfo] operatingSystemVersion];
    return std::to_string(v.majorVersion) + "." + std::to_string(v.minorVersion) + "." + std::to_string(v.patchVersion);
}

std::string vx::device::appVersion() {
    NSDictionary* infoDictionary = [[NSBundle mainBundle] infoDictionary];
    if (infoDictionary == nullptr) {
        return std::string();
    }
    NSString* appVersion = infoDictionary[@"CFBundleShortVersionString"];
    if (appVersion == nullptr) {
        return std::string();
    }
    return std::string([appVersion UTF8String]);
}

uint16_t vx::device::appBuildNumber() {
    NSDictionary* infoDictionary = [[NSBundle mainBundle] infoDictionary];
    if (infoDictionary == nullptr) {
        return 0;
    }
    NSString* key = static_cast<NSString*>(kCFBundleVersionKey);
    NSString* bundleVersion = infoDictionary[key];
    if (bundleVersion == nullptr) {
        return 0;
    }
    const uint16_t result = [bundleVersion intValue];
    return result;
}

std::string vx::device::hardwareBrand() {
    return "Apple";
}

std::string vx::device::hardwareModel() {
    NSString *result = @"";
    size_t len=0;
    sysctlbyname("hw.model", nullptr, &len, nullptr, 0);
    if (len) {
        NSMutableData *data=[NSMutableData dataWithLength:len];
        sysctlbyname("hw.model", [data mutableBytes], &len, nullptr, 0);
        const char *bytes = static_cast<const char *>([data bytes]);
        result = [NSString stringWithUTF8String:bytes];
    }
    return std::string([result UTF8String]);
}

std::string vx::device::hardwareProduct() {
    NSString *result = @"";
    size_t len=0;
    sysctlbyname("hw.product", nullptr, &len, nullptr, 0);
    if (len) {
        NSMutableData *data=[NSMutableData dataWithLength:len];
        sysctlbyname("hw.product", [data mutableBytes], &len, nullptr, 0);
        const char *bytes = static_cast<const char *>([data bytes]);
        result = [NSString stringWithUTF8String:bytes];
    }
    return std::string([result UTF8String]);
}

uint64_t vx::device::hardwareMemory() {
    uint64_t result = 0;
    size_t len=0;
    sysctlbyname("hw.memsize", nullptr, &len, nullptr, 0);
    if (len) {
        NSMutableData *data=[NSMutableData dataWithLength:len];
        sysctlbyname("hw.memsize", [data mutableBytes], &len, nullptr, 0);
        memcpy(&result, [data bytes], len);
    }
    return result;
}

void vx::device::terminate() {
    [[NSApplication sharedApplication] terminate:nil];
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
    NSString *nstext = [NSString stringWithUTF8String:text.c_str()];
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:nstext forType:NSPasteboardTypeString];
}

std::string vx::device::getClipboardText() {
    NSString *nstext = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
    std::string result;
    if (nstext != nil) {
        result.assign(nstext.UTF8String);
    }
    return result;
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
    // local notifications not supported (yet?) on macOS
}

void cancelLocalNotification(const std::string &identifier) {
    // local notifications not supported (yet?) on macOS
}

void vx::device::openApplicationSettings() {
    NSString *urlString = [NSString stringWithFormat:@"x-apple.systempreferences:com.apple.preference.notifications"];

    NSURL *url = [NSURL URLWithString:urlString];
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];

    if ([workspace openURL:url]) {
        NSLog(@"Successfully opened Notification Preferences");
    } else {
        NSLog(@"Failed to open Notification Preferences");
    }
}

std::vector<std::string> vx::device::preferredLanguages() {
    std::vector<std::string> languages;
    NSArray *preferredLanguages = [NSLocale preferredLanguages]; // Get the list of preferred languages
    for (NSString *lang in preferredLanguages) {
        languages.push_back([lang UTF8String]); // Convert each NSString to std::string and add to the vector
    }
    return languages;
}

void vx::device::refreshScreenOrientation() {
    // does nothing on macOS
}
