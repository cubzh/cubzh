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
    NotificationAuthorizationStatus_NotDetermined, // user's never been asked for authorization
    NotificationAuthorizationStatus_Denied, // user clearly denied the service
    NotificationAuthorizationStatus_Authorized,
    NotificationAuthorizationStatus_NotSupported // when not supported on the platform
} NotificationAuthorizationStatus;

typedef enum {
    NotificationAuthorizationResponse_Error, // unknown error, doesn't mean user denied it
    NotificationAuthorizationResponse_Authorized,
    NotificationAuthorizationResponse_Denied,
    NotificationAuthorizationResponse_NotSupported // when not supported on the platform
} NotificationAuthorizationResponse;

typedef std::function<void(NotificationAuthorizationResponse)> AuthorizationRequestCallback;

// Returns current authorization status for push notifications.
NotificationAuthorizationStatus remotePushAuthorizationStatus();

// Shows system popup requesting user's authorization to receive push notifications
void requestRemotePushAuthorization(AuthorizationRequestCallback callback);

// Same as requestRemotePushAuthorization, but only triggers system popup
// if auth status in not determined.
// Triggers callback with proper response otherwise, not asking user for anything.
void requestRemotePushAuthorizationIfAuthStatusNotDetermined(AuthorizationRequestCallback callback);

void scheduleLocalNotification(const std::string &title,
                               const std::string &body,
                               const std::string &identifier,
                               int days,
                               int hours,
                               int minutes,
                               int seconds);

void cancelLocalNotification(const std::string &identifier);



}
}
