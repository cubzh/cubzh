
#include "notifications.hpp"

namespace vx {
    namespace notification {

// Returns current authorization status for push notifications.
NotificationAuthorizationStatus remotePushAuthorizationStatus() {
	return NotificationAuthorizationStatus_NotSupported;
}

// Shows system popup requesting user's authorization to receive push notifications
void requestRemotePushAuthorization(AuthorizationRequestCallback callback) {}

// Same as requestRemotePushAuthorization, but only triggers system popup
// if auth status in not determined.
// Triggers callback with proper response otherwise, not asking user for anything.
void requestRemotePushAuthorizationIfAuthStatusNotDetermined(AuthorizationRequestCallback callback) {}

void requestRemotePushToken() {}

void scheduleLocalNotification(const std::string &title,
                               const std::string &body,
                               const std::string &identifier,
                               int days,
                               int hours,
                               int minutes,
                               int seconds) {}

void cancelLocalNotification(const std::string &identifier) {}

    }
}
