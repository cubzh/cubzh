//
//  notifications.h
//  xptools
//
//  Created by Gaetan de Villele on 11/07/2023.
//  Copyright © 2023 voxowl. All rights reserved.
//

#pragma once

// C++
#include <chrono>
#include <string>
#include <functional>

namespace vx {
namespace notification {

typedef enum {
    NotificationAuthorizationStatus_NotDetermined = 0, // user's never been asked for authorization
    NotificationAuthorizationStatus_Denied, // user clearly denied the service
    NotificationAuthorizationStatus_Authorized,
    NotificationAuthorizationStatus_Postponed,
    NotificationAuthorizationStatus_NotSupported // when not supported on the platform
} NotificationAuthorizationStatus;

typedef enum {
    NotificationAuthorizationResponse_Error = 0, // unknown error, doesn't mean user denied it
    NotificationAuthorizationResponse_Authorized,
    NotificationAuthorizationResponse_Denied,
    NotificationAuthorizationResponse_Postponed,
    NotificationAuthorizationResponse_NotSupported // when not supported on the platform
} NotificationAuthorizationResponse;

typedef std::function<void(NotificationAuthorizationStatus)> StatusCallback;
typedef std::function<void(NotificationAuthorizationResponse)> AuthorizationRequestCallback;

//
void setNeedsToPushToken(bool b);

//
bool needsToPushToken();


// Sets badge count
void setBadgeCount(int count);

// Triggers callback with current status
void remotePushAuthorizationStatus(StatusCallback callback);

// ! \\ returned char* should be freed
// ! \\ can return nullptr
// possible values in .notificationStatus:
// "postponed" -> user decided to postpone authorization
// "set" -> user did approve or deny (ask system, can be updated anytime in the settings)
char* readNotificationStatusFile();

// Should be called when user explicitly postpones
// remote push notification authorization.
// Returns true on success (saving information in .notificationStatus file)
bool postponeRemotePushAuthorization();

// Should be called when user authorizes or deny remote push notifications
bool setRemotePushAuthorization();

// Shows system popup requesting user's authorization to receive push notifications
void requestRemotePushAuthorization(AuthorizationRequestCallback callback);

// Request remote push token, only if authorized
// This should be done periodically as the token can expire.
void requestRemotePushToken();

void scheduleLocalNotification(const std::string &title,
                               const std::string &body,
                               const std::string &identifier,
                               int days,
                               int hours,
                               int minutes,
                               int seconds);

void cancelLocalNotification(const std::string &identifier);

#if defined(__VX_PLATFORM_ANDROID)
void didReplyToNotificationPermissionPopup(NotificationAuthorizationResponse response);
#endif

}
}
