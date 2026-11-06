# immortalwrt-rk356x

基于 [ImmortalWrt 24.10](https://github.com/immortalwrt/immortalwrt) 的 rockchip/armv8 派生仓库，面向 RK3568 系列 NAS/软路由设备，
内置 GitHub Actions 一键编译与 iStoreOS 风格插件集成。

---

## 当前状态（下次构建速览）

> 以下为 **2026-11-06 快照**；时间敏感信息请以 [Actions](https://github.com/iiibeloved/immortalwrt-rk356x/actions) 与 [Releases](https://github.com/iiibeloved/immortalwrt-rk356x/releases) 页面为准。

| 项目 | 值 |
| --- | --- |
| **下次自动构建** | **2026-11-09 02:00（周一，北京时间）** · cron `0 18 * * 0`（UTC 周日 18:00） |
| 想立即构建 | Actions → `Build G68-PLUS (iStoreOS style)` → **Run workflow**（≈ 2.5 小时） |
| 最近一次成功构建 | [run #42186516665](https://github.com/iiibeloved/immortalwrt-rk356x/actions/runs/42186516665) · commit `c6b3a90d` · 4 小时 09 分 |
| 最近一次发布 | [g68-plus-2026.11.06](https://github.com/iiibeloved/immortalwrt-rk356x/releases/tag/g68-plus-2026.11.06)（含 shadowsocks-rust，167 MB） |
| 当前仓库配置 | 已关闭 `shadowsocks-rust`（省约 2 小时）· rootfs 2048 MB · 22 个 iStoreOS 风格包 + samba4 + docker 引擎 |
| 下次构建预期 | ≈ 2.5 小时；成功后自动发布 `g68-plus-2026.11.09` Release（免登录直链） |
| 构建失败 | 自动开 Issue：标题 `CI 构建失败: … #<run>`，正文含失败步骤、run 链接与排查指引；同类未关闭则追加评论 |
| 详细步骤 | [docs/build-guide.md](docs/build-guide.md)（触发方式 / 20 步流程 / 失败速查表 / 12 条注意事项） |

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
| `rootfs_size` | `2048` | rootfs 分区 MB 数 |
| `upload_artifacts` | `true` | 上传 artifact（15 天） |
| `publish_release` | `true` | 成功后自动发布 Release |

耗时参考：**约 2.5 小时**（rust 步骤已按配置自动跳过）；保留 `shadowsocks-rust` 时约 4.2 小时。

---

## 集成内容（`g68-plus-istoreos.config`）

- **iStoreOS 风格**：`luci-app-quickstart` + `quickstart`、`luci-app-store`（iStore）+ `taskd` / `luci-lib-taskd` / `luci-lib-xterm`
- **共享 / 运维**：`unishare`（samba4 + webdav2 聚合面板）、`lucky`、`luci-app-wolplus`、`luci-app-rtbwmon`
- **文件管理**：`luci-app-filemanager`、`luci-app-filetransfer`
- **Samba4**：`samba4-server` + `luci-app-samba4`
- **Docker**：`dockerd` / `containerd` / `runc` / `docker`（原 defconfig 只有 dockerman 界面，已补齐引擎）
- **按需关闭**：`shadowsocks-rust-sslocal/ssserver`（默认关闭，可省约 2 小时构建时间）

第三方源：`kenzok8/small-package`（只按名安装需要的包，避免与官方源同名冲突）、`DustReliant/luci-app-filetransfer`（本地单包引入）。

---

## 文档

| 文档 | 内容 |
| --- | --- |
| [docs/build-guide.md](docs/build-guide.md) | **下次编译详细教程**：触发方式、20 步流程与实测耗时、产物下载、刷机、失败速查表、12 条注意事项、30 秒检查清单 |
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

1. 构建中途取消会丢失 `dl` / `.ccache` 缓存，下次仍需重拉 feeds 与重编。
2. 改 `docs/` 或 workflow 不会触发构建；只有改 `defconfig/` 下两个文件才会。
3. cron 是 UTC：`0 18 * * 0` 对应**周一 02:00（北京时间）**。
4. 仓库 60 天无提交活动，GitHub 会停用定时任务，需在 Actions 页面手动 Enable。
5. 构建失败会**自动开 Issue**（含定时构建），正文带 run 链接、失败步骤与排查指引；同类未关闭 issue 存在时改为追加评论。
6. 附加插件多为社区维护，刷机后建议逐项验证（quickstart / iStore / 共享 / Docker）。
7. 第三方 feed 跟随上游 `master`，需要完全可复现构建时应锁定 commit。
