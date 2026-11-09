# 固件包清单（基线 · 2026-11-08）

> 由构建产物 `immortalwrt-rockchip-armv8-nsy_g68-plus.manifest` 直接生成，非手写。

- **当前产物**：run [#42464195953](https://github.com/iiibeloved/immortalwrt-rk356x/actions/runs/42464195953) · Release [`g68-plus-2026.11.08-r25`](https://github.com/iiibeloved/immortalwrt-rk356x/releases/tag/g68-plus-2026.11.08-r25) · **556 个包**（含 DDNS）
- **镜像 sha256**：`f41162a3a8c374c09fe1f2300a3d3c1b359be905b8e1e120a34ebedeca34d462`
- **r27 起新增**：`luci-app-partexp`（分区/扩容/挂载界面）、`kmod-loop`、`f2fs-tools`、`cfdisk`、`cgdisk` → 预计 **561 个包**
- 与更早版本（549 包）差异：+`kmod-fs-f2fs`、+`kmod-fs-xfs`、+`kmod-crypto-crc32`、+DDNS 5 包、+partexp 3 包

## 基线指纹

| 文件 | sha256 |
| --- | --- |
| `defconfig/g68-plus-istoreos.config` | `32dffbc71e0dbf3bc6c2b6dce784232840a1fc52a3a5ae3b49186171531f8be8` |
| `.github/workflows/build-g68-plus-docker.yml` | `2a0429c522b2ba7bbb516bb8cc5879be11e761cd04a2f8991768eab354ec0226` |
| `scripts/gen_image_generic.sh` | `f6d59494a9c88f5fe4e2175f00067eb5b5160a32b903b0a16f726a7b99903e98` |
| 固件镜像 `*.img.gz` | `d0dc8eb943aedf9614690a6dc3e512709360d83926d406c80653ad0fd312fa2f` |

### 内置脚本 / 配置文件指纹（`files/`）

| 文件 | sha256 |
| --- | --- |
| `files/etc/config/ttyd` | `43666e86f2bdbfaf953a3b09bfdbf9960e6e1fff4fcd7cb687d0d257e17433e2` |
| `files/etc/init.d/ha-config-path` | `e6e47aa65bbf02c94ce37593bae709cf8f8b3d374851e0512d4a3c1a80f30053` |
| `files/etc/init.d/nvme-automount` | `5cc0155dc8d620f549bfdfea8e4ffa83c4cadae735c70a7bcfd871562650614b` |
| `files/etc/opkg/distfeeds.conf` | `d7ab59f54676a07d47413bff28beb87b592166a7b0e63b7c2730ec54be2721b7` |
| `files/etc/opkg/keys/a56f16274c6d486b` | `1d1722a67025a160806e52a53ba630f249ea8c32a9c6031298d0445663cde4fa` |
| `files/etc/opkg.conf` | `6e774833ba703e1bac7c09f7975fb69971e2bfed61ff263614acb5994f8b190d` |
| `files/etc/uci-defaults/98-enable-custom-initd` | `56b8176538b6f8e5a145694563714e73d721dbcf99f32bf362efd750ce54b3b3` |
| `files/etc/uci-defaults/98-fix-ttyd` | `3ea3fc0ba31c8f2efa3bf43422589a695bc5d713d3f78a144581986e0acc0f59` |
| `files/etc/uci-defaults/99-opkg-istore` | `682b76bbad78f356a0aa8c0a294f4c44fd2b75b2210b93317c9b2afbea3847b0` |
| `files/etc/uci-defaults/99-set-lan-ip` | `f48add100eb91cd175351357022cf76dbb4a68318471e2695cb98eca333208cd` |
| `files/usr/bin/firstboot-status` | `73f8ca3b7c2024982198a60b96bdd198577e695c94f5a2bc597161862b57e97a` |
| `files/usr/libexec/istorec/homeassistant.sh` | `38e3be3269f5e86383022481a8ddb6eaeee1c9bbbb7fe1efd498f4085134cff7` |

> 完整基线清单见 [`baseline.sha256`](baseline.sha256)，校验：`sha256sum -c docs/baseline.sha256`。

## 重点应用

### 系统 / 初始化

| 包 | 作用 | 版本 |
| --- | --- | --- |
| `luci-app-quickstart` | 向导式初始化：磁盘、网络、密码 | 0.12.10-r1 |
| `luci-app-store` | iStore 应用商店 | 0.2.1-r1 |
| `luci-theme-argon` | Argon 主题 | 2.4.3-r20250722 |

### 分区工具

| 包 | 作用 | 版本 |
| --- | --- | --- |
| `luci-app-partexp` | 一键格式化/扩容/挂载（sirpdboy） | 2.0.5-r20260318 |

### 文件共享 / 存储

| 包 | 作用 | 版本 |
| --- | --- | --- |
| `luci-app-samba4` | Samba4 共享管理 | 26.300.08316~d72e293 |
| `luci-app-unishare` | 统一共享面板（samba4 + webdav2） | 1.0.2-r1 |
| `luci-app-nfs` | NFS 服务端 | 1.1-r1 |
| `luci-app-cifs-mount` | CIFS/SMB 挂载 | 26.300.08316~d72e293 |
| `luci-app-diskman` | 磁盘管理 + SMART | 0.2.13-r1 |

### 文件管理

| 包 | 作用 | 版本 |
| --- | --- | --- |
| `luci-app-filemanager` | 文件管理器 | 26.300.08316~d72e293 |
| `luci-app-filetransfer` | 上传/下载/传输 | 1.3.0-r1 |

### 容器 / 应用

| 包 | 作用 | 版本 |
| --- | --- | --- |
| `luci-app-dockerman` | Docker 容器管理 | 0.5.26-r1 |
| `luci-app-homeassistant` | Home Assistant（Docker，含中文包） | 1.1.4-r20260804 |

### 监控 / 限速 / 管控

| 包 | 作用 | 版本 |
| --- | --- | --- |
| `luci-app-nlbwmon` | 每主机流量统计 | 26.300.08316~d72e293 |
| `luci-app-rtbwmon` | 实时带宽 | 1.1.0-r1 |
| `luci-app-eqosplus` | 按 IP/时段限速 | 1.3.0-r20251128 |
| `luci-app-timecontrol` | 上网时间控制 | 3.2.4-r20260322 |
| `luci-app-control-webrestriction` | 网站访问限制 | 1.1-r2 |
| `luci-app-control-weburl` | URL 关键词过滤 | 1.1-r2 |
| `luci-app-wolplus` | 网络唤醒增强 | 1.1-r20230724 |

### 网络 / 代理

| 包 | 作用 | 版本 |
| --- | --- | --- |
| `shadowsocks-rust-sslocal` | SS 客户端（含 ssserver/ssmanager） | 1.23.5-r1 |
| `xray-core` | Xray 核心 | 25.2.21-r1 |
| `v2ray-plugin` | V2Ray 插件 | 5.25.0-r1 |
| `chinadns-ng` | DNS 分流 | 2025.08.09-r1 |
| `luci-app-lucky` | Lucky：反代/DDNS/穿透/WOL | 3.0.0-r31 |

## 全量包清单

共 **552** 个包。

| 分类 | 包数 |
| --- | --- |
| 系统与其它 | 247 |
| 内核与驱动 | 154 |
| 存储与共享 | 28 |
| 容器 (Docker) | 7 |
| 网络 / 代理 / 流量 | 30 |
| LuCI 组件/主题/协议 | 22 |
| LuCI 应用 | 33 |
| LuCI 语言包 | 31 |

### 系统与其它（247）

| 包名 | 版本 |
| --- | --- |
| `appfilter` | 6.1.3-r1 |
| `attr` | 2.5.2-r3 |
| `autocore` | 42 |
| `avahi-dbus-daemon` | 0.9_rc5-r1 |
| `base-files` | 1~046b253 |
| `bash` | 5.2.37-r1 |
| `bc` | 1.07.1-r1 |
| `blockd` | 2024.07.14~408c2cc4-r1 |
| `bridge` | 1.7.1-r1 |
| `btrfs-progs` | 6.11-r1 |
| `busybox` | 1.36.1-r2 |
| `bzip2` | 1.0.8-r1 |
| `ca-bundle` | 20241223-r1 |
| `ca-certificates` | 20241223-r1 |
| `cgi-io` | 2026.07.21~31cb3c89-r1 |
| `coremark` | 2023.01.25~d5fad6bd-r1 |
| `coreutils` | 9.7-r1 |
| `coreutils-base64` | 9.7-r1 |
| `coreutils-nohup` | 9.7-r1 |
| `coreutils-stty` | 9.7-r1 |
| `cpufreq` | 1 |
| `dbus` | 1.14.10-r2 |
| `default-settings` | 29 |
| `default-settings-chn` | 29 |
| `dropbear` | 2024.86-r1 |
| `ethtool` | 6.11-r1 |
| `fdisk` | 2.40.2-r1 |
| `fstools` | 2024.07.14~408c2cc4-r1 |
| `fwtool` | 2019.11.12~8f7fe925-r1 |
| `geoview` | 0.1.10-r1 |
| `getrandom` | 2024.04.26~85f10530-r1 |
| `haproxy` | 3.0.25-r1 |
| `hostapd-common` | 2024.09.15~5ace39b0-r2 |
| `ip-full` | 6.11.0-r1 |
| `ip-tiny` | 6.11.0-r1 |
| `ip6tables-nft` | 1.8.10-r1 |
| `ipt2socks` | 1.1.4-r2 |
| `iw-full` | 6.9-r1 |
| `iwinfo` | 2024.10.20~b94f066e-r1 |
| `jansson4` | 2.14-r3 |
| `jshn` | 2024.03.29~eb9bcb64-r1 |
| `jsonfilter` | 2024.01.23~594cfa86-r1 |
| `libacl` | 2.3.2-r2 |
| `libatomic1` | 13.3.0-r4 |
| `libattr` | 2.5.2-r3 |
| `libavahi-client` | 0.9_rc5-r1 |
| `libavahi-dbus-support` | 0.9_rc5-r1 |
| `libblobmsg-json20240329` | 2024.03.29~eb9bcb64-r1 |
| `libbpf1` | 1.5.0-r1 |
| `libbz2-1.0` | 1.0.8-r1 |
| `libc` | 1.2.5-r4 |
| `libcap` | 2.69-r1 |
| `libcap-ng` | 0.8.4-r1 |
| `libcomerr0` | 1.47.0-r2 |
| `libcurl4` | 8.22.0-r1 |
| `libdaemon` | 0.14-r5 |
| `libdbus` | 1.14.10-r2 |
| `libdevmapper` | 1.02.199 |
| `libe2p2` | 1.47.0-r2 |
| `libelf1` | 0.192-r1 |
| `libev` | 4.33-r2 |
| `libexpat` | 2.8.4-r1 |
| `libfdisk1` | 2.40.2-r1 |
| `libfuse1` | 2.9.9-r2 |
| `libgcc1` | 13.3.0-r4 |
| `libgmp10` | 6.3.0-r1 |
| `libgnutls` | 3.8.5-r1 |
| `libinih` | 61-r1 |
| `libiptext-nft0` | 1.8.10-r1 |
| `libiptext0` | 1.8.10-r1 |
| `libiptext6-0` | 1.8.10-r1 |
| `libiwinfo-data` | 2024.10.20~b94f066e-r1 |
| `libiwinfo20230701` | 2024.10.20~b94f066e-r1 |
| `libjson-c5` | 0.18-r1 |
| `libjson-script20240329` | 2024.03.29~eb9bcb64-r1 |
| `libkeyutils1` | 1.6.3-r2 |
| `libltdl7` | 2.4.7-r1 |
| `liblua5.1.5` | 5.1.5-r11 |
| `liblua5.3-5.3` | 5.3.5-r6 |
| `liblucihttp-lua` | 2023.03.15~9b5b683f-r1 |
| `liblucihttp-ucode` | 2023.03.15~9b5b683f-r1 |
| `liblucihttp0` | 2023.03.15~9b5b683f-r1 |
| `liblzma` | 5.8.3-r1 |
| `liblzo2` | 2.10-r4 |
| `libminiupnpc` | 2.2.8-r1 |
| `libmnl0` | 1.0.5-r1 |
| `libmount1` | 2.40.2-r1 |
| `libnatpmp1` | 20230423-r2 |
| `libncurses6` | 6.4-r2 |
| `libnetfilter-conntrack3` | 1.0.9-r2 |
| `libnetfilter-cthelper0` | 1.0.0-r2 |
| `libnetfilter-cttimeout1` | 1.0.0-r2 |
| `libnetfilter-queue1` | 1.0.5-r4 |
| `libnettle8` | 3.9.1-r1 |
| `libnfnetlink0` | 1.0.2-r1 |
| `libnftnl11` | 1.2.8-r1 |
| `libnghttp2-14` | 1.63.0-r1 |
| `libnl-core200` | 3.10.0-r1 |
| `libnl-genl200` | 3.10.0-r1 |
| `libnl-tiny1` | 2025.03.19~c0df580a-r1 |
| `libnvme` | 1.9-r1 |
| `libopenssl-conf` | 3.0.16-r1 |
| `libopenssl-legacy` | 3.0.16-r1 |
| `libopenssl3` | 3.0.16-r1 |
| `libparted` | 3.6-r1 |
| `libpcre2` | 10.42-r1 |
| `libpopt0` | 1.19-r1 |
| `libpthread` | 1.2.5-r4 |
| `libreadline8` | 8.2-r2 |
| `librt` | 1.2.5-r4 |
| `libruby3.3` | 3.3.10-r1 |
| `libseccomp` | 2.5.5-r1 |
| `libsmartcols1` | 2.40.2-r1 |
| `libss2` | 1.47.0-r2 |
| `libstdcpp6` | 13.3.0-r4 |
| `libtasn1` | 4.19.0-r2 |
| `libtirpc` | 1.3.6-r1 |
| `libubox20240329` | 2024.03.29~eb9bcb64-r1 |
| `libubus-lua` | 2025.01.02~afa57cce-r1 |
| `libubus20250102` | 2025.01.02~afa57cce-r1 |
| `libuci-lua` | 2025.01.20~16ff0bad-r1 |
| `libuci20250120` | 2025.01.20~16ff0bad-r1 |
| `libuclient20201210` | 2024.10.22~88ae8f20-r1 |
| `libucode20230711` | 2025.02.10~a8a11aea-r1 |
| `libudebug` | 2023.12.06~6d3f51f9 |
| `liburcu` | 0.15.2-r1 |
| `liburing` | 2.7-r1 |
| `libustream-openssl20201210` | 2024.07.28~99bd3d2b-r1 |
| `libuuid1` | 2.40.2-r1 |
| `libuv1` | 1.48.0-r1 |
| `libwebsockets-full` | 4.3.3-r1 |
| `libwrap` | 7.6-r4 |
| `libxtables12` | 1.8.10-r1 |
| `libyaml` | 0.2.5-r1 |
| `libzstd` | 1.5.7-r1 |
| `logd` | 2024.04.26~85f10530-r1 |
| `losetup` | 2.40.2-r1 |
| `lua` | 5.1.5-r11 |
| `miniupnpd-nftables` | 2.3.9-r1 |
| `mtd` | 26 |
| `netdata` | 1.38.1-r3 |
| `netifd` | 2024.12.17~ea01ed41-r1 |
| `nvme-cli` | 2.9.1-r1 |
| `openssl-util` | 3.0.16-r1 |
| `openwrt-keyring` | 2024.11.01~c5d6bdf2-r1 |
| `opkg` | 2024.10.16~38eccbb1-r1 |
| `partx-utils` | 2.40.2-r1 |
| `procd` | 2024.12.22~42d39376-r1 |
| `procd-seccomp` | 2024.12.22~42d39376-r1 |
| `procd-ujail` | 2024.12.22~42d39376-r1 |
| `protobuf` | 3.17.3-r2 |
| `protobuf-lite` | 3.17.3-r2 |
| `quickstart` | 0.13.1-r1 |
| `resolveip` | 2 |
| `rpcbind` | 1.2.6-r2 |
| `rpcd` | 2024.09.17~9f4b86e7-r1 |
| `rpcd-mod-file` | 2024.09.17~9f4b86e7-r1 |
| `rpcd-mod-iwinfo` | 2024.09.17~9f4b86e7-r1 |
| `rpcd-mod-luci` | 20240305-r1 |
| `rpcd-mod-rrdns` | 20170710 |
| `rpcd-mod-ucode` | 2024.09.17~9f4b86e7-r1 |
| `ruby` | 3.3.10-r1 |
| `ruby-bigdecimal` | 3.3.10-r1 |
| `ruby-date` | 3.3.10-r1 |
| `ruby-digest` | 3.3.10-r1 |
| `ruby-enc` | 3.3.10-r1 |
| `ruby-pstore` | 3.3.10-r1 |
| `ruby-psych` | 3.3.10-r1 |
| `ruby-stringio` | 3.3.10-r1 |
| `ruby-yaml` | 3.3.10-r1 |
| `script-utils` | 2.40.2-r1 |
| `shadow` | 4.8.1-r3 |
| `shadow-chage` | 4.8.1-r3 |
| `shadow-chfn` | 4.8.1-r3 |
| `shadow-chgpasswd` | 4.8.1-r3 |
| `shadow-chpasswd` | 4.8.1-r3 |
| `shadow-chsh` | 4.8.1-r3 |
| `shadow-common` | 4.8.1-r3 |
| `shadow-expiry` | 4.8.1-r3 |
| `shadow-faillog` | 4.8.1-r3 |
| `shadow-gpasswd` | 4.8.1-r3 |
| `shadow-groupadd` | 4.8.1-r3 |
| `shadow-groupdel` | 4.8.1-r3 |
| `shadow-groupmems` | 4.8.1-r3 |
| `shadow-groupmod` | 4.8.1-r3 |
| `shadow-groups` | 4.8.1-r3 |
| `shadow-grpck` | 4.8.1-r3 |
| `shadow-grpconv` | 4.8.1-r3 |
| `shadow-grpunconv` | 4.8.1-r3 |
| `shadow-lastlog` | 4.8.1-r3 |
| `shadow-login` | 4.8.1-r3 |
| `shadow-logoutd` | 4.8.1-r3 |
| `shadow-newgidmap` | 4.8.1-r3 |
| `shadow-newgrp` | 4.8.1-r3 |
| `shadow-newuidmap` | 4.8.1-r3 |
| `shadow-newusers` | 4.8.1-r3 |
| `shadow-nologin` | 4.8.1-r3 |
| `shadow-passwd` | 4.8.1-r3 |
| `shadow-pwck` | 4.8.1-r3 |
| `shadow-pwconv` | 4.8.1-r3 |
| `shadow-pwunconv` | 4.8.1-r3 |
| `shadow-su` | 4.8.1-r3 |
| `shadow-useradd` | 4.8.1-r3 |
| `shadow-userdel` | 4.8.1-r3 |
| `shadow-usermod` | 4.8.1-r3 |
| `shadow-utils` | 4.8.1-r3 |
| `shadow-vipw` | 4.8.1-r3 |
| `shellsync` | 0.2-r2 |
| `simple-obfs-client` | 0.0.5-r2 |
| `sing-box` | 1.12.25-r1 |
| `smartd` | 7.5-r1 |
| `swconfig` | 12 |
| `tar` | 1.35-r1 |
| `taskd` | 1.0.3-r2 |
| `tc-tiny` | 6.11.0-r1 |
| `terminfo` | 6.4-r2 |
| `ttyd` | 1.7.3-r1 |
| `uboot-envtools` | 2024.07-r1 |
| `ubox` | 2024.04.26~85f10530-r1 |
| `uclient-fetch` | 2024.10.22~88ae8f20-r1 |
| `ucode` | 2025.02.10~a8a11aea-r1 |
| `ucode-mod-digest` | 2025.02.10~a8a11aea-r1 |
| `ucode-mod-fs` | 2025.02.10~a8a11aea-r1 |
| `ucode-mod-html` | 1 |
| `ucode-mod-lua` | 1 |
| `ucode-mod-math` | 2025.02.10~a8a11aea-r1 |
| `ucode-mod-nl80211` | 2025.02.10~a8a11aea-r1 |
| `ucode-mod-rtnl` | 2025.02.10~a8a11aea-r1 |
| `ucode-mod-ubus` | 2025.02.10~a8a11aea-r1 |
| `ucode-mod-uci` | 2025.02.10~a8a11aea-r1 |
| `ucode-mod-uloop` | 2025.02.10~a8a11aea-r1 |
| `uhttpd` | 2023.06.25~34a8a74d-r4 |
| `uhttpd-mod-ubus` | 2023.06.25~34a8a74d-r4 |
| `unzip` | 6.0-r9 |
| `urandom-seed` | 3 |
| `urngd` | 2023.11.01~44365eb1-r1 |
| `usign` | 2020.05.23~f1f65026-r1 |
| `wifi-scripts` | 1.0-r1 |
| `wireless-regdb` | 2025.02.20-r1 |
| `wireless-tools` | 29-r6 |
| `wpad-openssl` | 2024.09.15~5ace39b0-r2 |
| `wsdd2` | 2023.12.21~b676d8ac-r2 |
| `xtables-nft` | 1.8.10-r1 |
| `xz` | 5.8.3-r1 |
| `xz-utils` | 5.8.3-r1 |
| `zerotier` | 1.14.1-r14 |
| `zlib` | 1.3.1-r1 |

### 内核与驱动（154）

| 包名 | 版本 |
| --- | --- |
| `kernel` | 6.6.99~5ea661f7b6d7acc972ce0af4072e36b0-r1 |
| `kmod-asn1-decoder` | 6.6.99-r1 |
| `kmod-asn1-encoder` | 6.6.99-r1 |
| `kmod-br-netfilter` | 6.6.99-r1 |
| `kmod-cfg80211` | 6.6.99.6.12.6-r1 |
| `kmod-crypto-acompress` | 6.6.99-r1 |
| `kmod-crypto-aead` | 6.6.99-r1 |
| `kmod-crypto-arc4` | 6.6.99-r1 |
| `kmod-crypto-blake2b` | 6.6.99-r1 |
| `kmod-crypto-cbc` | 6.6.99-r1 |
| `kmod-crypto-ccm` | 6.6.99-r1 |
| `kmod-crypto-cmac` | 6.6.99-r1 |
| `kmod-crypto-crc32` | 6.6.99-r1 |
| `kmod-crypto-crc32c` | 6.6.99-r1 |
| `kmod-crypto-ctr` | 6.6.99-r1 |
| `kmod-crypto-cts` | 6.6.99-r1 |
| `kmod-crypto-des` | 6.6.99-r1 |
| `kmod-crypto-ecb` | 6.6.99-r1 |
| `kmod-crypto-gcm` | 6.6.99-r1 |
| `kmod-crypto-geniv` | 6.6.99-r1 |
| `kmod-crypto-gf128` | 6.6.99-r1 |
| `kmod-crypto-ghash` | 6.6.99-r1 |
| `kmod-crypto-hash` | 6.6.99-r1 |
| `kmod-crypto-hmac` | 6.6.99-r1 |
| `kmod-crypto-manager` | 6.6.99-r1 |
| `kmod-crypto-md5` | 6.6.99-r1 |
| `kmod-crypto-null` | 6.6.99-r1 |
| `kmod-crypto-rng` | 6.6.99-r1 |
| `kmod-crypto-seqiv` | 6.6.99-r1 |
| `kmod-crypto-sha1` | 6.6.99-r1 |
| `kmod-crypto-sha256` | 6.6.99-r1 |
| `kmod-crypto-sha3` | 6.6.99-r1 |
| `kmod-crypto-sha512` | 6.6.99-r1 |
| `kmod-crypto-user` | 6.6.99-r1 |
| `kmod-crypto-xxhash` | 6.6.99-r1 |
| `kmod-dax` | 6.6.99-r1 |
| `kmod-dm` | 6.6.99-r1 |
| `kmod-dnsresolver` | 6.6.99-r1 |
| `kmod-dummy` | 6.6.99-r1 |
| `kmod-fs-autofs4` | 6.6.99-r1 |
| `kmod-fs-btrfs` | 6.6.99-r1 |
| `kmod-fs-cifs` | 6.6.99-r1 |
| `kmod-fs-exfat` | 6.6.99-r1 |
| `kmod-fs-exportfs` | 6.6.99-r1 |
| `kmod-fs-ext4` | 6.6.99-r1 |
| `kmod-fs-f2fs` | 6.6.99-r1 |
| `kmod-fs-ksmbd` | 6.6.99-r1 |
| `kmod-fs-msdos` | 6.6.99-r1 |
| `kmod-fs-netfs` | 6.6.99-r1 |
| `kmod-fs-nfs` | 6.6.99-r1 |
| `kmod-fs-nfs-common` | 6.6.99-r1 |
| `kmod-fs-nfs-common-rpcsec` | 6.6.99-r1 |
| `kmod-fs-nfs-v4` | 6.6.99-r1 |
| `kmod-fs-nfsd` | 6.6.99-r1 |
| `kmod-fs-ntfs3` | 6.6.99-r1 |
| `kmod-fs-smbfs-common` | 6.6.99-r1 |
| `kmod-fs-vfat` | 6.6.99-r1 |
| `kmod-fs-xfs` | 6.6.99-r1 |
| `kmod-fuse` | 6.6.99-r1 |
| `kmod-gpio-button-hotplug` | 6.6.99-r5 |
| `kmod-hwmon-core` | 6.6.99-r1 |
| `kmod-ifb` | 6.6.99-r1 |
| `kmod-inet-diag` | 6.6.99-r1 |
| `kmod-ip6tables` | 6.6.99-r1 |
| `kmod-ipt-conntrack` | 6.6.99-r1 |
| `kmod-ipt-core` | 6.6.99-r1 |
| `kmod-ipt-extra` | 6.6.99-r1 |
| `kmod-ipt-filter` | 6.6.99-r1 |
| `kmod-ipt-nat` | 6.6.99-r1 |
| `kmod-ipt-nat6` | 6.6.99-r1 |
| `kmod-ipt-physdev` | 6.6.99-r1 |
| `kmod-keys-encrypted` | 6.6.99-r1 |
| `kmod-keys-trusted` | 6.6.99-r1 |
| `kmod-leds-gpio` | 6.6.99-r1 |
| `kmod-lib-crc-ccitt` | 6.6.99-r1 |
| `kmod-lib-crc16` | 6.6.99-r1 |
| `kmod-lib-crc32c` | 6.6.99-r1 |
| `kmod-lib-lzo` | 6.6.99-r1 |
| `kmod-lib-raid6` | 6.6.99-r1 |
| `kmod-lib-textsearch` | 6.6.99-r1 |
| `kmod-lib-xor` | 6.6.99-r1 |
| `kmod-lib-xxhash` | 6.6.99-r1 |
| `kmod-lib-zlib-deflate` | 6.6.99-r1 |
| `kmod-lib-zlib-inflate` | 6.6.99-r1 |
| `kmod-lib-zstd` | 6.6.99-r1 |
| `kmod-libphy` | 6.6.99-r1 |
| `kmod-mac80211` | 6.6.99.6.12.6-r1 |
| `kmod-macvlan` | 6.6.99-r1 |
| `kmod-md-mod` | 6.6.99-r1 |
| `kmod-md-raid0` | 6.6.99-r1 |
| `kmod-md-raid1` | 6.6.99-r1 |
| `kmod-md-raid10` | 6.6.99-r1 |
| `kmod-mmc` | 6.6.99-r1 |
| `kmod-mppe` | 6.6.99-r1 |
| `kmod-mt76-connac` | 6.6.99.2025.02.14~e5fef138-r1 |
| `kmod-mt76-core` | 6.6.99.2025.02.14~e5fef138-r1 |
| `kmod-mt7915e` | 6.6.99.2025.02.14~e5fef138-r1 |
| `kmod-mt7916-firmware` | 6.6.99.2025.02.14~e5fef138-r1 |
| `kmod-netlink-diag` | 6.6.99-r1 |
| `kmod-nf-conntrack` | 6.6.99-r1 |
| `kmod-nf-conntrack-netlink` | 6.6.99-r1 |
| `kmod-nf-conntrack6` | 6.6.99-r1 |
| `kmod-nf-flow` | 6.6.99-r1 |
| `kmod-nf-ipt` | 6.6.99-r1 |
| `kmod-nf-ipt6` | 6.6.99-r1 |
| `kmod-nf-ipvs` | 6.6.99-r1 |
| `kmod-nf-log` | 6.6.99-r1 |
| `kmod-nf-log6` | 6.6.99-r1 |
| `kmod-nf-nat` | 6.6.99-r1 |
| `kmod-nf-nat6` | 6.6.99-r1 |
| `kmod-nf-nathelper` | 6.6.99-r1 |
| `kmod-nf-nathelper-extra` | 6.6.99-r1 |
| `kmod-nf-reject` | 6.6.99-r1 |
| `kmod-nf-reject6` | 6.6.99-r1 |
| `kmod-nf-socket` | 6.6.99-r1 |
| `kmod-nf-tproxy` | 6.6.99-r1 |
| `kmod-nfnetlink` | 6.6.99-r1 |
| `kmod-nft-compat` | 6.6.99-r1 |
| `kmod-nft-core` | 6.6.99-r1 |
| `kmod-nft-fib` | 6.6.99-r1 |
| `kmod-nft-fullcone` | 6.6.99.2023.05.17~07d93b62-r1 |
| `kmod-nft-nat` | 6.6.99-r1 |
| `kmod-nft-offload` | 6.6.99-r1 |
| `kmod-nft-socket` | 6.6.99-r1 |
| `kmod-nft-tproxy` | 6.6.99-r1 |
| `kmod-nls-base` | 6.6.99-r1 |
| `kmod-nls-cp437` | 6.6.99-r1 |
| `kmod-nls-cp932` | 6.6.99-r1 |
| `kmod-nls-cp936` | 6.6.99-r1 |
| `kmod-nls-cp950` | 6.6.99-r1 |
| `kmod-nls-iso8859-1` | 6.6.99-r1 |
| `kmod-nls-ucs2-utils` | 6.6.99-r1 |
| `kmod-nls-utf8` | 6.6.99-r1 |
| `kmod-nvme` | 6.6.99-r1 |
| `kmod-oaf` | 6.6.99-r1 |
| `kmod-oid-registry` | 6.6.99-r1 |
| `kmod-ppp` | 6.6.99-r1 |
| `kmod-pppoe` | 6.6.99-r1 |
| `kmod-pppox` | 6.6.99-r1 |
| `kmod-random-core` | 6.6.99-r1 |
| `kmod-sched-core` | 6.6.99-r1 |
| `kmod-scsi-core` | 6.6.99-r1 |
| `kmod-slhc` | 6.6.99-r1 |
| `kmod-swconfig` | 6.6.99-r1 |
| `kmod-switch-rtl8366-smi` | 6.6.99-r1 |
| `kmod-switch-rtl8367b` | 6.6.99-r1 |
| `kmod-thermal` | 6.6.99-r1 |
| `kmod-tpm` | 6.6.99-r1 |
| `kmod-tun` | 6.6.99-r1 |
| `kmod-usb-core` | 6.6.99-r1 |
| `kmod-usb-storage` | 6.6.99-r1 |
| `kmod-usb-storage-extras` | 6.6.99-r1 |
| `kmod-usb-storage-uas` | 6.6.99-r1 |
| `kmod-veth` | 6.6.99-r1 |

### 存储与共享（28）

| 包名 | 版本 |
| --- | --- |
| `blkid` | 2.40.2-r1 |
| `block-mount` | 2024.07.14~408c2cc4-r1 |
| `cifsmount` | 6.11-r2 |
| `dosfstools` | 4.2-r4 |
| `e2fsprogs` | 1.47.0-r2 |
| `exfat-fsck` | 1.2.5-r1 |
| `exfat-mkfs` | 1.2.5-r1 |
| `fuse-utils` | 2.9.9-r2 |
| `ksmbd-server` | 3.5.5-r1 |
| `libblkid1` | 2.40.2-r1 |
| `libext2fs2` | 1.47.0-r2 |
| `libf2fs6` | 1.16.0-r3 |
| `lsblk` | 2.40.2-r1 |
| `mdadm` | 4.3-r2 |
| `mkf2fs` | 1.16.0-r3 |
| `mount-utils` | 2.40.2-r1 |
| `nfs-kernel-server` | 2.6.2-r4 |
| `nfs-kernel-server-utils` | 2.6.2-r4 |
| `nfs-utils` | 2.6.2-r4 |
| `nfs-utils-libs` | 2.6.2-r4 |
| `ntfs3-mount` | 10 |
| `parted` | 3.6-r1 |
| `resize2fs` | 1.47.0-r2 |
| `samba4-libs` | 4.18.11-r1 |
| `samba4-server` | 4.18.11-r1 |
| `smartmontools` | 7.5-r1 |
| `smartmontools-drivedb` | 7.5-r1 |
| `xfs-mkfs` | 6.10.1-r1 |

### 容器 (Docker)（7）

| 包名 | 版本 |
| --- | --- |
| `cgroupfs-mount` | 2020.06.26~05494281-r2 |
| `containerd` | 1.7.22-r1 |
| `docker` | 27.3.1-r1 |
| `docker-compose` | 2.39.1-r1 |
| `dockerd` | 27.3.1-r3 |
| `runc` | 1.1.14-r1 |
| `tini` | 0.19.0-r2 |

### 网络 / 代理 / 流量（30）

| 包名 | 版本 |
| --- | --- |
| `chinadns-ng` | 2025.08.09-r1 |
| `conntrack` | 1.4.8-r1 |
| `curl` | 8.22.0-r1 |
| `ddns-go` | 6.11.2-r1 |
| `dns2socks` | 2.1-r2 |
| `dnsmasq-full` | 2.90-r4 |
| `etherwake` | 1.09-r5 |
| `firewall4` | 2024.12.18~18fc0ead-r1 |
| `iptables-mod-extra` | 1.8.10-r1 |
| `iptables-mod-filter` | 1.8.10-r1 |
| `iptables-nft` | 1.8.10-r1 |
| `lucky` | 3.5.0-r1 |
| `microsocks` | 1.0.5-r2 |
| `nftables-json` | 1.1.1-r1 |
| `nlbwmon` | 2024.02.21~c7616bcf-r1 |
| `odhcp6c` | 2024.09.25~b6ae9ffa-r1 |
| `odhcpd-ipv6only` | 2024.05.08~a2988231-r2 |
| `ppp` | 2.5.1-r1 |
| `ppp-mod-pppoe` | 2.5.1-r1 |
| `shadowsocks-rust-sslocal` | 1.23.5-r1 |
| `shadowsocks-rust-ssserver` | 1.23.5-r1 |
| `tcping` | 2020.07.04~db910183-r1 |
| `ubus` | 2025.01.02~afa57cce-r1 |
| `ubusd` | 2025.01.02~afa57cce-r1 |
| `uci` | 2025.01.20~16ff0bad-r1 |
| `unishare` | 1.1.2-r1 |
| `v2ray-plugin` | 5.25.0-r1 |
| `webdav2` | 4.3.2-r1 |
| `wget-ssl` | 1.24.5-r2 |
| `xray-core` | 25.2.21-r1 |

### LuCI 组件/主题/协议（22）

| 包名 | 版本 |
| --- | --- |
| `luci` | 26.300.08316~d72e293 |
| `luci-base` | 26.300.08316~d72e293 |
| `luci-compat` | 26.300.08316~d72e293 |
| `luci-lib-base` | 26.300.08316~d72e293 |
| `luci-lib-chartjs` | 26.300.08316~d72e293 |
| `luci-lib-docker` | 26.300.08316~d72e293 |
| `luci-lib-ip` | 26.300.08316~d72e293 |
| `luci-lib-ipkg` | 26.300.08316~d72e293 |
| `luci-lib-jsonc` | 26.300.08316~d72e293 |
| `luci-lib-nixio` | 26.300.08316~d72e293 |
| `luci-lib-taskd` | 1.0.26 |
| `luci-lib-xterm` | 4.18.0 |
| `luci-light` | 26.300.08316~d72e293 |
| `luci-lua-runtime` | 26.300.08316~d72e293 |
| `luci-mod-admin-full` | 26.300.08316~d72e293 |
| `luci-mod-network` | 26.300.08316~d72e293 |
| `luci-mod-status` | 26.300.08316~d72e293 |
| `luci-mod-system` | 26.300.08316~d72e293 |
| `luci-proto-ipv6` | 26.300.08316~d72e293 |
| `luci-proto-ppp` | 26.300.08316~d72e293 |
| `luci-theme-argon` | 2.4.3-r20250722 |
| `luci-theme-bootstrap` | 26.300.08316~d72e293 |

### LuCI 应用（33）

| 包名 | 版本 |
| --- | --- |
| `luci-app-autoreboot` | 26.300.08316~d72e293 |
| `luci-app-cifs-mount` | 26.300.08316~d72e293 |
| `luci-app-control-webrestriction` | 1.1-r2 |
| `luci-app-control-weburl` | 1.1-r2 |
| `luci-app-cpufreq` | 26.300.08316~d72e293 |
| `luci-app-ddns-go` | 26.300.08316~d72e293 |
| `luci-app-diskman` | 0.2.13-r1 |
| `luci-app-dockerman` | 0.5.26-r1 |
| `luci-app-eqosplus` | 1.3.0-r20251128 |
| `luci-app-filemanager` | 26.300.08316~d72e293 |
| `luci-app-filetransfer` | 1.3.0-r1 |
| `luci-app-firewall` | 26.300.08316~d72e293 |
| `luci-app-homeassistant` | 1.1.4-r20260804 |
| `luci-app-homeproxy` | 26.300.08316~d72e293 |
| `luci-app-ksmbd` | 26.300.08316~d72e293 |
| `luci-app-lucky` | 3.0.0-r31 |
| `luci-app-nfs` | 1.1-r1 |
| `luci-app-nlbwmon` | 26.300.08316~d72e293 |
| `luci-app-oaf` | 6.1.1-r1 |
| `luci-app-openclash` | 0.47.156 |
| `luci-app-package-manager` | 26.300.08316~d72e293 |
| `luci-app-passwall` | 25.12.16-r1 |
| `luci-app-quickstart` | 0.12.10-r1 |
| `luci-app-rtbwmon` | 1.1.0-r1 |
| `luci-app-samba4` | 26.300.08316~d72e293 |
| `luci-app-store` | 0.2.1-r1 |
| `luci-app-timecontrol` | 3.2.4-r20260322 |
| `luci-app-ttyd` | 26.300.08316~d72e293 |
| `luci-app-unishare` | 1.0.2-r1 |
| `luci-app-upnp` | 26.300.08316~d72e293 |
| `luci-app-wol` | 26.300.08316~d72e293 |
| `luci-app-wolplus` | 1.1-r20230724 |
| `luci-app-zerotier` | 26.300.08316~d72e293 |

### LuCI 语言包（31）

| 包名 | 版本 |
| --- | --- |
| `luci-i18n-autoreboot-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-base-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-cifs-mount-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-control-webrestriction-zh-cn` | 26.311.43765~120312a |
| `luci-i18n-control-weburl-zh-cn` | 26.311.43765~120312a |
| `luci-i18n-cpufreq-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-ddns-go-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-diskman-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-dockerman-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-eqosplus-zh-cn` | 26.311.43765~120312a |
| `luci-i18n-filemanager-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-firewall-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-homeassistant-zh-cn` | 26.311.43765~120312a |
| `luci-i18n-homeproxy-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-ksmbd-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-lucky-zh-cn` | 26.311.43765~120312a |
| `luci-i18n-nfs-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-nlbwmon-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-oaf-zh-cn` | 26.311.53226~046b253 |
| `luci-i18n-package-manager-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-passwall-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-quickstart-zh-cn` | 26.311.43765~120312a |
| `luci-i18n-rtbwmon-zh-cn` | 26.311.43765~120312a |
| `luci-i18n-samba4-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-timecontrol-zh-cn` | 26.311.43765~120312a |
| `luci-i18n-ttyd-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-unishare-zh-cn` | 26.311.43765~120312a |
| `luci-i18n-upnp-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-wol-zh-cn` | 26.300.08316~d72e293 |
| `luci-i18n-wolplus-zh-cn` | 26.311.43765~120312a |
| `luci-i18n-zerotier-zh-cn` | 26.300.08316~d72e293 |
