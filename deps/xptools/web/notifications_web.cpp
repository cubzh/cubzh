
#include "notifications.hpp"

namespace vx {
namespace notification {

void remotePushAuthorizationStatus(StatusCallback callback) {
	if (callback != nullptr) {
		callback(NotificationAuthorizationStatus_NotSupported);
	}
}

void requestRemotePushAuthorization(AuthorizationRequestCallback callback) {}

void requestRemotePushToken() {}

void scheduleLocalNotification(
    const std::string& title,
    const std::string& body,
    const std::string& identifier,
    int days,
    int hours,
    int minutes,
    int seconds) {}

void cancelLocalNotification(const std::string &identifier) {}

void setBadgeCount(int) {}

}
}
