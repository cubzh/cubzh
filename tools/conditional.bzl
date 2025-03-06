
# def _android_nullable_toolchain_impl(repository_ctx):
#     if repository_ctx.os == "android":
#         print("REGISTERING ANDROID TOOLCHAIN !!!")
#         return "@androidndk//:all"
#     else:
#         print("NOT REGISTERING ANDROID TOOLCHAIN...")
#         return None

# android_nullable_toolchain = repository_rule(
#     implementation=_android_nullable_toolchain_impl,
# )

# def _register_toolchains_impl(repository_ctx):
#     print("Detected OS: ", repository_ctx.os)
#     # Check for Android environment using environment variables
#     result = repository_ctx.execute(["bash", "-c", "test -n \"$ANDROID_HOME\" && echo true || echo false"], quiet=True)
#     is_android = result.stdout.strip() == "true"
#     print("IS ANDROID: ", is_android)
#     # if repository_ctx.os == "android":
#     if is_android:
#         repository_ctx.execute(["register_toolchains", "@androidndk//:all"])
#         # Here you would include your actual toolchain registration logic
#         repository_ctx.file("BUILD.bazel", """
#         filegroup(
#             name = "dummy_target",
#             srcs = [],
#         )
#         """)
#     else:
#         repository_ctx.file("BUILD.bazel", """
#         filegroup(
#             name = "dummy_target",
#             srcs = [],
#         )
#         """)

    # repository_ctx.execute(["echo", "Not an Android platform, skipping Android toolchain registration"])
    # if repository_ctx.os == "android":
    #     print("Registering Android toolchains")
    #     repository_ctx.execute(["echo", "Registering Android toolchains"])
    #     # Register your Android toolchains here
    #     repository_ctx.execute(["register_toolchains", "@androidndk//:all"])
    # else:
    #     print("Not an Android platform, skipping Android toolchain registration")
    #     repository_ctx.execute(["echo", "Not an Android platform, skipping Android toolchain registration"])


register_toolchains_if_android = repository_rule(
    implementation = _register_toolchains_impl,
    local = True,
)

# def register_toolchains_if_macos(repository_ctx, arg):
    # if repository_ctx.os == "darwin":
        # register_toolchains(arg)
        # repository_ctx.file(
        #     "macos_toolchain.BUILD",
        #     """
        #     load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cc_toolchain")

        #     cc_toolchain_alias(
        #         name = "current_cc_toolchain",
        #         toolchain = find_cc_toolchain(),
        #     )
        #     """
        # )
        # repository_ctx.symlink(
        #     name = "my_macos_toolchain",
        #     target = repository_ctx.path(repository_ctx.attr.macos_toolchain_path)
        # )

# # Define the condition for macOS
# config_setting(
#     name = "is_macos",
#     values = {"host_os": "darwin"},
# )

# # Define the condition for non-macOS (for completeness)
# config_setting(
#     name = "is_not_macos",
#     values = {"host_os": "linux"},  # adjust this for other OS if needed
# )

# # ------------------------------
# # Toolchains
# # ------------------------------

# toolchain(
#     name = "linux_toolchain",
#     toolchain_type = "//my_toolchains:toolchain_type",
#     toolchain = select({
#         "//:is_not_macos": "//my_toolchains:linux_toolchain_impl",
#         "//conditions:default": None,
#     }),
# )

# toolchain(
#     name = "macos_toolchain",
#     toolchain_type = "//my_toolchains:toolchain_type",
#     toolchain = select({
#         "//:is_macos": "//my_toolchains:macos_toolchain_impl",
#         "//conditions:default": None,
#     }),
# )

# def _register_toolchain_impl(repository_ctx):
#     print("REGISTERING TOOLCHAIN FOR OS     :", repository_ctx.os)
#     print("REGISTERING TOOLCHAIN FOR TARGET :", repository_ctx.target)
#     print("REGISTERING TOOLCHAIN FOR ARCH   :", repository_ctx.target_arch)

# vx_register_toolchain = repository_rule(
#     implementation = _register_toolchain_impl,
#     attrs = {
#         "macos_toolchain_path": attr.string(mandatory=True),
#     },
# )

# if repository_ctx.os == "darwin":
#     repository_ctx.file(
#         "macos_toolchain.BUILD",
#         """
#         load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cc_toolchain")

#         cc_toolchain_alias(
#             name = "current_cc_toolchain",
#             toolchain = find_cc_toolchain(),
#         )
#         """
#     )
#     repository_ctx.symlink(
#         name = "my_macos_toolchain",
#         target = repository_ctx.path(repository_ctx.attr.macos_toolchain_path)
#     )
