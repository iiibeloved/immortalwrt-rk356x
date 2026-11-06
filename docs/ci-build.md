# G68-PLUS · iStoreOS 风格固件 CI 构建说明

针对仓库 <https://github.com/iiibeloved/immortalwrt-rk356x>（`main` 分支）的 GitHub Actions 编译方案。

## 1. 仓库结构分析结论

| 项目 | 结果 |
| --- | --- |
| 分支 / 提交 | `main`，活跃维护（最近 push `2026-11-06`） |
| 基础 defconfig | `defconfig/g68-plus-docker.config` ✅ 存在（303 KB / 7906 行） |
| 目标平台 | `rockchip` / `armv8` / `DEVICE_nsy_g68-plus`（NSY G68-PLUS，RK3568） |
| 包架构 | `aarch64_generic`，内核 `CONFIG_LINUX_6_6=y` |
| rootfs | squashfs（`CONFIG_TARGET_ROOTFS_SQUASHFS=y`），分区原为 200 MB |
| 启动方式 | `BOOT_FLOW := pine64-img`（SD/eMMC 直刷镜像） |
| 默认 feeds | 仅 4 个官方源（`packages` / `luci` / `routing` / `telephony`，分支 `openwrt-24.10`），**没有** iStoreOS 源 |
| `.github/` | 不存在，需新建 |
| `dl/` | 已随仓库提交，可被缓存复用 |

原配置里已有 424 个包，包含 `luci-app-dockerman`、`luci-lib-docker`、`luci-compat`、`luci-app-ttyd`、
`luci-theme-argon` 等，但**没有 docker 引擎本体**（`dockerd/containerd/runc/docker` 均未选中），
与文件名 `g68-plus-docker` 的意图不符，已在附加配置中补齐。

## 2. 需要放入仓库的文件

```
.github/workflows/build-g68-plus-docker.yml   # 工作流
defconfig/g68-plus-istoreos.config            # 附加配置片段（差异项）
```

`defconfig/g68-plus-istoreos.config` 只写“差异项”，不改动原 defconfig；
两者叠加后由 `make defconfig` 归一化（自动补依赖、丢弃不存在的符号）。

## 3. 触发条件

| 触发 | 说明 |
| --- | --- |
| `workflow_dispatch` | 手动运行，可覆盖 `defconfig` / `extra_config` / `rootfs_size` / 是否上传 artifact |
| `push`（`main`） | **仅当 `defconfig/` 下两个文件变动时**触发（改 workflow / docs 不重编，需要时手动 Run workflow） |
| `schedule` | `0 18 * * 0`（UTC）= 每周一 02:00（Asia/Shanghai），用于跟踪 feeds / 插件更新 |

`concurrency` 已设置但 `cancel-in-progress: false`，避免一次 3 小时的编译被后续提交打断。

## 4. 输出物位置

Actions run 页面底部 **Artifacts** → `immortalwrt-g68-plus-<run_number>.zip`，保留 15 天，内含：

```
immortalwrt-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img.gz  # 唯一镜像, dd 直刷 / 系统升级均用它
immortalwrt-rockchip-armv8-nsy_g68-plus.manifest                    # 包清单
sha256sums / config.buildinfo / config.applied                      # 校验与配置留档

> 实测: 该设备(pine64-img 流程)只产出 `sysupgrade.img.gz`(约 175 MB 未压缩),
> 没有单独的 sdcard.img.gz; 解压后用 dd / balenaEtcher 写入 eMMC 或 SD 卡即可。
```

编译失败时额外上传 `build-log-<run_number>.zip`（`build.log`，含失败前的完整输出）。

## 5. 工作流关键设计

1. **feeds 分两步装**：先 `cp feeds.conf.default feeds.conf` → `feeds update -a` → `feeds install -a`，
   确保官方 4 个源的包（defconfig 依赖 400+ 个）全部就位；**之后**再追加
   `kenzok8/small-package`，并且只按名字安装需要的 13 个包。
   原因：`small-package` 里也有 `docker` / `dnsmasq` / `firewall4` / `base-files` 等与官方同名的包，
   若对它执行 `feeds install -a`，同名包会互相覆盖并导致编译中断。
