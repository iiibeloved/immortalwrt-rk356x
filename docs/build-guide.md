# G68-PLUS 固件 · 下次编译详细教程

> 仓库：<https://github.com/iiibeloved/immortalwrt-rk356x>
> 目标：rockchip / armv8 / `DEVICE_nsy_g68-plus`（NSY G68-PLUS，RK3568，aarch64_generic，Linux 6.6）
> 当前配置：`defconfig/g68-plus-docker.config` + `defconfig/g68-plus-istoreos.config`
> 文档更新：2026-11-06（基于 run #42186516665 首次成功构建的实测数据）

---

## 0. 一页速查（赶时间只看这里）

| 事项 | 值 |
| --- | --- |
| 下次构建 | **每周一 02:00 CST**（cron `0 18 * * 0`，UTC 周日 18:00）；也可随时手动 Run workflow |
| 想提前编 | Actions → `Build G68-PLUS (iStoreOS style)` → **Run workflow** |
| 预计耗时 | **约 4 小时 15 分**（基线保留 ss-rust；关闭 ss-rust 可降到约 2.5 小时） |
| 单次超时上限 | 350 分钟（workflow 内 `timeout-minutes`，GitHub 硬上限 360） |
| 产物保存 | artifact **15 天**；Release 资产**长期**（除非手动删） |
| 成功后的 Release tag | `g68-plus-YYYY.MM.DD`，同日重编自动加 `-r<run_number>` |
| 失败时看什么 | 该 run 的 `build-log-<n>` artifact（内含 `build.log` / `download.log` / `rust-host.log` / `toolchain.log`） |
| 改哪个文件 | 只改 `defconfig/g68-plus-istoreos.config`（附加项），**不要手改 `.config`** |

---

## 1. 触发方式（三选一）

### 1.1 定时构建（默认，无需操作）

- workflow 内 `schedule: cron "0 18 * * 0"` → **每周一 02:00（北京时间）** 自动跑。
- 注意：**GitHub 的 cron 一律按 UTC 解释**，改时间时记得 -8 小时。
- 注意：仓库 **60 天无任何提交活动**，GitHub 会自动停用定时任务（页面会提示 `Disabled`），
  届时去 Actions 页面点一次 **Enable workflow** 即可。
- 定时任务只在**默认分支**（`main`）上生效；fork 出来的仓库默认不会继承定时构建。

### 1.2 网页手动触发（推荐用于验证改动）

1. 打开 <https://github.com/iiibeloved/immortalwrt-rk356x/actions/workflows/build-g68-plus-docker.yml>
2. 右上角 **Run workflow** → 分支选 `main`
3. 按下表填参数（全部有默认值，一般直接点绿色按钮）

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `defconfig` | `defconfig/g68-plus-docker.config` | 基础配置，改它等于换机型 |
| `extra_config` | `defconfig/g68-plus-istoreos.config` | 附加差异项（iStoreOS 插件等） |
| `rootfs_size` | `200` | 只读系统分区，与 fork 源 `CONFIG_TARGET_ROOTFS_PARTSIZE=200` 一致。**实测 squashfs=160.2 MiB**（xz，5824 inode）→ 占用 ~80%；去掉 ss-rust 后约 75%。需要余量传 `256` |
| `rootfs_data_size` | `4096` | 可写 overlay：iStore/opkg 装包、docker 数据、配置改动（镜像脚本读 `ROOTFS_DATA_PARTSIZE`） |
| `upload_artifacts` | `true` | 是否上传 artifact（15 天有效） |
| `publish_release` | `true` | 成功后是否自动发 Release（生成免登录直链） |

4. 触发后在同页面能看到新 run，点进去可看实时日志。

### 1.3 命令行触发（脚本化 / 批量）

```bash
# 方式 A: gh CLI
gh workflow run build-g68-plus-docker.yml \
  --repo iiibeloved/immortalwrt-rk356x --ref main \
  -f defconfig=defconfig/g68-plus-docker.config \
  -f extra_config=defconfig/g68-plus-istoreos.config \
  -f rootfs_size=2048 \
  -f rootfs_data_size=4096 \
  -f upload_artifacts=true \
  -f publish_release=true

# 方式 B: REST API（PAT 需要 workflow scope 或 fine-grained 的 Actions: write）
curl -X POST \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/iiibeloved/immortalwrt-rk356x/actions/workflows/build-g68-plus-docker.yml/dispatches \
  -d '{"ref":"main","inputs":{
        "defconfig":"defconfig/g68-plus-docker.config",
        "extra_config":"defconfig/g68-plus-istoreos.config",
        "rootfs_size":"2048",
        "rootfs_data_size":"4096",
        "upload_artifacts":"true",
        "publish_release":"true"}}'
```

触发成功返回 `204 No Content`；用下面命令确认：

```bash
gh run list --repo iiibeloved/immortalwrt-rk356x --limit 3
```

### 1.4 什么情况下会自动触发（以及不会）

| 事件 | 是否构建 |
| --- | --- |
| 手动 Run workflow | ✅ |
| push 改动 `defconfig/g68-plus-docker.config` 或 `defconfig/g68-plus-istoreos.config` | ✅ |
| push 改动 `.github/workflows/*.yml` 或 `docs/*` | ❌（故意如此，避免改文档就重编 2.5 小时） |
| 每周一 02:00 定时 | ✅ |

---

## 2. 编译过程（24 个步骤，按实际执行顺序）

| # | 步骤 | 参考耗时 | 说明 |
| --- | --- | --- | --- |
| 1 | 释放磁盘空间 | 1–3 min | 删 runner 上的 dotnet/Android SDK 等 |
| 2 | 检出源码 | <1 min | `fetch-depth: 1` |
| 3 | 修正内置脚本的可执行位 | <1 min | `files/` 下脚本 `chmod +x` 兜底 |
| 4 | 校验配置并打印目标 | <1 min | defconfig 不存在直接 fail-fast |
| 5 | 安装编译依赖 | 2–10 min | 含 `python3-pyelftools`（RK3568 u-boot 必需） |
| 6–7 | 生成 feeds.conf / 安装官方 4 源 | 3–8 min | packages/luci/routing/telephony 全量 |
| 8 | 引入第三方 feed 并选择性安装 | 2–3 min | `kenzok8/small-package` 只按名装需要的包 |
| 9 | 引入 `luci-app-filetransfer`（本地包） | <1 min | 第三方单包，直连 clone |
| 10 | 应用 defconfig + 附加配置 | <1 min | 追加 + `make defconfig` + **强制关闭 pass** |
| 11 | 校验宿主机依赖（`make prereq`） | 1–2 min | 提前暴露 pyelftools 类问题 |
| 12 | 校验附加包是否生效 | <1 min | Job Summary 表格 ✅ / ⚠️ / ⛔ |
| 13 | 缓存 dl 与 ccache | <1 min | 命中缓存显著提速 |
| 14 | 下载软件包源码 | 1–13 min | `make download`，命中缓存时很快 |
| 15 | 构建工具链（tools + toolchain） | 22–35 min | 产出 `aarch64-openwrt-linux-musl-gcc` |
| 16 | 修复 rust vendor 校验并预编译 rust host | **80–120 min**（保留 ss-rust 时） | 关掉 ss-rust 则整步跳过 |
| 17 | 编译固件（`make world` 剩余部分） | 45–75 min | 内核 + u-boot/ATF + 550+ 包 + 镜像 |
| 18 | 记录 rootfs 占用 | <1 min | 打印 squashfs 实际大小，≥85% 告警 |
| 19 | 校验镜像分区表 | <1 min | 断言 MBR 为 `16 / 200 / 4096`，不符直接失败 |
| 20 | 收集固件 | <1 min | 拷到 `output/` |
| 21 | 上传固件 artifact | 1–2 min | 约 165–200 MB |
| 22 | 发布到 Release | 1–2 min | tag `g68-plus-YYYY.MM.DD`，含 `.img.gz` + `sha256sums` |
| 23 | 构建失败时自动开 issue | 0 | 仅失败时执行，见 3.1 |
| 24 | 上传编译日志 | 0 | 仅失败时执行（`build.log` 等 4 个） |

**总时长参考**：保留 ss-rust（当前基线）**≈ 3.5–4 小时**；关掉 ss-rust 可降到 **≈ 2.5 小时**。

## 3. 怎么看进度 / 怎么判断成功

- run 列表：<https://github.com/iiibeloved/immortalwrt-rk356x/actions>
- 单个 run：点进去 → 左侧 job `rockchip/armv8 · nsy_g68-plus` → 步骤列表、点步骤展开实时日志
- 成功后：页面底部 **Artifacts** 出现 `immortalwrt-g68-plus-<n>`，同时 **Releases** 里多一个 tag
- 失败后：底部会多一个 `build-log-<n>`，下载解压可看到 4 个日志（见第 6 节）

> 提示：**构建中的 run 无法通过 API 下载完整日志**（GitHub 要等 job 结束才生成日志 blob）。
> 想实时看进度只能在网页里展开步骤看滚动日志。

### 3.1 构建失败会自动开 issue（含定时构建）

