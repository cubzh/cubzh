
#include "web.hpp"

// C++
#include <cassert>

// android
#include <android/log.h>

// xptools
#include "JNIUtils.hpp"

void _open(const std::string &url, bool modal) {
    __android_log_print(ANDROID_LOG_DEBUG, "Particubes", "[vx::Web::open]");
    
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;
    
    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached, &methodInfo,
                                                           "com/voxowl/tools/Web",
                                                           modal ? "openModal" : "open",
                                                           "(Ljava/lang/String;)V"))
    {
        __android_log_print(ANDROID_LOG_ERROR, "Particubes", "%s %d: error to get methodInfo", __FILE__, __LINE__);
        assert(false); // crash the program
    }
    
    jstring j_filename = methodInfo.env->NewStringUTF(url.c_str());
    
    methodInfo.env->CallStaticVoidMethod(methodInfo.classID, methodInfo.methodID, j_filename);
    
    methodInfo.env->DeleteLocalRef(methodInfo.classID);
    methodInfo.env->DeleteLocalRef(j_filename);
    
    if (just_attached) {
        vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
    }
}

void vx::Web::openModal(const std::string &url) {
    _open(url, true);
}

void vx::Web::open(const std::string &url) {
    _open(url, false);
}
