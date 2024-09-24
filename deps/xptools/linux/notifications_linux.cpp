
#include "notifications.hpp"

// Returns current authorization status for push notifications.
vx::notification::NotificationAuthorizationStatus vx::notification::remotePushAuthorizationStatus() {
	return vx::notification::NotificationAuthorizationStatus_NotSupported;
}

// Shows system popup requesting user's authorization to receive push notifications
void vx::notification::requestRemotePushAuthorization(vx::notification::AuthorizationRequestCallback callback) {}

// Same as requestRemotePushAuthorization, but only triggers system popup
// if auth status in not determined.
// Triggers callback with proper response otherwise, not asking user for anything.
void vx::notification::requestRemotePushAuthorizationIfAuthStatusNotDetermined(vx::notification::AuthorizationRequestCallback callback) {}

void vx::notification::scheduleLocalNotification(const std::string &title,
                               const std::string &body,
                               const std::string &identifier,
                               int days,
                               int hours,
                               int minutes,
                               int seconds) {}

void vx::notification::cancelLocalNotification(const std::string &identifier) {}
