# Home Network OpenWrt Mesh & Edge Gateway Infrastructure

[![License](https://img.shields.io/badge/License-All%20Rights%20Reserved-red.svg)](LICENSE)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-19.07%20%7C%2022.03-blue.svg)](https://openwrt.org/)
[![Fast Roaming](https://img.shields.io/badge/Roaming-802.11r%20%7C%20802.11k-brightgreen.svg)]()
[![DNS](https://img.shields.io/badge/DNS-over--TLS%20(DoT)-purple.svg)]()

Production-grade, privacy-hardened home network infrastructure engineered using low-power commodity Wi-Fi routers flashed with custom **OpenWrt** firmware, operating alongside a fiber **GPON ONT** gateway.

Delivers seamless **IEEE 802.11r/k Fast Roaming**, whole-house encrypted **DNS-over-TLS (DoT)**, calibrated radio propagation boundaries, and a single flat **Layer 2 (L2) broadcast domain** without Double-NAT.

---

## 1. Network Architecture & Topology

```
                                  +------------------------------------+
                                  |    Airtel Xstream Fiber (GPON)     |
                                  +-----------------+------------------+
                                                    | (VLAN 100 - PPPoE)
                                                    v
                                  +-----------------+------------------+
                                  |     Airtel Sercomm ONT (1.1)       |
                                  |   Location: Room 1 (Gateway & Node 1) (Same Floor) |
                                  |  - Wi-Fi Radios: Disabled          |
                                  |  - DHCP Server: Active (.9 - .254) |
                                  |  - Ports 2 & 3: Workstation 2 & Media TV 1  |
                                  +--------+------------------+--------+
                                           | (Port 1)         | (Port 4)
                        +------------------+                  +------------------+
                        |                                                        |
                        v                                                        v
+-----------------------+--------------+                         +---------------+----------------------+
| Node 1: TP-Link TL-WR841N v14 (1.2)  |                         | Node 2: TP-Link Archer C20 v5 (1.3)  |
| - Location: Room 1 (Gateway & Node 1) (Same Floor)   |                         | - Location: Hallway (Same Floor)     |
| - Port 1: Terrace PC (Win7 roof run) |                         | - Port 2: Workstation 1 (Ethernet) |
| - Firmware: OpenWrt 19.07.10 (Ath79) |                         | - Firmware: OpenWrt 22.03.6 (Ramips) |
| - Switch: 5 Ports Bridged (VLAN 1)   |                         | - Switch: 5 Ports Bridged (VLAN 1)   |
| - 2.4 GHz: Channel 11 @ 18 dBm (HT20)|                         | - 2.4 GHz: Channel 6 @ 21 dBm (HT20) |
| - 802.11r FT (Mobility Domain 1395)  |                         | - 5.0 GHz: Channel 149 @ 12 dBm(VHT80)|
| - 802.11k RRM (Advertises C20 2.4G)  |                         | - 802.11r FT & 802.11k Asymmetric RRM|
| - DHCP: Disabled (Bridge Mode)       |                         | - Stubby DNS-over-TLS (Port 5453)    |
|                                      |                         | - Physical Button RFKILL Disarmed    |
+--------------------------------------+                         +--------------------------------------+
```

---

## 2. Infrastructure Inventory

| Node | Model | SoC & Architecture | Memory / Flash | Firmware | IP Address | Primary Roles |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Gateway** | Airtel Sercomm ONT | MIPS GPON Processor | 128 MB / 128 MB | Sercomm Stock | `192.168.1.1` | Fiber Termination, PPPoE WAN, NAT, Master DHCP Server. |
| **Node 1** | TP-Link TL-WR841N v14 | MediaTek MT7628AN (580 MHz) | 32 MB / 4 MB | OpenWrt 19.07.10 | `192.168.1.2` | 2.4 GHz AP (Ch 11), 5-Port L2 Switch, 802.11r/k Mesh Node. |
| **Node 2** | TP-Link Archer C20 v5 | MT7628AN + MT7610E (580 MHz) | 64 MB / 8 MB | OpenWrt 22.03.6 | `192.168.1.3` | Dual-Band AP (Ch 6 / 149), 5-Port Switch, DNS-over-TLS Resolver. |

---

## 3. Engineering Highlights & Design Decisions

### A. Reviving 4MB Flash / 32MB RAM Hardware (TL-WR841N v14)
- **The Problem:** Modern OpenWrt (> 21.02) dropped official support for 4MB flash routers. TP-Link's v14 release lacked an official device profile in the legacy OpenWrt tree.
- **The Solution:** A custom Device Tree Source (`TL-WR841NV14.dts`) and patch were authored targeting `tplink,tl-wr841n-v14` on OpenWrt 19.07.10. Strip-down compilation with `wpad-basic-wolfssl` fits full 802.11r/k roaming capabilities into a lean ~3.8 MB image.

### B. Sub-50ms Fast Roaming (IEEE 802.11r & 802.11k)
- **Fast BSS Transition (802.11r):** Both nodes share Mobility Domain `1395` and local PMK-R1 key generation (`ft_psk_generate_local=1`), enabling cryptographic pre-authentication before disconnecting from an AP.
- **Asymmetric 802.11k Neighbor Reports:** Prevents client flapping/ping-ponging in rooms behind concrete walls:
  - Node 1 (WR841N) 2.4 GHz **only** advertises Node 2's 2.4 GHz radio (eliminates attempts to connect to 5 GHz through slabs).
  - Node 2 (C20) 2.4 GHz **only** advertises Node 1's 2.4 GHz radio.
  - Node 2 (C20) 5 GHz advertises both 2.4 GHz radios so attenuating clients drop cleanly to 2.4 GHz.

### C. Frequency Orthogonality & RF Power Calibration
- **Zero Co-Channel Interference:** Node 1 operates on **Channel 11** (2462 MHz) and Node 2 on **Channel 6** (2437 MHz). With HT20 channel widths, there is a clean 25 MHz inter-channel boundary.
- **Calibrated Transmit Powers:**
  - **Node 1 (WR841N):** Set to `18 dBm` (63 mW) to prevent sticky signal bleed into the hallway.
  - **Node 2 (Archer C20):** Set to `21 dBm` (125 mW) on 2.4 GHz for reliable penetration through closed bedroom doors (`-68 dBm` to `-71 dBm`, MCS 7).

### D. Centralized Encrypted DNS (Stubby DNS-over-TLS)
- All network clients receive DNS server IP `192.168.1.3` via DHCP Option 6.
- `dnsmasq` on Node 2 resolves local hostnames and forwards all external DNS queries over local loopback (`127.0.0.1#5453`) to **Stubby**.
- **Stubby** encrypts traffic over TLS 1.3 to **Cloudflare** (`1.1.1.1`) and **Google** (`8.8.8.8`) on port 853.
- **No-RTC Deadlock Solution:** `dnsmasq` directly routes NTP pool domains in plaintext during initial boot, allowing system time synchronization before TLS certificate verification begins.

### E. Physical Button Disarming (`rfkill` Fix)
- On the Archer C20 v5, the physical rear WPS/Wi-Fi button commonly causes accidental network dropouts when bumped.
- A custom handler at [`etc/rc.button/rfkill`](archer-c20-v5/etc/rc.button/rfkill) traps the release event, blinks the WPS LED for 10 seconds, and triggers WPS without disconnecting Wi-Fi.

---

## 4. Repository Structure

```
home-network-openwrt-mesh/
├── README.md                      # Master architecture & setup guide
├── LICENSE                        # All Rights Reserved personal copyright notice
├── .gitignore                     # Strictly ignores private credentials & binaries
├── reservations.example.txt       # Sanitized static IP allocation template
├── reservations.txt               # (Private, local only) Real IP & MAC reservations
│
├── airtel-sercomm-ont/            # Primary Gateway Documentation
│   ├── README.md                  # Sercomm ONT setup, PPPoE, DHCP & Wi-Fi offload
│   └── network-topology.md        # Physical cabling and Layer 2/3 diagrams
│
├── archer-c20-v5/                 # Node 2 (Archer C20 v5, Hallway / Upstairs)
│   ├── README.md                  # Build guide, DNS-over-TLS, button disarming
│   ├── etc/
│   │   ├── config/                # network, wireless, dhcp, system, stubby
│   │   ├── rc.local               # Post-boot init triggers
│   │   └── rc.button/rfkill       # Button disarm & WPS LED blinking handler
│   ├── scripts/
│   │   ├── set-rrm-neighbors.sh   # 802.11k neighbor injector
│   │   └── sync-dhcp-hosts.py     # Static reservation importer script
│   └── build/
│       └── build_c20_final.sh     # OpenWrt 22.03.6 ImageBuilder automated build script
│
└── tl-wr841n-v14/                 # Node 1 (TL-WR841N v14, Room / Downstairs)
    ├── README.md                  # 4MB Flash guide, Ath79 DTS patch, power tuning
    ├── etc/
    │   ├── config/                # network, wireless, dhcp, system
    │   └── rc.local               # Post-boot wireless & neighbor init
    ├── scripts/
    │   └── set-rrm-neighbors.sh   # 802.11k neighbor injector
    └── dts/
        ├── TL-WR841NV14.dts       # Device Tree Source for v14 hardware
        └── v14.patch              # Kernel ImageBuilder board profile patch
```

---

## 5. Deployment & Setup Guide

### 1. Configure the Gateway (Airtel Sercomm ONT)
1. Access web interface at `http://192.168.1.1`.
2. Disable 2.4 GHz and 5 GHz wireless radios under WLAN settings.
3. In DHCP Server settings:
   - IP Range: `192.168.1.9` to `192.168.1.254`
   - Subnet Mask: `255.255.255.0`
   - Gateway (Option 3): `192.168.1.1`
   - Primary DNS (Option 6): `192.168.1.3`
   - Secondary DNS: `1.1.1.1`

### 2. Deploy Node 1 (TL-WR841N v14)
1. Build OpenWrt 19.07.10 image using the provided DTS files in [`tl-wr841n-v14/dts/`](tl-wr841n-v14/dts/).
2. Flash image via TFTP recovery (`tp_recovery.bin`).
3. Deploy configuration files from [`tl-wr841n-v14/etc/config/`](tl-wr841n-v14/etc/config/).
4. Make scripts executable:
   ```sh
   chmod +x /etc/rc.local /usr/sbin/set-rrm-neighbors.sh
   ```

### 3. Deploy Node 2 (Archer C20 v5)
1. Execute [`archer-c20-v5/build/build_c20_final.sh`](archer-c20-v5/build/build_c20_final.sh) with OpenWrt 22.03.6 ImageBuilder.
2. Flash firmware via LuCI or TFTP recovery.
3. Deploy configurations from [`archer-c20-v5/etc/config/`](archer-c20-v5/etc/config/).
4. Deploy the physical button disarm handler:
   ```sh
   chmod +x /etc/rc.button/rfkill /etc/rc.local /usr/sbin/set-rrm-neighbors.sh
   ```

### 4. Populate Static Reservations
1. Copy [`reservations.example.txt`](reservations.example.txt) to `reservations.txt` and fill in your household devices.
2. Run the generator script:
   ```sh
   python archer-c20-v5/scripts/sync-dhcp-hosts.py reservations.txt
   sh import_hosts.sh
   ```

---

## 6. Privacy & Security Assurance

All files in this repository have been sanitized:
- **No private Wi-Fi passwords:** Default values replaced with standard configuration placeholders.
- **No real MAC addresses:** All BSSIDs and client hardware addresses sanitized using documentation ranges (`AA:BB:CC:...`).
- **Strict `.gitignore` policy:** Private reservation files (`reservations.txt`) and build binaries are strictly untracked.

---

## 7. License & Copyright

Copyright (c) 2026. All Rights Reserved.  
See [`LICENSE`](LICENSE) for terms of use.
