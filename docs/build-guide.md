# G68-PLUS 固件 · 下次编译详细教程

> 仓库：<https://github.com/iiibeloved/immortalwrt-rk356x>
> 目标：rockchip / armv8 / `DEVICE_nsy_g68-plus`（NSY G68-PLUS，RK3568，aarch64_generic，Linux 6.6）
> 当前配置：`defconfig/g68-plus-docker.config` + `defconfig/g68-plus-istoreos.config`
> 文档更新：2026-11-06（基于 run #42186516665 首次成功构建的实测数据）

---

## 0. 一页速查（赶时间只看这里）

| 事项 | 值 |
| --- | --- |
| 下次自动构建 | **2026-11-09 02:00（周一，Asia/Shanghai）**，cron `0 18 * * 0`（UTC 周日 18:00） |
| 想提前编 | Actions → `Build G68-PLUS (iStoreOS style)` → **Run workflow** |
| 预计耗时 | **约 2.5 小时**（ss-rust 已关闭，rust 步骤自动跳过；开启 ss-rust 则约 4.2 小时） |
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
| 手动 `mkfs`/`mount` 报 `No such device` / `Can't open blockdev` | 在线改分区表后内核还没生成分区节点 | 重启一次（新固件的 `docker-disk` 会自动重启一次并续跑） |
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

### 7.6 docker 数据目录自动落到外挂盘

固件内置 `/etc/init.d/docker-dataroot`（`files/` 目录打进镜像，START=60，早于 dockerd 的 START=99），
开机时自动把 `dockerd.globals.data_root` 指向外挂盘，默认 `/opt/docker` 只作兜底：

| 情况 | 行为 |
| --- | --- |
| 探测到 `/mnt/*` 下由 `/dev/sd*`、`/dev/nvme*`、`/dev/mmcblk*` 挂载的 ext4/btrfs/xfs/f2fs，且剩余 ≥ 8 GiB | 设 `data_root=<挂载点>/docker`（目录自动创建），并写标记 `/etc/.docker-dataroot` |
| 没探测到合适的外挂盘 | 若之前是脚本设到外挂盘的，自动回退 `/opt/docker`；否则保持不动 |
| `data_root` 已被你手工改成别的路径 | 完全不动（尊重手工设置），日志 `data_root=xxx 为手工设置, 跳过自动调整` |

相关日志：`logread | grep docker-dataroot`。

**想固定到某块盘**（推荐按 UUID 挂载后固定路径）：手工设置一次即可，之后脚本不再改动它——

```sh
uci set dockerd.globals.data_root='/mnt/data/docker'
uci commit dockerd && /etc/init.d/dockerd restart
```

判断条件：只要 `data_root` 不是 `/opt/docker`，且不等于标记文件里记录的「脚本上次设的值」，就视为手工设置。

### 7.7 首次启动自动拆分剩余空间（256G eMMC 场景）

镜像只占约 **4.3 GiB**（kernel 16 + rootfs 200 + rootfs_data 4096 MiB），256 GB 的 eMMC 有约 250 GB 未分配。
固件内置 `/etc/init.d/docker-disk`（START=58），**首次启动**时把剩余空间拆成两块：

| 分区 | 大小 | 文件系统 / 卷标 | 挂载点 | 用途 |
| --- | --- | --- | --- | --- |
| `p4` | 剩余空间全部 | **扩展分区（容器）** | — | 只用来容纳下面两个逻辑分区 |
| `p5`（逻辑） | **50 GiB** | ext4 / **`ext_relay`** | `/mnt/ext_relay` | **docker 数据目录**（`dockerd.data_root=/mnt/ext_relay/docker`） |
| `p6`（逻辑） | 其余（约 184 GiB ≈ 197 GB） | ext4 / **`Data`** | `/mnt/data` | 共享盘 |

> 为什么用扩展+逻辑分区：MBR 最多 4 个主分区，镜像已占用 kernel/rootfs/rootfs_data 三个，
> 只剩一个主分区槽位，所以两块新盘放在一个扩展分区里。

