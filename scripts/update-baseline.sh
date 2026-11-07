#!/bin/sh
# 重新生成 docs/baseline.sha256（有意修改基线文件后执行）
# 用法: ./scripts/update-baseline.sh
set -eu
cd "$(dirname "$0")/.."
OUT=docs/baseline.sha256
{
	echo "# 基线指纹（改动后请执行 scripts/update-baseline.sh 重新生成）"
	echo "# 校验: sha256sum -c docs/baseline.sha256"
	{
		echo defconfig/g68-plus-docker.config
		echo defconfig/g68-plus-istoreos.config
		echo .github/workflows/build-g68-plus-docker.yml
		echo .github/workflows/publish-release.yml
		echo scripts/gen_image_generic.sh
		find files -type f | sort
	} | while read -r f; do
		[ -f "$f" ] && sha256sum "$f"
	done
} > "$OUT"
echo "已生成 $OUT: $(grep -vc '^#' "$OUT") 个文件"
