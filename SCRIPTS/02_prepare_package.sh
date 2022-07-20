#!/bin/bash
set -x
set -e
alias wget="$(which wget) --https-only --retry-connrefused"

# 如果没有环境变量或无效，则默认构建R2S版本
[ -f "../SEED/${MYOPENWRTTARGET}.config.seed" ] || MYOPENWRTTARGET='R2S'
echo "==> Now building: ${MYOPENWRTTARGET}"

### 1. 准备工作 ###
# 获取额外代码
git clone -b openwrt-21.02 --depth=1 https://github.com/immortalwrt/immortalwrt Immortalwrt_SRC/
# R2S专用
if [ "${MYOPENWRTTARGET}" = 'R2S' ] ; then
  sed -i 's,-mcpu=generic,-mcpu=cortex-a53+crypto,g' include/target.mk
  cp -f ../PATCH/mbedtls/100-Implements-AES-and-GCM-with-ARMv8-Crypto-Extensions.patch ./package/libs/mbedtls/patches/100-Implements-AES-and-GCM-with-ARMv8-Crypto-Extensions.patch
  # 采用immortalwrt的优化
  rm -rf ./target/linux/rockchip ./package/boot/uboot-rockchip ./package/boot/arm-trusted-firmware-rockchip-vendor
  cp -a Immortalwrt_SRC/target/linux/rockchip                             target/linux/rockchip
  cp -a Immortalwrt_SRC/package/boot/uboot-rockchip                       package/boot/uboot-rockchip
  cp -a Immortalwrt_SRC/package/boot/arm-trusted-firmware-rockchip-vendor package/boot/arm-trusted-firmware-rockchip-vendor
  # overclocking 1.5GHz
  cp -f ../PATCH/999-RK3328-enable-1512mhz-opp.patch target/linux/rockchip/patches-5.4/991-arm64-dts-rockchip-add-more-cpu-operating-points-for.patch
fi
# 使用O2级别的优化
sed -i 's/ -Os / -O2 -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections /g' include/target.mk
# feed调节
sed -i '/telephony/d' feeds.conf.default
# 更新feed
./scripts/feeds update -a
./scripts/feeds install -a
# something called magic
rm -rf ./scripts/download.pl ./include/download.mk
cp -a Immortalwrt_SRC/include/download.mk include/download.mk
cp -a Immortalwrt_SRC/scripts/download.pl scripts/download.pl
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
# 根据体系调整
case ${MYOPENWRTTARGET} in
  R2S)
    # show cpu model name
    cp -a Immortalwrt_SRC/target/linux/generic/hack-5.4/312-arm64-cpuinfo-Add-model-name-in-proc-cpuinfo-for-64bit-ta.patch target/linux/generic/hack-5.4/
    # R8152 驱动
    svn export https://github.com/immortalwrt/immortalwrt/branches/master/package/kernel/r8152 package/new/r8152
    sed -i 's,kmod-usb-net-rtl8152,kmod-usb-net-rtl8152-vendor,g' target/linux/rockchip/image/armv8.mk
    # IRQ and disabed rk3328 ethernet tcp/udp offloading tx/rx
    sed -i '/set_interface_core 4 "eth1"/a\\tset_interface_core 1 "ff150000.i2c"' target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/40-net-smp-affinity
    sed -i                '/ff150000.i2c/a\\tset_interface_core 8 "ff160000.i2c"' target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/40-net-smp-affinity
    wget -P target/linux/rockchip/armv8/base-files/etc/hotplug.d/iface/ https://raw.githubusercontent.com/QiuSimons/OpenWrt-Add/master/12-disable-rk3328-eth-offloading
    sed -i 's,eth0,eth1,g' target/linux/rockchip/armv8/base-files/etc/hotplug.d/iface/12-disable-rk3328-eth-offloading
    # 添加 GPU 驱动
    rm -rf  package/kernel/linux/modules/video.mk
    cp -a Immortalwrt_SRC/package/kernel/linux/modules/video.mk package/kernel/linux/modules/
    # 交换 LAN WAN
    patch -p1 < ../PATCH/R2S-swap-LAN-WAN.patch
    ;;
  x86)
    # 默认开启 irqbalance
    sed -i "s/enabled '0'/enabled '1'/g" feeds/packages/utils/irqbalance/files/irqbalance.config
    ;;
