# 
# Cubzh Core
# 
# Unit Tests target
#  

cmake_minimum_required(VERSION 3.4.1)

project("Cubzh Core - Unit Tests")

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CUBZH_CORE_ROOT_DIR "${CMAKE_CURRENT_BINARY_DIR}/..")
set(CUBZH_CORE_TESTS_DIR "${CUBZH_CORE_ROOT_DIR}/tests")
set(CUBZH_CORE_DEPS_DIR "/deps")
set(SOURCE_FILES "")

# validate environment
if(NOT DEFINED ENV{DOCKER_TARGETPLATFORM})
    message(FATAL_ERROR "env var DOCKER_TARGETPLATFORM is not defined, CMake will exit.")
endif()

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
if($ENV{DOCKER_TARGETPLATFORM} STREQUAL "linux/amd64")
    set(LIBZ_PLATFORM_NAME "linux-ubuntu-x64")
elseif($ENV{DOCKER_TARGETPLATFORM} STREQUAL "linux/arm64")
    set(LIBZ_PLATFORM_NAME "linux-ubuntu-arm64")
else()
    message(FATAL_ERROR "env var DOCKER_TARGETPLATFORM contains unsupported platform name, CMake will exit.")
endif()
set(LIBZ_INC_DIR "${CUBZH_CORE_DEPS_DIR}/libz/${LIBZ_PLATFORM_NAME}/include")
set(LIBZ_LIB_DIR "${CUBZH_CORE_DEPS_DIR}/libz/${LIBZ_PLATFORM_NAME}/libs")
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

target_link_libraries(unit_tests
    ${LIBZ}
    m # libm (math)
)