workflow 最后有一步「构建失败时自动开 issue」（`if: failure()`），用的是内置 `GITHUB_TOKEN`
（workflow 顶部已声明 `issues: write` + `actions: read`），不需要额外 secret：

- 仓库 **Issues 页**会出现标题形如 `CI 构建失败: Build G68-PLUS (iStoreOS style) #58` 的 issue；
- 正文自动包含：本次 run 链接、commit、触发方式（schedule / workflow_dispatch / push）、**失败的具体步骤名**、
  以及 4 步排查指引（含 `build-log-<n>` artifact 说明和本文第 6 节的链接）；
- **去重策略**：若已存在未关闭的同类 issue，则不新建，改为在该 issue 下追加评论（每次失败一条）；
- 想恢复「每次失败都新建」：把 issue 关掉即可（关闭后下次失败会新开一条）；
- 想彻底关掉通知：删掉 workflow 里名为「构建失败时自动开 issue」的那一步。

---

## 4. 产物与下载

| 类型 | 位置 | 有效期 | 是否需要登录 |
| --- | --- | --- | --- |
| artifact | run 页面底部 Artifacts | **15 天** | 需要 GitHub 登录 |
| Release 资产 | `https://github.com/iiibeloved/immortalwrt-rk356x/releases/tag/<tag>` | 长期 | **不需要** |

Release 直链格式：

```
https://github.com/iiibeloved/immortalwrt-rk356x/releases/download/<tag>/immortalwrt-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img.gz
```

该机型（`pine64-img` 流程）**只产出 `sysupgrade.img.gz`**，没有单独的 sdcard 镜像；
这个 `.img.gz` 解压后就是完整可直刷镜像。

---

## 5. 刷机步骤（务必核对 sha256）

```bash
# 1) 下载
curl -LO https://github.com/iiibeloved/immortalwrt-rk356x/releases/download/<tag>/immortalwrt-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img.gz
curl -LO https://github.com/iiibeloved/immortalwrt-rk356x/releases/download/<tag>/sha256sums

# 2) 校验（必须做，写错设备会变砖）
sha256sum -c sha256sums --ignore-missing

# 3) 解压 + 写入（把 sdX 换成你的 eMMC/SD 设备，务必确认！）
gunzip immortalwrt-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img.gz
lsblk                                   # 先确认设备名
sudo dd if=immortalwrt-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img \
        of=/dev/sdX bs=4M conv=fsync status=progress
sync
```

也可以直接在 LuCI「系统 → 备份/升级」里上传 `.img.gz`（保留配置的勾选按需）。

---

## 6. 失败排查速查表

先下载该 run 的 `build-log-<n>` artifact，里面有 4 个文件：

| 文件 | 什么时候有 | 看什么 |
| --- | --- | --- |
| `build.log` | 走到第 17 步 | 最后的 `make[...]: *** ... Error` 行 |
| `download.log` | 第 14 步 | `Download failed` / `403` / `404` |
| `toolchain.log` | 第 15 步 | 工具链编译错误 |
| `rust-host.log` | 第 16 步 | `error: ...` / `panicked at` |

常见故障与处置：

| 现象 | 原因 | 处置 |
| --- | --- | --- |
| `Checking 'python3-pyelftools'... failed` | 宿主缺 pyelftools，RK3568 u-boot 打 FIT 需要 | 已修（apt 列表已含）；若换 runner 镜像需重新确认 |
| `failed to calculate checksum of ... Cargo.toml.orig` | rust vendor 的 `.cargo-checksum.json` 与解包内容不一致 | 已修（第 16 步会扫解包树删掉缺失条目） |
| `couldn't find required command: aarch64-...-gcc` | rust 预编译跑在工具链之前 | 已修（第 15 步先编工具链） |
| `ERROR: duplicate package name` 或 feeds 同名包冲突 | 对 `small-package` 执行了 `feeds install -a` | 已规避（只按名安装需要的包） |
| `Download failed` 若干条 | 上游源临时 403/404 | 一般是瞬时问题，重跑一次；持续失败就去查对应包的上游仓库 |
| 第 17 步超过 350 分钟被杀 | 超出 `timeout-minutes` | 把 `timeout-minutes` 提到 360（GitHub 上限），或关闭 ss-rust 缩短时间 |
| Release 步骤失败但构建成功 | `publish_release` 权限/网络问题 | 用 `Publish firmware to Release` workflow 手动补发（见 7.3） |
| 步骤显示 skipped | `if` 条件不满足（如 `publish_release=false`、或前序失败） | 检查输入参数与前序步骤 |
| 手动 `mkfs`/`mount` 报 `No such device` / `Can't open blockdev` | 在线改分区表后内核还没生成分区节点 | **重启一次**再格式化（本固件不再自动重启，需手动重启） |
| iStore「快速安装」里存储位置为空 | 没有任何可用数据分区（只有系统分区） | 先完成拆盘（新固件首启自动做），或手动建 p5/p6 并挂载 |

---

## 7. 常见维护操作

### 7.1 加/减软件包

只改 `defconfig/g68-plus-istoreos.config`：

```ini
CONFIG_PACKAGE_luci-app-xxx=y                  # 加包
# CONFIG_PACKAGE_luci-app-yyy is not set       # 关包（后面写会覆盖前面的 =y）
```

约束：

- 包名必须是 feeds 里真实存在的符号，写错会被 `make defconfig` 静默丢弃；
  第 12 步会在 Job Summary 里标 `⚠️ 未启用` 并发出 warning，照着补即可。
- 需要第三方源的包，要在 workflow 第 8 步的 `PKGS` 列表里加名字，否则构建时找不到包。
  当前 `PKGS` 已包含：quickstart / luci-app-quickstart / luci-app-store / luci-lib-taskd / luci-lib-xterm / taskd /
  unishare / luci-app-unishare / webdav2 / luci-app-lucky / lucky / luci-app-wolplus / luci-app-rtbwmon /
  luci-app-homeassistant / luci-app-eqosplus / luci-app-timecontrol / luci-app-control-webrestriction / luci-app-control-weburl。
- 官方 feed 里的包（`luci-app-nfs`、`luci-app-cifs-mount`、`luci-app-diskman`、`nfs-kernel-server`、`kmod-fs-cifs` 等）**不需要**加进 PKGS。
- 改完 push（只改这个文件会触发构建）。

### 7.2 关闭 / 恢复 shadowsocks-rust（影响约 2 小时）

**当前状态：保持启用**（由基础 defconfig 的 `CONFIG_PACKAGE_shadowsocks-rust-sslocal/ssserver=y` 选中），
固件带 ss 客户端/服务端；代价是要编 `lang/rust`（rustc + LLVM），构建约 **4 小时 15 分**。

**要关闭**：在 `defconfig/g68-plus-istoreos.config` 里加两行

```ini
# CONFIG_PACKAGE_shadowsocks-rust-sslocal is not set
# CONFIG_PACKAGE_shadowsocks-rust-ssserver is not set
```

workflow 的「强制关闭 pass」会用 `sed` 把 `.config` 里的 `=y` 改写成 `is not set` 并重跑一次
`make defconfig`（实测 kconfig 单独靠追加行会被翻回 `=y`）。之后第 17 步会检测到「config 里没有 rust 组件」
自动跳过，构建降到约 **2.5 小时**。

**要恢复**：删掉这两行即可。

### 7.3 手动补发 Release（历史构建）

Actions → `Publish firmware to Release` → Run workflow，填：

```
run_id   : 42186516665              # 来源构建 id
artifact : immortalwrt-g68-plus-6   # 该 run 的 artifact 名
tag      : g68-plus-2026.11.06      # 目标 tag；已存在则直接追加资产
```

### 7.4 调整 rootfs 分区

两个独立参数，Run workflow 时直接填：`rootfs_size`（只读系统分区，默认 2048）与 `rootfs_data_size`（可写 overlay，默认 4096）。
注意分区规则（`scripts/gen_image_generic.sh`）：

| 分区 | 大小 | 来源 | 用途 |
| --- | --- | --- | --- |
| kernel/boot | 16 MiB | `CONFIG_TARGET_KERNEL_PARTSIZE` | 内核 + dtb + boot.scr |
| rootfs | `rootfs_size`（现 **200 MiB**，与 fork 一致） | `CONFIG_TARGET_ROOTFS_PARTSIZE`，被 workflow 覆盖 | **只读 squashfs**，497 个包都在这里；**实测 160.2 MiB**（xz / 5824 inode / block 256 KiB） |
| rootfs_data | `rootfs_data_size`（现 **4096 MiB**） | 镜像脚本 `gen_image_generic.sh` 读 `ROOTFS_DATA_PARTSIZE`（本仓库默认 4096） | 可写 overlay：配置改动、iStore/opkg 装的包、docker 数据 |

当前配置整盘镜像约 **4.3 GiB**（16 + 200 + 4096 + 对齐空隙 32 MiB×2），`.img.gz` 约 165–180 MB；目标 eMMC/SD 卡 ≥5 GB。
构建会在 Job Summary 输出 squashfs 实际占用率；≥85% 时自动 `::warning::` 提示调大 `rootfs_size`。

**实测数据（2026-11-06 那版镜像，直接解析 squashfs 超级块）**：

