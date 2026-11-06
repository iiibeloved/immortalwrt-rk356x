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
| `rootfs_size` | `512` | 只读系统分区，只决定 squashfs 能否放下（当前 squashfs 约 150–180 MB）；运行期不可写，调大只增加镜像体积 |
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

## 2. 编译过程（22 个步骤，按实际执行顺序）

| # | 步骤 | 实测耗时 | 说明 |
| --- | --- | --- | --- |
| 1–2 | Set up job / 释放磁盘空间 | 2–10 min | 删掉 runner 上的 dotnet、Android SDK 等腾空间 |
| 3 | 检出源码 | <1 min | `fetch-depth: 1` |
| 4 | 校验配置并打印目标 | <1 min | 不存在直接 fail-fast |
| 5 | 安装编译依赖 | 2–10 min | 含 `python3-pyelftools`（RK3568 u-boot 必需） |
| 6–7 | 生成 feeds.conf / 更新并安装官方 feeds | 3–8 min | 4 个官方源全量安装 |
| 8 | 引入第三方 feed（`kenzok8/small-package`）并选择性安装 | 2–3 min | 只装需要的包，避免同名包覆盖 |
| 9 | 引入 `luci-app-filetransfer`（本地 `package/`） | <1 min | 第三方单包，直连 clone |
| 10 | 应用 defconfig + 附加配置 | <1 min | `cp` → 追加 → `make defconfig` |
| 11 | 校验宿主机依赖（`make prereq`） | 1–2 min | 提前暴露 pyelftools 这类问题 |
| 12 | 校验附加包是否生效 | <1 min | 生成 Job Summary 表格：✅ / ⚠️ / ⛔ |
| 13 | 缓存 dl 与 ccache | <1 min | 命中缓存可显著提速 |
| 14 | 下载软件包源码 | 6–13 min | `make download` |
| 15 | 构建工具链（tools + toolchain） | 30–35 min | 产出 `aarch64-openwrt-linux-musl-gcc` |
| 16 | 修复 rust vendor 校验并预编译 rust | **0（自动跳过）** / 118 min | 当前配置无 rust 组件 → 直接跳过 |
| 17 | 编译固件（`make world` 剩余部分） | 60–75 min | 内核 + u-boot/ATF + 450+ 包 + 镜像打包 |
| 18 | 收集固件 | <1 min | 拷到 `output/` |
| 19 | 上传固件 artifact | 1–2 min | 165–200 MB（零区压缩率高，rootfs 变大后变化不大） |
| 20 | 发布到 Release（自动） | 1–2 min | tag `g68-plus-YYYY.MM.DD`，上传 `*.img.gz` + `sha256sums` |

**总时长参考**：当前配置（无 ss-rust）**≈ 2 小时 20 分 – 2 小时 40 分**；
若把 ss-rust 加回来，会多出 rustc + LLVM 的 110–120 分钟。

---

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
- 改完 push（只改这个文件会触发构建）。

### 7.2 恢复 shadowsocks-rust（会多花约 2 小时）

当前 `defconfig/g68-plus-istoreos.config` 里有这两行，删掉即可恢复：

```ini
# CONFIG_PACKAGE_shadowsocks-rust-sslocal is not set
# CONFIG_PACKAGE_shadowsocks-rust-ssserver is not set
```

删除后第 16 步会自动生效（不再跳过），走「工具链 → 修 rust vendor → 编 rust」流程。

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
| rootfs | `rootfs_size`（现 **512 MiB**） | `CONFIG_TARGET_ROOTFS_PARTSIZE`，被 workflow 覆盖 | **只读 squashfs**，构建时打进固件的 497 个包都在这里；实际占用约 150–180 MiB |
| rootfs_data | `rootfs_data_size`（现 **4096 MiB**） | 镜像脚本 `gen_image_generic.sh` 读 `ROOTFS_DATA_PARTSIZE`（本仓库默认 4096） | 可写 overlay：配置改动、iStore/opkg 装的包、docker 数据 |