esac
# grub2强制使用O2级别优化
patch -p1 < ../PATCH/0001-grub2-use-O2.patch
# BBRv2
patch -p1 < ../PATCH/BBRv2/openwrt-kmod-bbr2.patch
cp -f ../PATCH/BBRv2/693-Add_BBRv2_congestion_control_for_Linux_TCP.patch ./target/linux/generic/hack-5.4/693-Add_BBRv2_congestion_control_for_Linux_TCP.patch
wget -qO - https://github.com/openwrt/openwrt/commit/cfaf039b0e5cf4c38b88c20540c76b10eac3078d.patch | patch -p1
# Patch dnsmasq filter AAAA
patch -p1 < ../PATCH/dnsmasq/dnsmasq-add-filter-aaaa-option.patch
patch -p1 < ../PATCH/dnsmasq/luci-add-filter-aaaa-option.patch
cp -f       ../PATCH/dnsmasq/900-add-filter-aaaa-option.patch ./package/network/services/dnsmasq/patches/900-add-filter-aaaa-option.patch
# Patch Kernel 以解决FullCone冲突
cp -a Immortalwrt_SRC/target/linux/generic/hack-5.4/952-net-conntrack-events-support-multiple-registrant.patch target/linux/generic/hack-5.4
# Patch FireWall 以增添FullCone功能
mkdir -p package/network/config/firewall/patches
wget  -P package/network/config/firewall/patches/ https://raw.githubusercontent.com/immortalwrt/immortalwrt/master/package/network/config/firewall/patches/fullconenat.patch
wget -qO- https://raw.githubusercontent.com/msylgj/R2S-R4S-OpenWrt/21.02/PATCHES/001-fix-firewall-flock.patch | patch -p1
# Patch LuCI 以增添FullCone开关
patch -p1 < ../PATCH/firewall/luci-app-firewall_add_fullcone.patch
# FullCone 相关组件
svn export https://github.com/coolsnowwolf/lede/trunk/package/network/services/fullconenat package/lean/openwrt-fullconenat
pushd package/lean/openwrt-fullconenat
patch -p2 <../../../../PATCH/firewall/fullcone6.patch
popd
# 修复由于shadow-utils引起的管理页面修改密码功能失效的问题
pushd feeds/luci
  patch -p1 < ../../../PATCH/let-luci-use-busybox-passwd.patch
popd

### 3. 更新部分软件包 ###
mkdir -p ./package/new/ ./package/lean/
# 更换 golang 版本
rm -rf ./feeds/packages/lang/golang
svn export https://github.com/openwrt/packages/trunk/lang/golang                       feeds/packages/lang/golang
# AutoCore & coremark
rm -rf ./feeds/packages/utils/coremark
cp -a Immortalwrt_SRC/package/emortal/autocore package/lean/autocore
sed -i 's/"getTempInfo" /"getTempInfo", "getCPUBench", "getCPUUsage" /g' package/lean/autocore/files/generic/luci-mod-status-autocore.json
svn export https://github.com/immortalwrt/packages/trunk/utils/coremark                feeds/packages/utils/coremark
# AutoReboot定时重启
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-autoreboot package/lean/luci-app-autoreboot
# ipv6-helper
svn export https://github.com/coolsnowwolf/lede/trunk/package/lean/ipv6-helper         package/lean/ipv6-helper
# 清理内存
svn export https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-ramfree    package/lean/luci-app-ramfree
# 流量监视
git clone -b master --depth=1 https://github.com/brvphoenix/wrtbwmon                   package/new/wrtbwmon
git clone -b master --depth=1 https://github.com/brvphoenix/luci-app-wrtbwmon          package/new/luci-app-wrtbwmon
# Haproxy
rm -rf ./feeds/packages/net/haproxy
svn export https://github.com/openwrt/packages/trunk/net/haproxy                       feeds/packages/net/haproxy
pushd feeds/packages
  wget -qO - https://github.com/QiuSimons/packages/commit/7ffbfbe01e01866947d5a79aeb2803c7c7634c0a.patch | patch -p1
