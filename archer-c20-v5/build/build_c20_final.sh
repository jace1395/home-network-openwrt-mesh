#!/bin/bash
# ==============================================================================
# OpenWrt 22.03.6 Custom Firmware Builder for TP-Link Archer C20 v5
# ==============================================================================
# Features:
# - Full LuCI WebUI (HTTP + HTTPS)
# - Stubby DNS-over-TLS (Cloudflare & Google DoT upstream)
# - Bridged 5-port switch topology (1 WAN + 4 LAN as unified LAN)
# - Pre-configured 802.11r/k Fast Roaming
# ==============================================================================
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

IB_DIR="${OPENWRT_IB_DIR:-/root/openwrt-imagebuilder-22.03.6-ramips-mt76x8.Linux-x86_64}"
FILES_DIR="$IB_DIR/files"

rm -rf "$FILES_DIR"
mkdir -p "$FILES_DIR/etc/uci-defaults"
mkdir -p "$FILES_DIR/etc/hotplug.d/ieee80211"
mkdir -p "$FILES_DIR/etc/config"
mkdir -p "$FILES_DIR/usr/sbin"

# 0. Shared Wi-Fi initialization helper
cat << 'EOF' > "$FILES_DIR/usr/sbin/init-mesh-wifi.sh"
#!/bin/sh
changed=0
for iface in $(uci show wireless 2>/dev/null | grep "=wifi-iface" | cut -d. -f2 | cut -d= -f1); do
    cur_ssid="$(uci -q get wireless.${iface}.ssid)"
    if [ -z "$cur_ssid" ] || [ "$cur_ssid" = "OpenWrt" ]; then
        dev="$(uci -q get wireless.${iface}.device)"
        [ -n "$dev" ] && uci set wireless.${dev}.disabled='0'
        uci set wireless.${iface}.ssid='HomeMesh-WiFi'
        uci set wireless.${iface}.encryption='psk2'
        uci set wireless.${iface}.key='ChangeThisToYourSecurePassword123'
        uci set wireless.${iface}.ieee80211r='1'
        uci set wireless.${iface}.mobility_domain='1395'
        uci set wireless.${iface}.ft_over_ds='0'
        uci set wireless.${iface}.ft_psk_generate_local='1'
        uci set wireless.${iface}.ieee80211k='1'
        changed=1
    fi
done
if [ "$changed" = "1" ]; then
    uci commit wireless
    wifi reload 2>/dev/null || true
fi
exit 0
EOF
chmod 755 "$FILES_DIR/usr/sbin/init-mesh-wifi.sh"

# 1. First-boot UCI defaults script
cat << 'EOF' > "$FILES_DIR/etc/uci-defaults/99-custom-c20-setup"
#!/bin/sh

# Set hostname and timezone
uci set system.@system[0].hostname='OpenWrt-ArcherC20'
uci set system.@system[0].timezone='IST-5:30'
uci set system.@system[0].zonename='Asia/Kolkata'
uci commit system

# 1. Network configuration: Static IP 192.168.1.3, Gateway 192.168.1.1, DNS 127.0.0.1
uci set network.lan.ipaddr='192.168.1.3'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.gateway='192.168.1.1'
uci -q delete network.lan.dns
uci add_list network.lan.dns='127.0.0.1'

# Bridge WAN port (port 0) into LAN switch so all 5 physical ports act as LAN
uci -q set network.@switch_vlan[0].ports='0 1 2 3 4 6t'
uci -q delete network.@switch_vlan[1]
uci -q delete network.wan
uci -q delete network.wan6
uci commit network

# 2. DHCP server disabled (all IP assignments handled by Primary Gateway 192.168.1.1)
uci set dhcp.lan.ignore='1'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.start='9'
uci set dhcp.lan.limit='245'
uci set dhcp.lan.leasetime='12h'
uci -q delete dhcp.lan.dhcp_option
uci add_list dhcp.lan.dhcp_option='3,192.168.1.1'
uci add_list dhcp.lan.dhcp_option='6,192.168.1.3'

