#!/bin/sh

set -e

# Force scrip execution at repo top level
START_LOCATION="$PWD"
SCRIPT_LOCATION=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# Go back to start location when script exits
trap "cd $START_LOCATION" EXIT
# Go to script location before running git command
# to make sure it runs within project tree
cd "$SCRIPT_LOCATION"
# Use git command to get root project directory.
PROJECT_ROOT=$(git rev-parse --show-toplevel)
# The script is now executed from project root directory
cd "$PROJECT_ROOT"

IP=$(ifconfig | grep "inet " | grep -Fv 127.0.0.1 | awk '{print $2}')
IP=$( cut -d $' ' -f 1 <<< $IP )

echo "IP: $IP"
echo "WORKDIR: $PWD"

docker rm -f lua-docs

docker compose -f "$PWD"/lua/docs/docker-compose.yml -f "$PWD"/lua/docs/docker-compose-dev.yml up -d --build

URL=$(docker ps --format="{{.Ports}}\t{{.Names}}" | grep lua-docs | sed -En "s|0.0.0.0:([0-9]+).*|http://$IP:\1|p")

echo ""
echo "----------------------"
echo "docker exec -ti lua-docs ash"
echo "go run *.go"
echo "----------------------"
echo "Open in browser: $URL"
echo "----------------------"
echo ""
