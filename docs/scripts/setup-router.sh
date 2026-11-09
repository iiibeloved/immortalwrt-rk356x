#!/bin/sh
# =============================================================================
#  setup-router.sh —— 刷完固件后的基础配置（幂等，可重复执行）
#  覆盖：时区/主机名、WAN 连通性、NVMe 挂载确认、docker 数据目录、iStore 路径
#  用法：在路由器上 root 执行  sh /tmp/setup-router.sh
# =============================================================================
set -u
LOG=/tmp/setup-router.log
NVME_MP=${NVME_MP:-/mnt/nvme0}
DATA_MP=${DATA_MP:-/mnt/data}
DOCKER_DIR=${DOCKER_DIR:-$NVME_MP/docker}

log(){ echo "$(date '+%F %T') $*" | tee -a "$LOG"; }
need_root(){ [ "$(id -u)" = "0" ] || { echo "请用 root 执行"; exit 1; }; }

need_root
log "===== 开始配置 ====="

# 1) 主机名 / 时区
uci set system.@system[0].hostname="${HOSTNAME_SET:-NSY-G68}"
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system
log "主机名/时区已设置"

# 2) 等 WAN 就绪（最多 60 秒）
i=0
while [ "$i" -lt 12 ]; do
    ping -c1 -W2 223.5.5.5 >/dev/null 2>&1 && break
    sleep 5; i=$((i+1))
done
if ping -c1 -W2 223.5.5.5 >/dev/null 2>&1; then
    log "外网连通 ✅"
else
    log "⚠️ 外网不通，请检查 WAN/上级路由；后续 docker pull 会失败"
fi

# 3) NVMe 挂载确认（等最多 30 秒）
i=0
while [ "$i" -lt 6 ]; do
    grep -q " $NVME_MP " /proc/mounts && break
    sleep 5; i=$((i+1))
done
if grep -q " $NVME_MP " /proc/mounts; then
    log "NVMe 已挂载: $NVME_MP ($(df -h "$NVME_MP" | awk 'NR==2{print $2" 可用"$4}'))"
else
    log "⚠️ $NVME_MP 未挂载：空白盘不会被自动格式化，请先手动分区+格式化+挂载（见 build-guide 7.6）"
fi

# 4) docker 数据目录
if grep -q " $NVME_MP " /proc/mounts || grep -q " $DATA_MP " /proc/mounts; then
    mkdir -p "$DOCKER_DIR"
    /etc/init.d/dockerd stop >/dev/null 2>&1 || true
    cur=$(uci -q get dockerd.globals.data_root)
    if [ "$cur" != "$DOCKER_DIR" ]; then
        # 迁移旧数据（若 /opt/docker 有内容）
        if [ -d /opt/docker ] && [ -n "$(ls -A /opt/docker 2>/dev/null)" ]; then
            log "迁移旧 docker 数据 /opt/docker -> $DOCKER_DIR"
            cp -a /opt/docker/. "$DOCKER_DIR"/ 2>/dev/null || true
        fi
        uci set dockerd.globals.data_root="$DOCKER_DIR"
        uci commit dockerd
        log "dockerd.globals.data_root = $DOCKER_DIR"
    else
        log "dockerd.globals.data_root 已是 $DOCKER_DIR"
    fi
    /etc/init.d/dockerd start >/dev/null 2>&1 || true
    sleep 2
    docker info 2>/dev/null | grep -i 'docker root dir' | tee -a "$LOG"
else
    log "⚠️ 没有已挂载的数据盘，docker 保持默认 /opt/docker（overlay 4 GiB）"
fi

# 5) iStore 应用数据目录（若 /mnt 有盘）
if grep -q " $NVME_MP " /proc/mounts; then
    uci set istore.istore.last_path="$NVME_MP" 2>/dev/null
    uci commit istore 2>/dev/null && log "iStore 存储位置 = $NVME_MP"
elif grep -q " $DATA_MP " /proc/mounts; then
    uci set istore.istore.last_path="$DATA_MP" 2>/dev/null
    uci commit istore 2>/dev/null && log "iStore 存储位置 = $DATA_MP"
fi

# 6) HA 配置路径（若有）
hap=$(uci -q get homeassistant.@homeassistant[0].config_path 2>/dev/null)
[ -n "$hap" ] && log "HA 配置路径 = $hap"

# 7) 一次性脚本状态 + 自检
n=$(ls /etc/uci-defaults/ 2>/dev/null | wc -l)
log "uci-defaults 剩余: $n （0 表示一次性脚本已跑完）"
command -v firstboot-status >/dev/null 2>&1 && firstboot-status | sed 's/\x1b\[[0-9;]*m//g' | tee -a "$LOG"

log "===== 基础配置完成，日志: $LOG ====="
