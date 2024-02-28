#!/bin/bash

function install_tor {
    if ! [ -x "$(command -v tor)" ]; then
        echo "Tor is not installed. Enabling Tor package repository and installing Tor..."
        if [ $(id -u) -eq 0 ]; then
            echo "Running as root user"
            echo "deb     [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $(lsb_release -cs) main" >> /etc/apt/sources.list.d/tor.list
            echo "deb-src [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $(lsb_release -cs) main" >> /etc/apt/sources.list.d/tor.list
            wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null
            apt-get update
            apt-get install apt-transport-https -y
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


function configure_iptables() {
    echo "Configure IP tables"
    iptables -F
    iptables -t nat -F
    iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 22 -j REDIRECT --to-ports 22 #SSH
    iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 9090 -j REDIRECT --to-ports 9090 #TOR Socks port
    iptables -t nat -A PREROUTING -i eth0 -p tcp --syn -j REDIRECT --to-ports 9040
    iptables -t nat -A PREROUTING -i eth0 -p udp --dport 53 -j REDIRECT --to-ports 5353

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
    mkdir /tor_transparent_proxy
    touch /tor_transparent_proxy/bridges.conf

    MY_IP=$(hostname -I | awk '{print $1}')

    replace_or_add_line /etc/tor/torrc "Log notice file" "Log notice file  /var/log/tor/notices.log"
    replace_or_add_line /etc/tor/torrc "VirtualAddrNetwork" "VirtualAddrNetwork 10.192.0.0/10"
    replace_or_add_line /etc/tor/torrc "AutomapHostsSuffixes" "AutomapHostsSuffixes .onion,.exit"
    replace_or_add_line /etc/tor/torrc "AutomapHostsOnResolve" "AutomapHostsOnResolve 1"
    replace_or_add_line /etc/tor/torrc "ExcludeExitNodes" "ExcludeExitNodes {ru},{ua},{by},{kz},{??}"

    replace_or_add_line /etc/tor/torrc "SocksPort $MY_IP:9090" "SocksPort $MY_IP:9090"
    replace_or_add_line /etc/tor/torrc "SocksPort 127.0.0.1:9090" "SocksPort 127.0.0.1:9090"

    #enable bridges
    replace_or_add_line /etc/tor/torrc "%include /tor_transparent_proxy/bridges.conf" "%include /tor_transparent_proxy/bridges.conf"
    #replace_or_add_line /etc/tor/torrc "UseBridges" "UseBridges 1"

    #(assuming this is the static IP address of the server)
    replace_or_add_line /etc/tor/torrc "TransPort" "TransPort $MY_IP:9040"
    replace_or_add_line /etc/tor/torrc "DNSPort" "DNSPort $MY_IP:5353"

}

function download_latest_tor_relay_scanner() {

    FILE_PATH="/tor_transparent_proxy/tor-relay-scanner-latest.pyz"
    if [ ! -f "$FILE_PATH" ]; then
        # Perform some commands here
        echo "File tor-relay-scanner-latest does not exist"
        echo "Download latest"

        # Download latest version
        # curl -s https://api.github.com/repos/ValdikSS/tor-relay-scanner/releases/latest |
        #     grep "browser_download_url.*pyz" |
        #     cut -d : -f 2,3 |
        #     tr -d \" |
        #     wget -i - -O $FILE_PATH

        wget https://github.com/ValdikSS/tor-relay-scanner/releases/download/0.0.9/tor-relay-scanner-0.0.9.pyz -O $FILE_PATH
    else
        echo "File $FILE_PATH exists"
    fi
}

function create_script_for_auto_update_bridges() {
    FILE_PATH="/tor_transparent_proxy/check-and-update-bridges.sh"

    script_contents=$(
        cat <<END
#!/bin/bash

count=0
while [[ \$count -lt 5 ]]; do
    if curl -s --head  --socks5 127.0.0.1:9090 --request GET google.com --connect-timeout 10 | grep "HTTP" > /dev/null; then
        echo "Internet connection detected."
        exit 0
    else
        echo "Internet connection not detected, wait and try again"
    fi
    count=\$((count + 1))
    sleep 10
done

echo "No internet connection found after multiple attempts."
echo "Start updating TOR bridges"
PY_VERSION=\$(ls -1 /usr/bin/python* | grep -Eo 'python[0-9]\.[0-9]+' | sort -V | tail -n1 | cut -c7-)
PYTHON=python\$PY_VERSION
\$PYTHON /tor_transparent_proxy/tor-relay-scanner-latest.pyz --torrc -o /tor_transparent_proxy/bridges.conf -g 100 -n 100

echo "Now restaring tor services in order to use new bridges"
systemctl restart tor
sleep 600

END
    )

    # Create the new script file
    echo "$script_contents" >"$FILE_PATH"

    # Make the new script executable
    chmod +x "$FILE_PATH"
}

function create_service_tor_auto_update_bridges() {
    FILE_PATH="/etc/systemd/system/tor_auto_update_bridges.service"

    script_contents=$(
        cat <<END
[Unit]
Description=tor auto update bridges script

[Service]
Type=simple
ExecStart=/tor_transparent_proxy/check-and-update-bridges.sh
Restart=always
RestartSec=10
TimeoutStopSec=600

[Install]
WantedBy=multi-user.target

END
    )

    # Create the new script file
    echo "$script_contents" >"$FILE_PATH"

    systemctl daemon-reload
    systemctl enable tor_auto_update_bridges.service
    systemctl start tor_auto_update_bridges
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
