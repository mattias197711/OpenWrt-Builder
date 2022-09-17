#!/bin/bash
set -e
alias wget="$(which wget) --https-only --retry-connrefused"

# get the latest release version of 22.03
LATESTRELEASE=$(curl -sSf -H 'Accept: application/vnd.github.v3+json' https://api.github.com/repos/openwrt/openwrt/tags | jq '.[].name' | grep -v 'rc' | grep 'v22' | sort -r | head -n 1)
LATESTRELEASE=${LATESTRELEASE:1:-1}

wget https://github.com/openwrt/openwrt/archive/${LATESTRELEASE}.tar.gz

mkdir openwrt_release

tar xf ${LATESTRELEASE}.tar.gz --strip-components=1 --directory=./openwrt_release
rm  -f ${LATESTRELEASE}.tar.gz

git clone --single-branch -b openwrt-22.03 https://github.com/openwrt/openwrt.git
rm  -f ./openwrt/include/version.mk
rm  -f ./openwrt/include/kernel.mk
rm  -f ./openwrt/include/kernel-5.10
rm  -f ./openwrt/include/kernel-version.mk
rm  -f ./openwrt/include/toolchain-build.mk
rm  -f ./openwrt/include/kernel-defaults.mk
rm  -f ./openwrt/package/base-files/image-config.in
rm -rf ./openwrt/package/kernel/linux/
rm -rf ./openwrt/target/linux/

cp  -f ./openwrt_release/include/version.mk                 ./openwrt/include/version.mk
cp  -f ./openwrt_release/include/kernel.mk                  ./openwrt/include/kernel.mk
cp  -f ./openwrt_release/include/kernel-5.10                ./openwrt/include/kernel-5.10
cp  -f ./openwrt_release/include/kernel-version.mk          ./openwrt/include/kernel-version.mk
cp  -f ./openwrt_release/include/toolchain-build.mk         ./openwrt/include/toolchain-build.mk
cp  -f ./openwrt_release/include/kernel-defaults.mk         ./openwrt/include/kernel-defaults.mk
cp  -f ./openwrt_release/package/base-files/image-config.in ./openwrt/package/base-files/image-config.in
cp -rf ./openwrt_release/package/kernel/linux/              ./openwrt/package/kernel/linux/
cp -rf ./openwrt_release/target/linux/                      ./openwrt/target/linux/

rm -rf ./openwrt_release/

unalias wget
exit 0
