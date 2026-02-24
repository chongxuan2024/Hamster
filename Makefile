.PHONY: framework cleanFramework scheme cleanScheme

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir := $(dir $(mkfile_path))

# framework target：
#   xcframework 文件已直接提交至 git 仓库 Frameworks/ 目录，
#   原 LibrimeKit releases 下载地址已不可用。
#   执行此 target 时仅做本地校验，有则跳过，无则报错提示。
framework:
	bash ./librimeFramework.sh

cleanFramework:
	rm -rf Packages/RimeKit/Frameworks

schema:
	bash ./InputSchemaBuild.sh

cleanSchema:
	rm -rf .tmp Resources/SharedSupport/*.zip
