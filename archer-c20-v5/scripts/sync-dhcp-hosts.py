#!/usr/bin/env python3
"""
Static DHCP Host Reservation Importer for OpenWrt (dnsmasq)
============================================================
Reads a structured reservation text file and generates UCI commands
to populate static host records in OpenWrt's /etc/config/dhcp.
"""

import re
import sys
import os

def parse_reservations(file_path):
    hosts = []
    pattern = re.compile(r'^([A-Za-z0-9\-_]+)\s*=\s*(192\.168\.\d+\.\d+)\s*-\s*([0-9A-Fa-f:]{17})')
    
    if not os.path.exists(file_path):
        print(f"Error: Reservation file not found: {file_path}", file=sys.stderr)
        return hosts

    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            m = pattern.match(line.strip())
            if m:
                name, ip, mac = m.groups()
                hosts.append({
                    'name': name,
                    'ip': ip,
                    'mac': mac.lower()
                })
    return hosts

def generate_uci_script(hosts):
    lines = [
        "#!/bin/sh",
        "# Clear existing static host mappings",
        "while uci -q delete dhcp.@host[0]; do :; done",
        ""
    ]
    for h in hosts:
        lines.append("uci add dhcp host >/dev/null")
        lines.append(f"uci set dhcp.@host[-1].name='{h['name']}'")
        lines.append(f"uci set dhcp.@host[-1].ip='{h['ip']}'")
        lines.append(f"uci set dhcp.@host[-1].mac='{h['mac']}'")
    
    lines.append("")
    lines.append("uci commit dhcp")
    lines.append("/etc/init.d/dnsmasq reload")
    lines.append("echo 'Static DNS and DHCP reservations successfully reloaded.'")
    return "\n".join(lines)

def main():
    if len(sys.argv) < 2:
        print("Usage: python sync-dhcp-hosts.py <path_to_reservations.txt>")
        sys.exit(1)

    file_path = sys.argv[1]
    hosts = parse_reservations(file_path)
    print(f"Parsed {len(hosts)} static host records.")
    
    output_script = "import_hosts.sh"
    with open(output_script, 'w', encoding='utf-8', newline='\n') as f:
        f.write(generate_uci_script(hosts))
    
    print(f"Generated execution script: {output_script}")

if __name__ == "__main__":
    main()
