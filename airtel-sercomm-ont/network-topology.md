# Network Topology & Cabling Architecture

This document describes the physical cabling, switch port configurations, and logical Layer 2 / Layer 3 data flows.

> [!NOTE]
> **Floor Layout:** All primary rooms and network routers are located on the **SAME single floor in a line**:
> `[Room 1 (Gateway & Node 1) (1.1 & 1.2)] <──▶ [Kitchen Area] <──▶ [Hallway (1.3)] <──▶ [Room 2 (Node 2 / Client Room)]`
> The only cable leaving this floor is the dedicated line running from Node 1 (WR841N) up to the Terrace PC.

---

## 1. Physical Layout & Star Topology Cabling

```
                                      +------------------------------------+
                                      |    Airtel Xstream Fiber (GPON)     |
                                      +-----------------+------------------+
                                                        |
                                                        v
+-------------------------------------------------------+-------------------------------------------------------+
|                                        Airtel Sercomm ONT (192.168.1.1)                                       |
|                                        Location: Room 1 (Gateway & Node 1) (Same Floor)                                     |
| [Port 1 / LAN] ──▶ Connected directly to Node 1 (TL-WR841N v14 Port 0)                                       |
| [Port 2 / LAN] ──▶ Workstation 2 (Wired Gigabit/Fast Ethernet)                                                      |
| [Port 3 / LAN] ──▶ Media TV 1 (Wired Fast Ethernet)                                                              |
| [Port 4 / LAN] ──▶ Connected directly to Node 2 (Archer C20 v5 Port 0 via Hallway Trunk Cable)                 |
+---------------------------+-------------------------------------------------------+---------------------------+
                            | (Port 1)                                              | (Port 4)
                            v                                                       v
+---------------------------+---------------------------+       +-------------------+---------------------------+
| Node 1: TP-Link TL-WR841N v14 (192.168.1.2)           |       | Node 2: TP-Link Archer C20 v5 (192.168.1.3)           |
| Location: Room 1 (Gateway & Node 1) (Same Floor)                    |       | Location: Hallway (Same Floor)                        |
| - [Port 0 / WAN] ──▶ Uplink from Airtel ONT Port 1     |       | - [Port 0 / WAN] ──▶ Uplink from Airtel ONT Port 4     |
| - [Port 1 / LAN] ──▶ Terrace PC (Win7 via Roof Run)   |       | - [Port 2 / LAN] ──▶ Workstation 1 (Realtek GbE)    |
| - [Port 2,3,4]   ──▶ Spare LAN Ports                  |       | - [Port 1,3,4]   ──▶ Spare LAN Ports                  |
| - [Radio 0]      ──▶ 2.4 GHz Wi-Fi AP (Ch 11 @ 18 dBm)|       | - [Radio 0]      ──▶ 2.4 GHz Wi-Fi AP (Ch 6 @ 21 dBm) |
|                                                       |       | - [Radio 1]      ──▶ 5 GHz Wi-Fi AP (Ch 149 @ 12 dBm) |
|                                                       |       | - [Services]     ──▶ Stubby DNS-over-TLS (Port 5453)  |
+-------------------------------------------------------+       +-------------------------------------------------------+
```

---

## 3. Logical Layer 2 (L2) Architecture

- **Single Broadcast Domain:** Both OpenWrt nodes have WAN ports bridged into `switch0` (VLAN 1).
- **Zero Double-NAT:** There is only one Layer 3 subnet (`192.168.1.0/24`). All devices, whether connected via Ethernet to the ONT, WR841N, or C20, or connected via Wi-Fi to either node, communicate directly over Layer 2 with sub-1ms local latency.
- **Unified Roaming:** Wi-Fi clients roam seamlessly between Node 1 and Node 2 using 802.11r FT and 802.11k RRM neighbor reports without IP lease renegotiation.
