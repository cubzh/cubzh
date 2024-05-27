//
//  compat_android.cpp
//  xptools
//
//  Created by Gaetan de Villele on 04/03/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#include "compat_android.hpp"

// C++
#include <iostream>

namespace vx {
    namespace android {

        ///
        JNIEnv *jnienv = nullptr;

        ///
        AAssetManager *androidAssetManager = nullptr;

        /// android application storage path
        /// example : "/data/user/0/com.voxowl.particubes.android/files"
        std::string appStoragePath = "";

    }
}

///
JNIEnv *vx::android::getJNIEnv() {
    return vx::android::jnienv;
}

///
AAssetManager *vx::android::getAndroidAssetManager() {
    return vx::android::androidAssetManager;
}

/// must be called on android before the vx::fs functions are used
void vx::android::setAndroidAssetManager(JNIEnv *jni, jobject javaAssetManager) {
    // keep a reference on the JNIEnv
    vx::android::jnienv = jni;
    //
    AAssetManager *nativeAssetManager = AAssetManager_fromJava(jni, javaAssetManager);
    if (nativeAssetManager == nullptr) {
        std::cout << "🔥 failed to obtain native Android AssetManager" << std::endl;
        return;
    }
    vx::android::androidAssetManager = nativeAssetManager;
}

///
std::string vx::android::getAndroidStoragePath() {
    return vx::android::appStoragePath;
}

///
void vx::android::setAndroidStoragePath(std::string absPath) {
    vx::android::appStoragePath = absPath;
}