当前配置整盘镜像约 **4.6 GiB**（16 + 512 + 4096 + 对齐空隙），`.img.gz` 约 165–180 MB；目标 eMMC/SD 卡 ≥5 GB（8 GB 卡可用）。
构建会在 Job Summary 输出 squashfs 实际占用率；≥85% 时自动 `::warning::` 提示调大 `rootfs_size`。
**docker / iStore 的可用空间由 `rootfs_data_size` 决定**（现 4096 MiB），与 `rootfs_size` 无关。

### 7.5 给 docker / iStore 扩容（rootfs_data 只有 2048 MiB）

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

### 7.8 首次启动自动拆分剩余空间（256G eMMC 场景）

镜像只占约 **4.6 GiB**（kernel 16 + rootfs 512 + rootfs_data 4096 MiB），256 GB 的 eMMC 有约 250 GB 未分配。
固件内置 `/etc/init.d/docker-disk`（START=58），**首次启动**时把剩余空间拆成两块：

| 分区 | 大小 | 文件系统 / 卷标 | 挂载点 | 用途 |
| --- | --- | --- | --- | --- |
| `p4` | 剩余空间全部 | **扩展分区（容器）** | — | 只用来容纳下面两个逻辑分区 |
| `p5`（逻辑） | **20 GiB** | ext4 / **`ext_relay`** | `/mnt/ext_relay` | **docker 数据目录**（`dockerd.data_root=/mnt/ext_relay/docker`） |
| `p6`（逻辑） | 其余（约 230 GB） | ext4 / **`Data`** | `/mnt/data` | 共享盘 |

> 为什么用扩展+逻辑分区：MBR 最多 4 个主分区，镜像已占用 kernel/rootfs/rootfs_data 三个，
> 只剩一个主分区槽位，所以两块新盘放在一个扩展分区里。

执行细节：

1. 由 `/rom` 反查启动盘（`/dev/mmcblk0` 或 `mmcblk1`）；
2. 剩余空间 ≥ **28 GiB**（20 GiB docker + 至少 8 GiB Data）才动手，从最后一个分区末尾往后追加；
3. `parted` 建扩展分区 + 两个逻辑分区 → `mkfs.ext4 -m 0 -E lazy_itable_init=1,discard` 并打卷标；
4. 分别挂到 `/mnt/ext_relay`、`/mnt/data`，写入 fstab（按 **UUID**，之后每次开机自动挂载）；
5. `dockerd.globals.data_root=/mnt/ext_relay/docker` 并重启 docker。

| 安全性 | 说明 |
| --- | --- |
| 幂等 | 已存在 `LABEL=ext_relay` + `LABEL=Data` 时**只挂载不格式化** |
| 只追加 | 只从最后一个分区末尾往后建，p1–p3 绝不改动 |
| 失败兜底 | 任一步失败打日志并保留默认 `/opt/docker`，不阻塞开机 |
| 只跑一次 | 成功后写 `/etc/.docker-disk.done` |
| 小盘保护 | 剩余 < 28 GiB 直接跳过 |
| 在线改表 | 新增分区内核不立刻识别，脚本用 `mknod` 造 `/dev/mmcblk0p5|p6`（minor 5/6）先挂上；重启后正常识别，之后走 fstab+UUID |

开关与排错：

```sh
touch /etc/.docker-disk.done                                    # 关闭
rm -f /etc/.docker-disk.done && /etc/init.d/docker-disk start    # 手动重跑
cat /etc/.docker-disk.log ; logread | grep docker-disk           # 日志
```

想改 docker 分区的容量：改脚本里的 `DOCKER_MIB`（默认 20480 = 20 GiB），或改 `DOCKER_LABEL` / `DATA_LABEL` / 挂载点。

### 7.9 回滚 / 删除发布

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
   二者之和决定整盘镜像大小（当前 16+512+4096 ≈ 4.6 GiB）。改完会有一道 `校验镜像分区表` 步骤核对实际 MBR。
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
- [ ] 决定 `rootfs_size`（默认 **512**，只读系统分区；看 Job Summary 的占用率再定）与 `rootfs_data_size`（默认 **4096**，docker/iStore 空间）
- [ ] 决定是否 `publish_release`（默认 true）
- [ ] 触发方式：等周一 02:00 定时 / 或手动 Run workflow
- [ ] 构建结束后：看 Job Summary 的包表格 → 下载 artifact 或 Release → 校验 sha256 → 刷机