2. **第三方包来源**（均已核对 2026-11 仍可访问）：

   | 包 | 来源 |
   | --- | --- |
   | `quickstart` / `luci-app-quickstart` | `kenzok8/small-package`（0.13.1 / 0.12.10，预编译，支持 aarch64） |
   | `luci-app-store`（iStore）+ `taskd` / `luci-lib-taskd` / `luci-lib-xterm` | `kenzok8/small-package`（0.2.1，Lua 版，兼容 24.10） |
   | `unishare` / `luci-app-unishare` / `webdav2` | `kenzok8/small-package` |
   | `lucky` / `luci-app-lucky` | `kenzok8/small-package`（3.5.0，aarch64→arm64 预编译） |
   | `luci-app-wolplus` | `kenzok8/small-package`（依赖 `etherwake`） |
   | `luci-app-rtbwmon` | `kenzok8/small-package` |
   | `luci-app-filemanager` | 官方 `luci` 源（24.10 分支为 JS 前端） |
   | `luci-app-filetransfer` | `DustReliant/luci-app-filetransfer`，**直接 clone 进 `package/`**，不占 feed（该仓库根目录即单包，不走 feed 索引更稳） |
   | `samba4-server` / `luci-app-samba4` | 官方 `packages` / `luci` 源 |
   | `docker` / `dockerd` / `containerd` / `runc` | 官方 `packages` 源（`utils/docker*`） |

3. **配置叠加**：`cp $CONFIG_FILE .config` → 追加附加片段 → `sed` 覆盖 `CONFIG_TARGET_ROOTFS_PARTSIZE`
   → `make defconfig`。命令行输入的 rootfs 大小优先级最高。
4. **配置校验**：归一化后逐个检查附加包是否真的 `=y`，写入 Job Summary 表格，
   缺失的用 `::warning::` 标注（不直接失败，保证仍能产出固件；需严格模式可改成 `exit 1`）。
5. **缓存**：`actions/cache` 缓存 `dl/` 与 `.ccache/`（`rules.mk` 中 `CONFIG_CCACHE=y` 时缓存目录为
   `$(TOPDIR)/.ccache`），key 带 `run_id` + 前缀 restore，重跑时能命中上一次的下载与编译缓存。
6. **编译**：`make -j$(nproc)`，失败后自动 `make -j1 V=s` 重试一次并保留完整日志。
7. **环境变量**：`FEEDS_CONF=feeds.conf` 显式导出（本树 `scripts/feeds` 实际读取 `./feeds.conf`，
   缺失时回退 `feeds.conf.default`；导出该变量是为了兼容读取它的派生脚本）。

## 6. 本地等价复现

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

## 7. 已知风险 / 注意事项

- **首次编译约 3–4 小时**（4 vCPU runner：工具链 + Linux 6.6 内核 + samba4 + Go 组件 dockerd/webdav2 + lucky/quickstart 预编译包），
  工作流 `timeout-minutes: 350`，接近 GitHub 单任务 6 小时上限；若频繁超时，建议拆分为
  “先 `make tools/install toolchain/install`” 的缓存式两段构建。
- **`kenzok8/small-package` 跟随 `master`**，不是 24.10 分支：多数插件是 `PKGARCH:=all` 的 Lua 应用，实测可行，
  但其上游随时可能变动；如需可复现构建，可把该 feed 换成固定 commit
  （`src-git small https://github.com/kenzok8/small-package.git;main` → `src-git-full` + 锁定 SHA 的自建 fork）。
- **编译期仍会联网下载**：`lucky`、`quickstart` 的预编译包由各自 Makefile 在 `Build/Prepare` 里直接 `wget` GitHub Release，
  不经过 `make download`，因此这类失败会出现在编译中段。可先手动验证对应 Release 资产是否还在。
- **`luci-app-filetransfer` 是个人维护的第三方单包**（MIT，依赖 `luci-compat`），若上游失效，
  工作流会告警并继续，固件仍然产出，只是少了该功能。
- **rootfs 改为 4096 MB**（v3 起）：只影响只读 rootfs 分区；`rootfs_data` 在 `scripts/gen_image_generic.sh` 里写死 `USERDATASIZE=2048`，
  因此整盘镜像约 4.3 GiB（boot 16 MiB + rootfs 200 MiB + rootfs_data 4096 MiB），
  artifact 上传时间增加；若只想最小镜像，把 `rootfs_size` 输入改回 `200`。
- **iStore 商店与 quickstart 的面板依赖 LuCI 前端能力**，在 24.10（Lua LuCI）上属“社区常用组合”，
  首次刷机后请实际打开 `系统 → 快速配置`、`iStore`、`网络存储 → 共享` 三项确认可用，再决定是否长期跟进。
- 工作流产物无签名、无 `opkg` 仓库，仅作为整机固件使用。

## 8. 合入仓库

无法直接推送到该仓库（无凭据），两种方式二选一：

```bash
# 方式 A：本地放进克隆的仓库再推
git clone https://github.com/iiibeloved/immortalwrt-rk356x.git
cd immortalwrt-rk356x
mkdir -p .github/workflows
cp /path/to/build-g68-plus-docker.yml .github/workflows/
cp /path/to/g68-plus-istoreos.config   defconfig/
git add .github defconfig
git commit -m "ci: build g68-plus-docker with iStoreOS style packages"
git push origin main
```

方式 B：GitHub 网页端 `Add file → Create new file`，路径填
`.github/workflows/build-g68-plus-docker.yml`，粘贴内容后提交；同样方式添加
`defconfig/g68-plus-istoreos.config`。提交后 Actions 会自动开始第一次编译。


