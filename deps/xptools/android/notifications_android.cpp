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

namespace vx {
    namespace notification {

        NotificationAuthorizationStatus remotePushAuthorizationStatus() {
            char *cStr = readNotificationStatusFile();
            if (cStr == nullptr) {
                vxlog_debug("CUBZH_DEBUG %s", "NotDetermined (1)");
                return NotificationAuthorizationStatus_NotDetermined;
            }
            std::string s(cStr);
            free(cStr);
            cStr = nullptr;

            if (s == "postponed") {
                vxlog_debug("CUBZH_DEBUG %s", "Postponed");
                return NotificationAuthorizationStatus_Postponed;
            }
            if (s != "set") {
                vxlog_debug("CUBZH_DEBUG %s", "NotDetermined (2)");
                return NotificationAuthorizationStatus_NotDetermined;
            }

            // permission status has been set by the user

            NotificationAuthorizationStatus status = NotificationAuthorizationStatus_NotDetermined;
            const bool granted = _javaPermissionGranted();
            if (granted) {
                vxlog_debug("CUBZH_DEBUG %s", "Authorized");
                status = NotificationAuthorizationStatus_Authorized;
            } else {
                vxlog_debug("CUBZH_DEBUG %s", "Denied");
                status = NotificationAuthorizationStatus_Denied;
            }
            return status;
        }

        void requestRemotePushAuthorization(AuthorizationRequestCallback callback) {
            _javaRequestRemotePush();
            callback(NotificationAuthorizationResponse_Postponed);
        }

        void requestRemotePushAuthorizationIfAuthStatusNotDetermined(AuthorizationRequestCallback callback) {
            // TODO: !!!
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

    }
}

//bool vx::notification::notificationsAvailable() {
//    bool just_attached = false;
//    vx::tools::JniMethodInfo methodInfo;
//
//    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
//                                                           &methodInfo,
//                                                           "com/voxowl/tools/Notifications",
//                                                           "permissionGranted",
//                                                           "()Z")) {
//        __android_log_print(ANDROID_LOG_ERROR,
//                            "Cubzh",
//                            "%s %d: error to get methodInfo",
//                            __FILE__,
//                            __LINE__);
//        assert(false); // crash the program
//    }
//
//    const jboolean result = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID);
//
//    methodInfo.env->DeleteLocalRef(methodInfo.classID);
//
//    if (just_attached) {
//        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
//    }
//
//    return result;
//}
//
//bool vx::notification::shouldShowInfoPopup() {
//    bool just_attached = false;
//    vx::tools::JniMethodInfo methodInfo;
//
//    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
//                                                           &methodInfo,
//                                                           "com/voxowl/tools/Notifications",
//                                                           "shouldShowInfoPopup",
//                                                           "()Z")) {
//        __android_log_print(ANDROID_LOG_ERROR,
//                            "Cubzh",
//                            "%s %d: error to get methodInfo",
//                            __FILE__,
//                            __LINE__);
//        assert(false); // crash the program
//    }
//
//    const jboolean result = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID);
//
//    methodInfo.env->DeleteLocalRef(methodInfo.classID);
//
//    if (just_attached) {
//        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
//    }
//
//    return result;
//}
//
//void vx::notification::requestRemotePush() {
//    bool just_attached = false;
//    vx::tools::JniMethodInfo methodInfo;
//
//    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
//                                                           &methodInfo,
//                                                           "com/voxowl/tools/Notifications",
//                                                           "request",
//                                                           "()V")) {
//        __android_log_print(ANDROID_LOG_ERROR,
//                            "Cubzh",
//                            "%s %d: error to get methodInfo",
//                            __FILE__,
//                            __LINE__);
//        assert(false); // crash the program
//    }
//
//    methodInfo.env->CallStaticVoidMethod(methodInfo.classID, methodInfo.methodID);
//
//    methodInfo.env->DeleteLocalRef(methodInfo.classID);
//
//    if (just_attached) {
//        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
//    }
//}
//
//bool vx::notification::scheduleAllLocalReminders(const std::string& title,
//                                                 const std::string& message) {
//    bool just_attached = false;
//    vx::tools::JniMethodInfo methodInfo;
//
//    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
//                                                           &methodInfo,
//                                                           "com/voxowl/tools/Notifications",
//                                                           "scheduleAllLocalNotificationReminders",
//                                                           "()Z")) {
//        __android_log_print(ANDROID_LOG_ERROR,
//                            "Cubzh",
//                            "%s %d: error to get methodInfo",
//                            __FILE__,
//                            __LINE__);
//        assert(false); // crash the program
//    }
//
//    const jboolean result = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID);
//
//    methodInfo.env->DeleteLocalRef(methodInfo.classID);
//
//    if (just_attached) {
//        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
//    }
//
//    return result;
//}

//bool vx::notification::scheduleAllLocalReminders(const std::string& title,
//                                                 const std::string& message) {
//    bool just_attached = false;
//    vx::tools::JniMethodInfo methodInfo;
//
//    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
//                                                           &methodInfo,
//                                                           "com/voxowl/tools/Notifications",
//                                                           "scheduleAllLocalNotificationReminders",
//                                                           "(Ljava/lang/String;Ljava/lang/String;)Z")) {
//        __android_log_print(ANDROID_LOG_ERROR,
//                            "Cubzh",
//                            "%s %d: error to get methodInfo",
//                            __FILE__,
//                            __LINE__);
//        assert(false); // crash the program
//    }
//
//    const jstring j_title = methodInfo.env->NewStringUTF(title.c_str());
//    const jstring j_message = methodInfo.env->NewStringUTF(message.c_str());
//
//    const jboolean result = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID, j_title, j_message);
//
//    methodInfo.env->DeleteLocalRef(methodInfo.classID);
//    methodInfo.env->DeleteLocalRef(j_title);
//    methodInfo.env->DeleteLocalRef(j_message);
//
//    if (just_attached) {
//        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
//    }
//
//    return result;
//}

//bool vx::notification::cancelAllLocalReminders() {
//    bool just_attached = false;
//    vx::tools::JniMethodInfo methodInfo;
//
//    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
//                                                           &methodInfo,
//                                                           "com/voxowl/tools/Notifications",
//                                                           "cancelAllLocalNotificationReminders",
//                                                           "()Z")) {
//        __android_log_print(ANDROID_LOG_ERROR,
//                            "Cubzh",
//                            "%s %d: error to get methodInfo",
//                            __FILE__,
//                            __LINE__);
//        assert(false); // crash the program
//    }
//
//    const jboolean result = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID, methodInfo.methodID);
//
//    methodInfo.env->DeleteLocalRef(methodInfo.classID);
//
//    if (just_attached) {
//        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
//    }
//
//    return result;
//}