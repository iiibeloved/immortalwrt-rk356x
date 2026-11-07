# immortalwrt-rk356x

基于 [ImmortalWrt 24.10](https://github.com/immortalwrt/immortalwrt) 的 rockchip/armv8 派生仓库，面向 RK3568 系列 NAS/软路由设备，
内置 GitHub Actions 一键编译与 iStoreOS 风格插件集成。

---

## 当前状态（下次构建速览）

> 以下为 **2026-11-06 快照**；时间敏感信息请以 [Actions](https://github.com/iiibeloved/immortalwrt-rk356x/actions) 与 [Releases](https://github.com/iiibeloved/immortalwrt-rk356x/releases) 页面为准。

| 项目 | 值 |
| --- | --- |
| **下次构建** | **2026-11-08 01:00（一次性基线构建）**，成功后自动发 Release；之后每周一 02:00 定时（cron `0 18 * * 0`）· 约 3.5–4 小时（含 ss-rust） |
| 想立即构建 | Actions → `Build G68-PLUS (iStoreOS style)` → **Run workflow**（≈ 2.5 小时） |
| 最近一次成功构建 | [run #42270932303](https://github.com/iiibeloved/immortalwrt-rk356x/actions/runs/42270932303)（2026-11-07 02:28 → 05:05，157 分钟） |
| 最近一次发布 | [g68-plus-2026.11.07](https://github.com/iiibeloved/immortalwrt-rk356x/releases/tag/g68-plus-2026.11.07)（165.4 MB，分区 16/200/4096） |
| 当前仓库配置 | **保留 `shadowsocks-rust`**（构建约 4 小时）· **`rootfs` 200 MiB（与 fork 一致）+ `rootfs_data` 4096 MiB** · 22 个 iStoreOS 风格包 + samba4 + docker 引擎 |
| 下次构建预期 | 11-08 01:00 起约 3.5–4 小时（保留 ss-rust）→ 成功后自动发布 `g68-plus-2026.11.08` Release（免登录直链） |
| 构建失败 | 自动开 Issue：标题 `CI 构建失败: … #<run>`，正文含失败步骤、run 链接与排查指引；同类未关闭则追加评论 |
| 详细步骤 | [docs/build-guide.md](docs/build-guide.md)（触发方式 / 24 步流程 / 失败速查表 / 注意事项） |
| **基线** | 冻结于 `d83f4b52`（17 个文件指纹）· CI 强校验，偏离即构建失败 · 校验 `sha256sum -c docs/baseline.sha256` |
| **固件包清单** | [docs/packages.md](docs/packages.md)（上一版 **549 个包**；11-08 版新增 3 个 kmod，构建后刷新） |

---

## 支持的设备与 defconfig

| defconfig | 设备 | 说明 |
| --- | --- | --- |
| `defconfig/g68-plus-docker.config` | NSY **G68-PLUS**（RK3568） | 带 Docker/商店的完整配置，CI 默认使用 |
| `defconfig/g68_mtk_wifi.config` | NSY G68-PLUS | MTK WiFi 变体 |
| `defconfig/g16-plus-docker.config` / `g16-plus.config` | NSY **G16-PLUS**（RK3568） | |
| `defconfig/g16_mtk_wifi.config` | NSY G16-PLUS | MTK WiFi 变体 |
| `defconfig/g18-pro-docker.config` / `g18-pro.config` | BDY **G18-PRO**（RK3568） | |
| `defconfig/g18_mtk_wifi.config` | BDY G18-PRO | MTK WiFi 变体 |

内核 Linux 6.6，包架构 `aarch64_generic`，启动流程 `pine64-img`（产物为 `*-squashfs-sysupgrade.img.gz`，可直接 dd 刷写）。

---

## 固件下载

编译成功后会自动发布到 **Releases**（免登录直链，长期有效）：

- 发布页：<https://github.com/iiibeloved/immortalwrt-rk356x/releases>
- 直链格式：`https://github.com/iiibeloved/immortalwrt-rk356x/releases/download/<tag>/immortalwrt-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img.gz`
- tag 规则：`g68-plus-YYYY.MM.DD`；同一天多次构建自动追加 `-r<run_number>`，多版本并存
- 每次构建的 Actions artifact 保留 15 天，Release 资产长期保留

刷机（**务必先校验 sha256**）：

```bash
curl -LO <release>/immortalwrt-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img.gz
curl -LO <release>/sha256sums
sha256sum -c sha256sums --ignore-missing
gunzip immortalwrt-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img.gz
sudo dd if=immortalwrt-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img of=/dev/sdX bs=4M conv=fsync status=progress
```

也可在 LuCI「系统 → 备份/升级」直接上传 `.img.gz`。

---

## 一键编译（GitHub Actions）

工作流：[`.github/workflows/build-g68-plus-docker.yml`](.github/workflows/build-g68-plus-docker.yml)

| 触发 | 条件 |
| --- | --- |
| 手动 | Actions → `Build G68-PLUS (iStoreOS style)` → **Run workflow** |
| push | 仅当 `defconfig/g68-plus-docker.config` 或 `defconfig/g68-plus-istoreos.config` 变动 |
| 定时 | 每周一 **02:00（Asia/Shanghai）**，cron `0 18 * * 0`（UTC） |

手动参数：

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `defconfig` | `defconfig/g68-plus-docker.config` | 基础配置（换机型就改这个） |
| `extra_config` | `defconfig/g68-plus-istoreos.config` | 附加差异项（iStoreOS 插件等） |
| `rootfs_size` | `200` | 只读系统分区，与 fork 源 `CONFIG_TARGET_ROOTFS_PARTSIZE=200` 一致。**实测 squashfs = 160.2 MiB**（xz，5824 inode），占 200 MiB 的 ~80%；去掉 ss-rust 后约 150 MiB（~75%）。要更多余量传 `256`（~60%） |
| `rootfs_data_size` | `4096` | 可写 overlay：iStore/opkg 装的包、docker 数据、配置改动（脚本 `gen_image_generic.sh` 读取 `ROOTFS_DATA_PARTSIZE`） |

> docker 数据目录：镜像内置 `/etc/init.d/docker-dataroot`，开机自动把 `dockerd.globals.data_root`
> 指到外挂盘（`<挂载点>/docker`，要求剩余 ≥8 GiB 的 ext4/btrfs/xfs/f2fs）；没有外挂盘时保持 `/opt/docker`。
> 手工设置过 `data_root` 则不再自动改动。
>
> 另外镜像内置 `/etc/init.d/docker-disk`：**首次启动**会把 eMMC 上镜像之外的剩余空间（≥58 GiB 时）拆成两块——
> **50 GiB ext4（卷标 `ext_relay`）挂 `/mnt/ext_relay` 给 docker**，其余 ext4（卷标 `Data`）挂 `/mnt/data` 作共享盘（iStore 安装时选它）；
> 幂等、只追加不改动已有分区、失败自动回退 `/opt/docker`；关闭方式 `touch /etc/.docker-disk.done`。详见 build-guide 7.8。

分区布局：`kernel 16 MiB + rootfs 200 MiB + rootfs_data 4096 MiB`，整盘镜像约 **4.3 GiB**，介质 ≥5 GB（8 GB 卡可用）。
其中 p1/p2 与 fork 源一致，只有 p3 放大到 4096 供 docker/iStore 使用。
每次构建会在 Job Summary 里输出 squashfs 实际占用率，超过 85% 会告警提示调大 `rootfs_size`。
| `upload_artifacts` | `true` | 上传 artifact（15 天） |
| `publish_release` | `true` | 成功后自动发布 Release |

耗时参考：**约 4 小时 15 分**（含 `shadowsocks-rust` → 需编 rustc/LLVM，约 2 小时）；若在附加配置里关掉 ss-rust，可降到约 2.5 小时。

---

## 集成内容（`g68-plus-istoreos.config`）

- **iStoreOS 风格**：`luci-app-quickstart` + `quickstart`、`luci-app-store`（iStore）+ `taskd` / `luci-lib-taskd` / `luci-lib-xterm`
- **共享 / 运维**：`unishare`（samba4 + webdav2 聚合面板）、`lucky`、`luci-app-wolplus`、`luci-app-rtbwmon`
- **文件管理**：`luci-app-filemanager`、`luci-app-filetransfer`
- **Samba4**：`samba4-server` + `luci-app-samba4`
- **Docker**：`dockerd` / `containerd` / `runc` / `docker`（原 defconfig 只有 dockerman 界面，已补齐引擎）
- **代理组件**：`shadowsocks-rust-sslocal/ssserver`（默认启用；不想要可在附加配置里关闭，省约 2 小时）
- **监控/管控**：`luci-app-nlbwmon`（流量）、`luci-app-eqosplus`（限速）、`luci-app-timecontrol`、`luci-app-control-webrestriction`、`luci-app-control-weburl`
- **存储**：`luci-app-nfs` + `nfs-kernel-server`、`luci-app-cifs-mount` + `kmod-fs-cifs` + `cifsmount`、`luci-app-diskman`（含 SMART 页签）
- **指示灯开关**：`/etc/config/portled` 可开关电源灯等 GPIO 灯；RJ45 网口灯由 RTL8367S 硬件驱动，软件不可控（该需求已放弃，详见 build-guide 7.13）
- **TTYD 终端防坑**：内置 `ttyd` 配置不绑定 `@lan`，改 LAN IP 后终端不会出现「已拒绝连接」（并带首次启动自动修正脚本）
- **NVMe 自动挂载**：开机检测 `/dev/nvme*n1`，已有文件系统直接挂 `/mnt/nvme0`（写 fstab/UUID）；空白盘自动 GPT+ext4（卷标 `NVME0`）；不支持的文件系统不格式化
- **Home Assistant**：`luci-app-homeassistant` + 中文语言包（Docker 方式，镜像首次启动拉取）
- **软件源**：内置 `/etc/opkg/distfeeds.conf` —— ImmortalWrt 24.10.0（CERNET，6 源）+ **iStoreOS 官方仓库（store / nas_luci / nas，322 个包）**，刷完即可在「系统 → 软件包」安装；首次启动自动补 `arch aarch64_cortex-a53`、必要时自动关闭签名校验（日志 `/etc/opkg-boot.log`）；kmods 因自编内核 6.6.99 与官方 6.6.86 不匹配而未启用

第三方源：`kenzok8/small-package`（只按名安装需要的包，避免与官方源同名冲突）、`DustReliant/luci-app-filetransfer`（本地单包引入）。

---

## 文档

| 文档 | 内容 |
| --- | --- |
| [docs/build-guide.md](docs/build-guide.md) | **下次编译详细教程**：触发方式、24 步流程与实测耗时、产物下载、刷机、失败速查表、12 条注意事项、30 秒检查清单 |
| [docs/packages.md](docs/packages.md) | **固件包清单**（重点应用 + 全量分类表 + 基线指纹；随每次成功构建刷新） |
| [docs/ci-build.md](docs/ci-build.md) | 构建方案设计、依赖来源表、实测记录与已踩过的坑 |
| [.github/workflows/publish-release.yml](.github/workflows/publish-release.yml) | 把任意历史 run 的 artifact 补发到指定 Release |

---

## 本地编译

```bash
git clone --depth 1 https://github.com/iiibeloved/immortalwrt-rk356x.git
cd immortalwrt-rk356x

cp feeds.conf.default feeds.conf
echo 'src-git small https://github.com/kenzok8/small-package.git;main' >> feeds.conf
./scripts/feeds update -a && ./scripts/feeds install -a
./scripts/feeds update small
for p in quickstart luci-app-quickstart luci-app-store luci-lib-taskd luci-lib-xterm taskd \
         unishare luci-app-unishare webdav2 luci-app-lucky lucky luci-app-wolplus luci-app-rtbwmon; do
  ./scripts/feeds install "$p"
done
git clone --depth 1 https://github.com/DustReliant/luci-app-filetransfer.git package/luci-app-filetransfer

cp defconfig/g68-plus-docker.config .config
cat defconfig/g68-plus-istoreos.config >> .config
make defconfig
make download -j"$(nproc)"
make -j"$(nproc)"

ls bin/targets/rockchip/armv8/
```

宿主机需要 `python3-pyelftools`（RK3568 u-boot 打 FIT 镜像必需），否则会在 prereq 阶段失败。

---

## 注意事项

1. **刷完默认 LAN 地址是 `192.168.100.1`**（首启由 `/etc/uci-defaults/99-set-lan-ip` 改好），DHCP 池 192.168.100.100–249；要换地址直接 `uci set network.lan.ipaddr=...`。
2. `uci-defaults` 里的 5 个脚本是**一次性**的（执行成功即自动删除）；`/etc/init.d/` 里 4 个每次开机运行但都幂等 —— 详见 [build-guide 附录 D](docs/build-guide.md)。

1. 构建中途取消会丢失 `dl` / `.ccache` 缓存，下次仍需重拉 feeds 与重编。
2. 改 `docs/` 或 workflow 不会触发构建；只有改 `defconfig/` 下两个文件才会。
3. cron 是 UTC：`0 18 * * 0` 对应**周一 02:00（北京时间）**。
4. 仓库 60 天无提交活动，GitHub 会停用定时任务，需在 Actions 页面手动 Enable。
5. 构建失败会**自动开 Issue**（含定时构建），正文带 run 链接、失败步骤与排查指引；同类未关闭 issue 存在时改为追加评论。
6. 附加插件多为社区维护，刷机后建议逐项验证（quickstart / iStore / 共享 / Docker）。
7. 第三方 feed 跟随上游 `master`，需要完全可复现构建时应锁定 commit。
