//
//  notifications.cpp
//  xptools
//
//  Created by Adrien Duermael on 17/09/2024.
//  Copyright © 2024 voxowl. All rights reserved.
//

#include "notifications.hpp"
#include "filesystem.hpp"
#include "filesystem.h"

char* vx::notification::readNotificationStatusFile() {
    return c_readStorageFileTextContent(".notificationStatus");
}

bool vx::notification::postponeRemotePushAuthorization() {
    return c_writeStorageFileTextContent(".notificationStatus", "postponed");
}

bool vx::notification::setRemotePushAuthorization() {
    return c_writeStorageFileTextContent(".notificationStatus", "set");
}
