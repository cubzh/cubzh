//
//  device_android.cpp
//  xptools
//
//  Created by Adrien Duermael on 04/20/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#include "device.hpp"

// C++
#include <cassert>

// android
#include <android/log.h>

// xptools
#include "JNIUtils.hpp"

// Returns platform type
vx::device::Platform vx::device::platform() {
    return Platform_Mobile;
}

std::string vx::device::osName() {
    // NOTE: maybe there's something better
    return "Android";
}

std::string vx::device::osVersion() {
    __android_log_print(ANDROID_LOG_ERROR, "Cubzh", "[osVersion]");

    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Device",
                                                           "getBuildVersionSdkInt",
                                                           "()I")) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Cubzh",
                            "%s %d: error to get methodInfo",
                            __FILE__,
                            __LINE__);
        assert(false); // crash the program
    }

    jint result = methodInfo.env->CallStaticIntMethod(methodInfo.classID, methodInfo.methodID);

    methodInfo.env->DeleteLocalRef(methodInfo.classID);

    if (just_attached) {
        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
    }

    std::string strResult = std::to_string(result);
    return strResult;
}

std::string vx::device::appVersion() {
    // __android_log_print(ANDROID_LOG_ERROR, "Cubzh", "[appVersion]");

    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Device",
                                                           "getAppVersionName",
                                                           "()Ljava/lang/String;")) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Cubzh",
                            "%s %d: error to get methodInfo",
                            __FILE__,
                            __LINE__);
        assert(false); // crash the program
    }

    jstring result = (jstring)methodInfo.env->CallStaticObjectMethod(methodInfo.classID,
                                                                     methodInfo.methodID);
    const char *resultCStr = methodInfo.env->GetStringUTFChars(result, 0);
    std::string strResult(resultCStr, methodInfo.env->GetStringUTFLength(result));
    methodInfo.env->ReleaseStringUTFChars(result, resultCStr);
    methodInfo.env->DeleteLocalRef(result);

    methodInfo.env->DeleteLocalRef(methodInfo.classID);

    if (just_attached) {
        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
    }

    return strResult;
}

uint16_t vx::device::appBuildNumber() {
    __android_log_print(ANDROID_LOG_ERROR, "Cubzh", "[appBuildNumber]");

    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Device",
                                                           "getAppVersionCode",
                                                           "()I")) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Cubzh",
                            "%s %d: error to get methodInfo",
                            __FILE__,
                            __LINE__);
        assert(false); // crash the program
    }

    jint result = methodInfo.env->CallStaticIntMethod(methodInfo.classID, methodInfo.methodID);

    methodInfo.env->DeleteLocalRef(methodInfo.classID);

    if (just_attached) {
        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
    }

    return result;
}

std::string vx::device::hardwareBrand() {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Device",
                                                           "getHardwareBrand",
                                                           "()Ljava/lang/String;")) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Cubzh",
                            "%s %d: error to get methodInfo",
                            __FILE__,
                            __LINE__);
        assert(false); // crash the program
    }

    jstring result = (jstring)methodInfo.env->CallStaticObjectMethod(methodInfo.classID,
                                                                     methodInfo.methodID);
    const char *resultCStr = methodInfo.env->GetStringUTFChars(result, 0);
    std::string strResult(resultCStr, methodInfo.env->GetStringUTFLength(result));
    methodInfo.env->ReleaseStringUTFChars(result, resultCStr);
    methodInfo.env->DeleteLocalRef(result);

    methodInfo.env->DeleteLocalRef(methodInfo.classID);

    if (just_attached) {
        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
    }

    return strResult;
}

std::string vx::device::hardwareModel() {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Device",
                                                           "getHardwareModel",
                                                           "()Ljava/lang/String;")) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Cubzh",
                            "%s %d: error to get methodInfo",
                            __FILE__,
                            __LINE__);
        assert(false); // crash the program
    }

    jstring result = (jstring)methodInfo.env->CallStaticObjectMethod(methodInfo.classID,
                                                                     methodInfo.methodID);
    const char *resultCStr = methodInfo.env->GetStringUTFChars(result, 0);
    std::string strResult(resultCStr, methodInfo.env->GetStringUTFLength(result));
    methodInfo.env->ReleaseStringUTFChars(result, resultCStr);
    methodInfo.env->DeleteLocalRef(result);

    methodInfo.env->DeleteLocalRef(methodInfo.classID);

    if (just_attached) {
        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
    }

    return strResult;
}

std::string vx::device::hardwareProduct() {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Device",
                                                           "getHardwareProduct",
                                                           "()Ljava/lang/String;")) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Cubzh",
                            "%s %d: error to get methodInfo",
                            __FILE__,
                            __LINE__);
        assert(false); // crash the program
    }

    jstring result = (jstring)methodInfo.env->CallStaticObjectMethod(methodInfo.classID,
                                                                     methodInfo.methodID);
    const char *resultCStr = methodInfo.env->GetStringUTFChars(result, 0);
    std::string strResult(resultCStr, methodInfo.env->GetStringUTFLength(result));
    methodInfo.env->ReleaseStringUTFChars(result, resultCStr);
    methodInfo.env->DeleteLocalRef(result);

    methodInfo.env->DeleteLocalRef(methodInfo.classID);

    if (just_attached) {
        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
    }

    return strResult;
}

