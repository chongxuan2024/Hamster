#!/usr/bin/env bash
# encoding: utf-8
set -e

OUTPUT="${PWD}/Frameworks"

# Frameworks 目录下的 xcframework 已直接提交至 git 仓库，无需再从远程下载。
# 原下载地址 https://github.com/imfuxiao/LibrimeKit/releases 已不可用。
#
# 若检测到 Frameworks 目录下已存在 xcframework，则直接跳过；
# 否则打印错误提示，告知用户从本地 Frameworks 目录获取。

XCFRAMEWORK_COUNT=$(find "$OUTPUT" -maxdepth 1 -name "*.xcframework" -type d 2>/dev/null | wc -l | tr -d ' ')

if [[ "$XCFRAMEWORK_COUNT" -gt 0 ]]; then
  echo "[librimeFramework] Frameworks 目录已存在 ${XCFRAMEWORK_COUNT} 个 xcframework，无需下载，跳过。"
  exit 0
fi

echo "[librimeFramework] 错误：Frameworks 目录下未找到任何 .xcframework 文件。"
echo ""
echo "  原 LibrimeKit releases 地址已删除，xcframework 文件已随源码提交至 git 仓库。"
echo "  请确认已正确执行 git clone，或检查 Frameworks/ 目录内容是否完整。"
echo ""
echo "  若需手动获取，请联系项目维护者或从历史 git commit 中恢复 Frameworks/ 目录。"
exit 1
