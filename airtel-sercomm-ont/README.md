# Primary Gateway: Airtel Sercomm GPON ONT

This directory documents the configuration, role, and network settings of the primary edge gateway: the **Airtel Sercomm GPON Optical Network Terminal (ONT)**.

---

## 1. Gateway Overview

| Parameter | Configuration |
| :--- | :--- |
| **Model** | Sercomm GPON ONT (Airtel Xstream Fiber) |
| **IP Address** | `192.168.1.1` |
| **Subnet Mask** | `255.255.255.0` (`/24`) |
| **WAN Uplink** | GPON Fiber (PPPoE encapsulation over VLAN 100) |
| **LAN DHCP Server** | **Active** (Manages primary DHCP leases for all network clients) |
| **Wi-Fi Radios** | **Disabled** (Turned OFF to avoid co-channel RF interference) |
| **Core Functions** | Fiber Termination, PPPoE Authentication, NAT, SPI Firewall, DHCP Gateway |

---

## 2. DHCP Server Configuration

The ONT handles IP lease allocation for all dynamic clients while reserving the lower IP block for static infrastructure:

```
Subnet Range: 192.168.1.0 / 24
+---------------------------+-----------------------------------------------+
| IP Range                  | Purpose                                       |
+---------------------------+-----------------------------------------------+
| 192.168.1.1               | Airtel Sercomm ONT (Default Gateway)          |
| 192.168.1.2               | Node 1: TP-Link TL-WR841N v14 (Downstairs AP) |
| 192.168.1.3               | Node 2: TP-Link Archer C20 v5 (Upstairs / DoT)|
| 192.168.1.4 - 192.168.1.5 | Network Printers (Brother & Epson)            |
| 192.168.1.6 - 192.168.1.8 | Infrastructure Buffer (Reserved)              |
| 192.168.1.9 - 192.168.1.19| IoT, Cameras, Smart Plugs & Fans              |
| 192.168.1.20 - 192.168.1.29| Desktop Workstations                          |
| 192.168.1.30 - 192.168.1.39| Smart TVs & Streaming Devices                 |
| 192.168.1.40 - 192.168.1.49| Mobile Devices & Tablets                      |
| 192.168.1.50 - 192.168.1.254| Dynamic DHCP Pool                             |
+---------------------------+-----------------------------------------------+
```

### DHCP Option Delivery
- **Router Option (Option 3):** `192.168.1.1` (all client traffic defaults directly to the fiber gateway).
- **DNS Server Option (Option 6):**
  - **Primary DNS:** `192.168.1.3` (Archer C20 v5 running Stubby DNS-over-TLS).
  - **Secondary DNS:** `1.1.1.1` (Cloudflare fallback).

---

## 3. Wi-Fi Offloading Strategy

To ensure deterministic 802.11r Fast Roaming across the house:
1. **Internal Wi-Fi Disabled:** The Sercomm ONT's built-in 2.4 GHz and 5 GHz Wi-Fi radios are completely disabled in the web management portal (`http://192.168.1.1`).
2. **Eliminates RF Pollution:** Prevents three overlapping 2.4 GHz APs in close proximity and ensures the 2.4 GHz spectrum is cleanly divided into non-overlapping **Channel 11** (Node 1) and **Channel 6** (Node 2).
3. **Roaming Compliance:** Commercial ISP ONTs do not support 802.11r/k neighbor coordination; offloading all wireless traffic to OpenWrt nodes guarantees sub-50ms handoffs.

---

## 4. NAT & Firewall Rules

- **NAT Traversal:** Full-Cone NAT enabled for VoIP / gaming / WebRTC.
- **Firewall Level:** Standard SPI Firewall enabled.
- **Port Forwarding:** Managed on the ONT for any incoming services, forwarding directly to the target static IP.
