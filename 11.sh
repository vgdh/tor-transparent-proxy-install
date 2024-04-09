#!/bin/bash

    interfaces=$(ip link show | awk -F': ' '/^[0-9]+:/{print $2}')

    for iface in $interfaces; do # Loop through each interface and filter for eth interfaces
        if [[ $iface == eth* ]]; then
            eth_name=$(echo "$iface" | cut -d'@' -f1) # Extract the part before the "@" symbol
            echo "add rule ip nat PREROUTING iifname \"$eth_name\" tcp dport 22 counter redirect to :22"
        fi
    done