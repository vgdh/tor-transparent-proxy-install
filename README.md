# tor-transparent-proxy-install
Install and configure TOR transparent proxy with bash script

It's recommended to install on a dedicated VM or container.

What this script does?
1. Install latest TOR
2. Install `apt-transport-https`
3. Download latest TOR relay scanner
4. Configure TOR:
    1. As transparent proxy
    2. Enable Socks5 on port 9090
5. Configure IPtables:
    1. To route all incoming traffic through TOR
    2. Accept SSH connections on port 22
6. Cteate a service for checking TOR alive connection and update bridges if it is dead.

**You must not change the IP address of the VM/container after install `TOR transparent proxy`**

In OS of your choice you need to change `Gateway` and `DNS` server to the address of configurated `tor-transparent-proxy` 
