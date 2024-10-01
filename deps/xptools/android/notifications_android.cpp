//
//  notifications_android.cpp
//  xptools
//
//  Created by Gaetan de Villele on 18/07/2023.
//  Copyright © 2023 voxowl. All rights reserved.
//

#include "notifications.hpp"

// C++
#include <cassert>
#include <future>

// android
#include <android/log.h>

// xptools
#include "vxlog.h"
#include "JNIUtils.hpp"

//
static vx::notification::AuthorizationRequestCallback storedCallback = nullptr;

bool _javaPermissionGranted() {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Notifications",
                                                           "permissionGranted",
                                                           "()Z")) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Cubzh",
                            "%s %d: error to get methodInfo",
                            __FILE__,
                            __LINE__);
        assert(false); // crash the program
    }

    const jboolean result = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID);

    methodInfo.env->DeleteLocalRef(methodInfo.classID);

    if (just_attached) {
        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
    }

    return result;
}

void _javaRequestRemotePush() {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Notifications",
                                                           "requestPermission",
                                                           "()V")) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Cubzh",
                            "%s %d: error to get methodInfo",
                            __FILE__,
                            __LINE__);
        assert(false); // crash the program
    }

    methodInfo.env->CallStaticVoidMethod(methodInfo.classID, methodInfo.methodID);

    methodInfo.env->DeleteLocalRef(methodInfo.classID);

    if (just_attached) {
        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
    }
}

void _javaRequestFirebaseToken() {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Notifications",
                                                           "requestFirebaseToken",
                                                           "()V")) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Cubzh",
                            "%s %d: error to get methodInfo",
                            __FILE__,
                            __LINE__);
        assert(false); // crash the program
    }

    methodInfo.env->CallStaticVoidMethod(methodInfo.classID, methodInfo.methodID);

    methodInfo.env->DeleteLocalRef(methodInfo.classID);

    if (just_attached) {
        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
    }
}

namespace vx {
namespace notification {

NotificationAuthorizationStatus remotePushAuthorizationStatus() {
    std::string _status = "";

    char *s = readNotificationStatusFile();
    if (s != nullptr) {
        _status = std::string(s); // "set" or "postponed"
        free(s);
        s = nullptr;
    }

    NotificationAuthorizationStatus status = NotificationAuthorizationStatus_NotDetermined;
    const bool granted = _javaPermissionGranted();
    if (granted) {
        status = NotificationAuthorizationStatus_Authorized;
        if (_status != "set") {
            setRemotePushAuthorization();
        }
    } else {
        if (_status == "postponed") {
            status = NotificationAuthorizationStatus_Postponed;
        } else if (_status == "set") {
            status = NotificationAuthorizationStatus_Denied;
        } else {
            status = NotificationAuthorizationStatus_NotDetermined;
        }
    }
    return status;
}

void requestRemotePushAuthorization(AuthorizationRequestCallback callback) {
    // store callback
    storedCallback = callback;
    _javaRequestRemotePush();
}

void requestRemotePushToken() {
    if (remotePushAuthorizationStatus() == NotificationAuthorizationStatus_Authorized) {
        _javaRequestFirebaseToken();
    }
}

void scheduleLocalNotification(const std::string &title,
                               const std::string &body,
                               const std::string &identifier,
                               int days,
                               int hours,
                               int minutes,
                               int seconds) {
    __android_log_print(ANDROID_LOG_ERROR,"Cubzh","%s %d: %s is not implemented", __FILE__, __LINE__, __FUNCTION__);
}

void cancelLocalNotification(const std::string &identifier) {
    __android_log_print(ANDROID_LOG_ERROR,"Cubzh","%s %d: %s is not implemented", __FILE__, __LINE__, __FUNCTION__);
}

// Android-specific
void didReplyToNotificationPermissionPopup(NotificationAuthorizationResponse response) {
    if (storedCallback != nullptr) {
        storedCallback(response);
    }
}


}
}
