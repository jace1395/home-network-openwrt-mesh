# Node 1: TP-Link TL-WR841N v14 (OpenWrt 19.07.10)

This directory contains the complete configuration, Device Tree Source (DTS), patches, and operational scripts for **Node 1** in the mesh network.

---

## 1. Hardware Specifications

| Component | Specification |
| :--- | :--- |
| **SoC** | MediaTek MT7628AN @ 580 MHz (MIPS 24KEc) |
| **RAM** | 32 MB DDR2 |
| **Flash** | 4 MB SPI NOR Flash (`Winbond W25Q32JV`) |
| **Wireless** | 2.4 GHz 802.11b/g/n (2T2R, up to 300 Mbps) |
| **Ethernet** | 5x 10/100 Mbps Fast Ethernet ports (1 WAN + 4 LAN) |
| **Role** | Downstairs Mesh Node & Wired Switch (IP: `192.168.1.2`) |

---

## 2. The 4MB Flash Challenge & OpenWrt 19.07

Modern OpenWrt releases (v21.02, v22.03, v23.05) officially deprecated and dropped support for devices with **4MB Flash / 32MB RAM** due to the size of the modern Linux kernel (> 5.4) and base package footprints.

To achieve enterprise-grade stability on this legacy hardware:
1. **Target Version:** Built using `openwrt-imagebuilder-19.07.10-ramips-mt76x8.Linux-x86_64` (Linux Kernel 4.14).
2. **Minimal Package Selection:** Stripped LuCI (Web UI), `odhcpd`, `ppp`, and firewall daemons.
3. **Roaming Engine:** Packed with `wpad-basic-wolfssl` to enable IEEE 802.11r Fast BSS Transition (FT) and IEEE 802.11k Radio Resource Measurement (RRM).
4. **Resulting Image Size:** Compressed kernel and SquashFS rootfs totals ~3.8 MB, fitting inside the 4MB SPI flash with zero wasted space.

---

## 3. Custom Device Tree Source (DTS)

TP-Link released the TL-WR841N v14 with internal MediaTek hardware identical to the TL-WR841N v13, but with different board identifiers and GPIO assignments.

The `dts/` folder includes:
- `TL-WR841NV14.dts`: Custom Device Tree Source targeting `tplink,tl-wr841n-v14`.
- `v14.patch`: Upstream kernel patch applying the board profile to the OpenWrt ramips/mt76x8 target.

Key DTS definitions:
- **Keys:** Polled GPIO 6 for hardware `reset` button.
- **LEDs:** WLAN green LED on GPIO 44 (configured as boot, failsafe, and netdev activity).
- **Ethernet:** Internal switch mapped with VLAN 1 bridging all 5 ports (`0 1 2 3 4 6t`).

---

## 4. Radio & Roaming Calibration

| Parameter | Configuration | Technical Rationale |
| :--- | :--- | :--- |
| **Channel** | **11** (2462 MHz) | 25 MHz frequency separation from Node 2 (Channel 6), preventing co-channel interference. |
| **Bandwidth** | **HT20** (20 MHz) | Eliminates 40 MHz overlap in crowded 2.4 GHz spectrum and ensures 100% compatibility with legacy IoT devices. |
| **Tx Power** | **18 dBm** (63 mW) | Calibrated for smooth handoff at the boundary (e.g. kitchen/hallway threshold) without sticky beacon locks. |
| **802.11r FT** | Enabled (`psk2`) | Shared Mobility Domain (`1395`), locally generated PMK-R1 keys for sub-50ms handoffs. |
| **802.11k RRM** | Enabled | Advertises Node 2 (Archer C20 2.4 GHz) in neighbor reports. 5 GHz is **omitted** to prevent false roaming attempts through concrete slabs. |

---

## 5. File Inventory

- [`etc/config/network`](tl-wr841n-v14/etc/config/network): Static IP `192.168.1.2`, Gateway `192.168.1.1`, DNS `192.168.1.3`, all 5 ports bridged.
- [`etc/config/wireless`](tl-wr841n-v14/etc/config/wireless): Radio configuration for Channel 11, 802.11r/k.
- [`etc/config/dhcp`](tl-wr841n-v14/etc/config/dhcp): DHCP daemon set to `ignore '1'` (Access Point bridge mode).
- [`etc/config/system`](tl-wr841n-v14/etc/config/system): System hostname, timezone (`IST-5:30`), and LED triggers.
- [`etc/rc.local`](tl-wr841n-v14/etc/rc.local): Boot trigger for wireless and delayed 802.11k neighbor injection.
- [`scripts/set-rrm-neighbors.sh`](tl-wr841n-v14/scripts/set-rrm-neighbors.sh): Injects 802.11k neighbor report into `hostapd` via ubus.
- [`dts/`](tl-wr841n-v14/dts/): Hardware device tree source and patch files.
