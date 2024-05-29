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

LIBPNG_DIR=../../lpng/src
LIBWEBSOCKETS_DIR=../../libwebsockets/linux/$(CUBZH_TARGETARCH)/include
LIBSSL_DIR=../../libssl/linux/$(CUBZH_TARGETARCH)/include
LIBZ_INCLUDE_DIR=../../libz/$(PLATFORM_ARCH_CMAKE)/include
MINIAUDIO_DIR=../../miniaudio

.PHONY: all clean

all: clean xptools.a

xptools.a:
	@gcc -std=c++11 -D__VX_PLATFORM_LINUX -D__VX_USE_LIBWEBSOCKETS -DDEBUG -c *.cpp \
	-I . \
	-I ../common \
	-I ../include \
	-I $(LIBPNG_DIR) \
	-I $(MINIAUDIO_DIR) \
	-I $(LIBWEBSOCKETS_DIR) \
	-I $(LIBSSL_DIR) \
	-I $(LIBZ_INCLUDE_DIR)
	(cd ../common; gcc -std=c++11 -D__VX_PLATFORM_LINUX -D__VX_USE_LIBWEBSOCKETS -DDEBUG -c *.cpp \
	-I . \
	-I ../include \
	-I ../deps \
	-I ../deps/md5 \
	-I $(LIBPNG_DIR) \
	-I $(MINIAUDIO_DIR) \
	-I $(LIBWEBSOCKETS_DIR) \
	-I $(LIBSSL_DIR) \
	-I $(LIBZ_INCLUDE_DIR))
	@(cd ../deps; gcc -D__VX_PLATFORM_LINUX -D__VX_USE_LIBWEBSOCKETS -DDEBUG -c *.c -I .)
	@ar rcs libxptools.a *.o ../common/*.o ../deps/*.o
	@rm -f *.o
	@rm -f ./../common/*.o

clean:
	@rm -f *.o
	@rm -f ./../common/*.o
	@rm -f ./../deps/*.o
	@rm -f *.a