| 项目 | 值 |
| --- | --- |
| squashfs 文件系统 | squashfs 4.0，xz 压缩，block 256 KiB |
| inode / 片段 | 5824 / 307 |
| `bytes_used` | **167,949,051 字节 = 160.17 MiB** |
| 放进 200 MiB 分区 | 占用 **80%**（余量 ~40 MiB） |
| 放进 256 MiB 分区 | 占用 63%（余量 ~96 MiB） |

该镜像含 `shadowsocks-rust`；下一版已关闭它，squashfs 会再小 5–10 MiB（约 150 MiB，占用 ~75%）。
**docker / iStore 的可用空间由 `rootfs_data_size` 决定**（现 4096 MiB），与 `rootfs_size` 无关。

### 7.5 给 docker / iStore 扩容（rootfs_data 默认 4096 MiB）

扩容 docker / iStore 要调的是 **`rootfs_data_size`**（现 4096 MiB）。另外三种免重编做法：

1. **docker 数据放外部盘（推荐）**：LuCI → Docker → 配置，把 `data_root` 改到挂载点，例如
   ```
   uci set dockerd.globals.data_root='/mnt/sda1/docker'
   uci commit dockerd && /etc/init.d/dockerd restart
   ```
2. **extroot**：把整个 overlay 迁到 USB/SSD，`rootfs_data` 只留启动用（LuCI → 系统 → 挂载点 → 生成配置 → 启用 extroot）。
3. **改镜像里的 rootfs_data 大小**：`scripts/gen_image_generic.sh` 里 `USERDATASIZE="2048"` 改成 `4096`（该文件不在 push 触发路径，改完需手动 Run workflow）。

### 7.6 数据盘：手动分区 / 挂载（2026-11-08 起不再自动分区）

> **重要变更**：固件**已移除自动分区脚本**（`docker-disk` / `docker-dataroot`）。
> 原因：在 eMMC 上在线改 MBR 需要重启才能被内核识别，而如果在格式化/重启窗口断电，
> 可能留下不完整的 overlay/分区表 —— 权衡后改为**可靠的手动操作**，固件只负责“挂载即可用”。

#### 7.6.1 一次性给 eMMC 划出 docker 盘与数据盘（手动，约 5 分钟）

前提：确认 eMMC 上除 p1/p2/p3 外没有要保留的数据。

```sh
# ① 看当前分区表（p3 结束位置记为 base，单位 MiB）
parted -s /dev/mmcblk0 unit MiB print

# ② 建扩展分区 + 两个逻辑分区（示例：p3 结束于 4597MiB，docker 50GiB）
parted -s /dev/mmcblk0 unit MiB mkpart extended 4598 100%
parted -s /dev/mmcblk0 unit MiB mkpart logical ext4 4599 55798
parted -s /dev/mmcblk0 unit MiB mkpart logical ext4 55799 100%
parted -s /dev/mmcblk0 unit MiB print          # 期望 4=extended, 5≈50GiB, 6=其余

# ③ 必须重启：内核要重新读取分区表（否则 mkfs 会报 No such device）
reboot
```

重启后：

```sh
mkfs.ext4 -F -m 0 -L ext_relay /dev/mmcblk0p5     # docker 用，50 GiB
mkfs.ext4 -F -m 0 -L Data      /dev/mmcblk0p6     # 数据/共享盘，其余
mkdir -p /mnt/ext_relay /mnt/data
mount -t ext4 /dev/mmcblk0p5 /mnt/ext_relay
mount -t ext4 /dev/mmcblk0p6 /mnt/data
df -h /mnt/ext_relay /mnt/data

# ④ 写入 fstab（重启自动挂载，按 UUID）
block detect > /etc/config/fstab && uci commit fstab
```

也可以全程用 LuCI：**系统 → 挂载点**（新建分区、格式化、挂载、勾选“启用”），效果相同。

> `parted` 用的是 `-a none` 之外的默认对齐；若报 `closest location`，把起点改成 `extended 起点 + 1`
> （上面的 `4599` 就是为此留的 EBR 位置）。

#### 7.6.2 让 docker 使用 ext_relay

```sh
uci set dockerd.globals.data_root='/mnt/ext_relay/docker'
uci commit dockerd
/etc/init.d/dockerd restart
docker info | grep -i 'docker root dir'      # 期望 /mnt/ext_relay/docker
```

不设置的话 docker 用 overlay 里的 `/opt/docker`（仅 4 GiB，容易满）。

#### 7.6.3 iStore 的「存储位置」

