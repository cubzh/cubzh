
cmake_minimum_required(VERSION 3.20)

set(VXTOOLS_DIR "${REPO_ROOT_DIR}/cubzh/deps/xptools")
set(VXTOOLS_DEPS_DIR "${VXTOOLS_DIR}/deps")
set(VXTOOLS_INCLUDE_DIR "${VXTOOLS_DIR}/include")
set(VXTOOLS_COMMON_DIR "${VXTOOLS_DIR}/common")
set(VXTOOLS_WEB_DIR "${VXTOOLS_DIR}/web")

file(GLOB VXTOOLS_SOURCES
        ${VXTOOLS_COMMON_DIR}/*.cpp ${VXTOOLS_COMMON_DIR}/*.c
        ${VXTOOLS_WEB_DIR}/*.cpp ${VXTOOLS_WEB_DIR}/*.c
        ${VXTOOLS_DEPS_DIR}/*.cpp ${VXTOOLS_DEPS_DIR}/*.c)

add_library(xptools STATIC
        ${VXTOOLS_SOURCES})
