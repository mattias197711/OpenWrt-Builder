#!/bin/bash
alias wget="$(which wget) --https-only --retry-connrefused"
set -e
set -x
# get the latest release version of 23.05
#LATESTRELEASE=$(curl -sSf -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' https://api.github.com/repos/openwrt/openwrt/tags | jq '.[].name' -r | grep -v 'rc' | grep 'v23' | sort -r | head -n 1)
# get the RC release version of 23.05
LATESTRELEASE=$(curl -sSf -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' https://api.github.com/repos/openwrt/openwrt/tags | jq '.[].name' -r | grep 'rc' | grep 'v23' | sort -r | head -n 1)

echo "LATESTRELEASE=$LATESTRELEASE" >> ./OPENWRT_GIT_TAG

git clone --single-branch -b 'openwrt-23.05'  --depth 1  https://github.com/openwrt/openwrt.git openwrt
git clone --single-branch -b "$LATESTRELEASE" --depth 1  https://github.com/openwrt/openwrt.git openwrt_snapshot

mv -f ./openwrt/package/base-files/ ./BAK_base-files/
mv -f ./openwrt/package/firmware/   ./BAK_firmware/
mv -f ./openwrt/package/kernel/     ./BAK_kernel/
mv -f ./openwrt/package/Makefile    ./BAK_Makefile

rm -rf ./openwrt_snapshot/package/base-files/
rm -rf ./openwrt_snapshot/package/firmware/
rm -rf ./openwrt_snapshot/package/kernel/
rm -rf ./openwrt_snapshot/package/Makefile

rm -rf ./openwrt/package
mv -f ./openwrt_snapshot/package ./openwrt/package

mv -f ./BAK_base-files ./openwrt/package/base-files
mv -f ./BAK_firmware   ./openwrt/package/firmware
mv -f ./BAK_kernel     ./openwrt/package/kernel
mv -f ./BAK_Makefile   ./openwrt/package/Makefile

mv -f ./openwrt_snapshot/feeds.conf.default ./openwrt/feeds.conf.default

# 获取额外代码
git clone -b openwrt-23.05 --depth 1 https://github.com/immortalwrt/immortalwrt.git    Immortalwrt_2305/
sleep 3
git clone -b master        --depth 1 https://github.com/immortalwrt/packages.git       Immortalwrt_PKG/
sleep 3
git clone -b openwrt-23.05 --depth 1 https://github.com/immortalwrt/luci.git           Immortalwrt_Luci_2305/
sleep 3
git clone -b master        --depth 1 https://github.com/coolsnowwolf/lede.git          Coolsnowwolf_MSTR/
sleep 3
git clone -b master        --depth 1 https://github.com/coolsnowwolf/packages.git      Coolsnowwolf_PKG/
sleep 3
git clone -b master        --depth 1 https://github.com/Lienol/openwrt.git             Lienol_MSTR/
sleep 3
git clone -b main          --depth 1 https://github.com/Lienol/openwrt-package.git     Lienol_PKG/
sleep 3
git clone -b master        --depth 1 https://github.com/QiuSimons/OpenWrt-Add.git      OpenWrt-Add/
sleep 3
git clone -b master        --depth 1 https://github.com/openwrt/packages.git           Openwrt_PKG_MSTR/
sleep 3
git clone -b main          --depth 1 https://github.com/jjm2473/openwrt-third.git      Jjm2473_PACKAGES/
sleep 3
git clone -b packages      --depth 1 https://github.com/xiaorouji/openwrt-passwall.git Passwall_PKG/
sleep 3
git clone -b master        --depth 1 https://github.com/fw876/helloworld.git           SSRP_SRC/

unalias wget
exit 0
