load(
    "@rules_apple//apple:apple.bzl",
    "apple_static_library",
)
load("@rules_cc//cc:defs.bzl", "cc_library")

# ----------------------------------------
# Compiler-specific compiler flags
# ----------------------------------------

CLANG_COPTS = [
    "-std=c++17",
    "-fPIC", # Position Independent Code
]

MSVC_COPTS = [
    "/std:c++17",
]

# Updated compiler selection based on OS
# TODO: filter on toolchain (if possible)
COMPILER_COPTS = select({
    "@platforms//os:windows": MSVC_COPTS,
    "//conditions:default": CLANG_COPTS,
})

# ----------------------------------------
# Platform-specific compiler flags
# ----------------------------------------

PLATFORM_COPTS = select({
    "@platforms//os:android": ["-Wno-string-conversion"],
    "//conditions:default": [],
})

COPTS = COMPILER_COPTS + PLATFORM_COPTS

# ----------------------------------------
# Targets
# ----------------------------------------

# luau (static library)

alias(
    name = "luau",
    actual = select({
        "@platforms//os:macos": ":luau-macos",
        "//conditions:default": ":luau-default",
    }),
)

luau_static_library_deps = [
    ":Luau.Analysis",
    ":Luau.Ast",
    # ":Luau.CLI.lib",
    ":Luau.CodeGen",
    ":Luau.Compiler",
    ":Luau.Config",
    ":Luau.EqSat",
    ":Luau.VM",
]

apple_static_library(
    name = "luau-macos",
    minimum_os_version = "11.0",
    platform_type = "macos",
    deps = luau_static_library_deps,
)

cc_static_library(
    name = "luau-default",
    deps = luau_static_library_deps,
)

# Luau.Common (only headers)

cc_library(
    name = "Luau.Common",
    hdrs = glob(["src/Common/include/Luau/*.h"]),
    copts = COPTS,
    includes = ["src/Common/include"],
    visibility = ["//visibility:public"],
)

# Luau.CLI.lib

cc_library(
    name = "Luau.CLI.lib",
    srcs = glob(["src/CLI/src/*.cpp"]),
    hdrs = glob(["src/CLI/include/Luau/*.h"]),
    copts = COPTS,
    includes = ["src/CLI/include"],
    visibility = ["//visibility:public"],
    deps = [
        ":Luau.Analysis",
        ":Luau.CodeGen",
        ":Luau.Compiler",
        ":Luau.Config",
        ":Luau.VM",
        ":isocline",
    ],
)

# Luau.Ast

cc_library(
    name = "Luau.Ast",
    srcs = glob(["src/Ast/src/*.cpp"]),
    hdrs = glob(["src/Ast/include/Luau/*.h"]),
    copts = COPTS,
    includes = ["src/Ast/include"],
    visibility = ["//visibility:public"],
    deps = [":Luau.Common"],
)

# Luau.Compiler

cc_library(
    name = "Luau.Compiler",
    srcs = glob([
        "src/Compiler/src/*.cpp",
        "src/Compiler/src/*.h",
    ]),
    hdrs = glob([
        "src/Compiler/include/*.h",
        "src/Compiler/include/Luau/*.h",
    ]),
    copts = COPTS,
    includes = ["src/Compiler/include"],
    visibility = ["//visibility:public"],
    deps = [":Luau.Ast"],
)

# Luau.Config

cc_library(
    name = "Luau.Config",
    srcs = glob(["src/Config/src/*.cpp"]),
    hdrs = glob(["src/Config/include/Luau/*.h"]),
    copts = COPTS,
    includes = ["src/Config/include"],
    visibility = ["//visibility:public"],
    deps = [":Luau.Ast"],
)

# Luau.Analysis

cc_library(
    name = "Luau.Analysis",
    srcs = glob([
        "src/Analysis/src/*.cpp",
        "src/Analysis/src/*.h",
    ]),
    hdrs = glob(["src/Analysis/include/Luau/*.h"]),
    copts = COPTS,
    includes = ["src/Analysis/include"],
    visibility = ["//visibility:public"],
    deps = [
        ":Luau.Ast",
        ":Luau.Common",
        ":Luau.Compiler",
        ":Luau.Config",
        ":Luau.EqSat",
        ":Luau.VM",
    ],
)

# Luau.EqSat

cc_library(
    name = "Luau.EqSat",
    srcs = glob(["src/EqSat/src/*.cpp"]),
    hdrs = glob(["src/EqSat/include/Luau/*.h"]),
    copts = COPTS,
    includes = ["src/EqSat/include"],
    visibility = ["//visibility:public"],
    deps = [":Luau.Common"],
)

# Luau.CodeGen

cc_library(
    name = "Luau.CodeGen",
    srcs = glob([
        "src/CodeGen/src/*.cpp",
        "src/CodeGen/src/*.h",
    ]),
    hdrs = glob([
        "src/CodeGen/include/*.h",
        "src/CodeGen/include/Luau/*.h",
    ]),
    copts = COPTS,
    includes = ["src/CodeGen/include"],
    linkstatic = select({
        "@platforms//os:android": True,
        "//conditions:default": False,
    }),
    visibility = ["//visibility:public"],
    deps = [
        ":Luau.Common",
        ":Luau.VM",
        ":Luau.VM.Internals",
    ],
)

# Luau.VM

cc_library(
    name = "Luau.VM",
    srcs = glob([
        "src/VM/src/*.cpp",
        "src/VM/src/*.h",
    ]),
    hdrs = glob(["src/VM/include/*.h"]),
    copts = COPTS,
    includes = ["src/VM/include"],
    visibility = ["//visibility:public"],
    deps = [":Luau.Common"],
)

# Luau.VM.Internals - expose private headers

cc_library(
    name = "Luau.VM.Internals",
    hdrs = glob(["src/VM/src/*.h"]),  # All internal VM headers
    includes = ["src/VM/src"],  # Make them available from VM/src
    visibility = [":__subpackages__"],  # Restrict visibility to just what needs it
)

# ----------------------------------------
# isocline
# ----------------------------------------

isocline_included_c_files = [
    "src/extern/isocline/src/editline_help.c",
    "src/extern/isocline/src/bbcode_colors.c",
    "src/extern/isocline/src/term_color.c",
    "src/extern/isocline/src/editline_history.c",
    "src/extern/isocline/src/editline_completion.c",
    "src/extern/isocline/src/wcwidth.c",
    "src/extern/isocline/src/attr.c",
    "src/extern/isocline/src/bbcode.c",
    "src/extern/isocline/src/editline.c",
    "src/extern/isocline/src/highlight.c",
    "src/extern/isocline/src/undo.c",
    "src/extern/isocline/src/history.c",
    "src/extern/isocline/src/completers.c",
    "src/extern/isocline/src/completions.c",
    "src/extern/isocline/src/term.c",
    "src/extern/isocline/src/tty_esc.c",
    "src/extern/isocline/src/tty.c",
    "src/extern/isocline/src/stringbuf.c",
    "src/extern/isocline/src/common.c",
]

cc_library(
    name = "isocline",
    srcs = glob(
        [
            "src/extern/isocline/src/*.c",
            "src/extern/isocline/src/*.h",
        ],
        # don't compile C files that are already included in other C files
        exclude = isocline_included_c_files,
    ),
    hdrs = [
        "src/extern/isocline/include/isocline.h",
    ] + glob([
        "src/extern/isocline/src/*.h",
    ]) + isocline_included_c_files,
    includes = [
        "src/extern/isocline/include",
        "src/extern/isocline/src",
    ],
    # copts = [
    #     "-include stdint.h",
    #     "-include stdbool.h",
    # ],
)
