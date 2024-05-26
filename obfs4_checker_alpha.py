import asyncio
from concurrent.futures import ThreadPoolExecutor
import socket
import urllib.request

url = "https://raw.githubusercontent.com/scriptzteam/Tor-Bridges-Collector/main/bridges-obfs4"


def fetch_data(url):
    with urllib.request.urlopen(url) as response:
        return response.read().decode('utf-8')


def parse_line(line):
    parts = line.split()
    if len(parts) > 1 and parts[0] == "obfs4":
        address = parts[1]
        ip, port = address.split(":")
        return ip, int(port)
    return None, None


async def check_connection(ip, port):
    loop = asyncio.get_event_loop()
    try:
        await loop.run_in_executor(None, socket.create_connection, (ip, port), 5)
        print(f"{ip}:{port} - Alive")
        return True
    except Exception:
        print(f"{ip}:{port} - Dead")
        return False


async def process_address(address):
    ip, port = address
    if await check_connection(ip, port):
        return f"{ip}:{port}"
    return None


async def main():
    data = fetch_data(url)
    lines = data.splitlines()
    addresses = [parse_line(line) for line in lines]
    addresses = [addr for addr in addresses if addr[0] is not None]

    loop = asyncio.get_running_loop()
    loop.set_default_executor(ThreadPoolExecutor(max_workers=50))

    tasks = [process_address(address) for address in addresses]
    results = await asyncio.gather(*tasks)

    successful_connections = [result for result in results if result]

    filtered_lines = [line for line in lines if any(
        item in line for item in successful_connections)]
    with open("successful_connections.txt", "w") as f:
        for obfs4proxy in filtered_lines:
            f.write("Bridge" + obfs4proxy + "\n")
        f.write("UseBridges 1")

asyncio.run(main())
