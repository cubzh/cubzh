//
// Created by Gaetan de Villele on 02/04/2020.
//

#include "JNIUtils.hpp"

// android NDK
#include <android/log.h>

#pragma mark - functions to be called from Java -

extern "C" {

/**
 * com.voxowl.tools.Manager
 * @param jni
 * @param thiz
 * @param bundleClassLoader
 */
JNIEXPORT void JNICALL Java_com_voxowl_particubes_android_MainActivity_sendAppClassLoaderToC(JNIEnv *jni, jobject thiz, jobject bundleClassLoader) {
    vx::tools::JNIUtils::getInstance()->setBundleClassLoader(jni->NewGlobalRef(bundleClassLoader));
}

}

namespace vx {

    namespace tools {

        namespace string {

            std::string convertJNIStringToCPPString(JNIEnv * const env, jstring jniString) {
                if (jniString == nullptr) {
                    return "";
                }
                // convert JNI string into C++ string
                std::string result = "";
                const char* utfChars = env->GetStringUTFChars(jniString, nullptr);
                if (utfChars != nullptr) {
                    result.assign(utfChars);
                    // Release the JNI string
                    env->ReleaseStringUTFChars(jniString, utfChars);
                }
                return result;
            }
            
        } // namespace string

#pragma mark - static -

        JNIUtils* JNIUtils::instance = nullptr;

        JNIUtils* JNIUtils::getInstance() {
            if (JNIUtils::instance == nullptr) {
                JNIUtils::instance = new JNIUtils();
            }
            return JNIUtils::instance;
        }



#pragma mark - constructor / destructor -

        JNIUtils::JNIUtils() :
            _java_vm(nullptr),
            _bundle_class_loader(nullptr) {
        }

        JNIUtils::~JNIUtils() {
        }



#pragma mark - public methods -

        const bool JNIUtils::getMethodInfo(bool* just_attached, JniMethodInfo* method_info,
                                           const char* class_name, const char* method_name, const char* param_code)
        {
            // get valid JNIEnv pointer
            JavaVM* vm  = this->getJavaVM();
            JNIEnv* jni = nullptr;
            *just_attached = false;

            jint result = vm->GetEnv((void**)&jni, JNI_VERSION_1_4);
            if(result == JNI_EVERSION)
            {
                // JNI version 1.4 is not supported on this device
                __android_log_print(ANDROID_LOG_ERROR, "Cubzh", "[attachThreadToJavaVmIfNeeded] JNI V1.4 IS NOT SUPPORTED");
                // we crash the game!
                int* i = nullptr;
                int j = *i;
            }
            else if(result == JNI_EDETACHED)
            {
                // current thread is NOT attached to Java VM
                __android_log_print(ANDROID_LOG_VERBOSE, "Cubzh", "[attachThreadToJavaVmIfNeeded] current thread is not attached to JavaVM, we attach it !");
                // we attach the
                vm->AttachCurrentThread(&jni, nullptr);
                *just_attached = true;
            }
            else
            {
                // current thread is ALREADY attached to Java VM
                __android_log_print(ANDROID_LOG_VERBOSE, "Cubzh", "[attachThreadToJavaVmIfNeeded] current thread is already attached to JavaVM, we just return the JNIEnv pointer : %d", result);
                // thread is already attached : we do nothing :)
            }

            // get JNI Method ID
            jmethodID methodID = 0;
            bool ret = false;
            do
            {
                if (*just_attached)
                {
                    // ClassLoader
                    jclass      ClassLoader_class = jni->FindClass("java/lang/ClassLoader");
                    jmethodID   ClassLoader_findClass = jni->GetMethodID(ClassLoader_class, "findClass", "(Ljava/lang/String;)Ljava/lang/Class;");

                    jstring     str_classname   = jni->NewStringUTF(class_name);
                    jclass      myjavaclass     = (jclass) jni->CallObjectMethod(this->getBundleClassLoader(), ClassLoader_findClass, str_classname);
                    jmethodID   myjavamethod    = jni->GetStaticMethodID(myjavaclass, method_name, param_code);

                    method_info->classID = myjavaclass;
                    method_info->env = jni;
                    method_info->methodID = myjavamethod;

                    jni->DeleteLocalRef(ClassLoader_class);
                    jni->DeleteLocalRef(str_classname);
                }
                else
                {
                    jclass classID = jni->FindClass(class_name);
                    if(!classID)
                    {
                        __android_log_print(ANDROID_LOG_ERROR, "Cubzh", "Failed to find class of %s", class_name);
                        // LOG("Failed to find class of %s", class_name);
                        break;
                    }
                    methodID = jni->GetStaticMethodID(classID, method_name, param_code);
                    if (!methodID)
                    {
                        __android_log_print(ANDROID_LOG_ERROR, "Cubzh", "Failed to find static method id of %s", method_name);
                        // LOG("Failed to find static method id of %s", method_name);
                        break;
                    }
                    method_info->classID = classID;
                    method_info->env = jni;
                    method_info->methodID = methodID;
                }
                ret = true;
            }
            while (0);

            return ret;
        }

        jbyteArray JNIUtils::createJByteArrayFromCString(JNIEnv * const env, const char* str) {
            const size_t strLen = strlen(str);

            // Create a new jbyteArray
            jbyteArray byteArray = env->NewByteArray(strLen);
            if (byteArray == nullptr) {
                // Error handling if NewByteArray fails
                __android_log_print(ANDROID_LOG_ERROR, "Cubzh", "\"Failed to create jbyteArray");
                return nullptr;
            }

            // Set the data to the jbyteArray
            env->SetByteArrayRegion(byteArray, 0, strLen, (jbyte*)str);

            return byteArray;
        }

#pragma mark - accessors -

        JavaVM* JNIUtils::getJavaVM() const {
            return _java_vm;
        }

        jobject JNIUtils::getBundleClassLoader() const {
            return _bundle_class_loader;
        }



#pragma mark - modifiers -

        void JNIUtils::setJavaVM(JavaVM* java_vm) {
            __android_log_print(ANDROID_LOG_INFO, "Cubzh", "[JNIUtils::setJavaVM] %p", java_vm);
            _java_vm = java_vm;
        }

        void JNIUtils::setBundleClassLoader(jobject bundle_class_loader) {
            __android_log_print(ANDROID_LOG_INFO, "Cubzh", "[JNIUtils::setBundleClassLoader] %p", bundle_class_loader);
            _bundle_class_loader = bundle_class_loader;
        }

    }
}
