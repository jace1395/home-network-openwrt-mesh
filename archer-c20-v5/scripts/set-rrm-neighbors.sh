#!/bin/sh
# ==============================================================================
# 802.11k Radio Resource Measurement (RRM) Neighbor Report Configuration
# Device: Node 2 - TP-Link Archer C20 v5 (Dual-Band 2.4 GHz + 5 GHz)
# ==============================================================================
# Roaming Architecture:
# 1. 2.4 GHz radio (wlan0, Channel 6):
#    ONLY advertises Node 1 (TL-WR841N on Channel 11).
#    Does NOT advertise 5 GHz to prevent client ping-ponging/flapping in rooms
#    where 5 GHz is marginal (-75 dBm to -82 dBm).
#
# 2. 5 GHz radio (wlan1, Channel 149):
#    Advertises both Node 1 (2.4 GHz) and Node 2's own 2.4 GHz radio (wlan0).
#    When clients move away from the hall and 5 GHz degrades, they are instantly
#    guided down to 2.4 GHz without connection drops.
# ==============================================================================

# Target BSSID of Node 1 (TL-WR841N v14 on 2.4 GHz Channel 11)
TARGET_WR841_BSSID="aa:bb:cc:00:00:02"

# BSSID of Node 2's own 2.4 GHz radio (Archer C20 on Channel 6)
LOCAL_C20_2G_BSSID="aa:bb:cc:00:00:03"

SSID_NAME="HomeMesh-WiFi"

# Hex Neighbor Subelement breakdown:
# BSSID (6B) | BSSID Info (4B) | OpClass (1B) | Channel (1B) | PHY (1B) | Subelements
# WR841N Ch 11 (0x0b), OpClass 81 (0x51), PHY HT (0x07)
WR841_HEX="$(echo ${TARGET_WR841_BSSID} | tr -d ':')af090000510b070603000b00"

# C20 Ch 6 (0x06), OpClass 81 (0x51), PHY HT (0x07)
C20_2G_HEX="$(echo ${LOCAL_C20_2G_BSSID} | tr -d ':')ef0900005106070603000600"

# 1. Inject neighbor report into 2.4 GHz hostapd instance
ubus call hostapd.wlan0 rrm_nr_set "{
  \"list\": [
    [\"${TARGET_WR841_BSSID}\", \"${SSID_NAME}\", \"${WR841_HEX}\"]
  ]
}"

# 2. Inject neighbor report into 5 GHz hostapd instance
ubus call hostapd.wlan1 rrm_nr_set "{
  \"list\": [
    [\"${TARGET_WR841_BSSID}\", \"${SSID_NAME}\", \"${WR841_HEX}\"],
    [\"${LOCAL_C20_2G_BSSID}\", \"${SSID_NAME}\", \"${C20_2G_HEX}\"]
  ]
}"
