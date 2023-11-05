#
# Cubzh CLI
#

# cmake_minimum_required(VERSION 3.19.8)
cmake_minimum_required(VERSION 3.10.2)

project("Cubzh CLI" VERSION 0.1
                    DESCRIPTION "Cubzh CLI"
                    LANGUAGES C CXX)

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
# message("CZH_ROOT_DIR: " ${CZH_ROOT_DIR})
set(CZH_ROOT_DIR "/cubzh")
if (NOT EXISTS ${CZH_ROOT_DIR})
    file(REAL_PATH "../.." CZH_ROOT_DIR) # relative to ${CMAKE_CURRENT_SOURCE_DIR}
endif()

# CZH_CORE_DIR: core directory
# file(REAL_PATH "./core" CZH_CORE_DIR BASE_DIRECTORY ${CZH_ROOT_DIR})
# message("CZH_CORE_DIR: " ${CZH_CORE_DIR})
set(CZH_CORE_DIR "${CZH_ROOT_DIR}/core")

# CZH_CLI_DIR: cli directory
# file(REAL_PATH "./cli" CZH_CLI_DIR BASE_DIRECTORY ${CZH_ROOT_DIR})
# message("CZH_CLI_DIR: " ${CZH_CLI_DIR})
set(CZH_CLI_DIR "${CZH_ROOT_DIR}/cli")

# CZH_DEPS_CXXOPTS_INC: cxxopts include directory
# file(REAL_PATH "./deps/cxxopts/include" CZH_DEPS_CXXOPTS_INC BASE_DIRECTORY ${CZH_ROOT_DIR})
set(CZH_DEPS_CXXOPTS_INC "${CZH_ROOT_DIR}/deps/cxxopts/include")



# --------------------------------------------------
# Deps : zlib
# --------------------------------------------------
# CZH_DEPS_LIBZ: libz directory for target system/arch
# file(REAL_PATH "./deps/libz/${CZH_SYSTEM}-${CZH_ARCH}" CZH_DEPS_LIBZ BASE_DIRECTORY ${CZH_ROOT_DIR})
# file(REAL_PATH "./include" CZH_DEPS_LIBZ_INC BASE_DIRECTORY ${CZH_DEPS_LIBZ})
# file(REAL_PATH "./lib" CZH_DEPS_LIBZ_LIB BASE_DIRECTORY ${CZH_DEPS_LIBZ})
set(CZH_DEPS_LIBZ "${CZH_ROOT_DIR}/deps/libz/linux-debian-x64")
set(CZH_DEPS_LIBZ_INC "${CZH_DEPS_LIBZ}/include")
set(CZH_DEPS_LIBZ_LIB "${CZH_DEPS_LIBZ}/lib")
message("CZH_DEPS_LIBZ_INC: " ${CZH_DEPS_LIBZ_INC})
message("CZH_DEPS_LIBZ_LIB: " ${CZH_DEPS_LIBZ_LIB})
add_library(cubzh_deps_libz STATIC IMPORTED)
set_target_properties(cubzh_deps_libz PROPERTIES IMPORTED_LOCATION ${CZH_DEPS_LIBZ_LIB}/libz.a)
# target_include_directories(cubzh_deps_libz INTERFACE ${CZH_DEPS_LIBZ_INC}) # needed ?


include_directories(${CZH_DEPS_LIBZ_INC})
link_directories(${CZH_DEPS_LIBZ_LIB})

# --------------------------------------------------
# Cubzh Core library
# --------------------------------------------------
# List header files
file(GLOB CZH_CORE_HEADERS CONFIGURE_DEPENDS ${CZH_CORE_DIR}/*.h)

# List source files
file(GLOB CZH_CORE_SOURCES CONFIGURE_DEPENDS ${CZH_CORE_DIR}/*.c)

# Define target
add_library(cubzh_core STATIC ${CZH_CORE_HEADERS} ${CZH_CORE_SOURCES})
target_include_directories(cubzh_core INTERFACE ${CZH_CORE_DIR} ${CZH_DEPS_LIBZ_INC})
target_link_libraries(cubzh_core PRIVATE cubzh_deps_libz)



# --------------------------------------------------
# Cubzh CLI executable
# --------------------------------------------------
# List header files
file(GLOB CZH_CLI_HEADERS CONFIGURE_DEPENDS ${CZH_CLI_DIR}/*.hpp)

# List source files
file(GLOB CZH_CLI_SOURCES CONFIGURE_DEPENDS ${CZH_CLI_DIR}/*.cpp)

add_executable(cubzh_cli ${CZH_CLI_HEADERS} ${CZH_CLI_SOURCES})
set_target_properties(cubzh_cli PROPERTIES
                      CXX_STANDARD_REQUIRED ON
                      CXX_STANDARD 11)
target_include_directories(cubzh_cli PRIVATE ${CZH_DEPS_CXXOPTS_INC} ${CZH_DEPS_LIBZ_INC})
target_link_libraries(cubzh_cli PRIVATE cubzh_core)



# --------------------------------------------------
# Notes
# --------------------------------------------------

# TODO: 
# - support cross-compilation

# define compilers
# set(CMAKE_C_COMPILER "clang")
# set(CMAKE_CXX_COMPILER "clang++")
# Note:
# By default, it searches for a list of known compiler names:
# cc, gcc, cl, bcc, xlc, clang
# In that order, in PATH.
# If you set the CC (or CXX respectively) environment variable, it will use this 
# compiler. This is the recommended way how to point cmake to a specific 
# compiler.

# set(CMAKE_COMPILE_WARNING_AS_ERROR ON) # not available yet (v3.25 ?)

# retrieve values from environment
# if(NOT DEFINED ENV{CUBZH_ARCH})
#     message(FATAL_ERROR "env var CUBZH_ARCH is not defined, CMake will exit.")
# endif()
