#!/bin/sh

#  ci_post_clone.sh
#  Hamster
#
#  Created by morse on 2023/9/28.
#
set -e

# ----------------------------------------------------------------
# Frameworks 说明
# ----------------------------------------------------------------
# xcframework 文件已直接提交至 git 仓库的 Frameworks/ 目录中，
# 原 https://github.com/imfuxiao/LibrimeKit/releases 下载地址已不可用。
# CI clone 仓库后 Frameworks/ 目录即包含所有依赖，无需额外下载。
# ----------------------------------------------------------------

# 生成 SharedSupport.zip 与 rime-ice.zip
OUTPUT="${CI_PRIMARY_REPOSITORY_PATH}/Resources/SharedSupport"
mkdir -p $OUTPUT
bash ${CI_PRIMARY_REPOSITORY_PATH}/InputSchemaBuild.sh
cp ${CI_PRIMARY_REPOSITORY_PATH}/.tmp/SharedSupport/SharedSupport.zip $OUTPUT
cp ${CI_PRIMARY_REPOSITORY_PATH}/.tmp/.rime-ice/rime-ice.zip $OUTPUT
