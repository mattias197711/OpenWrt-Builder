#!/bin/bash
alias wget="$(which wget) --https-only --retry-connrefused"
MY_svn_export () {
  set +x
  local MY_state=0
  for retry_count in {1..5} ; do
    if svn export "$1" "$2" ; then
      MY_state=1
      break
    fi
    sleep "${retry_count}0"
  done
  set -x
  [ ${MY_state} -ne 0 ]
}

# 如果没有环境变量或无效，则默认构建R2S版本
[ -f "../SEED/${MYOPENWRTTARGET}.config.seed" ] || MYOPENWRTTARGET='R2S'
echo "==> Now building: ${MYOPENWRTTARGET}"

set -e
set -x
### 1. 准备工作 ###
# 使用O2级别的优化
sed -i 's/ -Os / -O2 -Wl,--gc-sections /g' include/target.mk
wget -qO - https://github.com/openwrt/openwrt/commit/8249a8c54e26aa2039258ee4307ea0cc18edab78.patch | patch -p1
# feed使用GitHub
sed -i 's,git.openwrt.org/feed/packages,github.com/openwrt/packages,g'   ./feeds.conf.default
sed -i 's,git.openwrt.org/project/luci,github.com/openwrt/luci,g'        ./feeds.conf.default
sed -i 's,git.openwrt.org/feed/routing,github.com/openwrt/routing,g'     ./feeds.conf.default
sed -i 's,git.openwrt.org/feed/telephony,github.com/openwrt/telephony,g' ./feeds.conf.default
# 更新feed
./scripts/feeds update -a
./scripts/feeds install -a
# 获取额外代码
git clone -b master --depth 1 https://github.com/immortalwrt/immortalwrt Immortalwrt_SRC/
# something called magic
rm -rf ./scripts/download.pl ./include/download.mk
cp -a Immortalwrt_SRC/include/download.mk include/
cp -a Immortalwrt_SRC/scripts/download.pl scripts/
sed -i '/\.cn\//d'   scripts/download.pl
sed -i '/aliyun/d'   scripts/download.pl
sed -i '/cnpmjs/d'   scripts/download.pl
sed -i '/fastgit/d'  scripts/download.pl
sed -i '/ghproxy/d'  scripts/download.pl
sed -i '/mirror02/d' scripts/download.pl
sed -i '/sevencdn/d' scripts/download.pl
sed -i '/tencent/d'  scripts/download.pl
sed -i '/zwc365/d'   scripts/download.pl
sed -i '/182\.140\.223\.146/d' scripts/download.pl
chmod +x scripts/download.pl

