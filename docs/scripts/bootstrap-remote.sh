#!/bin/sh
# =============================================================================
#  bootstrap-remote.sh —— 在路由器上执行一次，允许 NAS 从 WAN 侧 SSH 接管
#  用法：笔记本 ssh root@192.168.100.1 后整段粘贴执行
#  安全：只放行 192.168.6.88 这一个源 IP；用完可删规则
# =============================================================================
set -u
NAS_IP="${NAS_IP:-192.168.6.88}"
TEMP_PASS="${TEMP_PASS:-Nasy-Temp2026}"

echo "== 1) 放行 NAS 从 WAN 访问 SSH =="
uci -q delete firewall.temp_nas_ssh
uci set firewall.temp_nas_ssh=rule
uci set firewall.temp_nas_ssh.name='temp-allow-ssh-from-nas'
uci set firewall.temp_nas_ssh.src='wan'
uci set firewall.temp_nas_ssh.src_ip="$NAS_IP"
uci set firewall.temp_nas_ssh.proto='tcp'
uci set firewall.temp_nas_ssh.dest_port='22'
uci set firewall.temp_nas_ssh.target='ACCEPT'
uci commit firewall
echo "   📌 规则已添加（仅 $NAS_IP 可用）"

echo "== 2) dropbear 监听所有地址 =="
uci -q delete dropbear.@dropbear[0].Interface
uci commit dropbear
/etc/init.d/dropbear restart >/dev/null 2>&1

echo "== 3) 重载防火墙 =="
/etc/init.d/firewall reload >/dev/null 2>&1

echo "== 4) 设置临时 root 密码 =="
echo "root:$TEMP_PASS" | chpasswd
echo "   📌 临时密码: $TEMP_PASS"

echo
echo "===== 请把下面 3 行发给助手 ====="
echo "LAN_IP: $(uci -q get network.lan.ipaddr)"
for i in $(ls /sys/class/net | grep -E '^(eth|wan)'); do
    ip -4 addr show dev "$i" 2>/dev/null | awk -v d="$i" '/inet /{print "IFACE("d"): "$2}'
done
echo "FIREWALL_RULE: temp-allow-ssh-from-nas ($NAS_IP -> 22/tcp wan)"
echo "=================================="