# Dnsmasq: forward all DNS to local Stubby DoT (5453)
uci set dhcp.@dnsmasq[0].noresolv='1'
uci set dhcp.@dnsmasq[0].localservice='1'
uci -q delete dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server='/pool.ntp.org/1.1.1.1'
uci add_list dhcp.@dnsmasq[0].server='/pool.ntp.org/8.8.8.8'
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5453'
uci add_list dhcp.@dnsmasq[0].server='::1#5453'
uci commit dhcp

# 3. Stubby DNS-over-TLS configuration (Cloudflare 1.1.1.1 + Google 8.8.8.8)
uci set stubby.global.manual='0'
uci set stubby.global.trigger='lan'
uci set stubby.global.tls_authentication='1'
uci set stubby.global.round_robin_upstreams='1'

while uci -q delete stubby.@resolver[0]; do :; done
uci add stubby resolver
uci set stubby.@resolver[-1].address='1.1.1.1'
uci set stubby.@resolver[-1].tls_auth_name='cloudflare-dns.com'

uci add stubby resolver
uci set stubby.@resolver[-1].address='1.0.0.1'
uci set stubby.@resolver[-1].tls_auth_name='cloudflare-dns.com'

uci add stubby resolver
uci set stubby.@resolver[-1].address='8.8.8.8'
uci set stubby.@resolver[-1].tls_auth_name='dns.google'

uci add stubby resolver
uci set stubby.@resolver[-1].address='8.8.4.4'
uci set stubby.@resolver[-1].tls_auth_name='dns.google'
uci commit stubby

# Allow both HTTP and HTTPS LuCI WebUI without forced redirect
uci -q set uhttpd.main.redirect_https='0'
uci -q commit uhttpd

# 4. LED Configuration for Archer C20 v5
uci -q delete system.led_lan
uci set system.led_lan='led'
uci set system.led_lan.name='LAN'
uci set system.led_lan.sysfs='green:lan'
uci set system.led_lan.trigger='switch0'
uci set system.led_lan.port_mask='0x1f'

uci -q delete system.led_wan
uci set system.led_wan='led'
uci set system.led_wan.name='WAN'
uci set system.led_wan.sysfs='green:wan'
uci set system.led_wan.trigger='switch0'
uci set system.led_wan.port_mask='0x01'

uci -q delete system.led_wlan2g
uci set system.led_wlan2g='led'
uci set system.led_wlan2g.name='WLAN2G'
uci set system.led_wlan2g.sysfs='green:wlan2g'
uci set system.led_wlan2g.trigger='phy0tpt'

uci -q delete system.led_wlan5g
uci set system.led_wlan5g='led'
uci set system.led_wlan5g.name='WLAN5G'
uci set system.led_wlan5g.sysfs='green:wlan5g'
uci set system.led_wlan5g.trigger='phy1tpt'
uci commit system

# 5. Initialize Dual-Band Wireless
[ -s /etc/config/wireless ] || wifi config
/usr/sbin/init-mesh-wifi.sh

/etc/init.d/stubby enable
/etc/init.d/uhttpd enable

exit 0
EOF
chmod 755 "$FILES_DIR/etc/uci-defaults/99-custom-c20-setup"

# 2. Wireless Hotplug script
cat << 'EOF' > "$FILES_DIR/etc/hotplug.d/ieee80211/99-custom-wifi"
#!/bin/sh
[ "${ACTION}" = "add" ] && {
    sleep 2
    [ -x /usr/sbin/init-mesh-wifi.sh ] && /usr/sbin/init-mesh-wifi.sh
}
EOF
chmod 755 "$FILES_DIR/etc/hotplug.d/ieee80211/99-custom-wifi"

# 3. rc.local startup verification & post-NTP Stubby refresh
cat << 'EOF' > "$FILES_DIR/etc/rc.local"
[ -x /usr/sbin/init-mesh-wifi.sh ] && /usr/sbin/init-mesh-wifi.sh
(sleep 15 && /etc/init.d/stubby restart) &
(sleep 10 && /usr/sbin/set-rrm-neighbors.sh) &

exit 0
EOF
chmod 755 "$FILES_DIR/etc/rc.local"

# 4. Build image with custom packages
cd "$IB_DIR"
make image PROFILE="tplink_archer-c20-v5" PACKAGES="luci luci-ssl stubby" FILES="files"

echo "Build successfully finished!"