uint64_t vx::device::hardwareMemory() {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Device",
                                                           "getHardwareMemory",
                                                           "()J")) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Cubzh",
                            "%s %d: error to get methodInfo",
                            __FILE__,
                            __LINE__);
        assert(false); // crash the program
    }

    jlong result = methodInfo.env->CallStaticLongMethod(methodInfo.classID, methodInfo.methodID);

    methodInfo.env->DeleteLocalRef(methodInfo.classID);

    if (just_attached) {
        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
    }

    uint64_t uintResult = result;
    return uintResult;
}

void vx::device::terminate() {}

bool vx::device::hasTouchScreen() {
    return true;
}

bool vx::device::hasMouseAndKeyboard() {
    return false;
}

bool vx::device::isMobile() {
    return true;
}

bool vx::device::isPC() {
    return false;
}

bool vx::device::isConsole() {
    return false;
}

void vx::device::setClipboardText(const std::string &text) {

    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Device",
                                                           "setClipboardText",
                                                           "(Ljava/lang/String;)V")) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Cubzh",
                            "%s %d: error to get methodInfo",
                            __FILE__,
                            __LINE__);
        assert(false); // crash the program
    }

    jstring j_text = methodInfo.env->NewStringUTF(text.c_str());

    methodInfo.env->CallStaticVoidMethod(methodInfo.classID, methodInfo.methodID, j_text);

    methodInfo.env->DeleteLocalRef(methodInfo.classID);
    methodInfo.env->DeleteLocalRef(j_text);

    if (just_attached) {
        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
    }
}

std::string vx::device::getClipboardText() {

    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Device",
                                                           "getClipboardText",
                                                           "()Ljava/lang/String;")) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Cubzh",
                            "%s %d: error to get methodInfo",
                            __FILE__,
                            __LINE__);
        assert(false); // crash the program
    }

    std::string strResult;

    jstring result = (jstring)methodInfo.env->CallStaticObjectMethod(methodInfo.classID,
                                                                     methodInfo.methodID);
    if (result != nullptr) {
        const char *resultCStr = methodInfo.env->GetStringUTFChars(result, nullptr);
        strResult.assign(resultCStr, methodInfo.env->GetStringUTFLength(result));
        methodInfo.env->ReleaseStringUTFChars(result, resultCStr);
        methodInfo.env->DeleteLocalRef(result);
    }

    methodInfo.env->DeleteLocalRef(methodInfo.classID);

    if (just_attached) {
        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
    }

    return strResult;
}

/// Haptic feedback
void vx::device::hapticImpactLight() {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Device",
                                                           "hapticImpactLight",
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

void vx::device::hapticImpactMedium() {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Device",
                                                           "hapticImpactMedium",
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

void vx::device::hapticImpactHeavy() {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Device",
                                                           "hapticImpactHeavy",
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

vx::device::PerformanceTier vx::device::getPerformanceTier() {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Device",
                                                           "getPerformanceTier",
                                                           "()I")) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Cubzh",
                            "%s %d: error to get methodInfo",
                            __FILE__,
                            __LINE__);
        assert(false); // crash the program
    }

    jint result = methodInfo.env->CallStaticIntMethod(methodInfo.classID, methodInfo.methodID);

    methodInfo.env->DeleteLocalRef(methodInfo.classID);

    if (just_attached) {
        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
    }

    return static_cast<PerformanceTier>(result);
}

// Notifications

void vx::device::openApplicationSettings() {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Device",
                                                           "openApplicationSettings",
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

std::vector<std::string> vx::device::preferredLanguages() {

    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Device",
                                                           "getPreferredLanguages",
                                                           "()Ljava/lang/String;")) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Cubzh",
                            "%s %d: error to get methodInfo",
                            __FILE__,
                            __LINE__);
        assert(false); // crash the program
    }

    std::string strResult;

    jstring result = (jstring)methodInfo.env->CallStaticObjectMethod(methodInfo.classID,
                                                                     methodInfo.methodID);
    if (result != nullptr) {
        const char *resultCStr = methodInfo.env->GetStringUTFChars(result, nullptr);
        strResult.assign(resultCStr, methodInfo.env->GetStringUTFLength(result));
        methodInfo.env->ReleaseStringUTFChars(result, resultCStr);
        methodInfo.env->DeleteLocalRef(result);
    }

    methodInfo.env->DeleteLocalRef(methodInfo.classID);

    if (just_attached) {
        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
    }

    std::vector<std::string> languages;
    languages.push_back(strResult);

    return languages;
}

void vx::device::refreshScreenOrientation() {
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;

    std::string func;
    if (getScreenAllowedOrientation() == "landscape") {
        func = "setLandscape";
    } else if (getScreenAllowedOrientation() == "portrait") {
        func = "setPortrait";
    } else {
        func = "setDefaultOrientation";
    }

    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Device",
                                                           func.c_str(),
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
