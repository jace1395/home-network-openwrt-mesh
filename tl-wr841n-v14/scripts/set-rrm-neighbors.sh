#!/bin/sh
# ==============================================================================
# 802.11k Radio Resource Measurement (RRM) Neighbor Report Configuration
# Device: Node 1 - TP-Link TL-WR841N v14 (Operating on Channel 11, 2.4 GHz)
# ==============================================================================
# Purpose:
#   Directs roaming-capable 802.11k clients on Node 1 (downstairs) to target
#   Node 2 (Archer C20 2.4 GHz) as the primary roaming candidate.
#   NOTE: 5 GHz is intentionally EXCLUDED from this report to prevent clients
#   from attempting to connect to 5 GHz through concrete ceilings/slabs.
# ==============================================================================

# Target BSSID of Node 2 (Archer C20 2.4 GHz radio)
# Replace with the actual BSSID of your second mesh access point:
TARGET_C20_2G_BSSID="aa:bb:cc:00:00:03"
SSID_NAME="HomeMesh-WiFi"

# Hex Neighbor Subelement breakdown:
# BSSID (6B) | BSSID Info (4B) | OpClass (1B) | Channel (1B) | PHY (1B) | Subelements
# Target: Ch 6 (0x06), OpClass 81 (0x51), PHY HT (0x07)
TARGET_HEX="$(echo ${TARGET_C20_2G_BSSID} | tr -d ':')ef0900005106070603000600"

ubus call hostapd.wlan0 rrm_nr_set "{
  \"list\": [
    [\"${TARGET_C20_2G_BSSID}\", \"${SSID_NAME}\", \"${TARGET_HEX}\"]
  ]
}"
