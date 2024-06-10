
cmake_minimum_required(VERSION 3.20)

set(LPNG_DIR "${REPO_ROOT_DIR}/deps/lpng")

# common sources
file(GLOB LPNG_SRC_COMMON
	${LPNG_DIR}/*.c)
list(REMOVE_ITEM LPNG_SRC_COMMON "${LPNG_DIR}/pngtest.c")

# arm-specific sources
file(GLOB LPNG_SRC_ARM
	${LPNG_DIR}/arm/*.c ${LPNG_DIR}/arm/*.S)

# intel-specific sources
file(GLOB LPNG_SRC_INTEL
	${LPNG_DIR}/intel/*.c ${LPNG_DIR}/intel/*.S)

# add lpng library
if(${CMAKE_ANDROID_ARCH} MATCHES "arm")
	message(STATUS "lpng built for ARM")
	add_library(lpng STATIC
		${LPNG_INCLUDE}
		${LPNG_SRC_COMMON}
		${LPNG_SRC_ARM})
else()
	message(STATUS "lpng built for INTEL")
	add_library(lpng STATIC
		${LPNG_INCLUDE}
		${LPNG_SRC_COMMON}
		${LPNG_SRC_INTEL})
endif()

#add_compile_options(
#	-DPNG_ARM_NEON_OPT=0
#)
