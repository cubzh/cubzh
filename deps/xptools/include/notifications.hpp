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

namespace vx {
namespace notification {

/**
 *
 */
bool notificationsAvailable();

/**
 *
 */
bool shouldShowInfoPopup();

/**
 *
 */
void requestRemotePush();

///
/// Schedules local notification reminders (7, 15, 30 days).
/// Returns true on success.
bool scheduleAllLocalReminders(const std::string& title,
                               const std::string& message);

///
/// Cancels all local notification reminders.
/// Returns true on success.
bool cancelAllLocalReminders();

}
}
