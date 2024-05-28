//
//  notifications.mm
//  xptools
//
//  Created by Gaetan de Villele on 11/07/2023.
//  Copyright © 2023 voxowl. All rights reserved.
//

#include "notifications.hpp"

// xptools
#include "vxlog.h"

// Obj-C
#import <UserNotifications/UserNotifications.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#elif TARGET_OS_MAC
#import <AppKit/AppKit.h>
#import <dispatch/block.h>
#endif

bool vx::notification::notificationsAvailable() {
    __block bool result = false;

    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    // Define callback function
    void(^callback)(UNNotificationSettings *) = ^(UNNotificationSettings * _Nonnull settings){
        result = (settings.authorizationStatus == UNAuthorizationStatusAuthorized ||
                  settings.authorizationStatus == UNAuthorizationStatusProvisional);
        dispatch_semaphore_signal(sema);
    };

    // Request current notification settings, passing it the callback function
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:callback];

    // Wait for the callback to be executed
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

    // wait for callback block to be executed and return result synchronously
    return result;
}

bool vx::notification::shouldShowInfoPopup() {
#if TARGET_OS_MAC
    return false; // no info popup on macOS
#elif TARGET_OS_IPHONE
    __block bool result = false;

    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    // Define callback function
    void(^callback)(UNNotificationSettings *) = ^(UNNotificationSettings * _Nonnull settings){
        result = (settings.authorizationStatus == UNAuthorizationStatusNotDetermined); // TODO: gdevillele: test this!
        dispatch_semaphore_signal(sema);
    };

    // Request current notification settings, passing it the callback function
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:callback];

    // Wait for the callback to be executed
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

    // wait for callback block to be executed and return result synchronously
    return result;
#endif
}

// TODO: return boolean `success`
void vx::notification::requestRemotePush() {
    const UNAuthorizationOptions opts = (UNAuthorizationOptionAlert |
                                         UNAuthorizationOptionBadge |
                                         UNAuthorizationOptionSound |
                                         UNAuthorizationOptionProvisional);

    [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:opts completionHandler:^(const BOOL granted, NSError * _Nullable error) {
        NSLog(@"[vx::notification::request] ERROR: %@", error.description);
        vxlog_debug("push notif approved: %s", granted ? "YES" : "NO");

        if (error != nil) {
            // TODO: gdevillele: also trigger VXApplication callback function on failure.
            return;
        }

        if (granted == NO) {
            // TODO: gdevillele: also trigger VXApplication callback function on access refusal.
            return;
        }

        // get notification settings
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:
         ^(UNNotificationSettings * _Nonnull settings) {

            if (settings.authorizationStatus != UNAuthorizationStatusAuthorized &&
                settings.authorizationStatus != UNAuthorizationStatusProvisional) {
                // App is not allowed to send notifications, abort.
                vxlog_warning("not allowed to send notifications");
                // TODO: gdevillele: also trigger VXApplication callback function on failure.
                return;
            }

            // must be called in main queue (iOS at least)
            dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_IPHONE
                [[UIApplication sharedApplication] registerForRemoteNotifications];
#elif TARGET_OS_MAC
                [[NSApplication sharedApplication] registerForRemoteNotifications];
#endif
            });
        }];
    }];
}

bool vx::notification::scheduleAllLocalReminders(const std::string& title,
                                                 const std::string& message) {
    // TODO: implement me!
    return false;
}

bool vx::notification::cancelAllLocalReminders() {
    // TODO: implement me!
    return false;
}

//bool vx::notification::scheduleLocal() {
//    bool result = false;
//
//    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:
//     ^(UNNotificationSettings * _Nonnull settings) {
//
//        if (settings.authorizationStatus != UNAuthorizationStatusAuthorized &&
//            settings.authorizationStatus != UNAuthorizationStatusProvisional) {
//            // App is not allowed to send notifications, abort.
//            vxlog_warning("not allowed to send notifications");
//            return;
//        }
//
//        if (settings.alertSetting != UNNotificationSettingEnabled) {
//            vxlog_debug("🔥 Notifications : alert not enabled");
//        }
//        if (settings.badgeSetting != UNNotificationSettingEnabled) {
//            vxlog_debug("🔥 Notifications : badge not enabled");
//        }
//        if (settings.soundSetting != UNNotificationSettingEnabled) {
//            vxlog_debug("🔥 Notifications : sound not enabled");
//        }
//
//        // Notification content
//        UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
//        content.title = @"Test";
//        content.body = @"This is a test notification.";
//        // content.categoryIdentifier = @"alarm";
//        // content.userInfo = ["customData": "fizzbuzz"];
//        content.sound = UNNotificationSound.defaultSound;
//
//        // Notification trigger
//        // UNTimeIntervalNotificationTrigger* trigger = nil; // nil trigger to deliver immediately
//        // 5 seconds
//        UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:5 repeats:FALSE];
//
//        // Notification request
//        UNNotificationRequest* req = [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString] content:content trigger:trigger];
//
//        [[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
//
//        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:req withCompletionHandler:
//         ^(NSError * _Nullable error) {
//            NSLog(@"%@", error.description);
//        }];
//    }];
//
//    return result;
//}
