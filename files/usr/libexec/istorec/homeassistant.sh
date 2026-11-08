#!/bin/sh
# =============================================================================
#  覆盖 iStore 的 homeassistant.sh（上游 luci-app-homeassistant/root/usr/libexec/istorec/homeassistant.sh）
#
#  改动点（仅 do_hacs_install）：
#    Home Assistant 自 2026.11 起内置 Marketplace 取代 HACS，HACS 安装脚本会直接报
#      ERROR: HACS does not work on Home Assistant 2026.11 and newer ...
#    原来这一步在安装日志里显示为失败（INFO/ERROR 混在一起），容易误判成「装坏了」。
#    这里先读容器内 /config/.HA_VERSION，>= 2026.11 就跳过并打印使用提示。
#    其余逻辑与上游一致。
# =============================================================================

ACTION=${1}
shift 1

istoreenhance_pull() {
  local image_name="$1"
  echo "docker pull ${image_name}"
  docker pull "$image_name"
  if [ $? -ne 0 ]; then
    local isInstall=$(command -v iStoreEnhance)
    local isRun=$(pgrep iStoreEnhance)
    if [ -n "$isRun" ]; then
      local registry_mirror=$(docker info 2>/dev/null | awk -F': ' '/Registry Mirrors:/ {found=1; next} found && NF {if ($0 ~ /registry.linkease.net/) {print; exit}}')
      if [[ -n "$registry_mirror" ]]; then
        echo "istoreenhance_pull failed"
      else
        echo "download failed, not found registry.linkease.net"
      fi
    else
      if [ -z "$isInstall" ]; then
        echo "download failed, install istoreenhance to speedup, \"https://doc.linkease.com/zh/guide/istore/software/istoreenhance.html\""
      else
        echo "download failed, enable istoreenhance to speedup"
      fi
    fi
    exit 1
  fi
}

ha_version() {
  docker exec homeassistant cat /config/.HA_VERSION 2>/dev/null | head -1 | tr -d ' \r\n'
}

hacs_supported() {   # $1=版本号  -> 0 支持 / 1 不支持
  local v="$1" major minor
  [ -n "$v" ] || return 1
  major=$(echo "$v" | cut -d. -f1); minor=$(echo "$v" | cut -d. -f2)
  case "$major" in ''|*[!0-9]*) return 1;; esac
  case "$minor" in ''|*[!0-9]*) minor=0;; esac
  [ "$major" -gt 2026 ] && return 1
  [ "$major" -eq 2026 ] && [ "$minor" -ge 11 ] && return 1
  return 0
}

do_install() {
  local config=`uci get homeassistant.@homeassistant[0].config_path 2>/dev/null`
  local IMAGE_NAME=`uci get homeassistant.@homeassistant[0].image_name 2>/dev/null`
  local tz=`uci get homeassistant.@homeassistant[0].time_zone 2>/dev/null`

  if [ -z "$config" ]; then
      echo "config path is empty!"
      exit 1
  fi

  istoreenhance_pull ${IMAGE_NAME}
  docker rm -f homeassistant

  local cmd="docker run --restart=unless-stopped -d \
    -v \"$config:/config\" \
    --privileged \
    --network=host \
    --dns=127.0.0.1 "

  if [ -z "$tz" ]; then
    tz="`uci get system.@system[0].zonename | sed 's/ /_/g'`"
  fi
  [ -z "$tz" ] || cmd="$cmd -e TZ=$tz"

  cmd="$cmd --name homeassistant \"$IMAGE_NAME\""

  echo "$cmd"
  eval "$cmd"

  RET=$?
  if [ "$RET" = "0" ]; then
    echo "Wait 10 seconds for homeassistant boot..."
    sleep 10
    do_hacs_install
  fi
}

do_hacs_install() {
  local ver
  ver=$(ha_version)
  if ! hacs_supported "$ver"; then
    echo "检测到 Home Assistant ${ver:-未知版本}: HACS 自 2026.11 起由内置 Marketplace 取代, 跳过 HACS 安装"
    echo "使用方式: HA 界面 → 设置 → Marketplace (右上角 Add from link 可加自定义 GitHub 仓库)"
    echo "加速: Marketplace 右上角 ⋮ → Download source → Chinese Community Relays"
    docker restart homeassistant >/dev/null 2>&1
    return 0
  fi

  echo "Install HACS"
  echo "rm -f custom_components/hacs.zip config/custom_components/hacs.zip ; wget -O - https://get.hacs.xyz | bash -" | docker exec -i homeassistant bash -
  sleep 3
  echo "restart homeassistant"
  docker restart homeassistant
  return 0
}

usage() {
  echo "usage: $0 sub-command"
  echo "where sub-command is one of:"
  echo "      install                Install the homeassistant"
  echo "      upgrade                Upgrade the homeassistant"
  echo "      rm/start/stop/restart  Remove/Start/Stop/Restart the homeassistant"
  echo "      status                 Home Assistant status"
  echo "      port                   Home Assistant port"
  echo "      hacs-install           Install HACS (auto-skipped on HA >= 2026.11)"
}

case ${ACTION} in
  "install") do_install ;;
  "upgrade") do_install ;;
  "rm") docker rm -f homeassistant ;;
  "start" | "stop" | "restart") docker ${ACTION} homeassistant ;;
  "status") docker ps --all -f 'name=^/homeassistant$' --format '{{.State}}' ;;
  "port") docker ps --all -f 'name=^/homeassistant$' --format '{{.Ports}}' | grep -om1 '0.0.0.0:[0-9]*' | sed 's/0.0.0.0://' ;;
  "hacs-install") do_hacs_install ;;
  *) usage; exit 1 ;;
esac