### 2. 必要的Patch ###
mkdir -p ./package/new/ ./package/lean/
cp -af ../PATCH/backport/290-remove-kconfig-CONFIG_I8K.patch ./target/linux/generic/hack-5.10/
# R8152 网卡驱动
cp -a Immortalwrt_SRC/package/kernel/r8152 package/new/r8152
# R8168 网卡驱动
git clone -b master --depth 1 https://github.com/BROBIRD/openwrt-r8168 package/new/r8168
# R8125 网卡驱动
MY_svn_export https://github.com/coolsnowwolf/lede/trunk/package/lean/r8125 package/new/r8125
# 根据体系调整
case ${MYOPENWRTTARGET} in
  R2S)
    # 显示 ARM64 CPU 型号
    cp -a Immortalwrt_SRC/target/linux/generic/hack-5.10/312-arm64-cpuinfo-Add-model-name-in-proc-cpuinfo-for-64bit-ta.patch target/linux/generic/hack-5.10/
    # R8168 网卡驱动
    patch -p1 < ../PATCH/r8168/r8168-fix_LAN_led-for_r4s-from_TL.patch
    # 更换 UBoot 以及 Target
    sed -i 's,-mcpu=generic,-mcpu=cortex-a53+crypto,g' include/target.mk
    rm -rf ./target/linux/rockchip
    MY_svn_export https://github.com/coolsnowwolf/lede/trunk/target/linux/rockchip target/linux/rockchip
    rm -rf ./target/linux/rockchip/Makefile
    wget -P target/linux/rockchip/ https://raw.githubusercontent.com/openwrt/openwrt/openwrt-22.03/target/linux/rockchip/Makefile
    rm -rf ./target/linux/rockchip/patches-5.10/002-net-usb-r8152-add-LED-configuration-from-OF.patch
    rm -rf ./target/linux/rockchip/patches-5.10/003-dt-bindings-net-add-RTL8152-binding-documentation.patch
    cp -af ../PATCH/rockchip-5.10/* ./target/linux/rockchip/patches-5.10/
    rm -rf ./package/firmware/linux-firmware/intel.mk ./package/firmware/linux-firmware/Makefile
    wget -P package/firmware/linux-firmware/ https://raw.githubusercontent.com/coolsnowwolf/lede/master/package/firmware/linux-firmware/intel.mk
    wget -P package/firmware/linux-firmware/ https://raw.githubusercontent.com/coolsnowwolf/lede/master/package/firmware/linux-firmware/Makefile
    # 用假的dts填补缺失的rk3568
    mkdir -p                 target/linux/rockchip/files-5.10/arch/arm64/boot/dts/rockchip/
    cp -f ../PATCH/dts/*.dts target/linux/rockchip/files-5.10/arch/arm64/boot/dts/rockchip/
    mkdir -p                 target/linux/rockchip/files-5.10/include/linux/
    cp -f ../PATCH/dts/*.h   target/linux/rockchip/files-5.10/include/linux/
    mkdir -p                 target/linux/rockchip/files-5.10/drivers/net/phy/
    cp -f ../PATCH/dts/*.c   target/linux/rockchip/files-5.10/drivers/net/phy/
    # 替换uboot
    rm -rf ./package/boot/uboot-rockchip
    MY_svn_export https://github.com/coolsnowwolf/lede/trunk/package/boot/uboot-rockchip package/boot/uboot-rockchip
    sed -i '/r2c-rk3328:arm-trusted/d' package/boot/uboot-rockchip/Makefile
    MY_svn_export https://github.com/coolsnowwolf/lede/trunk/package/boot/arm-trusted-firmware-rockchip-vendor package/boot/arm-trusted-firmware-rockchip-vendor
    # 添加 GPU 驱动
    rm -rf package/kernel/linux/modules/video.mk
    cp -a Immortalwrt_SRC/package/kernel/linux/modules/video.mk package/kernel/linux/modules/
    echo '
# CONFIG_IR_SANYO_DECODER is not set
# CONFIG_IR_SHARP_DECODER is not set
# CONFIG_IR_MCE_KBD_DECODER is not set
# CONFIG_IR_XMP_DECODER is not set
# CONFIG_IR_IMON_DECODER is not set
# CONFIG_IR_RCMM_DECODER is not set
# CONFIG_IR_SPI is not set
# CONFIG_IR_GPIO_TX is not set
# CONFIG_IR_PWM_TX is not set
# CONFIG_IR_SERIAL is not set
# CONFIG_IR_SIR is not set
# CONFIG_RC_XBOX_DVD is not set
# CONFIG_IR_TOY is not set
# CONFIG_MEDIA_CEC_RC is not set
' >> ./target/linux/rockchip/armv8/config-5.10
    # 其他内核配置
    echo '
# CONFIG_SHORTCUT_FE is not set
# CONFIG_PHY_ROCKCHIP_NANENG_COMBO_PHY is not set
# CONFIG_PHY_ROCKCHIP_SNPS_PCIE3 is not set
' >> ./target/linux/rockchip/armv8/config-5.10
    ;;
  x86)
    # Intel GPU 修正
    rm -rf  package/kernel/linux/modules/video.mk
    wget -P package/kernel/linux/modules/ https://raw.githubusercontent.com/coolsnowwolf/lede/master/package/kernel/linux/modules/video.mk
    sed -i 's,CONFIG_DRM_I915_CAPTURE_ERROR ,CONFIG_DRM_I915_CAPTURE_ERROR=n ,g' package/kernel/linux/modules/video.mk
    # config 变更
    rm -rf  target/linux/x86/64/config-5.10
    wget -P target/linux/x86/64/ https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/x86/64/config-5.10
    # igb-intel 网卡驱动
    MY_svn_export https://github.com/coolsnowwolf/lede/trunk/package/lean/igb-intel package/new/igb-intel
    # igc-backport
    mkdir -p target/linux/x86/files-5.10/drivers/net/ethernet/intel/igc/
    cp -f ../PATCH/intel-igc-driver/* ./target/linux/x86/files-5.10/drivers/net/ethernet/intel/igc/
    # 系统型号字符串
    echo '# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.

if grep -q "Default string" /tmp/sysinfo/model 2>/dev/null; then
    echo "Compatible PC" > /tmp/sysinfo/model
fi

exit 0
'> ./package/base-files/files/etc/rc.local
    ;;
esac
# 默认开启 irqbalance
sed -i "s/enabled '0'/enabled '1'/g" feeds/packages/utils/irqbalance/files/irqbalance.config
# grub2强制使用O2级别优化
wget -qO - https://github.com/openwrt/openwrt/commit/66fa3431125eca21f1b06878f508d5c079b7f76c.patch | patch -p1
# Patch Kernel 以解决FullCone冲突
cp -a Immortalwrt_SRC/target/linux/generic/hack-5.10/952-net-conntrack-events-support-multiple-registrant.patch target/linux/generic/hack-5.10/
# Patch FireWall 以增添FullCone功能
# FW4
rm -rf ./package/network/config/firewall4
cp -af Immortalwrt_SRC/package/network/config/firewall4                 ./package/network/config/firewall4
cp -af ../PATCH/firewall/990-unconditionally-allow-ct-status-dnat.patch ./package/network/config/firewall4/patches/990-unconditionally-allow-ct-status-dnat.patch
rm -rf ./package/libs/libnftnl ./package/network/utils/nftables
MY_svn_export https://github.com/wongsyrone/lede-1/trunk/package/libs/libnftnl          package/libs/libnftnl
MY_svn_export https://github.com/wongsyrone/lede-1/trunk/package/network/utils/nftables package/network/utils/nftables
# FW3
mkdir -p package/network/config/firewall/patches/
wget  -P package/network/config/firewall/patches/ https://raw.githubusercontent.com/immortalwrt/immortalwrt/openwrt-21.02/package/network/config/firewall/patches/100-fullconenat.patch
# Patch LuCI 以增添FullCone开关
patch -p1 < ../PATCH/firewall/luci-app-firewall_add_fullcone.patch
# FullCone 相关组件
git clone --depth 1 https://github.com/fullcone-nat-nftables/nft-fullcone         package/new/nft-fullcone
MY_svn_export https://github.com/Lienol/openwrt/trunk/package/network/fullconenat package/lean/openwrt-fullconenat
# mbedTLS
rm -rf ./package/libs/mbedtls
MY_svn_export https://github.com/immortalwrt/immortalwrt/branches/master/package/libs/mbedtls package/libs/mbedtls
# fstool patch
wget -qO - https://github.com/coolsnowwolf/lede/commit/8a4db762497b79cac91df5e777089448a2a71f7c.patch | patch -p1
# 修复由于 shadow-utils 引起的管理页面修改密码功能失效的问题
pushd feeds/luci
  patch -p1 < ../../../PATCH/0002-let-luci-use-busybox-passwd.patch
popd

### 3. 更新部分软件包 ###
# dnsmasq
rm -rf ./package/network/services/dnsmasq
MY_svn_export https://github.com/openwrt/openwrt/trunk/package/network/services/dnsmasq   package/network/services/dnsmasq
# 更换 golang 版本
rm -rf ./feeds/packages/lang/golang
MY_svn_export https://github.com/openwrt/packages/trunk/lang/golang                       feeds/packages/lang/golang
# AutoCore & coremark
cp -a Immortalwrt_SRC/package/emortal/autocore package/lean/autocore
pushd package/lean
  patch -p1 < ../../../PATCH/autocore/0003-some-fix.patch
popd
pushd feeds/luci
  patch -p1 < ../../../PATCH/autocore/0004-luci-base-add-functions-to-get-info.patch
popd
rm -rf ./feeds/packages/utils/coremark
MY_svn_export https://github.com/immortalwrt/packages/trunk/utils/coremark                feeds/packages/utils/coremark
# AutoReboot定时重启
MY_svn_export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-autoreboot package/lean/luci-app-autoreboot
sed -i '/LUCI_DEPENDS/d' package/lean/luci-app-autoreboot/Makefile
# ipv6-helper
MY_svn_export https://github.com/coolsnowwolf/lede/trunk/package/lean/ipv6-helper         package/lean/ipv6-helper
# 清理内存
MY_svn_export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-ramfree    package/lean/luci-app-ramfree
# 流量监视
git clone -b master --depth 1 https://github.com/brvphoenix/wrtbwmon                      package/new/wrtbwmon
git clone -b master --depth 1 https://github.com/brvphoenix/luci-app-wrtbwmon             package/new/luci-app-wrtbwmon
# Haproxy
rm -rf ./feeds/packages/net/haproxy
MY_svn_export https://github.com/openwrt/packages/trunk/net/haproxy                       feeds/packages/net/haproxy
pushd feeds/packages
  wget -qO - https://github.com/openwrt/packages/commit/a09cbcdf20dc4472eb4f464deb6921a6b9f366c8.patch | patch -p1
popd
# luci-app-irqbalance
MY_svn_export https://github.com/QiuSimons/OpenWrt-Add/trunk/luci-app-irqbalance          package/new/luci-app-irqbalance
# socat
MY_svn_export https://github.com/Lienol/openwrt-package/trunk/luci-app-socat              package/new/luci-app-socat
sed -i '/socat\.config/d' feeds/packages/net/socat/Makefile
# SSRP依赖
rm -rf ./feeds/packages/net/xray-core ./feeds/packages/net/kcptun ./feeds/packages/net/shadowsocks-libev ./feeds/packages/net/proxychains-ng ./feeds/packages/net/shadowsocks-rust ./feeds/packages/net/v2raya
MY_svn_export https://github.com/coolsnowwolf/lede/trunk/package/lean/srelay              package/lean/srelay
MY_svn_export https://github.com/coolsnowwolf/packages/trunk/net/shadowsocks-libev        package/lean/shadowsocks-libev
MY_svn_export https://github.com/xiaorouji/openwrt-passwall/trunk/brook                   package/new/brook
MY_svn_export https://github.com/xiaorouji/openwrt-passwall/trunk/dns2socks               package/lean/dns2socks
MY_svn_export https://github.com/xiaorouji/openwrt-passwall/trunk/ipt2socks               package/lean/ipt2socks
MY_svn_export https://github.com/xiaorouji/openwrt-passwall/trunk/microsocks              package/lean/microsocks
MY_svn_export https://github.com/xiaorouji/openwrt-passwall/trunk/pdnsd-alt               package/lean/pdnsd
MY_svn_export https://github.com/xiaorouji/openwrt-passwall/trunk/ssocks                  package/new/ssocks
MY_svn_export https://github.com/xiaorouji/openwrt-passwall/trunk/trojan-go               package/lean/trojan-go
MY_svn_export https://github.com/xiaorouji/openwrt-passwall/trunk/trojan-plus             package/new/trojan-plus
MY_svn_export https://github.com/immortalwrt/packages/trunk/net/kcptun                    feeds/packages/net/kcptun
git clone -b master --depth 1 https://github.com/fw876/helloworld                         SSRP_SRC
pushd SSRP_SRC
  patch -p1 < ../../PATCH/0005-add-QiuSimons-Chnroute-to-chnroute-url.patch
popd
mv SSRP_SRC/dns2tcp                                                                       package/new/dns2tcp
mv SSRP_SRC/hysteria                                                                      package/new/hysteria
mv SSRP_SRC/lua-neturl                                                                    package/new/lua-neturl
mv SSRP_SRC/naiveproxy                                                                    package/lean/naiveproxy
mv SSRP_SRC/redsocks2                                                                     package/lean/redsocks2
mv SSRP_SRC/sagernet-core                                                                 package/new/sagernet-core
mv SSRP_SRC/shadowsocks-rust                                                              feeds/packages/net/shadowsocks-rust
mv SSRP_SRC/shadowsocksr-libev                                                            package/lean/shadowsocksr-libev
mv SSRP_SRC/simple-obfs                                                                   package/lean/simple-obfs
mv SSRP_SRC/tcping                                                                        package/lean/tcping
mv SSRP_SRC/trojan                                                                        package/lean/trojan
mv SSRP_SRC/v2ray-core                                                                    package/lean/v2ray-core
mv SSRP_SRC/v2ray-geodata                                                                 package/new/v2ray-geodata
mv SSRP_SRC/v2ray-plugin                                                                  package/lean/v2ray-plugin
mv SSRP_SRC/xray-core                                                                     package/lean/xray-core
mv SSRP_SRC/xray-plugin                                                                   package/lean/xray-plugin
mv SSRP_SRC/luci-app-ssr-plus                                                             package/lean/luci-app-ssr-plus
MY_svn_export https://github.com/openwrt/packages/trunk/net/v2raya                        feeds/packages/net/v2raya
ln -sf ../../../feeds/packages/net/v2raya                                               ./package/feeds/packages/v2raya
ln -sf ../../../feeds/packages/net/kcptun                                               ./package/feeds/packages/kcptun
ln -sf ../../../feeds/packages/net/shadowsocks-rust                                     ./package/feeds/packages/shadowsocks-rust
rm -rf SSRP_SRC
# OpenClash
MY_svn_export https://github.com/vernesong/OpenClash/branches/dev/luci-app-openclash    package/new/luci-app-openclash
# 额外DDNS脚本
sed -i '/boot()/,+2d' feeds/packages/net/ddns-scripts/files/etc/init.d/ddns
MY_svn_export https://github.com/jjm2473/openwrt-third/trunk/ddns-scripts_dnspod        package/lean/ddns-scripts_dnspod
MY_svn_export https://github.com/jjm2473/openwrt-third/trunk/ddns-scripts_aliyun        package/lean/ddns-scripts_aliyun
# Zerotier
rm -rf ./feeds/packages/net/zerotier
MY_svn_export https://github.com/immortalwrt/packages/trunk/net/zerotier                feeds/packages/net/zerotier
MY_svn_export https://github.com/immortalwrt/luci/trunk/applications/luci-app-zerotier  feeds/luci/applications/luci-app-zerotier
ln -sf ../../../feeds/luci/applications/luci-app-zerotier                             ./package/feeds/luci/luci-app-zerotier
rm -rf ./feeds/packages/net/zerotier/files/etc/init.d/zerotier
# CPU 限制
MY_svn_export https://github.com/immortalwrt/packages/trunk/utils/cpulimit              feeds/packages/utils/cpulimit
ln -sf ../../../feeds/packages/utils/cpulimit                                         ./package/feeds/packages/cpulimit
MY_svn_export https://github.com/QiuSimons/OpenWrt-Add/trunk/luci-app-cpulimit          package/lean/luci-app-cpulimit
# CPU 主频
if [ "${MYOPENWRTTARGET}" = 'R2S' ] ; then
  MY_svn_export https://github.com/immortalwrt/luci/trunk/applications/luci-app-cpufreq feeds/luci/applications/luci-app-cpufreq
  ln -sf ../../../feeds/luci/applications/luci-app-cpufreq                            ./package/feeds/luci/luci-app-cpufreq
fi
# jq
sed -i 's,9625784cf2e4fd9842f1d407681ce4878b5b0dcddbcd31c6135114a30c71e6a8,5de8c8e29aaa3fb9cc6b47bb27299f271354ebb72514e3accadc7d38b5bbaa72,g' feeds/packages/utils/jq/Makefile
# 翻译及部分功能优化
MY_svn_export https://github.com/QiuSimons/OpenWrt-Add/trunk/addition-trans-zh          package/lean/lean-translate
sed -i 's,iptables-mod-fullconenat,iptables-nft +kmod-nft-fullcone,g'                   package/lean/lean-translate/Makefile
if [ "${MYOPENWRTTARGET}" != 'R2S' ] ; then
  sed -i '/openssl\.cnf/d' ../PATCH/addition-trans-zh/files/zzz-default-settings
  sed -i '/upnp/Id'        ../PATCH/addition-trans-zh/files/zzz-default-settings
fi
cp -f ../PATCH/addition-trans-zh/files/zzz-default-settings ./package/lean/lean-translate/files/zzz-default-settings
# 给root用户添加vim和screen的配置文件
mkdir -p                   ./package/base-files/files/root/
cp -f ../PRECONFS/vimrc    ./package/base-files/files/root/.vimrc
cp -f ../PRECONFS/screenrc ./package/base-files/files/root/.screenrc

### 4. 最后的收尾工作 ###
# vermagic
LATESTRELEASE=$(curl -sSf -H 'Accept: application/vnd.github+json' https://api.github.com/repos/openwrt/openwrt/tags | jq '.[].name' | grep -v 'rc' | grep 'v22' | sort -r | head -n 1)
LATESTRELEASE=${LATESTRELEASE:2:-1}
case ${MYOPENWRTTARGET} in
  R2S)
    wget https://downloads.openwrt.org/releases/${LATESTRELEASE}/targets/rockchip/armv8/packages/Packages.gz
    ;;
  x86)
    wget https://downloads.openwrt.org/releases/${LATESTRELEASE}/targets/x86/64/packages/Packages.gz
    ;;
esac
zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' > .vermagic
sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
rm -f Packages.gz
# nftables 额外规则
mkdir -p files/usr/share/nftables.d/chain-pre/forward/
cp -a ../PATCH/nftables/10-ios.nft files/usr/share/nftables.d/chain-pre/forward/
# 最大连接
sed -i 's/16384/65535/g' package/kernel/linux/files/sysctl-nf-conntrack.conf
echo 'net.netfilter.nf_conntrack_helper = 1' >> package/kernel/linux/files/sysctl-nf-conntrack.conf
# 删除已有配置
rm -rf .config
# 删除多余的代码库
rm -rf Immortalwrt_SRC/
# 删除.svn目录
find ./ -type d -name '.svn' -print0 | xargs -0 -s1024 /bin/rm -rf
unalias wget
