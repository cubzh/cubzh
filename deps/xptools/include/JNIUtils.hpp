//
// Created by Gaetan de Villele on 02/04/2020.
//

#pragma once

// C++
#include <string>

// android NDK
#include <jni.h>
// #include <android/asset_manager_jni.h>
// #include <android/asset_manager.h>

#pragma mark - functions to be called from Java -

extern "C" {
    /**
     *
     * @param jni
     * @param thiz
     * @param bundleClassLoader
     */
    JNIEXPORT void JNICALL Java_com_voxowl_particubes_android_MainActivity_sendAppClassLoaderToC(JNIEnv *jni, jobject thiz, jobject bundleClassLoader);
}

namespace vx
{
    namespace tools
    {
        typedef struct JniMethodInfo_
        {
            JNIEnv*   env;
            jclass    classID;
            jmethodID methodID;
        } JniMethodInfo;

        class JNIUtils
        {

        public:

            static JNIUtils* getInstance();

            virtual ~JNIUtils();

#pragma mark - public methods -

            const bool getMethodInfo(bool* just_attached, JniMethodInfo* method_info,
                                     const char* class_name, const char* method_name, const char* param_code);

            jbyteArray createJByteArrayFromCString(JNIEnv * const env, const char* str);

#pragma mark - accessors -

            JavaVM* getJavaVM() const;
            jobject getBundleClassLoader() const;

#pragma mark - modifiers -

            void setJavaVM(JavaVM* java_vm);
            void setBundleClassLoader(jobject bundle_class_loader);

        private:

            static JNIUtils* instance;

            JNIUtils();

            JavaVM *_java_vm;

            // reference on the Java ClassLoader
            jobject _bundle_class_loader;
        };

        namespace string {

            /// @brief Converts a Java string (jstring) into C++ string (std::string)
            /// @param env JNI environment
            /// @param jniString Java string to convert
            /// @return C++ string corresponding to the Java string
            std::string convertJNIStringToCPPString(JNIEnv * const env, jstring jniString);

        }
    }
}