执行细节：

1. 由 `/rom` 反查启动盘（`/dev/mmcblk0` 或 `mmcblk1`）；
2. 剩余空间 ≥ **58 GiB**（50 GiB docker + 至少 8 GiB Data）才动手，从最后一个分区末尾往后追加；
3. `parted` 建扩展分区 + 两个逻辑分区 → `mkfs.ext4 -m 0 -E lazy_itable_init=1,discard` 并打卷标；
4. 分别挂到 `/mnt/ext_relay`、`/mnt/data`，写入 fstab（按 **UUID**，之后每次开机自动挂载）；
5. `dockerd.globals.data_root=/mnt/ext_relay/docker` 并重启 docker。

| 安全性 | 说明 |
| --- | --- |
| 幂等 | 已存在 `LABEL=ext_relay` + `LABEL=Data` 时**只挂载不格式化** |
| 只追加 | 只从最后一个分区末尾往后建，p1–p3 绝不改动 |
| 失败兜底 | 任一步失败打日志并保留默认 `/opt/docker`，不阻塞开机 |
| 只跑一次 | 成功后写 `/etc/.docker-disk.done` |
| 小盘保护 | 剩余 < 58 GiB 直接跳过 |
| 在线改表 | 新增分区后内核若不生成 `p0n` 节点，脚本**自动重启一次**（`/etc/.docker-disk.rebooted` 防循环），下次开机走「复用已有 p5/p6」分支继续格式化/挂载 |

开关与排错：

```sh
touch /etc/.docker-disk.done                                    # 关闭
rm -f /etc/.docker-disk.done && /etc/init.d/docker-disk start    # 手动重跑
cat /etc/.docker-disk.log ; logread | grep docker-disk           # 日志
```

想改 docker 分区容量：改脚本里的 `DOCKER_MIB`（默认 **51200 = 50 GiB**；阈值会自动跟着变 = DOCKER_MIB + 8 GiB），
或改 `DOCKER_LABEL` / `DATA_LABEL` / 挂载点。

**对 iStore 商店的意义**：商店的「快速安装」向导必须从 `/admin/store/get_block_devices`
（内部执行 `block info`）里选一个**存储位置**。拆盘成功前系统只有 p1/p2/p3 三个系统分区，
列表为空 → 安装按钮点不动。拆盘并挂载后就会出现 `/mnt/ext_relay` 与 `/mnt/data`，选后者即可安装。

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
| 磁盘完全空白（无分区表、无文件系统签名）且 ≥ 8 GiB | 自动建 **GPT + 单分区 + ext4**（卷标 `NVME0`）后挂载 |
| 有分区但文件系统不受支持（如 NTFS） | **只记日志，不格式化、不挂载**（保护数据） |
| 小于 8 GiB 的空白盘 | 跳过格式化 |

日志：`/etc/nvme-automount.log`、`logread | grep nvme-automount`。
快捷开关（在 `/etc` 下建文件即可，开机读取）：

```sh
touch /etc/nvme-automount.off       # 完全关闭
touch /etc/nvme-automount.noformat  # 只挂载已有文件系统, 绝不分区/格式化(推荐给带数据的盘)
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

### 7.11 指示灯（电源灯）开关

查过 `rk3568-nsy-g68-plus.dts` 与内核驱动后确认这台机器的灯分两类：

| 灯 | 由谁控制 | 软件能否开关 |
| --- | --- | --- |
| 前面板电源灯 `led-power`（GPIO0_C4） | 内核 `gpio-leds` → `/sys/class/leds/led-power` | ✅ 能 |
| RJ45 网口灯 | **Realtek RTL8367S 交换芯片内部逻辑**（按链路/速率/活动自动驱动） | ❌ 不能 |

网口灯不可控的原因：`rtl8367b` 驱动只暴露 `enable_vlan / enable_vlan4k / reset_mibs / max_length / reset_mib / mib / info`，
没有任何 LED 属性（驱动里只有 `0x1b0e~0x1b10` 三个「LED 极性」寄存器，改的是高低电平有效，不是开关）。
**该需求已确认放弃**，不再做驱动改造；确实嫌灯亮时，用物理遮挡，或对长期不用的口
`swconfig dev switch0 port <n> set enable 0`（该口会同时断网）。

内置 `/etc/config/portled` + `/etc/init.d/portled`（START=70）用于控制 GPIO 灯：

```sh
# 关闭电源灯等所有可控 GPIO 灯
uci set portled.main.enable=0
uci commit portled
/etc/init.d/portled restart

