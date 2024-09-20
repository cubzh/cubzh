
#include "notifications.hpp"

vx::notification::NotificationAuthorizationStatus vx::notification::
    remotePushAuthorizationStatus() {
    return vx::notification::NotificationAuthorizationStatus_NotSupported;
}

char *vx::notification::readNotificationStatusFile() {
    return nullptr;
}

bool vx::notification::postponeRemotePushAuthorization() {
    return false;
}

bool vx::notification::setRemotePushAuthorization() {
    return false;
}

void vx::notification::requestRemotePushAuthorization(AuthorizationRequestCallback callback) {}

void vx::notification::requestRemotePushAuthorizationIfAuthStatusNotDetermined(
    AuthorizationRequestCallback callback) {}

void vx::notification::scheduleLocalNotification(const std::string& title,
    const std::string& body,
    const std::string& identifier,
    int days,
    int hours,
    int minutes,
    int seconds) {}

void cancelLocalNotification(const std::string &identifier) {}
