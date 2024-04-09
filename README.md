# Tor Transparent Proxy Installer

Automate the installation and configuration of a TOR transparent proxy using bash scripts.

_Recommended to be installed on a dedicated VM or container._

## Requirements:
- Ubuntu 23.04 (VM or Container)
- One or multiple **eth** adapters enabled in the VM or container.

## What This Script Does:
- Installs the latest TOR and its dependencies.
- Downloads the latest TOR relay scanner.
- Configures TOR to:
    - Act as a transparent proxy on all available interfaces.
    - Enable Socks5 on port 9090 on all available interfaces.
    - Enable TOR DNS on all available interfaces.
    - Configures nftables to:
        - Route all incoming external traffic through TOR.
        - Accept SSH connections on port 22 (all available interfaces).
        - Accept DNS connections on port 53 (all available interfaces).
        - Accept Socks5 connections on port 9090 (all available interfaces).
    - Sets up a service for checking TOR's connection status and updating bridges if it goes down.

Ensure that your OS's Gateway and DNS servers are set to one of the addresses configured by tor-transparent-proxy for proper functionality.

### Note: The script writes all available interfaces in the nftable config. If you add another interface, you'll need to repeat the installation or manually update the rules in /etc/nftables.conf.

## Installation:
1. Clone this repo
```
git clone https://github.com/vgdh/tor-transparent-proxy-install.git
```
2. Navigate in to the folder
```
cd tor-transparent-proxy-install
```
3. Run the installation
```
./tor-transparent-proxy-install.sh
```
