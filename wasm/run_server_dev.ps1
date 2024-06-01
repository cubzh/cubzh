#
# For now, this MUST be executed from the repository root directory
#

# set -e

$START_LOCATION=$pwd.Path
# SCRIPT_LOCATION=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# When script exits:
# - go back to start location
# - stop web server container
# trap "cd $START_LOCATION; docker rm -f wasm_server" EXIT

# Go to script location before running git command
# to make sure it runs within project tree
# cd "$SCRIPT_LOCATION"

# Use git command to get root project directory.
# PROJECT_ROOT=$(git rev-parse --show-toplevel)
$PROJECT_ROOT=$START_LOCATION # temporary

# The script is now executed from project root directory
# cd ${PROJECT_ROOT}

# build 2 docker images, one to build the wasm application, 
# the other to run the webserver
docker build --target wasm_build_env -t wasm_build_env -f ${PROJECT_ROOT}/dockerfiles/wasm.Dockerfile ${PROJECT_ROOT}
docker build --target web_server_empty -t wasm_web_server -f ${PROJECT_ROOT}/dockerfiles/wasm.Dockerfile ${PROJECT_ROOT}

# just in case web server is still running
docker rm -f wasm_web_server

# run web server
docker run --name wasm_web_server -d -e NO_CACHE=1 -p 1080:80 -p 1443:443 -v ${PROJECT_ROOT}/wasm/Particubes/build/output:/www wasm_web_server

docker run -ti --rm -v ${PROJECT_ROOT}:/repo wasm_build_env
