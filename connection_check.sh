#!/bin/bash

echo " "
echo " "
echo "Check internet through socks5"
echo " "
curl --head  --socks5 127.0.0.1:9090 --request GET google.com --connect-timeout 10

echo " "
echo " "
echo "Check TOR DNS"
echo " "
dig @127.0.0.1 -p 5353 google.com
