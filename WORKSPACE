# WORKSPACE

# --------------------
# Global imports
# --------------------

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# --------------------
# Android SDK & NDK
# --------------------

android_sdk_repository(
    name = "androidsdk",
    api_level = 34,
    build_tools_version = "34.0.0",
)

# Import and load new Android NDK rules (for recent NDK versions).
# Built-in rules are not compatible with NDK r22 and later.
RULES_ANDROID_NDK_COMMIT = "1ed5be3498d20c8120417fe73b6a5f2b4a3438cc"
RULES_ANDROID_NDK_SHA = "f238b4b0323f1e0028a4a3f1093574d70f087867f4b29626469a11eaaf9fd63f"

http_archive(
    name = "rules_android_ndk",
    url = "https://github.com/bazelbuild/rules_android_ndk/archive/%s.zip" % RULES_ANDROID_NDK_COMMIT,
    sha256 = RULES_ANDROID_NDK_SHA,
    strip_prefix = "rules_android_ndk-%s" % RULES_ANDROID_NDK_COMMIT,
)
load("@rules_android_ndk//:rules.bzl", "android_ndk_repository")

android_ndk_repository(
    name = "androidndk",
    # This is the target API level (for which we build the Android app & deps).
    # We suppose it should be equal to "minSdk" value in `build.gradle` file.
    api_level = 24, # 24 is Android 7.0 (Nougat)
)

# This fails if Android SDK/NDK are not installed.
# register_toolchains("@androidndk//:all")

# --------------------
# WASM
# --------------------

RULES_EMSDK_COMMIT = "0329dbaa2593dcb6604caf38893f276b06cc04ef"
RULES_EMSDK_SHA = "7d1825e545d5d98ab6e46317cc55ab85cfa8a5593e9397a71681dd16c27efefd"
RULES_EM_VERSION = "3.1.38"

http_archive(
    name = "emsdk",
    url = "https://github.com/emscripten-core/emsdk/archive/%s.tar.gz" % RULES_EMSDK_COMMIT,
    sha256 = RULES_EMSDK_SHA,
    strip_prefix = "emsdk-%s/bazel" % RULES_EMSDK_COMMIT,
)

load("@emsdk//:deps.bzl", emsdk_deps = "deps")
emsdk_deps()

load("@emsdk//:emscripten_deps.bzl", emsdk_emscripten_deps = "emscripten_deps")
emsdk_emscripten_deps(emscripten_version = RULES_EM_VERSION)

load("@emsdk//:toolchains.bzl", "register_emscripten_toolchains")
register_emscripten_toolchains()

# --------------------
# Linux toolchain
# --------------------

# http_archive(
#     name = "aspect_gcc_toolchain",
#     sha256 = "3341394b1376fb96a87ac3ca01c582f7f18e7dc5e16e8cf40880a31dd7ac0e1e",
#     strip_prefix = "gcc-toolchain-0.4.2",
#     urls = [
#         "https://github.com/aspect-build/gcc-toolchain/archive/refs/tags/0.4.2.tar.gz",
#     ],
# )

# load("@aspect_gcc_toolchain//toolchain:repositories.bzl", "gcc_toolchain_dependencies")

# gcc_toolchain_dependencies()

# load("@aspect_gcc_toolchain//toolchain:defs.bzl", "gcc_register_toolchain", "ARCHS")

# gcc_register_toolchain(
#     name = "gcc_toolchain_x86_64",
#     target_arch = ARCHS.x86_64,
# )
