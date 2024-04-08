#!/bin/bash

INSTALL_PATH="/opt/tor-transparent-proxy"

count=0
while [[ $count -lt 5 ]]; do
    if curl -s --head  --socks5 127.0.0.1:9090 --request GET google.com --connect-timeout 10 | grep "HTTP" > /dev/null; then
        echo "Internet connection detected."
        exit 0
    else
        echo "Internet connection not detected, wait and try again"
    fi
    count=$((count + 1))
    sleep 10
done

echo "No internet connection found after multiple attempts."
echo "Lets use new TOR bridges"

cp $INSTALL_PATH/new_bridges.conf /etc/tor/bridges.conf

echo "Now restaring tor services in order to use new bridges"
systemctl restart tor

sleep 600