popd
# socat
svn export https://github.com/Lienol/openwrt-package/trunk/luci-app-socat              package/new/luci-app-socat
# SSRP依赖
rm -rf ./feeds/packages/net/xray-core ./feeds/packages/net/kcptun ./feeds/packages/net/shadowsocks-libev ./feeds/packages/net/proxychains-ng ./feeds/packages/net/shadowsocks-rust
svn export https://github.com/coolsnowwolf/lede/trunk/package/lean/srelay              package/lean/srelay
svn export https://github.com/coolsnowwolf/packages/trunk/net/redsocks2                package/lean/redsocks2
svn export https://github.com/coolsnowwolf/packages/trunk/net/shadowsocks-libev        package/lean/shadowsocks-libev
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/brook                   package/new/brook
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/dns2socks               package/lean/dns2socks
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/ipt2socks               package/lean/ipt2socks
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/microsocks              package/lean/microsocks
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/pdnsd-alt               package/lean/pdnsd
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/ssocks                  package/new/ssocks
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/tcping                  package/lean/tcping
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/trojan                  package/lean/trojan
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/trojan-go               package/lean/trojan-go
svn export https://github.com/xiaorouji/openwrt-passwall/trunk/trojan-plus             package/new/trojan-plus
svn export https://github.com/immortalwrt/packages/trunk/net/proxychains-ng            package/lean/proxychains-ng
svn export https://github.com/immortalwrt/packages/trunk/net/kcptun                    feeds/packages/net/kcptun
git clone -b master --depth=1 https://github.com/fw876/helloworld                      SSRP_SRC
mv SSRP_SRC/dns2tcp                                                                    package/new/dns2tcp
mv SSRP_SRC/hysteria                                                                   package/new/hysteria
mv SSRP_SRC/naiveproxy                                                                 package/lean/naiveproxy
mv SSRP_SRC/sagernet-core                                                              package/new/sagernet-core
mv SSRP_SRC/shadowsocksr-libev                                                         package/lean/shadowsocksr-libev
mv SSRP_SRC/simple-obfs                                                                package/lean/simple-obfs
mv SSRP_SRC/v2ray-core                                                                 package/lean/v2ray-core
mv SSRP_SRC/v2ray-geodata                                                              package/new/v2ray-geodata
mv SSRP_SRC/v2ray-plugin                                                               package/lean/v2ray-plugin
mv SSRP_SRC/v2raya                                                                     package/new/v2raya
mv SSRP_SRC/xray-core                                                                  package/lean/xray-core
mv SSRP_SRC/xray-plugin                                                                package/lean/xray-plugin
mv SSRP_SRC/luci-app-ssr-plus                                                          package/lean/luci-app-ssr-plus
mv SSRP_SRC/shadowsocks-rust                                                           feeds/packages/net/shadowsocks-rust
ln -sf ../../../feeds/packages/net/kcptun                                            ./package/feeds/packages/kcptun
ln -sf ../../../feeds/packages/net/shadowsocks-rust                                  ./package/feeds/packages/shadowsocks-rust
rm -rf SSRP_SRC
# SSRP Patch
pushd package/lean
  patch -p1 < ../../../PATCH/0005-add-QiuSimons-Chnroute-to-chnroute-url.patch
