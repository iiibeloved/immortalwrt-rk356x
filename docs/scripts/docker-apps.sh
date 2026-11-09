#!/bin/sh
# =============================================================================
#  docker-apps.sh —— 按清单安装 docker 应用（幂等：重复执行=重建容器）
#  修改下面 APPS 列表后执行： sh /tmp/docker-apps.sh
#  格式（用 | 分隔）：
#    名称|镜像|网络(host 或 bridge)|端口映射(host:container 或 -)|卷(宿主:容器;多个用 ,)|环境(多个用 ,)|附加参数
#  说明：卷/环填 - 表示不设置
# =============================================================================
set -u
log(){ echo "$(date '+%F %T') $*"; }

ROOT_DIR=${ROOT_DIR:-/mnt/nvme0/docker}

APPS="
homeassistant|ghcr.io/home-assistant/home-assistant:stable|host|-|$ROOT_DIR/homeassistant:/config|TZ=Asia/Shanghai|--restart unless-stopped --privileged
"

install_app() {
    name=$1; image=$2; net=$3; ports=$4; vols=$5; envs=$6; extra=$7

    log "=== [$name] 镜像 $image ==="
    docker pull "$image" || { log "❌ pull 失败: $name"; return 1; }

    # 组装参数
    set -- run -d --name "$name"
    [ "$net" = "host" ] && set -- "$@" --network host
    [ "$net" = "bridge" ] && set -- "$@" --network bridge
    if [ "$ports" != "-" ]; then
        IFS=','
        for pm in $ports; do set -- "$@" -p "$pm"; done
        unset IFS
    fi
    if [ "$vols" != "-" ]; then
        IFS=','
        for v in $vols; do
            host="${v%%:*}"
            mkdir -p "$host" 2>/dev/null || true
            set -- "$@" -v "$v"
        done
        unset IFS
    fi
    if [ "$envs" != "-" ]; then
        IFS=','
        for e in $envs; do set -- "$@" -e "$e"; done
        unset IFS
    fi
    # extra 里的空格参数
    for a in $extra; do set -- "$@" "$a"; done
    set -- "$@" "$image"

    docker rm -f "$name" >/dev/null 2>&1 || true
    log "执行: docker $*"
    docker "$@" || { log "❌ 启动失败: $name"; return 1; }
    sleep 2
    docker ps --filter "name=^/${name}$" --format '  ✅ {{.Names}} {{.Status}} {{.Image}}'
}

echo "$APPS" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in \#*) continue;; esac
    IFS='|'
    # shellcheck disable=SC2086
    set -- $line
    unset IFS
    [ $# -ge 6 ] || { log "跳过格式不完整的行: $line"; continue; }
    install_app "$1" "$2" "$3" "$4" "$5" "$6" "${7:--}"
done

log "=== 当前容器 ==="
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
log "提示：高级应用（Jellyfin/qBittorrent 等）建议用 LuCI → Docker → 容器 图形化配置，或把上面的 APPS 行补全后重跑本脚本。"
