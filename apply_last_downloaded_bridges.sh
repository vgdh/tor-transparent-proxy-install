#!/bin/bash

INSTALL_PATH="/opt/tor-transparent-proxy"

echo "Copying these bridges to tor config"
cat $INSTALL_PATH/new_bridges.conf
cp $INSTALL_PATH/new_bridges.conf /etc/tor/bridges.conf

echo "Now restaring tor services in order to use new bridges"
systemctl restart tor