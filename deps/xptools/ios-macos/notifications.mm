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

vx::notification::NotificationAuthorizationStatus vx::notification::remotePushAuthorizationStatus() {
    char *s = readNotificationStatusFile();
    if (s == nullptr) {
        return NotificationAuthorizationStatus_NotDetermined;
    }
    if (strcmp(s, "postponed") == 0) {
        free(s);
        return NotificationAuthorizationStatus_Postponed;
    }
    if (strcmp(s, "set") != 0) {
        free(s);
        return NotificationAuthorizationStatus_NotDetermined;
    }
    free(s);

    __block NotificationAuthorizationStatus status = NotificationAuthorizationStatus_NotDetermined;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
            status = NotificationAuthorizationStatus_Authorized;
        } else if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
            status = NotificationAuthorizationStatus_Denied;
        } else {
            // NOTE: considering UNAuthorizationStatusProvisional as "not determined"
            // we want clear approval
            status = NotificationAuthorizationStatus_NotDetermined;
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return status;
}

// #if TARGET_OS_MAC
// #elif TARGET_OS_IPHONE

void vx::notification::requestRemotePushAuthorization(AuthorizationRequestCallback callback) {
    const UNAuthorizationOptions opts = (UNAuthorizationOptionAlert |
                                         UNAuthorizationOptionBadge |
                                         UNAuthorizationOptionSound);

    [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:opts completionHandler:^(const BOOL granted, NSError * _Nullable error) {
        NSLog(@"[vx::notification::request] ERROR: %@", error.description);
        vxlog_debug("push notif approved: %s", granted ? "YES" : "NO");

        if (error != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(NotificationAuthorizationResponse_Error);
            });
            return;
        }

        if (granted == NO) {
            dispatch_async(dispatch_get_main_queue(), ^{
                setRemotePushAuthorization();
                callback(NotificationAuthorizationResponse_Denied);
            });
            return;
        }

        // get notification settings
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:
         ^(UNNotificationSettings * _Nonnull settings) {
            if (settings.authorizationStatus != UNAuthorizationStatusAuthorized) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    callback(NotificationAuthorizationResponse_Error);
                });
                return;
            }

            // must be called in main queue (iOS at least)
            dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_IPHONE
                [[UIApplication sharedApplication] registerForRemoteNotifications];
#elif TARGET_OS_MAC
                [[NSApplication sharedApplication] registerForRemoteNotifications];
#endif
                // NOTE: considering everything went well from this point,
                // even though the system could still fail obtaining token.
                // Even though, now with user's authorization, we should be able to retry
                // and obtain the token.
                dispatch_async(dispatch_get_main_queue(), ^{
                    setRemotePushAuthorization();
                    callback(NotificationAuthorizationResponse_Authorized);
                });
            });
        }];
    }];
}

void vx::notification::requestRemotePushAuthorizationIfAuthStatusNotDetermined(AuthorizationRequestCallback callback) {
    NotificationAuthorizationStatus s = remotePushAuthorizationStatus();
    switch (s) {
        case NotificationAuthorizationStatus_NotDetermined:
            requestRemotePushAuthorization(callback);
            break;
        case NotificationAuthorizationStatus_Postponed:
            callback(NotificationAuthorizationResponse_Postponed);
            break;
        case NotificationAuthorizationStatus_NotSupported:
            callback(NotificationAuthorizationResponse_NotSupported);
            break;
        case NotificationAuthorizationStatus_Denied:
            callback(NotificationAuthorizationResponse_Denied);
            break;
        case NotificationAuthorizationStatus_Authorized:
            callback(NotificationAuthorizationResponse_Authorized);
            break;
    }
}

void vx::notification::scheduleLocalNotification(const std::string &title,
                                                 const std::string &body,
                                                 const std::string &identifier,
                                                 int days,
                                                 int hours,
                                                 int minutes,
                                                 int seconds) {
    UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];

    NSString *nstitle = [NSString stringWithCString:title.c_str() encoding:NSUTF8StringEncoding];
    NSString *nsbody = [NSString stringWithCString:body.c_str() encoding:NSUTF8StringEncoding];
    NSString *nsidentifier = [NSString stringWithCString:identifier.c_str() encoding:NSUTF8StringEncoding];

    content.title = [NSString localizedUserNotificationStringForKey:nstitle arguments:nil];
    content.body = [NSString localizedUserNotificationStringForKey:nsbody arguments:nil];

    NSTimeInterval timeInterval = days * 86400 + hours * 3600 + minutes * 60 + seconds;
    UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:timeInterval repeats:NO];

    UNNotificationRequest* request = [UNNotificationRequest
           requestWithIdentifier:nsidentifier content:content trigger:trigger];

    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
       if (error != nil) {
           NSLog(@"could not schedule notification: %@", error.localizedDescription);
       }
    }];
}

void vx::notification::cancelLocalNotification(const std::string &identifier) {
    NSString *nsidentifier = [NSString stringWithCString:identifier.c_str() encoding:NSUTF8StringEncoding];

    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center removePendingNotificationRequestsWithIdentifiers:@[nsidentifier]];
}