popd
# OpenClash
wget -qO - https://github.com/openwrt/openwrt/commit/efc8aff62cb244583a14c30f8d099103b75ced1d.patch | patch -p1
git clone -b master --depth=1 https://github.com/vernesong/OpenClash                   package/new/luci-app-openclash
# ucode
svn export https://github.com/openwrt/openwrt/trunk/package/utils/ucode              package/utils/ucode
# 额外DDNS脚本
sed -i '/boot()/,+2d' feeds/packages/net/ddns-scripts/files/etc/init.d/ddns
svn export https://github.com/kiddin9/openwrt-packages/trunk/ddns-scripts-aliyun     package/lean/ddns-scripts_dnspod
svn export https://github.com/kiddin9/openwrt-packages/trunk/ddns-scripts-dnspod     package/lean/ddns-scripts_aliyun
# UPnP 
rm -rf ./feeds/packages/net/miniupnpd 
svn export https://github.com/openwrt/packages/trunk/net/miniupnpd                   feeds/packages/net/miniupnpd
# Zerotier 
rm -rf ./feeds/packages/net/zerotier 
svn export https://github.com/openwrt/packages/trunk/net/zerotier                    feeds/packages/net/zerotier
svn export https://github.com/immortalwrt/luci/trunk/applications/luci-app-zerotier  feeds/luci/applications/luci-app-zerotier
ln -sf ../../../feeds/luci/applications/luci-app-zerotier                          ./package/feeds/luci/luci-app-zerotier
rm -rf ./feeds/packages/net/zerotier/files/etc/init.d/zerotier
# CPU限制
svn export https://github.com/immortalwrt/packages/trunk/utils/cpulimit              feeds/packages/utils/cpulimit
ln -sf ../../../feeds/packages/utils/cpulimit                                      ./package/feeds/packages/cpulimit
svn export https://github.com/QiuSimons/OpenWrt-Add/trunk/luci-app-cpulimit          package/lean/luci-app-cpulimit
cp -f ../PATCH/luci-app-cpulimit_config/cpulimit                                   ./package/lean/luci-app-cpulimit/root/etc/config/cpulimit
# CPU主频
if [ "${MYOPENWRTTARGET}" = 'R2S' ] ; then
  svn export https://github.com/immortalwrt/luci/trunk/applications/luci-app-cpufreq feeds/luci/applications/luci-app-cpufreq
  ln -sf ../../../feeds/luci/applications/luci-app-cpufreq                         ./package/feeds/luci/luci-app-cpufreq
fi
# 翻译及部分功能优化
svn export https://github.com/QiuSimons/OpenWrt-Add/trunk/addition-trans-zh          package/lean/lean-translate
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
## vermagic
#LATESTRELEASE=$(curl -sSf -H 'Accept: application/vnd.github.v3+json' https://api.github.com/repos/openwrt/openwrt/tags | jq '.[].name' | grep -v 'rc' | grep 'v21' | sort -r | head -n 1)
#LATESTRELEASE=${LATESTRELEASE:2:-1}
#case ${MYOPENWRTTARGET} in
#  R2S)
#    wget https://downloads.openwrt.org/releases/${LATESTRELEASE}/targets/rockchip/armv8/packages/Packages.gz
#    ;;
#  x86)
#    wget https://downloads.openwrt.org/releases/${LATESTRELEASE}/targets/x86/64/packages/Packages.gz
#    ;;
#esac
#zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' > .vermagic
#sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
#rm -f Packages.gz
# 最大连接
sed -i 's/16384/65535/g' package/kernel/linux/files/sysctl-nf-conntrack.conf
echo 'net.netfilter.nf_conntrack_helper = 1' >> package/kernel/linux/files/sysctl-nf-conntrack.conf
# crypto相关
if [ "${MYOPENWRTTARGET}" = 'x86' ] ; then
  echo 'CONFIG_CRYPTO_AES_NI_INTEL=y' >> ./target/linux/x86/64/config-5.4
fi
# 删除已有配置
rm -rf .config
# 删除多余的代码库
rm -rf Immortalwrt_SRC/
# 删除.svn目录
find ./ -type d -name '.svn' -print0 | xargs -0 -s1024 /bin/rm -rf
unalias wget
