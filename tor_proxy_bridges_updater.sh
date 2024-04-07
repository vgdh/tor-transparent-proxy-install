#!/bin/bash

INSTALL_PATH="/opt/tor-transparent-proxy"

echo "Download and checking TOR bridges"

PY_VERSION=$(ls -1 /usr/bin/python* | grep -Eo 'python[0-9]\.[0-9]+' | sort -V | tail -n1 | cut -c7-)
PYTHON=python$PY_VERSION
$PYTHON $INSTALL_PATH/tor-relay-scanner-latest.pyz --torrc -o $INSTALL_PATH/tmp_bridges.conf -g 100 -n 100

NEW_BRIDGES=$INSTALL_PATH/new_bridges.conf

echo "Bridges saved to $NEW_BRIDGES"
cp $INSTALL_PATH/tmp_bridges.conf $NEW_BRIDGES
