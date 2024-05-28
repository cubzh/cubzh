
#include "notifications.hpp"

bool vx::notification::notificationsAvailable() {
    // Notifications are not implemented yet for this platform.
    return false;
}

bool vx::notification::shouldShowInfoPopup() {
    // Notifications are not implemented yet for this platform.
    return false;
}

void vx::notification::requestRemotePush() {
    // Notifications are not implemented yet for this platform.
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
