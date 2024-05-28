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

bool vx::notification::notificationsAvailable() {
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

bool vx::notification::shouldShowInfoPopup() {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Notifications",
                                                           "shouldShowInfoPopup",
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

void vx::notification::requestRemotePush() {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Notifications",
                                                           "request",
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

bool vx::notification::scheduleAllLocalReminders(const std::string& title,
                                                 const std::string& message) {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Notifications",
                                                           "scheduleAllLocalNotificationReminders",
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

bool vx::notification::cancelAllLocalReminders() {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Notifications",
                                                           "cancelAllLocalNotificationReminders",
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