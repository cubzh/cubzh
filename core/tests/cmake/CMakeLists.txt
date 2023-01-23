# 
# Cubzh Core
# 
# Unit Tests target
#  

cmake_minimum_required(VERSION 3.4.1)

# define compilers
set(CMAKE_C_COMPILER "clang")
set(CMAKE_CXX_COMPILER "clang++")

project("Cubzh Core - Unit Tests")

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# set(CMAKE_COMPILE_WARNING_AS_ERROR ON) # not available yet

# --------------------------------------------------
# TARGET SYSTEM & ARCH
# --------------------------------------------------

# CZH_SYSTEM : "linux", "darwin", "windows", ...
string(TOLOWER ${CMAKE_SYSTEM_NAME} CZH_SYSTEM)
message("CZH_SYSTEM: " ${CZH_SYSTEM})

# CZH_ARCH : "arm64", ...
set(CZH_ARCH ${CMAKE_SYSTEM_PROCESSOR})
message("CZH_ARCH: " ${CZH_ARCH})

# --------------------------------------------------
# PATHS
# --------------------------------------------------

# CZH_ROOT_DIR: Git repo root directory
file(REAL_PATH "../../.." CZH_ROOT_DIR) # relative to ${CMAKE_CURRENT_SOURCE_DIR}
# message("CZH_ROOT_DIR: " ${CZH_ROOT_DIR})

# --------------------------------------------------
# Deps : zlib
# --------------------------------------------------
# CZH_DEPS_LIBZ: libz directory for target system/arch
file(REAL_PATH "./deps/libz/${CZH_SYSTEM}-${CZH_ARCH}" CZH_DEPS_LIBZ BASE_DIRECTORY ${CZH_ROOT_DIR})
file(REAL_PATH "./include" CZH_DEPS_LIBZ_INC BASE_DIRECTORY ${CZH_DEPS_LIBZ})
file(REAL_PATH "./lib" CZH_DEPS_LIBZ_LIB BASE_DIRECTORY ${CZH_DEPS_LIBZ})
message("CZH_DEPS_LIBZ_INC: " ${CZH_DEPS_LIBZ_INC})
message("CZH_DEPS_LIBZ_LIB: " ${CZH_DEPS_LIBZ_LIB})



set(CUBZH_CORE_TESTS_DIR "${CMAKE_CURRENT_BINARY_DIR}/..")
set(CUBZH_CORE_ROOT_DIR "${CUBZH_CORE_TESTS_DIR}/..")
set(CUBZH_DEPS_DIR "${CUBZH_CORE_ROOT_DIR}/../deps")
set(SOURCE_FILES "")

# cubzh core source files
file(GLOB CUBZH_CORE_SOURCES
    CONFIGURE_DEPENDS
    ${CUBZH_CORE_ROOT_DIR}/*.c)
set(SOURCE_FILES ${SOURCE_FILES} ${CUBZH_CORE_SOURCES})

# unit tests source files
file(GLOB CUBZH_CORE_TESTS_SOURCES
    CONFIGURE_DEPENDS
    ${CUBZH_CORE_TESTS_DIR}/*.c)
set(SOURCE_FILES ${SOURCE_FILES} ${CUBZH_CORE_TESTS_SOURCES})

# zlib
set(LIBZ_INC_DIR "${CZH_DEPS_LIBZ_INC}")
set(LIBZ_LIB_DIR "${CZH_DEPS_LIBZ_LIB}")
# pre-compiled lib
find_library(LIBZ z ${LIBZ_LIB_DIR})

# Compile options
add_compile_options(
    -DDEBUG
)

# Search paths
include_directories(
    ${LIBZ_INC_DIR}
    ${CUBZH_CORE_ROOT_DIR}
)

add_executable(unit_tests ${SOURCE_FILES})

# more info here: https://releases.llvm.org/14.0.0/tools/clang/docs/DiagnosticsReference.html
# -Werror: process warnings as errors
# -Wshadow: same variable created twice
# -Wdouble-promotion: avoid using a float as a double
# -Wundef: undefined macro
# -Wconversion: implicit casts
# -Wunused-parameter: to be avoided, useful in callbacks
# -Wshadow: warns of shadowed variables (same name in lower scope)
target_compile_options(unit_tests PRIVATE -Werror -Wall -Wshadow -Wdouble-promotion -Wundef -Wconversion -Wno-unused-parameter -Wno-shadow)

target_link_libraries(unit_tests
    ${LIBZ}
    m # libm (math)
)