#!/bin/sh

docker-compose -f docker-compose.yml -f docker-compose-dev.yml up -d --build

IP=$(ifconfig | grep "inet " | grep -Fv 127.0.0.1 | awk '{print $2}')
IP=$( cut -d $' ' -f 1 <<< $IP )

URL=$(docker ps --format="{{.Ports}}\t{{.Names}}" | grep lua-docs | sed -En "s|0.0.0.0:([0-9]+).*|http://$IP:\1|p")

echo ""
echo "----------------------"
echo "docker exec -ti lua-docs ash"
echo "go run *.go"
echo "----------------------"
echo "Open in browser: $URL"
echo "----------------------"
echo ""