#!/bin/bash

INSTALL_PATH="/opt/tor-transparent-proxy"

SCRIPT_DIR=$(dirname "$0") # Get the directory of the script

function install_tor {
    if ! [ -x "$(command -v tor)" ]; then
        echo "Tor is not installed. Enabling Tor package repository and installing Tor..."
        if [ $(id -u) -eq 0 ]; then
            echo "Running as root user"

            echo "deb     [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $(lsb_release -cs) main" >> /etc/apt/sources.list.d/tor.list
            echo "deb-src [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $(lsb_release -cs) main" >> /etc/apt/sources.list.d/tor.list
            
            apt-get update
            apt-get install apt-transport-https -y            
            apt-get install gpg -y
            wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null
            
            apt-get update
            apt-get install tor deb.torproject.org-keyring -y
            apt-get install tor-geoipdb -y
            echo "Tor has been installed successfully."
        else
            echo "This script requires root privileges to install Tor. Please run with sudo or as root user."
        fi
    else
        echo "Tor is already installed."
    fi
}

function replace_or_add_line {
    file="$1"
    search_text="$2"
    new_line="$3"

    if grep -iq "$search_text" "$file"; then
        # If the search text is found in the file, replace the line
        sed -i "/$search_text/c $new_line" "$file"
    else
        # If the search text is not found in the file, add the new line at the end
        echo "$new_line" >>"$file"
    fi
}

function delete_all_lines {
    file="$1"
    search_text="$2"
    sed -i "/$search_text/d" $file
}


function configure_iptables() {
    echo "Configure IP tables"
    iptables -F
    iptables -t nat -F
    iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 22 -j REDIRECT --to-ports 22 #SSH
    iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 9090 -j REDIRECT --to-ports 9090 #TOR SocksPort port
    iptables -t nat -A PREROUTING -i eth0 -p tcp --syn -j REDIRECT --to-ports 9040 #TOR TransPort port
    iptables -t nat -A PREROUTING -i eth0 -p udp --dport 53 -j REDIRECT --to-ports 5353 #TOR DNSPort port 

    # Autoload iptables rules
    debconf-set-selections <<EOF
iptables-persistent iptables-persistent/autosave_v4 boolean true
iptables-persistent iptables-persistent/autosave_v6 boolean true
EOF
    apt update
    apt install iptables-persistent -y
    systemctl enable netfilter-persistent.service

    /sbin/iptables-save > /etc/iptables/rules.v4
    /sbin/ip6tables-save > /etc/iptables/rules.v6

}

function configure_tor() {
    mkdir $INSTALL_PATH
    touch $INSTALL_PATH/tmp_bridges.conf
    touch $INSTALL_PATH/new_bridges.conf
    touch $INSTALL_PATH/current_bridges.conf

    MY_IP=$(hostname -I | awk '{print $1}')

    replace_or_add_line /etc/tor/torrc "Log notice file" "Log notice file  /var/log/tor/notices.log"
    replace_or_add_line /etc/tor/torrc "VirtualAddrNetwork" "VirtualAddrNetwork 10.192.0.0/10"
    replace_or_add_line /etc/tor/torrc "AutomapHostsSuffixes" "AutomapHostsSuffixes .onion,.exit"
    replace_or_add_line /etc/tor/torrc "AutomapHostsOnResolve" "AutomapHostsOnResolve 1"
    replace_or_add_line /etc/tor/torrc "ExcludeExitNodes" "ExcludeExitNodes {ru},{ua},{by},{kz},{??}"

    #(assuming this is the static IP address of the server)
    ip_addresses=$(hostname -I | awk '{print $0}' | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

    delete_all_lines /etc/tor/torrc "SocksPort"
    for ip in $ip_addresses; do
        echo "SocksPort $ip:9090" >> /etc/tor/torrc 
    done

    delete_all_lines /etc/tor/torrc "TransPort"
    for ip in $ip_addresses; do
        echo "TransPort $ip:9040" >> /etc/tor/torrc 
    done

    delete_all_lines /etc/tor/torrc "DNSPort"
    for ip in $ip_addresses; do
        echo "DNSPort $ip:5353" >> /etc/tor/torrc 
    done

    #enable bridges
    replace_or_add_line /etc/tor/torrc "%include" "%include $INSTALL_PATH/current_bridges.conf"
}

function download_latest_tor_relay_scanner() {
    TOR_SCANNER_FILE_PATH="$INSTALL_PATH/tor-relay-scanner-latest.pyz"

    echo "Download tor-relay-scanner-latest"

    #Download latest version
    curl -s https://api.github.com/repos/ValdikSS/tor-relay-scanner/releases/latest |
        grep "browser_download_url.*pyz" |
        cut -d : -f 2,3 |
        tr -d \" |
        wget -i - -O $TOR_SCANNER_FILE_PATH

    #Download fixed version
    # wget https://github.com/ValdikSS/tor-relay-scanner/releases/download/1.0.0/tor-relay-scanner-1.0.0.pyz -O $TOR_SCANNER_FILE_PATH
}

function copy_scripts_to_install_folder() {

    cp $SCRIPT_DIR/tor_proxy_bridges_updater.sh $INSTALL_PATH/tor_proxy_bridges_updater.sh
    cp $SCRIPT_DIR/tor_proxy_connectivity_checker.sh $INSTALL_PATH/tor_proxy_connectivity_checker.sh
}

function create_service_tor_auto_update_bridges() {
    SERVICE_PATH="/etc/systemd/system"

    cp $SCRIPT_DIR/tor_proxy_bridges_updater.service $SERVICE_PATH/tor_proxy_bridges_updater.service
    cp $SCRIPT_DIR/tor_proxy_connectivity_checker.service $SERVICE_PATH/tor_proxy_connectivity_checker.service

    systemctl daemon-reload
    systemctl enable tor_proxy_bridges_updater.service
    systemctl start tor_proxy_bridges_updater

    systemctl enable tor_proxy_connectivity_checker.service
    systemctl start tor_proxy_connectivity_checker
}


main() {
    install_tor
    configure_iptables
    configure_tor
    download_latest_tor_relay_scanner
    create_script_for_auto_update_bridges
    create_service_tor_auto_update_bridges

    systemctl restart tor
}

check_root_and_run_main () {
  if [ $(id -u) -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
  else
    echo "I am root."
    main
  fi
}

check_root_and_run_main
