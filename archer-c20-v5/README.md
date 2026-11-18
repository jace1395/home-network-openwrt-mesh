# Node 2: TP-Link Archer C20 v5 (OpenWrt 22.03.6)

This directory contains the configuration, build scripts, custom button handlers, and operational scripts for **Node 2** in the mesh network.

---

## 1. Hardware Specifications

| Component | Specification |
| :--- | :--- |
| **SoC** | MediaTek MT7628AN @ 580 MHz (MIPS 24KEc) |
| **5 GHz PCIe Radio** | MediaTek MT7610E (1T1R 802.11ac, up to 433 Mbps) |
| **RAM** | 64 MB DDR2 |
| **Flash** | 8 MB SPI NOR Flash |
| **Wireless** | Simultaneous Dual-Band (2.4 GHz 300 Mbps + 5 GHz 433 Mbps) |
| **Ethernet** | 5x 10/100 Mbps Fast Ethernet ports (1 WAN + 4 LAN) |
| **Role** | Upstairs Mesh Node, Switch, & Network DNS-over-TLS Server (IP: `192.168.1.3`) |

---

## 2. Firmware Architecture & Build Details

Built on official OpenWrt 22.03.6 using `openwrt-imagebuilder-22.03.6-ramips-mt76x8.Linux-x86_64`.

Key packages embedded directly into SquashFS rootfs:
- `luci` & `luci-ssl`: Full web management interface available via HTTPS without forced redirection.
- `stubby`: Encrypted DNS-over-TLS (DoT) recursive stub resolver.
- `wpad-basic-wolfssl`: Lightweight 802.11r/k roaming daemon with WolfSSL cryptography.
- **Flash Utilization:** ~6.8 MB used of 8.0 MB total flash, leaving ~1.2 MB JFFS2 overlay space for runtime configs.

---

## 3. Privacy DNS Engine: DNS-over-TLS (Stubby)

Archer C20 v5 acts as the centralized DNS resolution engine for all network clients.

```
+-------------------------------------------------------------------+
|                     Client Device (192.168.1.X)                   |
+---------------------------------+---------------------------------+
                                  | (Standard DNS queries - Port 53)
                                  v
+---------------------------------+---------------------------------+
| Archer C20 v5: dnsmasq (192.168.1.3:53)                           |
| - Resolves local hostname overrides from /etc/config/dhcp         |
| - Forwards pool.ntp.org queries to 1.1.1.1 / 8.8.8.8 (plaintext)  |
| - Forwards all internet DNS queries to local Stubby daemon        |
+---------------------------------+---------------------------------+
                                  | (Local loopback - Port 5453)
                                  v
+---------------------------------+---------------------------------+
| Archer C20 v5: Stubby (127.0.0.1:5453)                            |
| - Encrypts upstream queries with TLS 1.3                          |
| - Round-robins upstream resolvers                                 |
+---------------------------------+---------------------------------+
                                  | (Encrypted DoT - Port 853)
                 +----------------+----------------+
                 |                                 |
                 v                                 v
   +-----------------------------+   +-----------------------------+
   | Cloudflare DNS (1.1.1.1)    |   | Google DNS (8.8.8.8)        |
   | tls_auth: cloudflare-dns.com|   | tls_auth: dns.google        |
   +-----------------------------+   +-----------------------------+
```

### The "No-RTC" Bootstrapping Solution
The MT7628 SoC has no battery-backed Real Time Clock (RTC). On power loss, it boots at Unix epoch (Jan 1, 1970). TLS certificates will fail verification if the system clock is incorrect.
To solve this deadlock:
1. `dnsmasq` has explicit exception rules directing `pool.ntp.org` queries directly to public DNS IP addresses (`1.1.1.1`, `8.8.8.8`) in plaintext.
2. NTP synchronizes system time immediately upon network link establishment.
3. `/etc/rc.local` issues a delayed restart of `stubby` 15 seconds post-boot, ensuring all TLS certificates validate cleanly against real-world UTC time.

---

## 4. Physical Button Disarming (`rfkill` Fix)

On the physical TP-Link Archer C20 v5 casing, the rear button functions as both WPS and Wi-Fi On/Off.

### The Problem
An accidental brush or press of the button triggers OpenWrt's default `/etc/rc.button/rfkill` script, which issues `wifi down`, shutting off both 2.4 GHz and 5 GHz radios and severing all wireless connectivity in the house.

### The Fix
The file [`etc/rc.button/rfkill`](archer-c20-v5/etc/rc.button/rfkill) replaces the default handler:
1. Intercepts the button release event.
2. Flashes the green WPS LED at 250ms intervals for 10 seconds to indicate the button was pressed.
3. Invokes `/etc/rc.button/wps` instead of toggling radio state.
4. **Result:** Wireless radios remain 100% operational regardless of button state.

---

## 5. Wireless & Roaming Calibration

| Radio | Frequency | Channel | Channel Width | Transmit Power | Role |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Radio 0 (MT7628)** | 2.4 GHz | **6** (2437 MHz) | **HT20** (20 MHz) | **21 dBm** (125 mW) | Primary whole-floor coverage, penetration through walls/doors. |
| **Radio 1 (MT7610E)** | 5 GHz | **149** (5745 MHz) | **VHT80** (80 MHz) | **12 dBm** (~16 mW) | High-speed low-latency cell for hall and line-of-sight devices. |

### Asymmetric 802.11k Neighbor Topology
To eliminate ping-ponging (clients repeatedly hopping between 2.4 GHz and weak 5 GHz signals in bedrooms):
- **On 2.4 GHz (`wlan0`):** Only advertises Node 1 (WR841N). 5 GHz is **omitted** so clients connected to 2.4 GHz stay locked stably.
- **On 5 GHz (`wlan1`):** Advertises both Node 1 (2.4 GHz) and Node 2 (2.4 GHz). When clients walk behind walls and 5 GHz attenuates, they fall back smoothly to 2.4 GHz.

---

## 6. File Inventory

- [`etc/config/network`](archer-c20-v5/etc/config/network): Bridged LAN with static IP `192.168.1.3`, gateway `192.168.1.1`.
- [`etc/config/wireless`](archer-c20-v5/etc/config/wireless): Dual-band wireless configuration, 802.11r/k.
- [`etc/config/dhcp`](archer-c20-v5/etc/config/dhcp): Dnsmasq forwarding to Stubby DoT, static host entries.
- [`etc/config/stubby`](archer-c20-v5/etc/config/stubby): DNS-over-TLS daemon upstream configuration.
- [`etc/config/system`](archer-c20-v5/etc/config/system): System hostname, timezone, and LED mappings.
- [`etc/rc.button/rfkill`](archer-c20-v5/etc/rc.button/rfkill): Physical button disarming handler.
- [`scripts/set-rrm-neighbors.sh`](archer-c20-v5/scripts/set-rrm-neighbors.sh): 802.11k directional neighbor injector.
- [`scripts/sync-dhcp-hosts.py`](archer-c20-v5/scripts/sync-dhcp-hosts.py): Static reservation generator.
- [`build/build_c20_final.sh`](archer-c20-v5/build/build_c20_final.sh): Automated OpenWrt 22.03.6 ImageBuilder script.
