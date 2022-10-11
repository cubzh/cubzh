#!/bin/sh
      
set -e

START_LOCATION="$PWD"
SCRIPT_LOCATION=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# Go back to start location when script exits
trap "cd $START_LOCATION" EXIT

# Go to script location
cd "$SCRIPT_LOCATION"

IMAGES_PREFIX="cubzh-deps"
TARGET=""

while read -p "linux-debian-x64, linux-ubuntu-amd64, linux-ubuntu-arm64 ?" v; do
    if [ "$v" = "linux-debian-x64" ] || [ "$v" = "linux-ubuntu-amd64" ] || [ "$v" = "linux-ubuntu-arm64" ]
    then
        TARGET=$v
        break
    fi
    echo "option not supported"
done

if [ "$TARGET" = "linux-debian-x64" ]
then
	
	# ========== libz ==========

	DEP="libz"
	IMAGE_NAME=$IMAGES_PREFIX"-"$TARGET"-"$DEP
	INCLUDE_DIR="$PWD"/$DEP/$TARGET/include
	LIBS_DIR="$PWD"/$DEP/$TARGET/libs

	rm -rf $INCLUDE_DIR
	rm -rf $LIBS_DIR
	
	echo "-----------------------------"
	echo "--- $DEP ($TARGET)"
	echo "-----------------------------"

	docker build -f ./$DEP/$TARGET/Dockerfile -t $IMAGE_NAME .
	docker run --rm -ti -v $INCLUDE_DIR:/include $IMAGE_NAME cp -r /usr/include/zconf.h /include/zconf.h
	docker run --rm -ti -v $INCLUDE_DIR:/include $IMAGE_NAME cp -r /usr/include/zlib.h /include/zlib.h
	docker run --rm -ti -v $LIBS_DIR:/libs $IMAGE_NAME cp /usr/lib/x86_64-linux-gnu/libz.a /libs/libz.a
fi

if [ "$TARGET" = "linux-ubuntu-amd64" ]
then
	
	# ========== libz ==========

	DEP="libz"
	IMAGE_NAME=$IMAGES_PREFIX"-"$TARGET"-"$DEP
	INCLUDE_DIR="$PWD"/$DEP/$TARGET/include
	LIBS_DIR="$PWD"/$DEP/$TARGET/libs

	rm -rf $INCLUDE_DIR
	rm -rf $LIBS_DIR
	
	echo "-----------------------------"
	echo "--- $DEP ($TARGET)"
	echo "-----------------------------"

	docker build -f ./$DEP/$TARGET/Dockerfile -t $IMAGE_NAME .
	docker run --rm -ti -v $INCLUDE_DIR:/include $IMAGE_NAME cp -r /usr/include/zconf.h /include/zconf.h
	docker run --rm -ti -v $INCLUDE_DIR:/include $IMAGE_NAME cp -r /usr/include/zlib.h /include/zlib.h
	docker run --rm -ti -v $LIBS_DIR:/libs $IMAGE_NAME cp /usr/lib/x86_64-linux-gnu/libz.a /libs/libz.a
fi

if [ "$TARGET" = "linux-ubuntu-arm64" ]
then

	# ========== libz ==========
	
	DEP="libz"
	IMAGE_NAME=$IMAGES_PREFIX"-"$TARGET"-"$DEP
	INCLUDE_DIR="$PWD"/$DEP/$TARGET/include
	LIBS_DIR="$PWD"/$DEP/$TARGET/libs

	rm -rf $INCLUDE_DIR
	rm -rf $LIBS_DIR
	
	echo "-----------------------------"
	echo "--- $DEP ($TARGET)"
	echo "-----------------------------"

	docker build -f ./$DEP/$TARGET/Dockerfile -t $IMAGE_NAME .
	docker run --rm -ti -v $INCLUDE_DIR:/include $IMAGE_NAME cp -r /usr/include/zconf.h /include/zconf.h
	docker run --rm -ti -v $INCLUDE_DIR:/include $IMAGE_NAME cp -r /usr/include/zlib.h /include/zlib.h
	docker run --rm -ti -v $LIBS_DIR:/libs $IMAGE_NAME cp /usr/lib/aarch64-linux-gnu/libz.a /libs/libz.a
fi
