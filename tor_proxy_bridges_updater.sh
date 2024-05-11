#!/bin/bash

INSTALL_PATH="/opt/tor-transparent-proxy"

# Set default values for passed params
default_br_num=30 # how many bridges to find
default_br_conf_path=$INSTALL_PATH/new_bridges.conf

# Check if parameters are provided, otherwise use default values
BR_NUM=${1:-$default_br_num}
NEW_BRIDGES_PATH=${2:-$default_br_conf_path}
TMP_BRIDGES_PATH=$INSTALL_PATH/tmp_bridges.conf

echo "Download bridges and checking TOR bridges. Find $BR_NUM working and save to $NEW_BRIDGES_PATH"

PY_VERSION=$(ls -1 /usr/bin/python* | grep -Eo 'python[0-9]\.[0-9]+' | sort -V | tail -n1 | cut -c7-)
PYTHON=python$PY_VERSION
$PYTHON $INSTALL_PATH/tor-relay-scanner-latest.pyz --torrc -o $TMP_BRIDGES_PATH -g $BR_NUM -n 50

# Check if the file has a minimum of 2 lines
if [ $(wc -l < "$TMP_BRIDGES_PATH") -ge 2 ]; then
  echo "Tmp bridge config contains two or more lines. Copy tmp config to $NEW_BRIDGES_PATH"
  cp $TMP_BRIDGES_PATH $NEW_BRIDGES_PATH
else
  echo "Tmp bridge contains less than two lines. Ignore it"
fi
