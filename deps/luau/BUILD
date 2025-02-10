
# ----------------------------------------
# Compiler-specific compiler flags
# ----------------------------------------

CLANG_COPTS = [
    "-std=c++17",
]

MSVC_COPTS = [
    "/std:c++17",
]

# TODO: if possible, select on the compiler instead of the platform
#       (or use the same compiler everywhere)
COMPILER_COPTS = select({
    "@platforms//os:windows": MSVC_COPTS,
    "//conditions:default": CLANG_COPTS,
})

# ----------------------------------------
# Platform-specific compiler flags
# ----------------------------------------

ANDROID_COPTS = [
    "-Wno-string-conversion",
]

PLATFORM_COPTS = select({
    "@platforms//os:android": ANDROID_COPTS,
    "//conditions:default": [],
})

COPTS = COMPILER_COPTS + PLATFORM_COPTS

# luau (static library)

cc_static_library(
    name = "luau",
    deps = [
        ":Luau.Analysis",
        ":Luau.Ast",
        # ":Luau.CLI.lib",
        ":Luau.CodeGen",
        ":Luau.Compiler",
        ":Luau.Config",
        ":Luau.EqSat",
        ":Luau.VM",
    ],
    visibility = ["//visibility:public"],
)

# Luau.Common (only headers)

cc_library(
    name = "Luau.Common",
    includes = ["src/Common/include"],
    hdrs = glob(["src/Common/include/Luau/*.h"]),
    visibility = ["//visibility:public"],
    copts = COPTS,
)

# Luau.CLI.lib

cc_library(
    name = "Luau.CLI.lib",
    srcs = glob(["src/CLI/src/*.cpp"]),
    includes = ["src/CLI/include"],
    hdrs = glob(["src/CLI/include/Luau/*.h"]),
    deps = [
        ":Luau.Analysis",
        ":Luau.CodeGen",
        ":Luau.Compiler",
        ":Luau.Config",
        ":Luau.VM",
        ":isocline",
    ],
    visibility = ["//visibility:public"],
    copts = COPTS,
)

# Luau.Ast

cc_library(
    name = "Luau.Ast",
    srcs = glob(["src/Ast/src/*.cpp"]),
    includes = ["src/Ast/include"],
    hdrs = glob(["src/Ast/include/Luau/*.h"]),
    deps = [":Luau.Common"],
    visibility = ["//visibility:public"],
    copts = COPTS,
)

# Luau.Compiler

cc_library(
    name = "Luau.Compiler",
    srcs = glob([
        "src/Compiler/src/*.cpp",
        "src/Compiler/src/*.h",
    ]),
    includes = ["src/Compiler/include"],
    hdrs = glob([
        "src/Compiler/include/*.h",
        "src/Compiler/include/Luau/*.h",
    ]),
    deps = [":Luau.Ast"],
    visibility = ["//visibility:public"],
    copts = COPTS,
)

# Luau.Config

cc_library(
    name = "Luau.Config",
    srcs = glob(["src/Config/src/*.cpp"]),
    includes = ["src/Config/include"],
    hdrs = glob(["src/Config/include/Luau/*.h"]),
    deps = [":Luau.Ast"],
    visibility = ["//visibility:public"],
    copts = COPTS,
)

# Luau.Analysis

cc_library(
    name = "Luau.Analysis",
    srcs = glob([
        "src/Analysis/src/*.cpp",
        "src/Analysis/src/*.h",
    ]),
    includes = ["src/Analysis/include"],
    hdrs = glob(["src/Analysis/include/Luau/*.h"]),
    deps = [
        ":Luau.Ast", 
        ":Luau.Common", 
        ":Luau.Compiler", 
        ":Luau.Config", 
        ":Luau.EqSat", 
        ":Luau.VM",
    ],
    visibility = ["//visibility:public"],
    copts = COPTS,
)

# Luau.EqSat

cc_library(
    name = "Luau.EqSat",
    srcs = glob(["src/EqSat/src/*.cpp"]),
    includes = ["src/EqSat/include"],
    hdrs = glob(["src/EqSat/include/Luau/*.h"]),
    deps = [":Luau.Common"],
    visibility = ["//visibility:public"],
    copts = COPTS,
)

# Luau.CodeGen

cc_library(
    name = "Luau.CodeGen",
    srcs = glob([
        "src/CodeGen/src/*.cpp",
        "src/CodeGen/src/*.h",
    ]),
    includes = ["src/CodeGen/include"],
    hdrs = glob([
        "src/CodeGen/include/*.h",
        "src/CodeGen/include/Luau/*.h",
    ]),
    deps = [
        ":Luau.Common",
        ":Luau.VM",
        ":Luau.VM.Internals",
    ],
    visibility = ["//visibility:public"],
    linkstatic = select({
        "@platforms//os:android": True,
        "//conditions:default": False,
    }),
    copts = COPTS,
)

# Luau.VM

cc_library(
    name = "Luau.VM",
    srcs = glob([
        "src/VM/src/*.cpp",
        "src/VM/src/*.h",
    ]),
    includes = ["src/VM/include"],
    hdrs = glob(["src/VM/include/*.h"]),
    deps = [":Luau.Common"],
    visibility = ["//visibility:public"],
    copts = COPTS,
)

# Luau.VM.Internals - expose private headers

cc_library(
    name = "Luau.VM.Internals",
    hdrs = glob(["src/VM/src/*.h"]),  # All internal VM headers
    includes = ["src/VM/src"],         # Make them available from VM/src
    visibility = [":__subpackages__"], # Restrict visibility to just what needs it
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
    includes = [
        "src/extern/isocline/include",
        "src/extern/isocline/src",
    ],
    hdrs = [
        "src/extern/isocline/include/isocline.h",
    ] + glob([
        "src/extern/isocline/src/*.h",
    ]) + isocline_included_c_files,
    # copts = [
    #     "-include stdint.h",
    #     "-include stdbool.h",
    # ],
)
