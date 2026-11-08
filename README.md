# ImmortalWrt · RK3568（NSY G68-PLUS）定制固件

> **致谢**：由衷感谢 [@zhoufuli](https://github.com/zhoufuli/immortalwrt-rk356x) —— 本仓库 fork 自 `zhoufuli/immortalwrt-rk356x`，
> 设备适配（DTS、u-boot/ATF、分区方案）全部来自上游；同时感谢 [ImmortalWrt](https://github.com/immortalwrt) 与 OpenWrt 构建体系，
> 以及 [kenzok8/small-package](https://github.com/kenzok8/small-package)、[iStoreOS](https://github.com/linkease) 提供的软件包与源。

面向 **NSY G68-PLUS（RK3568 / ARMv8）** 的 ImmortalWrt 24.10 固件：**iStoreOS 风格**的初始化与商店、Docker、
存储（NVMe 自动挂载、数据盘手动划分，**不做自动分区**），全流程 GitHub Actions 构建、自动发版，配置以**冻结基线**约束。

---

## 目录

1. [开箱信息](#1-开箱信息)
2. [首次启动自动做了什么](#2-首次启动自动做了什么)
3. [存储分布（docker / iStore）](#3-存储分布)
4. [软件构成（iStoreOS 风格）](#4-软件构成istoreos-风格)
5. [自动构建流程](#5-自动构建流程)
6. [手动构建 / 本地复现](#6-手动构建--本地复现)
7. [下载与刷机](#7-下载与刷机)
8. [基线冻结与校验](#8-基线冻结与校验)
9. [文档索引](#9-文档索引)
10. [已知限制](#10-已知限制)

---

## 1. 开箱信息

| 项目 | 值 |
| --- | --- |
| 设备 | NSY G68-PLUS（RK3568，aarch64_generic） |
| 系统 | ImmortalWrt 24.10（kernel 6.6.99、u-boot/ATF 走 `pine64-img` 流程） |
| **管理地址** | **`http://192.168.100.1`**（首启由 `99-set-lan-ip` 写入，掩码 `/24`） |
| 登录账号 | `root`，**默认空密码**（首登后请在「系统 → 管理权」立即设置） |
| SSH | `ssh root@192.168.100.1`（22） |
| DHCP 池 | `192.168.100.100 – 192.168.100.249`（`dhcp.lan.start=100 / limit=150`，随网段自动偏移） |
| 默认时区 | `Asia/Shanghai`（`CST-8`） |
| 内置终端 | LuCI → 系统 → **TTYD 终端**（`ttyd` 监听 `0.0.0.0:7681`，不绑定网卡，改 IP 不掉线） |
| 电源灯指示 | **快速闪烁 = 正在初始化**（挂载/一次性脚本/opkg）；**常亮 = 就绪**；不亮 = 未启动（见 build-guide 7.11） |
| 应用商店 | LuCI → **iStore**（「存储位置」下拉来自已挂载的盘，选中即可；固件不预设） |

> 改地址：`uci set network.lan.ipaddr=192.168.100.1 && uci commit network && /etc/init.d/network reload`

---

## 2. 首次启动自动做了什么

固件只做**安全的自动化**（改 LAN、启服务、挂 NVMe、写 HA 路径）；涉及分区的动作一律留给手动，避免断电风险。脚本分两类语义：**一次性**（`/etc/uci-defaults/`，执行成功即被 OpenWrt 删除）
与**常驻**（`/etc/init.d/`，每次开机执行但带幂等守卫）。

| 动作 | 实现 | 时机 | 幂等保护 |
| --- | --- | --- | --- |
| 改 LAN 为 `192.168.100.1` | `99-set-lan-ip` | 一次性 | 已是目标值则跳过 |
| 启用常驻脚本 + 首启立即执行一次 | `98-enable-custom-initd` | 一次性 | — |
| **数据盘：由你手动分区/挂载**（固件不再自动分区） | 手动（`parted` + `mkfs` + `mount`，或 LuCI 挂载点） | — | 见 build-guide 7.6 |
| docker 数据目录（可选，手动指定） | `uci set dockerd.globals.data_root=...` | — | 不指定则用 overlay 的 `/opt/docker` |
| NVMe 自动检测挂载 → `/mnt/nvme0`（**只挂载、不格式化**，保留盘内数据） | `nvme-automount` | 常驻 | 已挂载跳过；fstab 按 UUID 去重；空白盘只记日志 |
| TTYD 去掉 `@lan` 绑定（改 IP 不再「已拒绝连接」） | `98-fix-ttyd` + `files/etc/config/ttyd` | 一次性 | 无 `interface` 才改 |
| 补 opkg arch、必要时关签名校验 | `99-opkg-istore` | 一次性 | 已有 arch 行则不重复 |
| 指示灯（电源灯等 GPIO 灯）可关 | `portled` | 常驻 | 按 `/etc/config/portled` 应用 |

**磁盘布局**（256 GB eMMC，镜像占约 4.3 GiB）：

```
p1 kernel 16 MiB │ p2 rootfs 200 MiB (squashfs) │ p3 rootfs_data 4096 MiB (/overlay)
p4 extended ── p5 ext4 ext_relay  50 GiB  → /mnt/ext_relay   (docker 数据)
            └─ p6 ext4 Data       其余     → /mnt/data        (共享 / iStore 安装位置)
```

剩余空间 < 58 GiB 时脚本跳过拆盘（小盘保护），此时 iStore 的「存储位置」为空 —— 这是唯一需要人工介入的情形。

---

## 3. 存储分布

先看分区与挂载（首次启动由 `docker-disk` 自动创建）：

| 分区 | 大小 | 挂载点 | 用途 |
| --- | --- | --- | --- |
| `mmcblk0p1` | 16 MiB | — | kernel |
| `mmcblk0p2` | 200 MiB | `/rom` | squashfs 只读根 |
| **`mmcblk0p3`** | **4096 MiB** | **`/overlay`** | 系统可写层（配置、`opkg` 安装的 **iStore 应用本体**） |
| `mmcblk0p5`（可选，手动创建） | 自定（建议 50 GiB） | `/mnt/ext_relay` | Docker 数据目录（`dockerd.globals.data_root` 手动指定） |
| `mmcblk0p6`（可选，手动创建） | 其余 | `/mnt/data` | 共享盘 / iStore 应用数据（向导里「存储位置」选它） |
| NVMe（若有） | — | `/mnt/nvme0` | 仅挂载，保留原有内容，不被自动格式化 |

> 出厂默认**没有** p5/p6，也**不会**自动分区/格式化（见 build-guide 7.6）。
> 需要 docker 和数据盘时按手册手动划一次，之后 fstab 会自动挂载。

**结论（容易混淆的两点）**

| 对象 | 实际落盘位置 | 说明 |
| --- | --- | --- |
| **Docker 容器 / 镜像 / 卷** | 默认 `/opt/docker`（overlay，4 GiB）；建议手动 `uci set dockerd.globals.data_root='/mnt/ext_relay/docker'` | `docker info` 里的 `Docker Root Dir` 应显示你设的路径 |
| **iStore 应用（程序本体）** | **`/overlay`（p3，4096 MiB）** | iStore 通过 `opkg` 安装，`opkg` 的 `dest root /` 就是 overlay；商城里的「存储位置」**不会**把程序装到数据盘 |
| iStore 应用**数据**（部分带向导的应用） | 你在「存储位置」里选的那块盘，建议 **`/mnt/data`** | 选择结果写入 `uci get istore.istore.last_path`，仅用于应用数据目录 |
| 共享文件 / 下载 | `/mnt/data`（p6） | samba4、NFS、filemanager 的共享根建议指向这里 |
| **Home Assistant 配置目录** | 由 `ha-config-path` 在**已挂载的 /mnt 盘**上自动选一个（≥1 GiB），如 `/mnt/data/Configs/HomeAssistant` | 写入 `homeassistant.@homeassistant[0].config_path`，挂进容器 `/config` |

**确认当前落盘**

```sh
docker info | grep -i 'docker root dir'    # 期望 /mnt/ext_relay/docker
df -h /overlay /mnt/ext_relay /mnt/data    # overlay(=iStore 程序) 是否吃紧
du -sh /mnt/ext_relay/docker               # docker 实际占用
uci get istore.istore.last_path            # 商店里选的应用数据目录
```

**要把 docker 换到别的盘**（例如空间更大的 `/mnt/data` 或 NVMe）

```sh
docker ps -a                 # 先看清有哪些容器
uci set dockerd.globals.data_root='/mnt/data/docker'
uci commit dockerd && /etc/init.d/dockerd restart
docker info | grep -i 'docker root dir'
```

**Home Assistant 的配置路径是自动填好的**：首启脚本 `ha-config-path` 按
`/mnt/data` → `/mnt/ext_relay` → `/mnt/nvme*` → 其它 `/mnt` 块挂载 的顺序选一个（要求 ≥1 GiB 空闲），
在其下创建 `Configs/HomeAssistant/custom_components` 并写入 uci，因此 HA 应用页面里的「配置路径」下拉
**默认就有选中项**，HACS 所需的 `custom_components` 目录也提前存在。想自己改：在页面下拉里选别的路径后再点安装/升级即可（脚本只在当前值无效时才覆写）。

> 如果 `docker info` 显示 `Docker Root Dir: /opt/docker`，说明拆盘脚本还没成功跑过（此时 docker 实际占用的是 overlay 的 4 GiB，很容易满）。
> 如果 iStore 安装时报「空间不足」，那是 `/overlay`（4 GiB）满了，不是数据盘满了 —— 用 `df -h /overlay` 确认。

---

## 4. 软件构成（iStoreOS 风格）

| 维度 | 内容 |
| --- | --- |
| **商店 / 初始化** | `luci-app-store`（iStore）+ `luci-app-quickstart`（向导：磁盘、网络、密码）+ `luci-lib-taskd` / `taskd` |
| **容器** | `dockerd` / `containerd` / `runc` / `docker` + `luci-app-dockerman`；数据目录自动落 `/mnt/ext_relay/docker` |
| **共享** | `samba4-server` + `luci-app-samba4`、`unishare`（samba4 + webdav2 聚合面板）、`nfs-kernel-server` + `luci-app-nfs`、`cifsmount` + `kmod-fs-cifs` + `luci-app-cifs-mount` |
| **存储运维** | `luci-app-diskman`（分区 + SMART）、`parted`、`e2fsprogs`、`btrfs-progs`、`xfs-mkfs`、`mkf2fs`；kmod：ext4 / exfat / vfat / btrfs / f2fs / xfs / ntfs3 / nvme |
| **监控限速** | `luci-app-nlbwmon`（每主机流量）、`luci-app-rtbwmon`（实时带宽）、`luci-app-eqosplus`（按 IP/时段限速）、`appfilter` |
| **上网管控** | `luci-app-timecontrol`、`luci-app-control-webrestriction`、`luci-app-control-weburl` |
| **代理** | `shadowsocks-rust`（sslocal/ssserver/ssmanager）、`xray-core`、`v2ray-plugin`、`chinadns-ng`、`luci-app-lucky` |
| **文件管理** | `luci-app-filemanager`、`luci-app-filetransfer` |
| **其他** | `luci-app-wolplus` + `etherwake`（网络唤醒）、`luci-theme-argon`、`ca-certificates`、`curl` |
| **软件源** | 内置 `/etc/opkg/distfeeds.conf`：官方 6 个（24.10.0）+ iStoreOS 3 个（store / nas_luci / nas） |

完整 **556 个包**（含版本）见 **[docs/packages.md](docs/packages.md)**。

---

## 5. 自动构建流程

### 5.1 触发方式

| 方式 | 说明 |
| --- | --- |
| **定时** | cron `0 18 * * 0`（UTC 周日 18:00 = **每周一 02:00 CST**） |
| **手动** | Actions → Build G68-PLUS → *Run workflow*，参数见下 |
| **推送** | 仅当 `defconfig/g68-plus-docker.config` 或 `defconfig/g68-plus-istoreos.config` 变更时触发 |

`workflow_dispatch` 输入（默认值即基线）：

| 输入 | 默认 | 说明 |
| --- | --- | --- |
| `defconfig` | `defconfig/g68-plus-docker.config` | 基础配置（目标/设备/内核） |
| `extra_config` | `defconfig/g68-plus-istoreos.config` | 附加包（iStoreOS 风格那一层） |
| `rootfs_size` | `200` | rootfs 分区 MiB |
| `rootfs_data_size` | `4096` | rootfs_data（overlay）MiB |
| `upload_artifacts` | `true` | 是否上传 artifact |
| `publish_release` | `true` | 是否自动发 Release |

> 临时试验请**显式传参**，不要改默认值；同日多次构建会自动加 `-r<run_number>` 后缀并存。

### 5.2 流水线（24 步，关键闸门）

```
释放空间 → 检出源码 → chmod 内置脚本 → 校验配置(+ 基线强校验) → 装依赖
→ 生成 feeds.conf → 官方 4 源 → 第三方 feed 选择性安装 → 本地 filetransfer
→ 应用 defconfig + 附加配置(+ 强制关闭 pass) → make prereq → 校验附加包
→ 缓存 → make download → tools+toolchain → rust host → make world
→ 记录 squashfs 占用 → 断言分区表(16/200/4096) → 收集 → 上传 artifact → 发布 Release
→ [失败时] 自动开 issue / 上传日志
```

- **闸门 1**：基线指纹（`sha256sum -c docs/baseline.sha256`）不一致 → `::error::` 并**中断**；
- **闸门 2**：`make prereq`（pyelftools 等宿主机依赖）；
- **闸门 3**：附加包生效校验（Job Summary 表格 ✅/⚠️/⛔）；
- **闸门 4**：镜像 MBR 断言必须为 `16 / 200 / 4096` MiB，否则失败；
- **产物**：`*.img.gz` + `sha256sums` 自动挂到 Release，说明页内置**直链 + 3 条加速链接**。

### 5.3 耗时基线（保留 ss-rust）

| 阶段 | 耗时 |
| --- | --- |
| 工具链 | ~37 min |
| rust（vendor 修复 + 预编译） | ~126 min |
| `make world` | ~82 min |
| 合计 | **~4 h 15 min**（关闭 ss-rust 可降到约 2.5 h） |

---

## 6. 手动构建 / 本地复现

适合本地调试或没有 Actions 的环境（Ubuntu 22.04+ / Debian 12，≥ 60 GB 磁盘，≥ 8 GB RAM）。

```bash
# 0) 克隆（建议浅克隆）
git clone --depth 1 https://github.com/iiibeloved/immortalwrt-rk356x.git
cd immortalwrt-rk356x

# 1) 宿主机依赖（与 CI 一致）
sudo apt-get update && sudo apt-get install -y build-essential gawk gcc-multilib g++-multilib \
  flex bison libncurses-dev zlib1g-dev libssl-dev python3 python3-distutils python3-setuptools \
  python3-pyelftools libgnutls28-dev device-tree-compiler rsync unzip wget curl git \
  libelf-dev bc bzip2 patch perl cpio

# 2) 软件源（4 个官方源；如需 iStoreOS 源见 files/etc/opkg/distfeeds.conf）
./scripts/feeds update -a && ./scripts/feeds install -a

# 3) 应用配置：基础 defconfig + 附加配置（顺序不能反）
cp defconfig/g68-plus-docker.config .config
cat defconfig/g68-plus-istoreos.config >> .config
make defconfig                       # 关键：让 kconfig 重新解析，否则附加项会被还原

# 4) 校验附加包是否真的生效
grep -c '^CONFIG_PACKAGE_.*=y' .config     # 基线约 550+ 项

# 5) 编译（先下载，再并行编译；JOBS 按机器核数调整）
make download -j8
make -j$(nproc) V=s                        # 首次约 1.5–4 h，视是否编 rust 而定

# 6) 产物
ls bin/targets/rockchip/armv8/*.img.gz     # immortalwrt-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img.gz
cat bin/targets/rockchip/armv8/sha256sums
```

**要点**

- 只改 `extra_config` 里的包，也要走 `make defconfig`，否则自定义 `# CONFIG_PACKAGE_x is not set` 会被 kconfig 还原（CI 用「强制关闭 pass」二次修正）；
- 想内置自己的文件：放进仓库 `files/`（构建时 `include/image.mk` 最后一步 `prepare_rootfs(..., $(TOPDIR)/files)` 覆盖）；
- 想减小编译时间：把 `defconfig/g68-plus-istoreos.config` 里的 shadowsocks-rust 关闭（省约 2 小时）。

---

## 7. 下载与刷机

> **接在上游路由后面？** 两条路都行：**WAN 接上级 LAN**（默认路由模式，双重 NAT，免配置）；
> 或 **LAN 接上级 LAN**（交换机/AP 模式，需关本机 DHCP 并把 LAN 改到上游网段，见
> [build-guide 附录 J](docs/build-guide.md)）。两种方式下 docker、HA、opkg 都能正常上网。
>
> **要拿它当主路由（撤掉上级路由）**：WAN 直接接光猫 —— 光猫桥接就用 `wan.proto=pppoe` + 账号密码；
> 光猫拨号则用 `wan.proto=dhcp`。PPPoE 所需包（`ppp` / `ppp-mod-pppoe` / `kmod-pppoe`）已内置。详见附录 J「方案 A+」。
>
> **WAN 接上级路由 LAN，默认设置就能上网**（本机 WAN=DHCP 客户端，LAN=192.168.100.1/24 + NAT），
> 无需特殊设置；上级若没有 DHCP 或做了 MAC 白名单才需要调整。详见 [build-guide 附录 I](docs/build-guide.md)。
>
> **首次开机操作要点**：LAN 接电脑、WAN 接上级路由（默认 DHCP，免设置）；通电后等 **1–2 分钟**即可访问
> `http://192.168.100.1`（本版**不会**自动重启、也不会自动分区/格式化）。
> 需要 docker 数据盘时再按 [build-guide 7.6](docs/build-guide.md) 手动划一次分区。
> **判定初始化完成**：`ls /etc/uci-defaults/` 为空 + `/etc/.docker-disk.done` 存在 + 无 `mkfs` 进程；
> 下一版固件起可直接运行 `firstboot-status` 一键自检。详见 [build-guide 附录 I](docs/build-guide.md)。

最新基线：**Release [`g68-plus-2026.11.08`](https://github.com/iiibeloved/immortalwrt-rk356x/releases/tag/g68-plus-2026.11.08)** · 167.1 MB · sha256 `d0dc8eb943aedf9614690a6dc3e512709360d83926d406c80653ad0fd312fa2f`

```bash
TAG=g68-plus-2026.11.08
FILE=immortalwrt-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img.gz
BASE=https://github.com/iiibeloved/immortalwrt-rk356x/releases/download/$TAG

# 直连慢就在 URL 前加代理前缀（文件内容与 sha256 完全相同）
#   https://gh-proxy.com/   https://ghfast.top/   https://ghproxy.net/
curl -LO "$BASE/$FILE"
curl -LO "$BASE/sha256sums"
sha256sum -c sha256sums --ignore-missing
```

**写入**（整盘写入，会清空目标盘）：

```bash
gunzip -k "$FILE"
sudo dd if="${FILE%.gz}" of=/dev/sdX bs=4M conv=fsync status=progress   # /dev/sdX 换成你的设备
```

也可在 LuCI「系统 → 备份/升级」直接上传 `.img.gz`（sysupgrade 升级会保留 overlay 配置；
首刷若要不带旧配置，请勾掉「保留配置」）。

---

## 8. 基线冻结与校验

配置已冻结：**除显式变更请求外，所有自动/手动构建都基于同一基线**，并由 CI 强制校验。

```bash
sha256sum -c docs/baseline.sha256        # 全部 OK = 仓库仍在基线状态
```

- 指纹清单：[docs/baseline.sha256](docs/baseline.sha256)（17 个文件：2 个 defconfig、2 个 workflow、`gen_image_generic.sh`、`files/` 全部）
- CI 行为：不一致 → 打 `::error::` 列出差异文件并**中断构建**（防止「基线被悄悄改掉却照常出固件」）
- 有意修改基线后必须执行：

```bash
./scripts/update-baseline.sh && sha256sum -c docs/baseline.sha256
```

---

## 9. 文档索引

| 文档 | 内容 |
| --- | --- |
| [docs/build-guide.md](docs/build-guide.md) | 详细教程：触发方式、24 步流程、产物、刷机、失败速查、13 个专题（加减包 / ss-rust / rootfs / docker 扩容 / 拆盘 / opkg 源 / NVMe / TTYD / 指示灯 / 回滚）+ 附录 A–E |
| [docs/packages.md](docs/packages.md) | 固件包清单（552 包 + 重点应用 + 基线指纹） |
| [docs/ci-build.md](docs/ci-build.md) | 构建方案设计、依赖来源、实测记录 |
| [docs/baseline.sha256](docs/baseline.sha256) | 基线指纹（CI 强校验依据） |

---

## 10. 已知限制

| 项 | 说明 |
| --- | --- |
| `mergerfs` | ImmortalWrt 24.10 与 small-package 均无此包，未集成（可用 diskman + 多挂载点替代） |
| RJ45 网口灯 | 由 RTL8367S 交换芯片硬件驱动，`rtl8367b` 驱动未暴露 LED 属性，**软件无法开关**（`portled` 只控 GPIO 灯，如电源灯） |
| 小盘设备 | eMMC 剩余 < 58 GiB 时不自动拆盘 → iStore「存储位置」为空，需手动建分区 |
| NVMe 空白盘 | 默认**不**自动格式化（保护数据）；确需格式化请 `touch /etc/nvme-automount.format` 后重启 |
| HA 的 HACS（旧插件商店） | HA **2026.11 起内置 Marketplace 取代 HACS**，HACS 安装脚本会自行退出；固件已改为友好提示并跳过（不影响 HA 运行）。用「设置 → Marketplace」 |
| **自动分区已移除** | 为避免「在线改 MBR + 重启窗口断电」损坏 eMMC，固件不再自动分区/格式化；数据盘由你手动划分（build-guide 7.6） |
| iStore 程序空间 | iStore 应用装在 `/overlay`（4 GiB），**不是**数据盘；装大应用前先看 `df -h /overlay` |
| 更新列表报 iStoreOS 源 `Signature check failed` | 那三个源的签名 key 未公开，固件已默认注释；商店安装不受影响。详见 [build-guide 附录 H](docs/build-guide.md) |
| opkg 装包报 `has no valid architecture` | 旧固件首启脚本把 `arch` 行拼接坏了（优先级变成 `10arch`）；修复命令见 [build-guide 附录 G](docs/build-guide.md) |
| 首启一次重启 | 若内核未即时识别新分区，`docker-disk` 会自动重启一次再接续（最多一次，防循环） |
| 时间同步 | RK3568 无电池 RTC，开机时间可能滞后；HTTPS 拉取失败时先 `date` 检查并等待 NTP |
| 构建耗时 | 保留 ss-rust 时约 4 h 15 min；GitHub cron 偶有延迟/跳过，已用脚本核验兜底 |