# 只关电源灯
uci set portled.main.power_led=0 && uci commit portled && /etc/init.d/portled restart

# 恢复
uci set portled.main.enable=1 && uci set portled.main.power_led=1
uci commit portled && /etc/init.d/portled restart
```

日志：`/etc/portled.log`、`logread | grep portled`。

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
| 构建（上一版） | run #42337188896（2026-11-07，549 个包，24 步全绿） |
| Release | `g68-plus-2026.11.07-r12` |
| 镜像 sha256 | `0ecc1541a381669861c45f8a505d077e97a986697064a4ab5d8fddfc8d3a9e96` |
| 分区 | kernel 16 MiB / rootfs 200 MiB / rootfs_data 4096 MiB |
| 首次启动自动拆盘 | 50 GiB `ext_relay`（docker）+ 其余 `Data`（共享） |
| 完整包清单 | [packages.md](packages.md) |

**基线校验**：想确认仓库未被改动，比对 `docs/packages.md` 顶部的三个 sha256
（`g68-plus-istoreos.config`、`build-g68-plus-docker.yml`、`gen_image_generic.sh`）即可。

**要偏离基线时**（例如临时试别的 rootfs 大小），不要改默认值，直接 Run workflow 显式传参，
构建产物会带 `-r<run_number>` 后缀，基线不受影响。


## 附录 B. 基线自检（2026-11-07 全面检查结果）

| 检查项 | 方法 | 结果 |
| --- | --- | --- |
| 脚本语法 | `sh -n` 全部 8 个脚本 + `gen_image_generic.sh` | ✅ 全部通过 |
| 执行位 | 远程 git tree mode 检查 | ✅ init.d / uci-defaults 均 `100755`，配置文件 `100644` |
| 开机自启 | 每个 init.d 脚本都有对应 uci-defaults `enable` | ✅ docker-disk/docker-dataroot/nvme-automount → `98-enable-custom-initd`；portled → `98-portled`；ttyd → `98-fix-ttyd` |
| 启动顺序 | START 值 | docker-disk 58 → docker-dataroot 60 → nvme-automount 62 → portled 70 → dockerd 99 ✅ |
| 首次启动即生效 | `98-enable-custom-initd` 在后台立即执行一次（sleep 5） | ✅ 无需重启 |
| NVMe 支持 | 内核模块 | ✅ kmod-nvme / kmod-fs-ext4 / exfat / vfat / btrfs 已在；**本次补上 kmod-fs-f2fs、kmod-fs-xfs、kmod-fs-ntfs3** |
| 分区脚本幂等 | 假 sysfs 冒烟测试 | ✅ 已有 p5/p6 且已格式化 → 只挂载不重格；中途失败不写完成标记，下次自动重试 |
| fstab 安全 | 两个脚本都按 UUID 去重 | ✅ 不再追加重复项、也不再删已有条目 |
| 在线改表兼容 | 分区后内核未识别 → 自动重启一次（防循环标记） | ✅ 假 sysfs 4 场景验证（建盘→重启→格式化→幂等） |
| 商店可用性 | 拆盘后出现 `/mnt/ext_relay`、`/mnt/data` 供选择 | ✅ 依赖拆盘成功 |
| ttyd | 不绑定 `@lan` | ✅ 改 LAN IP 后不会「已拒绝连接」 |
| opkg 源 | 9 个源（官方 6 + iStoreOS 3） | ✅ 首次启动自动补 arch、必要时关签名校验 |
