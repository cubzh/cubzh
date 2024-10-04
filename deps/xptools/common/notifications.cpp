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

void vx::notification::setNeedsToPushToken(bool b) {
    if (b) {
        c_writeStorageFileTextContent(".notificationNeedsToPushToken", "1");
    } else {
        c_removeStorageFile(".notificationNeedsToPushToken");
    }
}

bool vx::notification::needsToPushToken() {
    return c_storageFileExists(".notificationNeedsToPushToken", nullptr);
}

char* vx::notification::readNotificationStatusFile() {
    return c_readStorageFileTextContent(".notificationStatus");
}

bool vx::notification::postponeRemotePushAuthorization() {
    return c_writeStorageFileTextContent(".notificationStatus", "postponed");
}

bool vx::notification::setRemotePushAuthorization() {
    return c_writeStorageFileTextContent(".notificationStatus", "set");
}
