#!/bin/bash

INSTALL_PATH="/opt/tor-transparent-proxy"

# Set default values for passed params
default_br_num=10 # how many bridges to find
default_br_conf_path=$INSTALL_PATH/new_bridges.conf

# Check if parameters are provided, otherwise use default values
BR_NUM=${1:-$default_br_num}
NEW_BRIDGES_PATH=${2:-$default_br_conf_path}

echo "Download bridges and checking TOR bridges. Find $BR_NUM working and save to $NEW_BRIDGES_PATH"

PY_VERSION=$(ls -1 /usr/bin/python* | grep -Eo 'python[0-9]\.[0-9]+' | sort -V | tail -n1 | cut -c7-)
PYTHON=python$PY_VERSION
$PYTHON $INSTALL_PATH/tor-relay-scanner-latest.pyz --torrc -o $INSTALL_PATH/tmp_bridges.conf -g $BR_NUM -n 100

echo "Bridges saved to $NEW_BRIDGES_PATH"
cp $INSTALL_PATH/tmp_bridges.conf $NEW_BRIDGES_PATH
