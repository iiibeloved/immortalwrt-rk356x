#!/usr/bin/env python3
"""跟随一次构建直到结束，并输出完整收尾报告（Release / sha256 / 包数 / 4 条下载链接）。

用法:
  GH_TOKEN=xxx python3 scripts/watch_build.py                 # 跟随最新一次 run
  GH_TOKEN=xxx python3 scripts/watch_build.py --run-id 12345  # 跟随指定 run
  ... --no-wait     # 只报告当前状态，不等待

退出码: 0 = 成功并已报告; 2 = 失败; 3 = 仍在进行(--no-wait)
"""
import argparse, json, os, struct, subprocess, sys, time, urllib.error, urllib.request, zlib

OWNER, REPO = "iiibeloved", "immortalwrt-rk356x"
API = "https://api.github.com"
TK = os.environ.get("GH_TOKEN", "").strip()
PROXIES = ["https://gh-proxy.com/", "https://ghfast.top/", "https://ghproxy.net/"]


def api(path):
    req = urllib.request.Request(API + path, headers={
        "Accept": "application/vnd.github+json", "Authorization": f"Bearer {TK}",
        "User-Agent": "dsh-watch"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            b = r.read().decode()
            return (json.loads(b) if b else {}), 200
    except urllib.error.HTTPError as e:
        return {"error": e.read().decode(errors="replace")[:200]}, e.code


def latest_run():
    d, st = api(f"/repos/{OWNER}/{REPO}/actions/runs?per_page=1")
    return d["workflow_runs"][0] if st == 200 else None


def manifest_packages(run_id):
    """从 artifact zip 里 range 读取 manifest，返回 (包名集合, 错误)"""
    d, st = api(f"/repos/{OWNER}/{REPO}/actions/runs/{run_id}/artifacts")
    if st != 200:
        return None, "读取 artifact 失败"
    cand = [a for a in d.get("artifacts", []) if a["name"].startswith("immortalwrt-g68-plus")]
    if not cand:
        return None, "没有固件 artifact"
    aid = cand[0]["id"]

    class NR(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *a, **k):
            return None

    req = urllib.request.Request(f"{API}/repos/{OWNER}/{REPO}/actions/artifacts/{aid}/zip",
                                 headers={"Authorization": f"Bearer {TK}", "User-Agent": "dsh"})
    try:
        urllib.request.build_opener(NR).open(req, timeout=60)
        return None, "artifact 无重定向"
    except urllib.error.HTTPError as e:
        url = e.headers.get("Location")
    if not url:
        return None, "拿不到下载地址"
    size = int(urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=60)
               .headers["Content-Length"])
    tail = subprocess.run(["curl", "-s", "--max-time", "180", "-H",
                           f"Range: bytes={size-300000}-{size-1}", url],
                          capture_output=True).stdout
    i = tail.rfind(b"PK\x05\x06")
    if i < 0:
        return None, "zip 目录读取失败"
    eocd = tail[i:i + 22]
    cds, cdo = struct.unpack("<I", eocd[12:16])[0], struct.unpack("<I", eocd[16:20])[0]
    cd = subprocess.run(["curl", "-s", "--max-time", "180", "-H",
                         f"Range: bytes={cdo}-{cdo+cds-1}", url], capture_output=True).stdout
    pos, ents = 0, {}
    while pos + 46 <= len(cd) and cd[pos:pos + 4] == b"PK\x01\x02":
        n = struct.unpack("<H", cd[pos+28:pos+30])[0]
        cs = struct.unpack("<I", cd[pos+20:pos+24])[0]
        lho = struct.unpack("<I", cd[pos+42:pos+46])[0]
        ents[cd[pos+46:pos+46+n].decode()] = (lho, cs)
        pos += 46 + n + struct.unpack("<H", cd[pos+30:pos+32])[0]
    name = next((k for k in ents if k.endswith(".manifest")), None)
    if not name:
        return None, "zip 内没有 manifest"
    lho, cs = ents[name]
    hdr = subprocess.run(["curl", "-s", "--max-time", "90", "-H",
                          f"Range: bytes={lho}-{lho+29}", url], capture_output=True).stdout
    nl, el = struct.unpack("<H", hdr[26:28])[0], struct.unpack("<H", hdr[28:30])[0]
    s = lho + 30 + nl + el
    data = subprocess.run(["curl", "-s", "--max-time", "240", "-H",
                           f"Range: bytes={s}-{s+cs-1}", url], capture_output=True).stdout
    man = zlib.decompress(data, -15).decode()
    return {l.split(" - ")[0].strip() for l in man.splitlines() if " - " in l}, None


def report(run):
    rid = run["id"]
    print(f"\n===== run #{run['run_number']} | {run['status']} | {run.get('conclusion')} =====")
    print(run["html_url"])
    jobs, _ = api(f"/repos/{OWNER}/{REPO}/actions/runs/{rid}/jobs")
    if isinstance(jobs, dict) and jobs.get("jobs"):
        j = jobs["jobs"][0]
        bad = [s for s in j["steps"] if s.get("conclusion") in ("failure", "cancelled")]
        print(f"job: {j['status']} {j.get('conclusion') or ''} | 失败步骤: "
              f"{[(s['number'], s['name']) for s in bad] or '无'}")
    rels, _ = api(f"/repos/{OWNER}/{REPO}/releases?per_page=3")
    rel = None
    if isinstance(rels, list):
        for r in rels:
            if r.get("target_commitish") and run["head_sha"][:8] in (r.get("body") or ""):
                rel = r
                break
        rel = rel or rels[0]
    if rel:
        print(f"\nRelease: {rel['tag_name']} | {rel['html_url']}")
        for a in rel["assets"]:
            print(f"  {a['name']}  {a['size']/1048576:.1f} MB")
        body = rel.get("body") or ""
        for line in body.splitlines():
            if "软件包" in line or "镜像 sha256" in line:
                print(" ", line.strip())
        asset = next((a for a in rel["assets"] if a["name"].endswith(".img.gz")), None)
        if asset:
            url = asset["browser_download_url"]
            print("\n下载链接:")
            print("  GitHub 直链 :", url)
            for p in PROXIES:
                print(f"  {p} :", p + url)
            sums = next((a for a in rel["assets"] if a["name"] == "sha256sums"), None)
            if sums:
                print("  sha256sums  :", sums["browser_download_url"])
    names, err = manifest_packages(rid)
    if names:
        print(f"\n固件包数: {len(names)} | 解析: {err or 'OK'}")
        for k in ["gdisk", "sfdisk", "cfdisk", "cgdisk", "luci-app-partexp", "kmod-loop",
                  "f2fs-tools", "luci-app-ddns", "luci-app-homeassistant"]:
            print(("  ✅ " if k in names else "  ⚠️ ")+k)
    else:
        print(f"\nmanifest 读取失败: {err}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-id", type=int)
    ap.add_argument("--no-wait", action="store_true")
    ap.add_argument("--interval", type=int, default=180)
    a = ap.parse_args()

    run = None
    if a.run_id:
        d, st = api(f"/repos/{OWNER}/{REPO}/actions/runs/{a.run_id}")
        run = d if st == 200 else None
    else:
        run = latest_run()
    if not run:
        print("拿不到 run 信息"); return 2

    print(f"跟踪 run #{run['run_number']} ({run['head_sha'][:8]}) ...", flush=True)
    deadline = time.time() + 6 * 3600
    while run["status"] != "completed" and not a.no_wait and time.time() < deadline:
        time.sleep(a.interval)
        d, st = api(f"/repos/{OWNER}/{REPO}/actions/runs/{run['id']}")
        if st == 200:
            run = d
            print(f"  ... {run['status']}", flush=True)
    if run["status"] != "completed":
        print("仍在进行中（未等待/超时）")
        return 3
    report(run)
    return 0 if run.get("conclusion") == "success" else 2


if __name__ == "__main__":
    sys.exit(main())