## 9. 实测记录：2026-11-06 首次成功构建

| 项目 | 结果 |
| --- | --- |
| run | [#42186516665](https://github.com/iiibeloved/immortalwrt-rk356x/actions/runs/42186516665)，commit `c6b3a90d` |
| 总耗时 | **4 小时 09 分**（16:17 → 20:26，Asia/Shanghai） |
| 阶段耗时 | 准备 25 min · 下载 6 min · 工具链 34 min · rust 118 min · 世界构建 72 min |
| artifact | `immortalwrt-g68-plus-6`，165.4 MB |
| 固件 | 包 497 个，内核 `6.6.99`，`base-files 1~c6b3a90` |
| 附加包校验 | **22/22 全部命中**（quickstart/store/unishare/lucky/wolplus/rtbwmon/filemanager/filetransfer/samba4/docker 全套） |

`sysupgrade.img.gz` 的 sha256：

```
d4a1908a71dc8b7977eb626b07b0f291b575cc35b3958757b58aaec56eeba41d
```

### 踩过的两个坑（已在 workflow 内修掉）

1. **`python3-pyelftools` 缺失** —— RK3568 的 u-boot 打 FIT 镜像需要它，`make` 在 prereq 阶段直接 exit 2。
   现在 apt 列表已包含，并加了独立的 `make prereq` 门禁步骤（1–2 分钟暴露问题）。
2. **`lang/rust` 宿主工具链 vendor 校验失败**（`Cargo.toml.orig` 找不到）—— 由基础 defconfig 里的
   `shadowsocks-rust-sslocal/ssserver` 作为 `rust/host` 构建依赖拉起。
   workflow 的做法：先 `make .../rust/host/compile` 触发解包（必然在 checksum 处快速失败），
   然后扫描 `build_dir/*/host/rustc-*-src/vendor/*/.cargo-checksum.json`，
   **把「登记了但文件确实不存在」的条目删掉**，再重编；同时提前编好 tools + toolchain，
   否则 rust 的 sanity check 会因为找不到 `aarch64-openwrt-linux-musl-gcc` 而失败。

### 维护建议

- **rust 已默认关闭**：`shadowsocks-rust-sslocal/ssserver` 在附加配置里被显式设为 `is not set`，
  workflow 的 rust 步骤会检测到「config 里没有 rust 组件」后自动跳过（省 ~2 小时，构建约 2.5 小时）。
  需要 ss 客户端/服务端时，删掉 `defconfig/g68-plus-istoreos.config` 里的这两行：

  ```
  # CONFIG_PACKAGE_shadowsocks-rust-sslocal is not set
  # CONFIG_PACKAGE_shadowsocks-rust-ssserver is not set
  ```

  此时会自动回到「工具链 → 修 rust vendor → 编 rust」的路径（rustc + LLVM，约 +2 小时）。
  其余 20 个 iStoreOS 相关包不受影响；校验步骤的表格里会显示 `⛔ 已按预期关闭` / `⚠️ 预期关闭但仍启用`。
- `dl/` 与 `.ccache/` 已被 `actions/cache` 缓存，二次构建的下载与 C 编译会明显加快。
- 定时任务每周一 02:00 会自动重编，用于跟踪 feeds / 插件更新。


## 10. 自动发布 Release（免登录直链）

构建成功后会**自动**把固件挂到 GitHub Release，产出无需登录、不随 artifact 过期的直链：

```
https://github.com/iiibeloved/immortalwrt-rk356x/releases/download/<tag>/<file>.img.gz
```

- **tag 规则**：`g68-plus-YYYY.MM.DD`（按 Asia/Shanghai 日期）；同一天已有同名 Release 时自动加 `-r<run_number>`，
  因此「带 ss-rust 版」和「无 ss-rust 版」可以并存对比。
- **资产**：`immortalwrt-rockchip-armv8-nsy_g68-plus-squashfs-sysupgrade.img.gz` + `sha256sums`。
- **Release 说明**：自动写入来源 run、commit、内核版本、包数量、镜像 sha256、集成清单与刷机命令。
- **关闭方式**：手动 Run workflow 时把 `publish_release` 设为 false；或从 workflow 里删掉「发布到 Release」这一步。
- 需要的权限已写在 workflow 顶部（`permissions: contents: write`），使用的是内置 `GITHUB_TOKEN`，无需额外配置 secret。

### 补发历史构建

`.github/workflows/publish-release.yml`（仅手动 / API 触发）可以把**任意历史 run 的 artifact** 补挂到 Release：

```
Actions → Publish firmware to Release → Run workflow
  run_id   : 42186516665              # 来源构建
  artifact : immortalwrt-g68-plus-6   # 该 run 的 artifact 名
  tag      : g68-plus-2026.11.06      # 目标 tag（已存在则直接上传资产）
```
