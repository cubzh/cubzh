# WORKSPACE

# --------------------
# Android NDK
# --------------------

# Import and load Android NDK rules
RULES_ANDROID_NDK_COMMIT= "1ed5be3498d20c8120417fe73b6a5f2b4a3438cc"
RULES_ANDROID_NDK_SHA = "f238b4b0323f1e0028a4a3f1093574d70f087867f4b29626469a11eaaf9fd63f"

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
http_archive(
    name = "rules_android_ndk",
    url = "https://github.com/bazelbuild/rules_android_ndk/archive/%s.zip" % RULES_ANDROID_NDK_COMMIT,
    sha256 = RULES_ANDROID_NDK_SHA,
    strip_prefix = "rules_android_ndk-%s" % RULES_ANDROID_NDK_COMMIT,
)
load("@rules_android_ndk//:rules.bzl", "android_ndk_repository")

android_ndk_repository(
    name = "androidndk",
    path = "/Users/gaetan/Library/Android/sdk/ndk/27.0.11718014",
    # This is the target API level (for which we build the Android app & deps).
    # We suppose it should be equal to "minSdk" value in `build.gradle` file.
    api_level = 24, # 24 is Android 7.0 (Nougat)
)

register_toolchains("@androidndk//:all")

# --------------------
# Android SDK
# --------------------

android_sdk_repository(
    name = "androidsdk",
    path = "/Users/gaetan/Library/Android/sdk",
    api_level = 34,
    build_tools_version = "34.0.0",
)
