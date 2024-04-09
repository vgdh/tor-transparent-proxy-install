#!/bin/bash

echo "Check internet through socks5"
curl --head  --socks5 127.0.0.1:9090 --request GET google.com --connect-timeout 10

echo "Check TOR DNS"
dig @127.0.0.1 -p 5353 google.com
