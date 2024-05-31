//
//  compat_android.hpp
//  xptools
//
//  Created by Gaetan de Villele on 04/03/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#ifndef compat_android_hpp
#define compat_android_hpp

// C++
#include <string>

// jni
#include <jni.h>

// android
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>

namespace vx {
namespace android {

///
JNIEnv *getJNIEnv();

///
AAssetManager *getAndroidAssetManager();

/// must be called on android before the vx::fs functions are used
void setAndroidAssetManager(JNIEnv *jni, jobject asset_manager);

///
std::string getAndroidStoragePath();

///
void setAndroidStoragePath(std::string absPath);

}
}

#endif /* compat_android_hpp */
