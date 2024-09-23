
#include "notifications.hpp"

// Returns current authorization status for push notifications.
vx::notification::NotificationAuthorizationStatus vx::notification::remotePushAuthorizationStatus() {
	return vx::notification::NotificationAuthorizationStatus_NotSupported;
}

// ! \\ returned char* should be freed
// ! \\ can return nullptr
// possible values in .notificationStatus:
// "postponed" -> user decided to postpone authorization
// "set" -> user did approve or deny (ask system, can be updated anytime in the settings)
char* vx::notification::readNotificationStatusFile() {
	return nullptr;
}

// Should be called when user explicitely postpones
// remote push notification authorization.
// Returns true on success (saving information in .notificationStatus file)
bool vx::notification::postponeRemotePushAuthorization() {
	return false;
}

// Should be called when user authorizes or deny remote push notifications
bool vx::notification::setRemotePushAuthorization() {
	return false;
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
