# --------------------------------------------------
# Convert architecture name from Docker to CMake format
# --------------------------------------------------
PLATFORM_ARCH_CMAKE=linux-x86_64 # default
ifeq ($(CUBZH_TARGETARCH),arm64)
	PLATFORM_ARCH_CMAKE=linux-aarch64
else ifeq ($(CUBZH_TARGETARCH),amd64)
	PLATFORM_ARCH_CMAKE=linux-x86_64
endif
echo "PLATFORM/ARCH: "$(PLATFORM_ARCH_CMAKE)

.PHONY: all clean

all: clean xptools.a

xptools.a:
	@gcc -std=c++11 -D__VX_PLATFORM_LINUX -D__VX_USE_LIBWEBSOCKETS -DDEBUG -c *.cpp \
	-I . \
	-I ../common \
	-I ../include \
	-I ../../deps/lpng \
	-I ../../deps/miniaudio \
	-I ../../deps/libwebsockets/linux/${CUBZH_TARGETARCH}/include \
	-I ../../deps/libssl/linux/${CUBZH_TARGETARCH}/include \
	-I ../../cubzh/deps/libz/${PLATFORM_ARCH_CMAKE}/include
	(cd ../common; gcc -std=c++11 -D__VX_PLATFORM_LINUX -D__VX_USE_LIBWEBSOCKETS -DDEBUG -c *.cpp \
	-I . \
	-I ../include \
	-I ../deps \
	-I ../deps/md5 \
	-I ../../deps/lpng \
	-I ../../deps/miniaudio \
	-I ../../deps/libwebsockets/linux/${CUBZH_TARGETARCH}/include \
	-I ../../deps/libssl/linux/${CUBZH_TARGETARCH}/include \
	-I ../../cubzh/deps/libz/${PLATFORM_ARCH_CMAKE}/include)
	@(cd ../deps; gcc -D__VX_PLATFORM_LINUX -D__VX_USE_LIBWEBSOCKETS -DDEBUG -c *.c -I .)
	@ar rcs xptools.a *.o ../common/*.o ../deps/*.o
	@rm -f *.o
	@rm -f ./../common/*.o

clean:
	@rm -f *.o
	@rm -f ./../common/*.o
	@rm -f ./../deps/*.o
	@rm -f *.a