固件**不再自动预设**任何安装路径：商店「快速安装」里的 `存储位置` 下拉，内容来自
`lsblk` 中 **fssize > 1 GiB 且有挂载点** 的分区（例如你手动挂好的 `/mnt/data`、`/mnt/nvme0`），
选哪个就用哪个；不选则用 `quickstart` 的默认目录。程序本体仍装进 `/overlay`（见[附录 F](#附录-f-存储分布与安装位置docker--istore)）。

### 7.8 内置 opkg 软件源（官方 + iStoreOS，刷完即用）

镜像内置 `files/etc/opkg/distfeeds.conf`，刷完开机即生效，**不用再手动粘贴地址**。分两组：

**A. ImmortalWrt 24.10.0（CERNET 镜像，6 个源）**

```
src/gz immortalwrt_core       .../releases/24.10.0/targets/rockchip/armv8/packages
src/gz immortalwrt_base       .../releases/24.10.0/packages/aarch64_generic/base
src/gz immortalwrt_luci       .../releases/24.10.0/packages/aarch64_generic/luci
src/gz immortalwrt_packages   .../releases/24.10.0/packages/aarch64_generic/packages
src/gz immortalwrt_routing    .../releases/24.10.0/packages/aarch64_generic/routing
src/gz immortalwrt_telephony  .../releases/24.10.0/packages/aarch64_generic/telephony
```

**B. iStoreOS 系（linkease 官方二进制仓库，3 个源）**

| 源 | URL | 内容 | 实测包数 |
| --- | --- | --- | --- |
| `istore_store` | `https://istore.istoreos.com/repo/all/store` | luci-app-store + luci-lib-taskd/xterm + taskd | 4 |
| `istore_nas_luci` | `https://istore.istoreos.com/repo/all/nas_luci` | iStore 应用（ariang、docker-lan-bridge、luci-app-agentflow、LingTiGameAcc…） | 251 |
| `istore_nas` | `https://istore.istoreos.com/repo/aarch64_cortex-a53/nas` | NAS 相关二进制（cortex-a53 编译，与 aarch64_generic 兼容） | 67 |

配套的两个处理（首次启动自动执行，脚本 `files/etc/uci-defaults/99-opkg-istore`）：

1. **架构兼容**：nas 源是 `aarch64_cortex-a53` 编译，首次启动会在 `/etc/opkg.conf` 追加
   `arch aarch64_cortex-a53 5`，否则 opkg 会以架构不匹配拒绝安装；
2. **签名兜底**：iStore 的 `Packages.sig` 由 key `1d15e401c11b3e0f` 签名，但**该公钥未公开**
   （仓库根目录只放了 `a56f16274c6d486b`，已内置到 `/etc/opkg/keys/`）。首次启动会后台跑一次
   `opkg update`（等 25 秒、限时 120 秒），若日志出现 `Signature check failed`，自动追加
   `option check_signature 0` 并重试一次。全过程记录在 **`/etc/opkg-boot.log`**。

**kmods 未启用**：kmods 目录按「内核版本 + vermagic」分目录，本固件内核是 fork 自编的 **6.6.99**，
官方 24.10.1 的是 6.6.86 系列，装了会报 `kernel version mismatch`（连 core 源里的 `kmod-*` 也一样）。
需要内核模块请在构建时通过 defconfig 选进固件。确认本机内核：`uname -r`。

**换镜像**：直接编辑 `/etc/opkg/distfeeds.conf` 的 URL，然后 `opkg update`。
不要在快照固件上跑全量 `opkg upgrade`（快照包与 24.10.0 发布版不完全一致），只装需要的新包。

### 7.9 NVMe 硬盘自动检测与挂载

固件内置 `/etc/init.d/nvme-automount`（START=62，每次开机执行、幂等），自动处理 `/dev/nvme*n1`：

| 情况 | 行为 |
| --- | --- |
| 已有分区 + 受支持文件系统（ext4 / xfs / btrfs / f2fs / exfat / **ntfs3**） | 挂到 `/mnt/nvme0`（多分区依次 `/mnt/nvme0_pN`），按 **UUID** 写入 fstab，后续开机由 block-mount 自动挂载 |
| 磁盘完全空白（无分区表） | **默认不格式化、直接跳过**（保护盘内数据，只写日志）；确需自动建 GPT+ext4 时显式开启：`touch /etc/nvme-automount.format` 后重启（或临时 `NVME_FORMAT=1`） |
| 有分区但文件系统不受支持（如 NTFS） | **只记日志，不格式化、不挂载**（保护数据） |
| 小于 8 GiB 的空白盘 | 即使开启格式化也跳过 |

日志：`/etc/nvme-automount.log`、`logread | grep nvme-automount`。
快捷开关（在 `/etc` 下建文件即可，开机读取）：

```sh
touch /etc/nvme-automount.off       # 完全关闭（不检测、不挂载）
touch /etc/nvme-automount.format    # 【非默认】允许对空白盘自动建 GPT+ext4（会丢盘内数据，慎用）
# 默认行为 = 只挂载已有文件系统；空白/未知文件系统只记日志，绝不格式化
```

**与 docker 的关系**：当前 docker 数据目录固定走 eMMC 的 `/mnt/ext_relay/docker`（50 GiB，`docker-disk` 在 START=58 已设好，
`nvme-automount` 在 62 才跑，所以不会抢占）。想把 docker 放到 NVMe 上：

```sh
uci set dockerd.globals.data_root='/mnt/nvme0/docker'
uci commit dockerd && /etc/init.d/dockerd restart
```

（也可以在镜像里把 `nvme-automount` 的 `START` 调到 56，让 `docker-dataroot` 自动优先选 NVMe。）

### 7.10 修掉 TTYD 终端「已拒绝连接」（改 LAN IP 后必现）

**症状**：改过 LAN 管理地址（或换网段）后，LuCI 里的 TTYD 终端打不开，浏览器报「已拒绝连接 / ERR_CONNECTION_REFUSED」。

**原因**：上游 `/etc/config/ttyd` 默认有 `option interface '@lan'`，`/etc/init.d/ttyd` 会把它翻成
`ttyd -i <LAN 网卡>`。ttyd 只在**启动那一刻**绑定该网卡当时的地址；之后 LAN IP 变了，
监听 socket 还停在旧地址，新地址自然连不上（重启 ttyd 或重启路由器就能临时恢复，但下次改 IP 又会出现）。

**固件内的处理**（无需再手改 init 脚本）：

1. 内置 `/etc/config/ttyd` **不设置** `interface`，即 ttyd 监听 `0.0.0.0:7681`，任何已放行网段都可访问，改 IP 不受影响；
2. 首次启动 `/etc/uci-defaults/98-fix-ttyd` 会**删掉**已有配置里的 `interface` 项（保留其它选项），
   `enable` 并 `restart` 一次，日志写 `/etc/ttyd-fix.log`。

**已经刷好的旧固件想立刻修**（SSH 执行，无需重编）：

```sh
uci -q delete ttyd.@ttyd[0].interface
uci commit ttyd
/etc/init.d/ttyd enable
/etc/init.d/ttyd restart
netstat -lntp | grep 7681        # 应看到 0.0.0.0:7681（而不是旧的 LAN IP）
```

**安全提醒**：监听 `0.0.0.0` 只代表「不受网卡 IP 变化影响」，WAN 侧仍由防火墙默认策略拦截（没有放行 7681 的规则）；
不要把 7681 加到 WAN 区域，也不要用 root 空密码。

### 7.11 电源灯：兼作「初始化进度指示」

电源灯 `led-power`（GPIO0_C4 → `/sys/class/leds/led-power`）由 `bootled`（START=12）统一管理，
**不再有独立的「电源灯开关」脚本**（原 `portled` 已合并删除，避免两个脚本抢写同一个灯）。

| 状态 | 含义 |
| --- | --- |
| **快速闪烁**（约 200 ms 亮/灭） | 正在初始化：挂载 / 一次性脚本 / `opkg update` 等 |
| **常亮** | 初始化完成，可登录 `192.168.100.1` |
| 不亮 | `bootled` 未运行或硬件问题 |

就绪判据：`/etc/uci-defaults/` 已清空 **且** 没有 `mkfs / parted / ha-config-path / nvme-automount / opkg update` 在跑；
最多闪 300 秒，超时强制常亮。日志 `/etc/bootled.log`。

**RJ45 网口灯不可控**：由 RTL8367S 交换芯片硬件驱动，`rtl8367b` 驱动未暴露 LED 属性；
该需求已放弃，嫌亮用物理遮挡或对长期不用的口 `swconfig dev switch0 port <n> set enable 0`（该口会断网）。

### 7.12 回滚 / 删除发布

```bash
gh release delete g68-plus-2026.11.06 --repo iiibeloved/immortalwrt-rk356x --cleanup-tag
```

---

## 8. 注意事项清单（最容易踩的坑）

1. **不要中途取消构建**：取消会让 `Post 缓存` 被跳过，本次下载/编译缓存全部丢弃，
   下次仍要重新拉 feeds 与重编。要停就等它跑完，或者接受缓存损失。
2. **同一时间只跑一个构建**：`concurrency` 已设为不自动取消，两个构建同时跑会互相吃 IO，
   且都拿不到缓存收益（workflow 里 key 带 `run_id`，不会互相覆盖，但重复劳动）。
3. **cron 是 UTC**：`0 18 * * 0` = 周一 02:00 北京时间，不是周日 18:00 北京时间。
4. **60 天无活动会停用定时任务**：GitHub 的政策，需手动 Enable workflow。
5. **不要手改 runner 上的 `.config`**：配置的唯一来源是仓库里的两个 defconfig 文件；
   手改只对当次有效，且会被下一次 `make defconfig` 归一化覆盖。
6. **附加包"启用了"不等于"能用"**：个别第三方插件（如 `luci-app-filetransfer`）是社区个人维护，
   首次刷机后建议实际打开验证；失效时构建只是少了那个功能，不影响出固件。
7. **`kenzok8/small-package` 跟随 master**：上游随时变动，同名包版本会漂移；
   需要完全可复现就把该 feed 锁定到某个 commit（`src-git-full` + 固定 SHA 的自建 fork）。
8. **两个参数各管各的**：`rootfs_size` 是只读系统分区，`rootfs_data_size` 才是 docker / iStore 的可用空间；
   二者之和决定整盘镜像大小（当前 16+200+4096 ≈ 4.3 GiB）。改完会有一道 `校验镜像分区表` 步骤核对实际 MBR。
9. **artifact 15 天过期**：重要固件立刻转存到 Release（workflow 已自动做）或本地归档。
10. **PAT/Token 权限**：手动触发需要 `workflow`（classic）或 Actions: write（fine-grained）；
    自动发布用的是内置 `GITHUB_TOKEN`（`permissions: contents: write`），不需要你配 secret。
11. **Actions 额度**：仓库是 public，构建不消耗私有仓库的免费分钟数；单 job 上限 6 小时。
12. **首次刷机后建议核对**（LuCI 里能直接看到）：
    `状态 → 概览`（内核 6.6.99）、`系统 → 软件包`（497 个包）、
    `系统 → 快速配置`（quickstart）、`iStore`（应用商店）、`网络存储 → 共享`（unishare/samba4）、
    `Docker → 容器`（dockerd）。

---

## 9. 下次构建前的 30 秒检查清单

- [ ] 确认 `defconfig/g68-plus-istoreos.config` 里想加的包都已写入（且包名拼写正确）
- [ ] 确认上次构建的失败日志已处理（如有）
- [ ] 确认没有正在运行的构建（避免并发）
- [ ] 决定 `rootfs_size`（默认 **200**，与 fork 一致；看 Job Summary 占用率，>85% 告警就调到 256/512）与 `rootfs_data_size`（默认 **4096**）
- [ ] 决定是否 `publish_release`（默认 true）
- [ ] 触发方式：等周一 02:00 定时 / 或手动 Run workflow
- [ ] 构建结束后：看 Job Summary 的包表格 → 下载 artifact 或 Release → 校验 sha256 → 刷机


## 附录 A. 当前冻结基线（配置已冻结；产物以最新 Release 为准）

2026-11-07 起，`defconfig/g68-plus-istoreos.config` + 本 workflow 作为**最终基线**：定时构建与手动构建都用它，
不再有临时改动/一次性 cron。基线产物：

| 项目 | 值 |
| --- | --- |
| 构建 | run #42395804653（2026-11-08 01:20，**552 个包**，24 步全绿，257 分钟） |
| Release | `g68-plus-2026.11.08` |
| 镜像 sha256 | `d0dc8eb943aedf9614690a6dc3e512709360d83926d406c80653ad0fd312fa2f` |
| 分区 | kernel 16 MiB / rootfs 200 MiB / rootfs_data 4096 MiB |
| 首次启动自动拆盘 | 50 GiB `ext_relay`（docker）+ 其余 `Data`（共享） |
| 完整包清单 | [packages.md](packages.md) |

**基线校验**：想确认仓库未被改动，比对 `docs/packages.md` 顶部的三个 sha256
（`g68-plus-istoreos.config`、`build-g68-plus-docker.yml`、`gen_image_generic.sh`）即可。

**要偏离基线时**（例如临时试别的 rootfs 大小），不要改默认值，直接 Run workflow 显式传参，
构建产物会带 `-r<run_number>` 后缀，基线不受影响。

**基线提交**：`051846bb` 之后（含 LAN `192.168.100.1`、首启自动拆盘、NVMe 挂载、TTYD 修复）；**基线指纹文件**：[`docs/baseline.sha256`](baseline.sha256)
（17 个文件：2 个 defconfig、2 个 workflow、`gen_image_generic.sh`、`files/` 全部脚本与配置）。校验方式：

```bash
sha256sum -c docs/baseline.sha256      # 全部 OK = 仓库仍在基线状态
```

CI 在「校验配置并打印目标」步骤里做**强校验**：与指纹不一致直接 `::error::` 并**失败**（摘要表也会标 ❌），
避免「基线被悄悄改动却照常出固件」。**有意修改基线文件后**必须执行：

```bash
./scripts/update-baseline.sh      # 重新生成 docs/baseline.sha256
sha256sum -c docs/baseline.sha256 # 确认全 OK 再提交
```


## 附录 B. 基线自检（2026-11-07 全面检查结果）

| 检查项 | 方法 | 结果 |
| --- | --- | --- |
| 脚本语法 | `sh -n` 全部 8 个脚本 + `gen_image_generic.sh` | ✅ 全部通过 |
| 执行位 | 远程 git tree mode 检查 | ✅ init.d / uci-defaults 均 `100755`，配置文件 `100644` |
| 开机自启 | 每个 init.d 脚本都有对应 uci-defaults `enable` | ✅ bootled / nvme-automount / ha-config-path → `98-enable-custom-initd`；ttyd → `98-fix-ttyd` |
| 启动顺序 | START 值 | bootled 12 → nvme-automount 62 → ha-config-path 75 → dockerd 99 ✅ |
| 首次启动即生效 | `98-enable-custom-initd` 在后台立即执行一次（sleep 5） | ✅ 无需重启 |
| NVMe 支持 | 内核模块 | ✅ kmod-nvme / kmod-fs-ext4 / exfat / vfat / btrfs 已在；**本次补上 kmod-fs-f2fs、kmod-fs-xfs、kmod-fs-ntfs3** |
| 分区脚本幂等 | 假 sysfs 冒烟测试 | ✅ 已有 p5/p6 且已格式化 → 只挂载不重格；中途失败不写完成标记，下次自动重试 |
| fstab 安全 | 两个脚本都按 UUID 去重 | ✅ 不再追加重复项、也不再删已有条目 |
| 在线改表兼容 | 分区后内核未识别 → 自动重启一次（防循环标记） | ✅ 假 sysfs 4 场景验证（建盘→重启→格式化→幂等） |
| 商店可用性 | 拆盘后出现 `/mnt/ext_relay`、`/mnt/data` 供选择 | ✅ 依赖拆盘成功 |
| ttyd | 不绑定 `@lan` | ✅ 改 LAN IP 后不会「已拒绝连接」 |
| opkg 源 | 9 个源（官方 6 + iStoreOS 3） | ✅ 首次启动自动补 arch、必要时关签名校验 |


## 附录 C. 下载加速（GitHub 代理直链）

Release 资产在 GitHub 上直连慢时，可在链接前加代理前缀（文件内容与 sha256 完全不变）：

```
https://gh-proxy.com/https://github.com/<owner>/<repo>/releases/download/<tag>/<file>
https://ghfast.top/https://github.com/<owner>/<repo>/releases/download/<tag>/<file>
https://ghproxy.net/https://github.com/<owner>/<repo>/releases/download/<tag>/<file>
```

本仓库的实际链接（把 `<tag>` 换成具体版本，如 `g68-plus-2026.11.08`）：

| 方式 | 链接 |
| --- | --- |
| GitHub 直链 | `https://github.com/iiibeloved/immortalwrt-rk356x/releases/download/<tag>/immortalwrt-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img.gz` |
| 加速 1 | `https://gh-proxy.com/https://github.com/iiibeloved/immortalwrt-rk356x/releases/download/<tag>/immortalwrt-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img.gz` |
| 加速 2 | `https://ghfast.top/https://github.com/iiibeloved/immortalwrt-rk356x/releases/download/<tag>/immortalwrt-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img.gz` |
| 加速 3 | `https://ghproxy.net/https://github.com/iiibeloved/immortalwrt-rk356x/releases/download/<tag>/immortalwrt-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img.gz` |

`sha256sums` 同样可加前缀：

```
https://gh-proxy.com/https://github.com/iiibeloved/immortalwrt-rk356x/releases/download/<tag>/sha256sums
```

> 2026-11-07 实测三个代理对该仓库的 Release 资产均返回 `206`（支持断点续传）；
> `github.moeyy.xyz`、`hub.gitmirror.com`、`ghproxy.cc` 当时不可用。
>
> 每次构建的 Release 说明页也会自动列出这三条加速链接（workflow 的「发布到 Release」步骤生成）。


## 附录 D. 内置脚本的运行时机（一次性 / 每次开机）

| 脚本 | 位置 | 运行时机 | 会不会每次重启都跑 | 幂等保护 |
| --- | --- | --- | --- | --- |
| `98-enable-custom-initd` | `/etc/uci-defaults/` | 首次启动一次 | **不会**（OpenWrt 执行成功即删除该文件） | — |
| `98-fix-ttyd` | `/etc/uci-defaults/` | 首次启动一次 | **不会**（同上） | 只在存在 `interface` 时才改 |
| `99-set-lan-ip` | `/etc/uci-defaults/` | 首次启动一次 | **不会**（同上） | 已是目标地址则直接跳过 |
| `99-opkg-istore` | `/etc/uci-defaults/` | 首次启动一次 | **不会**（同上） | 已有 arch 行则不重复加 |
| `nvme-automount` | `/etc/init.d/`（已 enable） | **每次开机**（有意为之） | 会，但已挂载则跳过、fstab 按 UUID 去重 | 天然幂等 |
| `bootled` | `/etc/init.d/`（已 enable） | 每次开机 | 会（**必须**）：先闪烁，就绪后置常亮 | 就绪判据 + 300s 超时 |

**结论**：`uci-defaults` 那 5 个是**一次性**的，跑成功后被 OpenWrt 自动删除（失败的会保留、下次再试）；
`/etc/init.d/` 里的 4 个是**常驻**的，每次开机都会执行，但都带幂等/守卫逻辑，**不会重复分区、重复格式化或重复写 fstab**。

想手动重置某一步：

```sh
rm -f /etc/.docker-disk.done /etc/.docker-disk.rebooted   # 允许 docker-disk 重新执行
/etc/init.d/docker-disk start
```

## 附录 E. 默认 LAN 管理地址

固件首次启动会把 LAN 改成 **`192.168.100.1/24`**（由 `/etc/uci-defaults/99-set-lan-ip` 完成，一次性脚本）：

- 管理页：`http://192.168.100.1`
- DHCP 池：`192.168.100.100 – 192.168.100.249`（`dhcp.lan` 的 start/limit 是相对网段的偏移，改网段后自动跟随）
- 改完地址后旧网段（192.168.1.x）的会话会断开，电脑重新获取 DHCP 即可
- 想改回或换别的地址：`uci set network.lan.ipaddr=192.168.1.1 && uci commit network && /etc/init.d/network reload`


## 附录 F. 存储分布与安装位置（docker / iStore）

| 分区 | 大小 | 挂载点 | 谁在用 |
| --- | --- | --- | --- |
| `mmcblk0p1` | 16 MiB | — | kernel |
| `mmcblk0p2` | 200 MiB | `/rom` | squashfs 根（只读） |
| `mmcblk0p3` | 4096 MiB | `/overlay` | 系统可写层 + **iStore 应用本体**（opkg 装到这里） |
| `mmcblk0p5` | 50 GiB | `/mnt/ext_relay` | **Docker** 数据目录 `/mnt/ext_relay/docker` |
| `mmcblk0p6` | 其余 | `/mnt/data` | 共享盘 + **iStore 应用数据**（向导「存储位置」选它） |
| NVMe | — | `/mnt/nvme0` | 只挂载，内容不动 |

**Home Assistant 配置目录**：`/etc/init.d/ha-config-path`（START=75，每次开机轻量校验）按
`/mnt/data` → `/mnt/ext_relay` → `/mnt/nvme*` → 其它 `/mnt` 块挂载 选一个 ≥1 GiB 空闲的盘，
创建 `<base>/Configs/HomeAssistant/custom_components` 并写 `uci homeassistant.@homeassistant[0].config_path`。
路径命名与 LuCI 下拉选项一致（`<挂载点>/Configs/HomeAssistant`），所以页面会回显已选中；HACS 装进 `/config/custom_components` 即正常。
日志：`/etc/ha-config.log`。

**HACS 说明**：Home Assistant 自 **2026.11** 起用内置 **Marketplace** 取代 HACS（官方文档
`https://www.home-assistant.io/integrations/marketplace`），HACS 安装脚本会直接退出：

```
ERROR: HACS does not work on Home Assistant 2026.11 and newer (found 2026.11.0), as it has been replaced by the native Marketplace integration.
```

固件用 `files/usr/libexec/istorec/homeassistant.sh` 覆盖了 iStore 的安装脚本：先读容器内 `/config/.HA_VERSION`，
`>= 2026.11` 时**跳过 HACS 步骤并打印 Marketplace 使用提示**，不再刷 ERROR；其余安装逻辑与上游一致。

- 用 Marketplace：HA 界面 **设置 → Marketplace**；右上角 ⋮ → *Download source* 可切「Chinese Community Relays」加速；*Add from link* 可加 GitHub 上的自定义仓库。
- 确实要 HACS：把镜像换成 `2026.10.x` 的旧标签（应用页面「镜像」下拉里没有，需要 `uci set homeassistant.@homeassistant[0].image_name='homeassistant/home-assistant:2026.10.4'` 后重装），但会失去新特性与安全更新，不推荐。

**怎么确认**

```sh
docker info | grep -i 'docker root dir'      # 期望 /mnt/ext_relay/docker
df -h /overlay /mnt/ext_relay /mnt/data      # overlay 满 → iStore 安装失败
du -sh /mnt/ext_relay/docker                 # docker 实际占用
uci get istore.istore.last_path              # 商店里选的应用数据目录
opkg list-installed | wc -l                  # 已装包数（含 iStore 应用）
```

**两条容易踩的误解**

1. iStore 的「存储位置」**不是**程序安装位置：ipk 的安装目标由 `opkg` 的 `dest root /` 决定，永远是 `/overlay`（p3）。
   那个下拉框只把路径传给应用的安装向导（`AUTOCONF=<pkg> path=...`）并记到 `istore.last_path`，用于**应用数据**。
2. `docker info` 若显示 `/opt/docker`，说明拆盘没成功（旧固件 bug），此时 docker 在 overlay 的 4 GiB 内跑，很容易把系统撑满。

**想把 docker 挪到别的盘**

```sh
uci set dockerd.globals.data_root='/mnt/data/docker'   # 或 /mnt/nvme0/docker
uci commit dockerd && /etc/init.d/dockerd restart
docker info | grep -i 'docker root dir'
```
（迁移前先 `docker ps -a` 停掉容器，旧目录数据可 `cp -a` 过去。）


## 附录 G. opkg 报「has no valid architecture」的根因与修复

**现象**：`opkg install xxx` 对**任何包**都输出

```
Package luci-app-ddns version ... has no valid architecture, ignoring.
...
 * opkg_install_cmd: Cannot install package luci-app-ddns.
```

**根因**：`/etc/opkg.conf` 的架构段被拼接坏了。旧版首启脚本用 `echo 'arch aarch64_cortex-a53 5' >> /etc/opkg.conf` 追加，
而该文件末尾原本**没有换行符**，于是最后一行变成：

```
arch aarch64_generic 10arch aarch64_cortex-a53 5
```

优先级字段成了 `10arch`，opkg 解析后认为**所有**包的架构都不受支持 → 全部忽略。

**修复（已刷旧固件的机器，SSH 执行）**

```sh
cp /etc/opkg.conf /etc/opkg.conf.bak
sed -i '/^arch[ 	]/d' /etc/opkg.conf
printf 'arch all 1
arch noarch 1
arch aarch64_generic 10
arch aarch64_cortex-a53 5
' >> /etc/opkg.conf
opkg print-architecture          # 应看到 4 行，优先级是纯数字
opkg update
opkg install luci-app-ddns luci-i18n-ddns-zh-cn
```

**固件侧修复**（`files/etc/uci-defaults/99-opkg-istore`）：

1. 追加任何内容前先 `ensure_newline`（文件末尾无换行时补一个）；
2. `archs_ok` 校验每条 `arch` 行的**优先级必须是纯数字**；
3. 校验失败 → 删掉全部 `arch` 行后**重建**标准四行（`all 1` / `noarch 1` / `aarch64_generic 10` / `aarch64_cortex-a53 5`）；
4. 之后再等网络、校时、`opkg update`（3 次重试，仅签名失败时关校验）。

> 装完 DDNS 后日志里出现 `WARN : Service section disabled! - TERMINATE` 是**正常的** ——
> 表示 `/etc/config/ddns` 里还没有启用任何服务项；到 LuCI「服务 → 动态 DNS」添加一条（服务商 / 域名 / 密钥）即可。


## 附录 H. iStoreOS 源「Signature check failed」说明

`opkg update` 时三条 iStoreOS 源报签名失败，官方 6 个源全部 `Signature check passed`：

```
Downloading https://istore.istoreos.com/repo/all/store/Packages.sig
Signature check failed.
Remove wrong Signature file.
```

**原因**：iStoreOS 的 `store` / `nas_luci` / `nas` 三个仓库由 key **`1d15e401c11b3e0f`** 签名，
该公钥未公开发布；仓库根目录只提供 `a56f16274c6d486b`（只能验证 `all/compat` 这一个子源）。

**固件默认策略**：三个源**保持启用**（这样「软件包」里能看到 iStoreOS 的包），
首次启动脚本检测到签名失败时，会把 `/etc/opkg.conf` 里的 `option check_signature` **注释掉**后重试，
之后 `opkg update` 干净无报错。日志见 `/etc/opkg-boot.log`。

| 场景 | 做法 |
| --- | --- |
| 在 **iStore 商店**装应用 | 直接用商店即可。商店走 `/bin/is-opkg`，有独立源列表（`istore.istoreos.com/repo/{all,aarch64_generic}/isfeeds.conf`）且**跳过签名校验** |
| 在 **LuCI 软件包**里装 iStoreOS 的包 | 保持三源启用 + `option check_signature` 注释（脚本会自动处理）；等价手工命令：`sed -i 's/^\(option check_signature.*\)$/#\1/' /etc/opkg.conf && opkg update` |
| 想恢复**严格校验** | 恢复 `option check_signature`，并把三条 iStoreOS 源注释（官方 6 源签名均正常） |

**已刷旧固件想立刻消除这三条报错**（二选一）：

```sh
# 方案 A（推荐, 保留 iStoreOS 包源）: 关闭签名校验
sed -i 's/^\(option check_signature.*\)$/\#\1/' /etc/opkg.conf
opkg update

# 方案 B（严格校验官方源）: 注释掉三条 iStoreOS 源
sed -i 's#^src/gz istore_#\#src/gz istore_#' /etc/opkg/distfeeds.conf
opkg update
```

> 取舍：方案 A 会同时不再校验官方源的签名（因为 opkg 没有「按源」开关）；方案 B 保留官方校验，
> 但「软件包」里看不到 iStoreOS 的包（商店安装不受影响）。

（不影响已安装的 iStore 与商店安装应用。）


## 附录 I. 首次刷机操作指引（含「首启自动重启」）

刷完新固件**第一次开机**，固件会做一串初始化，其中可能**自动重启一次**（分区表写入后内核未即时识别时的兜底）。
按下面顺序操作最省事，也最不容易误判成「卡死 / 刷坏」。

### 一、刷机前（30 秒）

| 动作 | 说明 |
| --- | --- |
| **LAN 口接电脑**（或交换机） | 默认地址 `192.168.100.1`，DHCP 池 `192.168.100.100–249` |
| **WAN 口接光猫 / 上级路由** | 首启的 `opkg update`、NTP 校时需要外网；**不接也能用**，只是软件包列表要登录后手动点一次「更新列表」 |
| 不用插 NVMe / USB | 插了也行，`nvme-automount` 只挂载、不格式化，不会动盘内数据 |

### 二、第一次开机：什么都不做，等它自己重启

- 通电后**不要登录、不要断电**（此时后台可能在写分区表）；
- 约 **1–3 分钟**内会自动重启一次，日志特征（登录后可在 `/etc/.docker-disk.log` 看到）：

```
内核尚未识别新分区, 写入重启标记并重启(下次开机继续格式化)
```

- 这次重启是**预期行为**，SSH/LuCI 会断开，属正常。

### 三、第二次开机：继续等 2–5 分钟

后台在做（顺序执行）：

1. `mkfs.ext4` 格式化 `p5`（50 GiB，约 10–30 秒）
2. `mkfs.ext4` 格式化 `p6`（其余，约 30–60 秒）
3. 挂载 `/mnt/ext_relay`、`/mnt/data`，写 fstab（按 UUID）
4. `dockerd.globals.data_root=/mnt/ext_relay/docker`
5. `ha-config-path` 生成 `/mnt/data/Configs/HomeAssistant`（+`custom_components`）
6. `99-opkg-istore`：等网络 → NTP 校时 → `opkg update`（最多 3 次重试）

**这段时间不要断电**（正在格式化）。

### 四、5 分钟后登录并验证

```
浏览器: http://192.168.100.1    用户名 root / 密码空（首登请立刻设置）
```

```sh
parted -s /dev/mmcblk0 print | tail -4        # 期望 4 extended / 5 约 50G / 6 其余
df -h /mnt/ext_relay /mnt/data
docker info | grep -i 'docker root dir'       # 期望 /mnt/ext_relay/docker
ls /etc/rc.d/ | grep -E 'docker|nvme|ha-config'
cat /etc/.docker-disk.log                     # 拆盘全过程
cat /etc/opkg-boot.log | tail -5              # opkg 初始化结果
```

### 四点五、怎么判断「初始化已经跑完」

最省事的判断：**一次性脚本目录被清空 + 完成标记出现 + 90 秒内没有 mkfs 进程**。

```sh
# ① 一次性脚本应已全部被删除（OpenWrt 执行成功即删）
ls /etc/uci-defaults/                 # 期望：无输出

# ② 拆盘完成标记（存在=分区+格式化+挂载+fstab+docker root 都已做完）
ls -l /etc/.docker-disk.done          # 期望：存在
ls -l /etc/.docker-disk.rebooted      # 期望：不存在（存在=刚重启过，还在第二轮）

# ③ 没有正在跑的初始化进程
pgrep -f 'mkfs|docker-disk|docker-dataroot|ha-config-path'   # 期望：无输出

# ④ 结果自检
df -h | grep -E 'ext_relay|/mnt/data'
docker info | grep -i 'docker root dir'
```

**从下一版固件起**可以直接跑一条命令（本次 r25 里还没有这个文件）：

```sh
firstboot-status      # 8 项逐条 ✅/⏳，最后给「已就绪 / 仍在初始化」结论
```

各步骤的日志与标记一览：

| 步骤 | 日志 | 完成标记/判据 |
| --- | --- | --- |
| 启用常驻脚本 + 首启执行 | `/etc/custom-initd.log` | `/etc/rc.d/S58docker-disk` 等符号链接存在 |
| LAN 改址 | `/etc/lan-ip.log` | `uci get network.lan.ipaddr` = `192.168.100.1` |
| TTYD 修复 | `/etc/ttyd-fix.log` | `netstat -lnt \| grep 7681` |
| eMMC 拆盘 | `/etc/.docker-disk.log` | `/etc/.docker-disk.done`（末尾日志 `完成: …`） |
| NVMe 挂载 | `/etc/nvme-automount.log` | `/proc/mounts` 中出现 `/mnt/nvme0` |
| docker 数据目录 | `docker info` | `Docker Root Dir: /mnt/ext_relay/docker` |
| HA 配置路径 | `/etc/ha-config.log` | `uci get homeassistant.@homeassistant[0].config_path` |
| 电源灯进度 | `/etc/bootled.log` | 常亮=就绪 |
| 软件源 | `/etc/opkg-boot.log` | 末尾 `opkg update 成功（第 N 次）` |

> 经验时长（256 GB eMMC）：第一次开机到自动重启 **1–3 分钟**；第二次开机到全部就绪 **2–5 分钟**。
> 超过 **10 分钟**仍未出现 `.done`，按上一节看 `/etc/.docker-disk.log`。

### 五、如果 10 分钟后仍没有 p5/p6

按顺序看两处日志，按报错对照 [7.7 节](#77-首次启动自动拆分剩余空间256g-emmc-场景) 的坑位表：

```sh
cat /etc/.docker-disk.log
parted -s /dev/mmcblk0 print
ls -l /etc/.docker-disk.*     # .done 表示已完成; .rebooted 表示已重启过一次
```

手动兜底命令见 7.7 / 附录 G（`parted` 建 extended + 两次 `mkpart logical` → 重启 → `mkfs` → `mount` → `block detect`）。

### 六、常见疑问

| 疑问 | 回答 |
| --- | --- |
| 首启不插网线可以吗？ | 可以。拆盘/挂载/docker 都不需要网络；只有 `opkg update` 与 NTP 会失败（日志记录），登录后手动点一次「软件包 → 刷新」即可 |
| 必须先插 WAN 再开机吗？ | 不必，但**先插好**能让首启的 opkg/NTP 一次成功，省去手动刷新 |
| WAN 接上级路由 LAN，默认设置能上网吗？ | **能**。本机默认 `WAN(eth1/交换口 4) = DHCP 客户端`、`LAN(eth0/交换口 0-3) = 192.168.100.1/24 + DHCP + NAT`，上级有 DHCP 就自动拿到地址，无需任何设置 |
| 首启的 opkg update 会被自动重启打断吗？ | 可能。若被打断，一次性脚本**不会**被删除，第二次开机会自动重试；也可登录后手动「软件包 → 刷新列表」 |
| 需要改 WAN 协议吗？ | 仅两种情况：上级 LAN 没有 DHCP（改 `wan.proto=static`）；上游做了 MAC 白名单（`wan.macaddr` 克隆旧设备 MAC） |
| 自动重启会丢配置吗？ | 不会。它发生在初始化早期、还没做任何用户配置 |
| 可以在自动重启期间登录改设置吗？ | 不建议。等第二次开机后 5 分钟再操作 |
| 断电会怎样？ | 分区表已写则无害；**格式化进行中断电**可能留下不完整分区，脚本下次开机检测到「已有分区但无文件系统」会重新格式化（幂等） |


## 附录 J. 外网接入方式：路由模式 / 交换机(AP)模式

本机是「上级路由下面的二级设备」，两种接法都行，区别在于上网方式与网段。

### 方案 A：路由模式（默认，推荐）

```
上级路由 LAN ──► 本机 WAN        （上网走 NAT）
本机 LAN ──► 电脑/NAS            （192.168.100.x）
```

- 无需任何配置，刷完即用；本机所有设备、docker、HA 都能上网；
- 代价是**双重 NAT**：外网访问内网服务需要在上游路由和本机各做一次端口映射；
- 本机自身出网正常（`opkg update`、拉取 docker 镜像都没问题）。

### 方案 A+：本机作为主路由（撤掉上级路由）

如果这台要**直接当主路由**（上级路由撤掉，WAN 直接接光猫），比方案 A 更简单：只有一层 NAT，
端口映射只在本机做一次。按光猫的工作模式分两种：

**① 光猫改桥接 + 本机 PPPoE 拨号（推荐，性能与可控性最好）**

```sh
uci set network.wan.proto='pppoe'
uci set network.wan.username='宽带账号'
uci set network.wan.password='宽带密码'
uci set network.wan.ipv6='1'          # 需要 IPv6 时
uci commit network
/etc/init.d/network reload
```

**② 光猫保持路由模式（光猫拨号）→ 本机 WAN 用 DHCP**

```sh
uci set network.wan.proto='dhcp'
uci set network.wan.ipv6='1'
uci commit network
/etc/init.d/network reload
```

> 这种情况仍是「光猫 NAT + 本机 NAT」两层，但普通上网/Docker/HA 完全够用；
> 要从外网访问内网，两层都要做端口映射（或把本机 WAN 设成光猫网段内的固定 IP 后放 DMZ）。

**验证 WAN 是否起来**

```sh
ubus call network.interface.wan status | grep -E '"up"|"proto"|address'
ip -4 addr show | grep -A2 'wan'
ping -c3 223.5.5.5 && ping -c3 www.baidu.com      # 通外网 + 通 DNS
```

**撤掉上级路由后要确认的几件事**

| 项 | 说明 |
| --- | --- |
| 网段不冲突 | 本机 LAN `192.168.100.1/24`；光猫若是 `192.168.1.1` 没问题，若也是 `192.168.100.x` 就改本机 |
| MAC 绑定 | 运营商若绑定了旧路由 MAC：`uci set network.wan.macaddr='旧路由MAC'`（或 LuCI「WAN → 高级 → 覆盖 MAC」） |
| 端口映射 | 只需在本机「防火墙 → 端口转发」做一次；光猫若是路由模式则光猫里再做一次 |
| IPv6 | 桥接 + PPPoE 时 `wan.ipv6=1`，LAN 默认 `ip6assign`；光猫路由模式需开启前缀委派 |
| DNS | 默认跟随 WAN；想用公共 DNS：`uci add_list network.wan.dns='223.5.5.5'`（UCI 里是 `network.wan.peerdns='0'` + `dns`） |
| 无线 | 本机若有 Wi-Fi 模块需单独配置；纯有线时忽略 |
| 固件包 | PPPoE 所需 `ppp` + `ppp-mod-pppoe` + `kmod-pppoe` 已内置（manifest 可查） |

### 方案 B：交换机 / AP 模式（同级网段）

```
上级路由 LAN ──► 本机 LAN        （不要同时插 WAN）
```

此时本机变成「带 Wi-Fi 的交换机」，所有设备直接从**上级路由**拿 IP，处于同一网段。

需要改三处（否则两个 DHCP 会打架）：

```sh
# 1) LAN 改为「上游网段内的固定 IP」便于管理（例: 上游是 192.168.1.x）
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.1.250'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.gateway='192.168.1.1'
uci set network.lan.dns='192.168.1.1'

# 2) 若上游做 DHCP，也可以让本机 LAN 直接当客户端（IP 由上游分配，需去上游查）
# uci set network.lan.proto='dhcp'; uci -q delete network.lan.ipaddr; uci -q delete network.lan.netmask

# 3) 关闭本机 DHCP 服务（关键，避免与上游 DHCP 冲突）
uci set dhcp.lan.ignore='1'

uci commit network; uci commit dhcp
/etc/init.d/network reload; /etc/init.d/dnsmasq restart
```

注意事项：

| 项 | 说明 |
| --- | --- |
| 必须先关本机 DHCP | 两个 DHCP 服务器在同一二层网络里会互相抢答，表现为「时好时坏、IP 乱变」 |
| 网段冲突 | 若上游就是 `192.168.100.x`，把本机改成别的地址（如 `.250`）或让上级换网段 |
| 同时只插一个口 | WAN 和 LAN 都接同一台上游 = 二层环路，会广播风暴 |
| 管理地址 | 改成上游网段后，用新地址登录；不确定就在上级路由的客户端列表里找本机 MAC |
| 本机自身出网 | 方案 B 下本机经 LAN 走上游上网，`opkg`/docker/HA 都正常 |
| WAN 口闲置 | 方案 B 不需要 WAN；想保留可用它做「双 WAN」但需额外策略路由，不在默认范围 |

### 方案 C：只想临时给本机联网更新应用

最省事：**上级 LAN 插本机 WAN**，本机保持默认 `192.168.100.1`，登录后直接
「系统 → 软件包 → 刷新列表」或 `opkg update`；更新完想改成交换机模式再按方案 B 改。

> 补充：方案 A/B 都不影响首启的自动拆盘、NVMe 挂载、docker 数据目录、HA 配置路径 —— 那些与网络接入方式无关。


## 附录 K. 刷机后首次配置手册（11-09 起适用）

> 适用于「已移除自动分区脚本」的固件：**固件不会自动分区、不会自动重启**，下面按顺序做一遍即可。
> 全程约 15 分钟，其中分区 + 重启约 5 分钟。

### K0. 判断固件已就绪

| 判据 | 说明 |
| --- | --- |
| **电源灯常亮** | `bootled` 判断初始化完成（快速闪烁=仍在初始化） |
| 浏览器能开 `http://192.168.100.1` | LAN 默认地址（DHCP 池 `192.168.100.100–249`） |
| `firstboot-status` 全绿 | 8 项自检（挂载 / 一次性脚本 / docker / opkg …） |

```sh
firstboot-status
```

### K1. 登录并改密码（必做）

浏览器 `http://192.168.100.1` → 用户名 `root`、**密码为空** → 登录后立刻：

- LuCI：**系统 → 管理权 → 修改密码**（建议强密码）
- 或命令行：

```sh
passwd root
```

同时建议：

```sh
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system
```

### K2. 确认上网正常（WAN 接上级路由 LAN 的默认场景）

```sh
ip -4 addr show | grep -A2 eth1        # WAN 是否拿到 IP
ping -c3 223.5.5.5                     # 通外网
opkg update                            # 软件源可用
```

需要 PPPoE（光猫桥接）或静态 IP 时见[附录 J](#附录-j-外网接入方式路由模式--交换机ap模式)。

### K3. 给 eMMC 划出 50 GiB 的 `ext_relay` 与 `Data` 盘（手动，一次就好）

> ⚠️ 会改动 eMMC 分区表；操作期间**不要断电**。已有的 p1/p2/p3 不受影响。

```sh
# ① 自动推导边界（p3 结束位置 + 1 MiB 作为扩展分区起点）
END=$(parted -m -s /dev/mmcblk0 unit MiB print | awk -F: '$1=="3"{gsub(/MiB/,"",$3); print int($3)}')
S=$((END+1)); A=$((S+1)); B=$((A+51200-1))
echo "extended=${S}MiB  p5=${A}..${B}MiB(50GiB)  p6=$((B+1))..100%"

# ② 建扩展分区 + 两个逻辑分区
parted -s /dev/mmcblk0 unit MiB mkpart extended ${S} 100%
parted -s /dev/mmcblk0 unit MiB mkpart logical ext4 ${A} ${B}
parted -s /dev/mmcblk0 unit MiB mkpart logical ext4 $((B+1)) 100%
parted -s /dev/mmcblk0 print          # 期望 4=extended / 5≈50GiB / 6=其余

# ③ 必须重启（内核要重新读分区表，否则 mkfs 报 No such device）
reboot
```

重启后：

```sh
mkfs.ext4 -F -m 0 -L ext_relay /dev/mmcblk0p5     # docker 专用 50 GiB
mkfs.ext4 -F -m 0 -L Data      /dev/mmcblk0p6     # 数据/共享盘 其余

mkdir -p /mnt/ext_relay /mnt/data
mount -t ext4 /dev/mmcblk0p5 /mnt/ext_relay
mount -t ext4 /dev/mmcblk0p6 /mnt/data
df -h /mnt/ext_relay /mnt/data

# 写入 fstab（按 UUID，重启自动挂载）
block detect > /etc/config/fstab && uci commit fstab
```

也可以全程用 LuCI：**系统 → 挂载点**（新建分区 → 格式化 → 挂载 → 勾选「启用」）。

### K4. 把 Docker 放到手动分区（`/mnt/ext_relay/docker`）

```sh
# 停 docker
/etc/init.d/dockerd stop

# 若之前 docker 在别处（如 /mnt/nvme0/docker）且想保留镜像：先搬过去
mkdir -p /mnt/ext_relay/docker
[ -d /mnt/nvme0/docker ] && cp -a /mnt/nvme0/docker/. /mnt/ext_relay/docker/ 2>/dev/null

# 指定数据目录
uci set dockerd.globals.data_root='/mnt/ext_relay/docker'
uci commit dockerd
/etc/init.d/dockerd start
sleep 3

docker info | grep -i 'docker root dir'     # 期望 /mnt/ext_relay/docker
docker images && docker ps -a               # 镜像/容器还在
```

> 之后重启也不会被改（新版固件已无 `docker-dataroot` 自动改路径逻辑）。
> 想放回 NVMe：`uci set dockerd.globals.data_root='/mnt/nvme0/docker'`。

### K4.5 eMMC 剩余空间怎么用（推荐：留给 overlay，别急着分区）

把 docker 放到 NVMe 后，eMMC 上还空着约 229 GiB。按「写入量」排序的建议：

| 用途 | 写入强度 | 建议 |
| --- | --- | --- |
| **保持未分配（默认）** | 0 | ✅ **最推荐**。不分区就不磨损，将来需要时再划 |
| **给 overlay 扩容**（`p3` 从 4 GiB → 8/16 GiB） | 中（装包/配置） | 想多装 iStore 应用时值得做；需要改构建参数重新出固件（见下） |
| **小容量备份分区**（`p6` 8–16 GiB 放配置备份/固件） | 低（每周几次） | 可接受；用 `tar` 备份到那里，别放视频/下载 |
| **共享盘 / 下载盘** | 高（大文件写入） | ❌ 不建议放 eMMC，交给 NVMe |
| **swap** | 极高 | ❌ 不需要（本机 3.75 GiB 内存） |
| **docker / HA 数据** | 高 | ❌ 已按建议放到 NVMe |

**推荐组合**：

- **NVMe（468 GiB）**：docker 数据目录 `/mnt/nvme0/docker`、HA 配置、iStore 应用数据、共享/下载；
- **eMMC**：只承载系统（rootfs 200 MiB + overlay 4 GiB）；剩余空间先不分配；
- 想扩 overlay 时，用 workflow 参数 `rootfs_data_size=8192`（需同步把构建里「分区表断言」从 4096 改成 8192）后重刷 —— 这属于换镜像，不是在线改分区。

> 提示：eMMC 上**不建分区**就没有额外写入，是对寿命最友好的选择。真有备份需求，优先备份到 NVMe。

### K5. iStore / 应用的数据位置

| 对象 | 建议位置 | 设置方式 |
| --- | --- | --- |
| iStore 应用**程序** | `/overlay`（4 GiB，自动） | 无需设置 |
| iStore 应用**数据** | `/mnt/data` | 商店「快速安装 → 存储位置」下拉里选 `/mnt/data` |
| Home Assistant 配置 | `/mnt/data/Configs/HomeAssistant` | `ha-config-path` 自动选（≥1 GiB 的已挂载盘），也可在 HA 页面下拉里改 |

检查：

```sh
df -h /overlay /mnt/data
uci get istore.istore.last_path 2>/dev/null
uci get homeassistant.@homeassistant[0].config_path 2>/dev/null
```

### K6. 建议顺手配好

| 项 | 命令/位置 |
| --- | --- |
| 远程管理 | LuCI → 系统 → 管理权（SSH 已开 22） |
| 终端 | LuCI → 系统 → TTYD 终端（`netstat -lnt \| grep 7681` 应为 `0.0.0.0:7681`） |
| DDNS | LuCI → 服务 → 动态 DNS / DDNS-GO（已预装） |
| 端口转发 | LuCI → 防火墙 → 端口转发（只在本机做一次，单层 NAT） |
| DHCP 静态绑定 | LuCI → 网络 → DHCP/DNS → 静态地址（给 NAS/HA 固定 IP） |
| 定时重启（可选） | LuCI → 系统 → 计划任务：`0 4 * * * reboot` |

### K7. 收尾校验清单

```sh
firstboot-status                            # 8 项自检
parted -s /dev/mmcblk0 print | tail -4      # 4/5/6 分区
df -h /mnt/ext_relay /mnt/data /overlay
docker info | grep -i 'docker root dir'
uci show dockerd | grep data_root
cat /etc/config/fstab | grep -E 'target|uuid'
```

### K8. 注意

| 项 | 说明 |
| --- | --- |
| eMMC 寿命 | 50 GiB 分区跑 docker 可用，但写入较频繁；在意寿命可把 `data_root` 改到 NVMe |
| 断电风险 | 分区表写入与 `mkfs` 期间断电可能留残；本手册的做法是「建表→重启→格式化」，窗口很短 |
| 备份 | 配好后 LuCI 生成一次配置备份；升级勾「保留配置」即可沿用 |
| 升级 | 以后刷同一基线的新版本，勾保留配置 → 分区、fstab、docker 路径都保留 |
