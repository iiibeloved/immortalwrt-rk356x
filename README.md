# ImmortalWrt · 农商云 G68-PLUS（RK3568）定制固件

> **致谢**：本仓库 fork 自 [@zhoufuli](https://github.com/zhoufuli/immortalwrt-rk356x)，设备适配（DTS / u-boot / 分区）
> 全部来自上游；感谢 [ImmortalWrt](https://github.com/immortalwrt)、[OpenWrt](https://openwrt.org)、
> [kenzok8/small-package](https://github.com/kenzok8/small-package)、[iStoreOS](https://github.com/linkease)、
> [sirpdboy](https://github.com/sirpdboy) 等项目的软件包与源。

---

## 1. 这是什么

给 **RK3568 软路由/NAS 小板**编的 ImmortalWrt 24.10 固件：**iStoreOS 风格**（商店 + 向导）、
Docker、DDNS、共享、分区工具齐全；**不做任何自动分区/格式化**，把有断电风险的磁盘操作交给你手动执行。

- 构建：GitHub Actions 自动出包（每周六 02:00，或手动触发）
- 产物：`*.img.gz` + `sha256sums`，自动发布到 Release
- 配置：冻结基线 + CI 指纹校验（改动会被拦下）

## 2. 特点

| 特点 | 说明 |
| --- | --- |
| **iStoreOS 风格** | `luci-app-store`（iStore 商店）+ `luci-app-quickstart`（初始化向导） |
| **Docker 就绪** | `dockerd/containerd/runc` + `luci-app-dockerman`；数据目录手动指到 NVMe/eMMC；**容器日志自动轮转**（10 MiB × 3） |
| **零自动磁盘操作** | 不自动分区、不自动格式化、不自动重启；只自动**挂载**已有文件系统（NVMe） |
| **分区工具齐全** | `parted / fdisk / cfdisk / cgdisk / gdisk / sfdisk` + `luci-app-partexp`（界面化格式化/扩容/挂载） |
| **软件源开箱可用** | 官方 6 源 + iStoreOS 3 源；`/etc/opkg.conf` 架构表内置、签名默认不校验（避免 iStoreOS 源报错） |
| **运维友好** | `firstboot-status` 一键自检；LAN 默认 `192.168.100.1`；TTYD 改 IP 不掉线 |

## 3. 包含的主要软件

| 类别 | 软件 |
| --- | --- |
| 商店/向导 | `luci-app-store`、`luci-app-quickstart`、`taskd`、`luci-lib-taskd` |
| 容器 | `dockerd`、`containerd`、`runc`、`luci-app-dockerman` |
| 共享/存储 | `samba4`、`unishare`、`luci-app-nfs`、`luci-app-cifs-mount`、`luci-app-diskman`（SMART） |
| 分区 | `partexp`（LuCI）、`parted`、`fdisk`、`cfdisk`、`cgdisk`、`gdisk`、`sfdisk` |
| DDNS | `luci-app-ddns`（+中文）、`ddns-scripts`、`ddns-go`、`luci-app-ddns-go` |
| 监控/管控 | `luci-app-nlbwmon`、`luci-app-rtbwmon`、`luci-app-eqosplus`、`luci-app-timecontrol`、网站/URL 过滤 |
| 代理 | `shadowsocks-rust`、`xray-core`、`v2ray-plugin`、`chinadns-ng`、`lucky` |
| 文件 | `luci-app-filemanager`、`luci-app-filetransfer` |
| 应用 | `luci-app-homeassistant`（Docker 方式，含中文；HA≥2026.11 用内置 Marketplace） |

完整包清单（**565 个**，含版本）：[docs/packages.md](docs/packages.md)

## 4. 适用机型

| 机型 | 是否适用 |
| --- | --- |
| **农商云 G68_PLUS** | ✅ 本仓库默认目标（`NSY G68-PLUS`，RK3568） |
| 彼度云 G18_PRO / G18_PLUS | ✅ 同板型（带 USB 口可 maskrom 刷写） |
| 彼度云 G16_PLUS | ❌ 无 USB 口，不适用 |

## 5. 刷机前注意

1. 准备：**双公头 USB 线**、`RKDevTool_Release_v3.18`、驱动 `Rockchip_DriverAssitant_v5.12`；
2. 镜像必须**解压成 `.img`**（工具不认 `.img.gz`）；
3. 先 `sha256sum -c sha256sums` 校验，不一致重下；
4. 备份旧配置（LuCI → 系统 → 备份/升级）；
5. 刷写与**首次启动期间不要断电**（eMMC 写坏最难救）；
6. 板上若有 SPI flash，建议先清 SPI 再刷 eMMC。

## 6. 刷机时注意（两种方式）

### 6.1 系统还能进 → LuCI 升级

```
系统 → 备份/升级 → 上传 .img.gz → 勾「保留配置」→ 执行
```

### 6.2 首次刷写 / 进不去系统 → USB 刷机（厂商步骤）

> 依据厂商《农商云&彼度云刷固件教程》：**必须用 USB 接口刷**，适用于带 USB 口的
> 农商云 G68_PLUS、彼度云 G18_PRO / G18_PLUS（G16_PLUS 无 USB 口不适用）。

**准备**：双公头 USB 数据线、`RKDevTool_Release_v3.18`、驱动 `Rockchip_DriverAssitant_v5.12`、
以及**解压后的 `.img`**（工具只认 `.img`，不认 `.img.gz`）。

**步骤**

1. 安装驱动 `Rockchip_DriverAssitant_v5.12`；
2. 打开 `RKDevTool_Release_v3.18`；
3. **进 maskrom**（两种任选）：
   - 拆掉/短接 SPI 后：双公头线插板子 USB 口 → 短接板上两个短接点 → 通电；
   - **不拆 SPI、不短接也可以**：断电 → **按住 Reset 不松开** → 同时插电源 → 直到刷机软件「发现设备」→
     在「高级功能」里点 **进入 maskrom**（没提示通常是驱动没装好）；
4. 切到 **高级功能** → 导入 `rk356x_spl_loader_v1.21.113.bin` → **下载 uboot**（右侧提示成功）；
5. **获取当前存储**：
   - 显示 **SPI** → 点 **擦除所有**，清空 SPI；
   - 没有 SPI / 已切到 **EMMC** → 同样点 **擦除所有**；
   - 进度到 **100%** 才算成功；**如果「秒擦除」，说明 eMMC 可能有问题，需要检查**；
6. 点工具栏第一个页签 **下载镜像**：
   - 表格每行对应一个分区/组件（Loader / Parameter / Uboot / … / **System** / Backup），
     只需关注**有路径的那一行**（通常是 `System`，存储显示 `EMMC`，路径指向你解压的 `.img`）；
     若路径为空，点该行右侧 `...` 选择解压后的 `.img`；
   - 勾上该行左侧的复选框；
   - 窗口**左下角、`执行` 按钮下方**的 **「强制按地址写」复选框一定要打勾**（否则可能写入不完整/校验失败）；
   - 点 **`执行`**，等进度到 100% 并提示成功；
7. 完成后**断电重启**（或断开 USB 再上电），接网线，**网口灯亮**即表示已启动。

⚠️ **地址/密码不同**：厂商固件默认 `192.168.1.1` / `root` / `password`；
**本固件是 `192.168.100.1` / `root` / 空密码**（首次登录立刻设置）。

> 完整图文步骤与细节见 [build-guide 4.5](docs/build-guide.md)。

## 7. 刷机后配置流程（按顺序）

**① 登录改密码**（默认空密码，必须第一步）

```
浏览器 http://192.168.100.1  →  系统 → 管理权 → 修改密码
```

```sh
passwd root
uci set system.@system[0].timezone='CST-8'; uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system
```

**② 确认上网**（WAN 接上级路由 LAN，默认 DHCP）

```sh
ping -c3 223.5.5.5 && opkg update
```

**③ 磁盘（可选，按需）**：NVMe 有文件系统会自动挂到 `/mnt/nvme0`；空白盘/要改分区请手动：

```sh
# 方式A：界面  系统 → 挂载点（或 系统 → Partition Expansion）
# 方式B：命令行（eMMC 划 50G ext_relay + 其余 Data）
parted -s /dev/mmcblk0 unit MiB mkpart extended 4598 100%
parted -s /dev/mmcblk0 unit MiB mkpart logical ext4 4599 55798
parted -s /dev/mmcblk0 unit MiB mkpart logical ext4 55799 100%
reboot                                    # 必须！内核才认新分区
mkfs.ext4 -F -m 0 -L ext_relay /dev/mmcblk0p5
mkfs.ext4 -F -m 0 -L Data      /dev/mmcblk0p6
mkdir -p /mnt/ext_relay /mnt/data
mount -t ext4 /dev/mmcblk0p5 /mnt/ext_relay
mount -t ext4 /dev/mmcblk0p6 /mnt/data
block detect > /etc/config/fstab && uci commit fstab
```

**④ Docker 数据目录**（默认 `/opt/docker` 在 4 GiB overlay，必须改）

```sh
uci set dockerd.globals.data_root='/mnt/nvme0/docker'   # 或 /mnt/ext_relay/docker
uci commit dockerd && /etc/init.d/dockerd restart
docker info | grep -i 'docker root dir'
```

**⑤ iStore 安装位置**：iStore → 安装弹窗「存储位置」选已挂载的盘（如 `/mnt/nvme0`）；
程序本体固定进 `/overlay`，装前看 `df -h /overlay`。

**⑥ 收尾**：`firstboot-status` 全绿 → 系统 → 备份/升级 → 生成配置备份。

> 详细分步（含每个 LuCI 菜单路径）：[docs/first-boot-checklist.md](docs/first-boot-checklist.md)

## 8. 常见问题

| 现象 | 处理 |
| --- | --- |
| `opkg` 报 `has no valid architecture` | 架构表坏了：`sed -i '/^arch/d' /etc/opkg.conf` 后补 `all/noarch/aarch64_generic/aarch64_cortex-a53` 四行 |
| iStoreOS 源 `Signature check failed` | 固件默认已注释 `option check_signature`；旧版手动注释即可 |
| `mkfs` 报 `No such device` | 新建分区后**必须重启** |
| Docker 日志占满盘 | 开机自动生成 `/etc/dockerd-custom.json`（10 MiB×3），无需手工（[K4.6](docs/build-guide.md)） |
| Docker 只有 `vfs`、空间暴涨 | `data_root` 在 overlay 上；改到真实 ext4 挂载点（如 `/mnt/nvme0/docker`）后重启 dockerd |
| HA 没有 HACS | HA ≥ 2026.11 用内置 **Marketplace** 取代 HACS |

## 9. 下载与文档

- 下载：见 [Releases](https://github.com/iiibeloved/immortalwrt-rk356x/releases)；直连慢时在链接前加
  `https://gh-proxy.com/`（或 `ghfast.top` / `ghproxy.net`），sha256 不变
- [docs/first-boot-checklist.md](docs/first-boot-checklist.md)：刷机后完整操作流程（按重要程度）
- [docs/build-guide.md](docs/build-guide.md)：构建/刷机/维护全教程（含 USB maskrom、dd、手动分区、附录）
- [docs/packages.md](docs/packages.md)：固件包清单（约 565 包 + 基线指纹）
- [docs/scripts/](docs/scripts/)：`bootstrap-remote.sh`、`setup-router.sh`、`docker-apps.sh`

## 10. 已知限制

| 项 | 说明 |
| --- | --- |
| 自动分区 | 已移除（断电风险）；数据盘请手动划 |
| `mergerfs` | 24.10 无此包，未集成 |
| RJ45 网口灯 | 由 RTL8367S 硬件驱动，软件不可控 |
| 内核模块 | 与自编内核绑定，**不能**用官方 kmods 源安装，需重编 |
| GitHub cron | 偶有延迟/跳过，已用脚本核验兜底 |
