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

namespace vx {
namespace notification {


void remotePushAuthorizationStatus(StatusCallback callback) {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        dispatch_async(dispatch_get_main_queue(), ^{
            std::string _status = "";

            char *s = readNotificationStatusFile();
            if (s != nullptr) {
                _status = std::string(s); // "set" or "postponed"
                free(s);
            }

            if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                if (_status != "set") {
                    setRemotePushAuthorization();
                }
                callback(NotificationAuthorizationStatus_Authorized);
            } else if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
                if (_status != "set") {
                    setRemotePushAuthorization();
                }
                callback(NotificationAuthorizationStatus_Denied);
            } else {
                if (_status == "postponed") {
                    callback(NotificationAuthorizationStatus_Postponed);
                } else {
                    callback(NotificationAuthorizationStatus_NotDetermined);
                }
            }
        });
    }];;
}

// #if TARGET_OS_MAC
// #elif TARGET_OS_IPHONE

void requestRemotePushAuthorization(AuthorizationRequestCallback callback) {
    const UNAuthorizationOptions opts = (UNAuthorizationOptionAlert |
                                         UNAuthorizationOptionBadge |
                                         UNAuthorizationOptionSound);

    [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:opts completionHandler:^(const BOOL granted, NSError * _Nullable error) {
        NSLog(@"[request] ERROR: %@", error.description);
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

        // GRANTED!

        // NOTE: push notifications and badges authorized by user,
        // but token should still be requested, and it should be done
        // periodically as it may expire.
        dispatch_async(dispatch_get_main_queue(), ^{
            setRemotePushAuthorization();
            callback(NotificationAuthorizationResponse_Authorized);
        });

        requestRemotePushToken();
    }];
}

void requestRemotePushToken() {
    remotePushAuthorizationStatus([](NotificationAuthorizationStatus status){
        if (status == NotificationAuthorizationStatus_Authorized) {
            // already in main queue
#if TARGET_OS_IPHONE
            [[UIApplication sharedApplication] registerForRemoteNotifications];
#elif TARGET_OS_MAC
            [[NSApplication sharedApplication] registerForRemoteNotifications];
#endif
        }
    });
}

void scheduleLocalNotification(const std::string &title,
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

void cancelLocalNotification(const std::string &identifier) {
    NSString *nsidentifier = [NSString stringWithCString:identifier.c_str() encoding:NSUTF8StringEncoding];

    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center removePendingNotificationRequestsWithIdentifiers:@[nsidentifier]];
}

}
}
