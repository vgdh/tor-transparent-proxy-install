#!/bin/bash

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
echo "Start updating TOR bridges"

PY_VERSION=$(ls -1 /usr/bin/python* | grep -Eo 'python[0-9]\.[0-9]+' | sort -V | tail -n1 | cut -c7-)
PYTHON=python$PY_VERSION
$PYTHON /tor_transparent_proxy/tor-relay-scanner-latest.pyz --torrc -o /tor_transparent_proxy/bridges.conf -g 100 -n 100

echo "Now restaring tor services in order to use new bridges"
systemctl restart tor

sleep 600
