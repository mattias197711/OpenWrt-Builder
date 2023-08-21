#!/bin/bash
alias wget="$(which wget) --https-only --retry-connrefused"

# 如果没有环境变量或无效，则默认构建R2S版本
[ -f "../SEED/${MYOPENWRTTARGET}.config.seed" ] || MYOPENWRTTARGET='R2S'
echo "==> Now building: ${MYOPENWRTTARGET}"

set -e
set -x
### 1. 准备工作 ###
# 使用O2级别的优化
sed -i 's/ -Os / -O2 /g' include/target.mk
# 更新feed
./scripts/feeds update -a
./scripts/feeds install -a
# 获取额外代码
git clone -b master --depth 1 https://github.com/immortalwrt/immortalwrt.git      Immortalwrt_SRC/       && sleep 3
git clone -b master --depth 1 https://github.com/immortalwrt/packages.git         Immortalwrt_PACKAGES/  && sleep 3
git clone -b master --depth 1 https://github.com/immortalwrt/luci.git             Immortalwrt_LUCI/      && sleep 3
git clone -b master --depth 1 https://github.com/coolsnowwolf/lede.git            Coolsnowwolf_SRC/      && sleep 3
git clone -b master --depth 1 https://github.com/coolsnowwolf/packages.git        Coolsnowwolf_PACKAGES/ && sleep 3
git clone -b master --depth 1 https://github.com/coolsnowwolf/luci.git            Coolsnowwolf_LUCI/     && sleep 3
git clone -b 21.02  --depth 1 https://github.com/Lienol/openwrt.git               Lienol_SRC/            && sleep 3
git clone -b main   --depth 1 https://github.com/Lienol/openwrt-package.git       Lienol_PACKAGES/       && sleep 3
git clone -b main   --depth 1 https://github.com/jjm2473/openwrt-third.git        Jjm2473_PACKAGES/      && sleep 3
git clone -b master --depth 1 https://github.com/QiuSimons/OpenWrt-Add            QiuSimons_ADD/         && sleep 3
git clone -b master --depth 1 https://github.com/wongsyrone/lede-1.git            Wongsyrone_SRC/        && sleep 3
git clone -b main   --depth 1 https://github.com/openwrt/openwrt.git              Openwrt_SRC_MAIN/      && sleep 3
git clone -b master --depth 1 https://github.com/openwrt/packages.git             Openwrt_PACKAGES_MSTR/ && sleep 3
git clone -b master --depth 1 https://github.com/fw876/helloworld.git             SSRP_SRC/              && sleep 3
pushd SSRP_SRC
  patch -p1 < ../../PATCH/0005-add-QiuSimons-Chnroute-to-chnroute-url.patch
popd
git clone -b packages --depth 1 https://github.com/xiaorouji/openwrt-passwall.git Passwall_SRC/          && sleep 3
git clone -b dev      --depth 1 https://github.com/vernesong/OpenClash.git        OpenClash_SRC/         && sleep 3
# something called magic
mv -f Immortalwrt_SRC/include/download.mk include/download.mk
mv -f Immortalwrt_SRC/scripts/download.pl scripts/download.pl
sed -i '/\.cn\//d'    scripts/download.pl
sed -i '/aliyun/d'    scripts/download.pl
sed -i '/fastgit/d'   scripts/download.pl
sed -i '/sevencdn/d'  scripts/download.pl
sed -i '/tencent/d'   scripts/download.pl
chmod +x scripts/download.pl

### 2. 必要的Patch ###
mkdir -p package/new/ package/lean/
mv -f ../PATCH/backport/290-remove-kconfig-CONFIG_I8K.patch target/linux/generic/hack-5.10/290-remove-kconfig-CONFIG_I8K.patch
# R8125 网卡驱动
mv Coolsnowwolf_SRC/package/lean/r8125  package/new/r8125
# R8152 网卡驱动
mv Immortalwrt_SRC/package/kernel/r8152 package/new/r8152
# R8168 网卡驱动
git clone -b master --depth 1 https://github.com/BROBIRD/openwrt-r8168.git package/new/r8168
# 根据体系调整
case ${MYOPENWRTTARGET} in
  R2S)
    # 显示 ARM64 CPU 型号
    mv -f Immortalwrt_SRC/target/linux/generic/hack-5.15/312-arm64-cpuinfo-Add-model-name-in-proc-cpuinfo-for-64bit-ta.patch target/linux/generic/hack-5.10/312-arm64-cpuinfo-Add-model-name-in-proc-cpuinfo-for-64bit-ta.patch
    # R8168 网卡驱动
    patch -p1 < ../PATCH/r8168/r8168-fix_LAN_led-for_r4s-from_TL.patch
    # 更换 Target
    sed -i 's,-mcpu=generic,-mcpu=cortex-a53+crypto,g' include/target.mk
    mv -f ../PATCH/rockchip-5.10/* target/linux/rockchip/patches-5.10/
    # 其他内核配置
    echo '
# CONFIG_SHORTCUT_FE is not set
# CONFIG_PHY_ROCKCHIP_NANENG_COMBO_PHY is not set
# CONFIG_PHY_ROCKCHIP_SNPS_PCIE3 is not set
' >> target/linux/rockchip/armv8/config-5.10
    ;;
  x86)
    # Intel GPU 修正
    rm -rf  package/kernel/linux/modules/video.mk
    wget -P package/kernel/linux/modules/ https://raw.githubusercontent.com/coolsnowwolf/lede/master/package/kernel/linux/modules/video.mk
    sed -i '/nouveau\.ko/d'                                                      package/kernel/linux/modules/video.mk
    sed -i 's,CONFIG_DRM_I915_CAPTURE_ERROR ,CONFIG_DRM_I915_CAPTURE_ERROR=n ,g' package/kernel/linux/modules/video.mk
    # config 变更
    rm -rf  target/linux/x86/64/config-5.10
    wget -P target/linux/x86/64/ https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/x86/64/config-5.10
    # igc-backport
    mkdir -p                       target/linux/x86/files-5.10/drivers/net/ethernet/intel/igc/
    mv ../PATCH/intel-igc-driver/* target/linux/x86/files-5.10/drivers/net/ethernet/intel/igc/
    # 系统型号字符串
    echo '# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.

if grep -q "Default string" /tmp/sysinfo/model 2>/dev/null; then
    echo "Compatible PC" > /tmp/sysinfo/model
fi

exit 0
'> package/base-files/files/etc/rc.local
    ;;
esac
# 默认开启 irqbalance
sed -i "s/enabled '0'/enabled '1'/g" feeds/packages/utils/irqbalance/files/irqbalance.config
# grub2强制使用O2级别优化
wget -qO - https://github.com/openwrt/openwrt/commit/66fa3431125eca21f1b06878f508d5c079b7f76c.patch | patch -p1
# Patch Kernel 以解决FullCone冲突
mv -f Coolsnowwolf_SRC/target/linux/generic/hack-5.10/952-net-conntrack-events-support-multiple-registrant.patch target/linux/generic/hack-5.10/952-net-conntrack-events-support-multiple-registrant.patch
mv -f Coolsnowwolf_SRC/target/linux/generic/hack-5.10/982-add-bcm-fullconenat-support.patch                      target/linux/generic/hack-5.10/982-add-bcm-fullconenat-support.patch
# Patch FireWall 以增添FullCone功能
# FW4
rm -rf package/libs/libnftnl package/network/utils/nftables package/network/config/firewall4
mv Wongsyrone_SRC/package/libs/libnftnl                                package/libs/libnftnl
mv Wongsyrone_SRC/package/network/utils/nftables                       package/network/utils/nftables
mv Immortalwrt_SRC/package/network/config/firewall4                    package/network/config/firewall4
mv -f ../PATCH/firewall/990-unconditionally-allow-ct-status-dnat.patch package/network/config/firewall4/patches/990-unconditionally-allow-ct-status-dnat.patch
# FW3
mkdir -p package/network/config/firewall/patches/
wget  -P package/network/config/firewall/patches/ https://raw.githubusercontent.com/immortalwrt/immortalwrt/openwrt-21.02/package/network/config/firewall/patches/100-fullconenat.patch
mv -f Coolsnowwolf_SRC/package/network/config/firewall/patches/101-bcm-fullconenat.patch package/network/config/firewall/patches/101-bcm-fullconenat.patch
# iptables
mv -f Coolsnowwolf_SRC/package/network/utils/iptables/patches/900-bcm-fullconenat.patch  package/network/utils/iptables/patches/900-bcm-fullconenat.patch
# network
echo 'net.netfilter.nf_conntrack_helper = 1' >> package/kernel/linux/files/sysctl-nf-conntrack.conf
wget -qO - https://github.com/openwrt/openwrt/commit/bbf39d07fd43977f55a4b9ba9e384cdf8a0d2b50.patch | patch -p1
# Patch LuCI 以增添FullCone开关
pushd feeds/luci
  wget -qO- https://github.com/openwrt/luci/commit/471182b2f0eb9f4ce1683392762fa490d3d32e51.patch | patch -p1
popd
# FullCone 相关组件
git clone --depth 1 https://github.com/fullcone-nat-nftables/nft-fullcone.git package/new/nft-fullcone
mv Lienol_SRC/package/network/fullconenat package/lean/openwrt-fullconenat
# mbedTLS
rm -rf package/libs/mbedtls
mv Immortalwrt_SRC/package/libs/mbedtls package/libs/mbedtls
# fstool patch
wget -qO - https://github.com/coolsnowwolf/lede/commit/8a4db762497b79cac91df5e777089448a2a71f7c.patch | patch -p1
# 修复由于 shadow-utils 引起的管理页面修改密码功能失效的问题
pushd feeds/luci
  patch -p1 < ../../../PATCH/0002-let-luci-use-busybox-passwd.patch
popd

### 3. 更新部分软件包 ###
# dwarves
rm -rf tools/dwarves
mv Openwrt_SRC_MAIN/tools/dwarves tools/dwarves
# dnsmasq
rm -rf package/network/services/dnsmasq
mv Openwrt_SRC_MAIN/package/network/services/dnsmasq package/network/services/dnsmasq
# 更换 golang 版本
rm -rf feeds/packages/lang/golang
mv Openwrt_PACKAGES_MSTR/lang/golang        feeds/packages/lang/golang
# 回滚 go 1.20.x
pushd feeds/packages
  wget -qO - https://github.com/openwrt/packages/commit/a80af7e44347c50c745967c17f20c89385f1ea08.patch | patch -R -p1
popd
# AutoCore & coremark
rm -rf feeds/packages/utils/coremark
mv Immortalwrt_PACKAGES/utils/coremark      feeds/packages/utils/coremark
mv Immortalwrt_SRC/package/emortal/autocore package/lean/autocore
pushd package/lean
  patch -p1 < ../../../PATCH/autocore/0003-some-fix.patch
popd
pushd feeds/luci
  patch -p1 < ../../../PATCH/autocore/0004-luci-base-add-fullcone-flag.patch
popd
# AutoReboot定时重启
mv Coolsnowwolf_LUCI/applications/luci-app-autoreboot package/lean/luci-app-autoreboot
sed -i '/LUCI_DEPENDS/d' package/lean/luci-app-autoreboot/Makefile
# ipv6-helper
mv Coolsnowwolf_SRC/package/lean/ipv6-helper          package/lean/ipv6-helper
# 清理内存
mv Coolsnowwolf_LUCI/applications/luci-app-ramfree    package/lean/luci-app-ramfree
# 流量监视
git clone -b master --depth 1 https://github.com/brvphoenix/wrtbwmon.git          package/new/wrtbwmon
git clone -b master --depth 1 https://github.com/brvphoenix/luci-app-wrtbwmon.git package/new/luci-app-wrtbwmon
# Nginx
sed -i 's/client_max_body_size 128M/client_max_body_size 2048M/g'                 feeds/packages/net/nginx-util/files/uci.conf.template
# uwsgi
sed -i 's,procd_set_param stderr 1,procd_set_param stderr 0,g'                    feeds/packages/net/uwsgi/files/uwsgi.init
# Haproxy
rm -rf feeds/packages/net/haproxy
mv Openwrt_PACKAGES_MSTR/net/haproxy feeds/packages/net/haproxy
pushd feeds/packages
  wget -qO - https://github.com/openwrt/packages/commit/a09cbcdf20dc4472eb4f464deb6921a6b9f366c8.patch | patch -p1
popd
# luci-app-irqbalance
mv QiuSimons_ADD/luci-app-irqbalance package/new/luci-app-irqbalance
# socat
mv Lienol_PACKAGES/luci-app-socat    package/new/luci-app-socat
sed -i '/socat\.config/d'            feeds/packages/net/socat/Makefile
# SSRP依赖
rm -rf feeds/packages/net/xray-core feeds/packages/net/kcptun feeds/packages/net/shadowsocks-libev feeds/packages/net/proxychains-ng feeds/packages/net/shadowsocks-rust feeds/packages/net/v2raya
mv Coolsnowwolf_SRC/package/lean/srelay                   package/lean/srelay
mv Coolsnowwolf_PACKAGES/net/shadowsocks-libev            package/lean/shadowsocks-libev
mv Passwall_SRC/brook                                     package/new/brook
mv Passwall_SRC/dns2socks                                 package/lean/dns2socks
mv Passwall_SRC/ipt2socks                                 package/lean/ipt2socks
mv Passwall_SRC/microsocks                                package/lean/microsocks
mv Passwall_SRC/pdnsd-alt                                 package/lean/pdnsd
mv Passwall_SRC/ssocks                                    package/new/ssocks
mv Passwall_SRC/trojan-go                                 package/lean/trojan-go
mv Passwall_SRC/trojan-plus                               package/new/trojan-plus
mv Immortalwrt_PACKAGES/net/kcptun                        feeds/packages/net/kcptun
mv SSRP_SRC/chinadns-ng                                   package/new/chinadns-ng
mv SSRP_SRC/dns2tcp                                       package/new/dns2tcp
mv SSRP_SRC/gn                                            package/new/gn
mv SSRP_SRC/hysteria                                      package/new/hysteria
mv SSRP_SRC/lua-neturl                                    package/new/lua-neturl
mv SSRP_SRC/naiveproxy                                    package/lean/naiveproxy
mv SSRP_SRC/redsocks2                                     package/lean/redsocks2
mv SSRP_SRC/shadowsocks-rust                              feeds/packages/net/shadowsocks-rust
mv SSRP_SRC/shadowsocksr-libev                            package/lean/shadowsocksr-libev
mv SSRP_SRC/simple-obfs                                   package/lean/simple-obfs
mv SSRP_SRC/tcping                                        package/lean/tcping
mv SSRP_SRC/trojan                                        package/lean/trojan
mv SSRP_SRC/tuic-client                                   package/new/tuic-client
mv SSRP_SRC/v2ray-core                                    package/lean/v2ray-core
mv SSRP_SRC/v2ray-geodata                                 package/new/v2ray-geodata
mv SSRP_SRC/v2ray-plugin                                  package/lean/v2ray-plugin
mv SSRP_SRC/xray-core                                     package/lean/xray-core
mv SSRP_SRC/xray-plugin                                   package/lean/xray-plugin
mv SSRP_SRC/luci-app-ssr-plus                             package/lean/luci-app-ssr-plus
mv Openwrt_PACKAGES_MSTR/net/v2raya                       feeds/packages/net/v2raya
ln -sf ../../../feeds/packages/net/v2raya                 package/feeds/packages/v2raya
ln -sf ../../../feeds/packages/net/kcptun                 package/feeds/packages/kcptun
ln -sf ../../../feeds/packages/net/shadowsocks-rust       package/feeds/packages/shadowsocks-rust
# OpenClash
mv OpenClash_SRC/luci-app-openclash                       package/new/luci-app-openclash
# 额外DDNS脚本
sed -i '/boot()/,+2d' feeds/packages/net/ddns-scripts/files/etc/init.d/ddns
mv Jjm2473_PACKAGES/ddns-scripts_aliyun                   package/lean/ddns-scripts_aliyun
# Zerotier
rm -rf feeds/packages/net/zerotier
mv Immortalwrt_PACKAGES/net/zerotier                      feeds/packages/net/zerotier
mv Immortalwrt_LUCI/applications/luci-app-zerotier        feeds/luci/applications/luci-app-zerotier
ln -sf ../../../feeds/luci/applications/luci-app-zerotier package/feeds/luci/luci-app-zerotier
rm -rf feeds/packages/net/zerotier/files/etc/init.d/zerotier
# CPU 限制
mv QiuSimons_ADD/luci-app-cpulimit            package/lean/luci-app-cpulimit
mv Immortalwrt_PACKAGES/utils/cpulimit        feeds/packages/utils/cpulimit
ln -sf ../../../feeds/packages/utils/cpulimit package/feeds/packages/cpulimit
# CPU 主频
if [ "${MYOPENWRTTARGET}" = 'R2S' ] ; then
  mv Immortalwrt_LUCI/applications/luci-app-cpufreq        feeds/luci/applications/luci-app-cpufreq
  ln -sf ../../../feeds/luci/applications/luci-app-cpufreq package/feeds/luci/luci-app-cpufreq
fi
# 翻译及部分功能优化
mv QiuSimons_ADD/addition-trans-zh                                    package/lean/lean-translate
sed -i 's,iptables-mod-fullconenat,iptables-nft +kmod-nft-fullcone,g' package/lean/lean-translate/Makefile
if [ "${MYOPENWRTTARGET}" != 'R2S' ] ; then
  sed -i '/openssl\.cnf/d' ../PATCH/addition-trans-zh/files/zzz-default-settings
  sed -i '/upnp/Id'        ../PATCH/addition-trans-zh/files/zzz-default-settings
fi
mv -f ../PATCH/addition-trans-zh/files/zzz-default-settings package/lean/lean-translate/files/zzz-default-settings
# 给root用户添加vim和screen的配置文件
mkdir -p                   package/base-files/files/root/
mv -f ../PRECONFS/vimrc    package/base-files/files/root/.vimrc
mv -f ../PRECONFS/screenrc package/base-files/files/root/.screenrc

### 4. 最后的收尾工作 ###
case ${MYOPENWRTTARGET} in
  R2S)
    cat ../SEED/extra.cfg >> target/linux/generic/config-5.10
    ;;
  x86)
    sed '/RK3328/d;/ROCKCHIP/d' ../SEED/extra.cfg >> target/linux/generic/config-5.10
    ;;
esac
# vermagic
LATESTRELEASE=$(curl -sSf -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' https://api.github.com/repos/openwrt/openwrt/tags | jq '.[].name' -r | grep -v 'rc' | grep 'v22' | sort -r | head -n 1)
LATESTRELEASE=${LATESTRELEASE:1}
case ${MYOPENWRTTARGET} in
  R2S)
    wget "https://downloads.openwrt.org/releases/${LATESTRELEASE}/targets/rockchip/armv8/packages/Packages.gz"
    ;;
  x86)
    wget "https://downloads.openwrt.org/releases/${LATESTRELEASE}/targets/x86/64/packages/Packages.gz"
    ;;
esac
zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' > .vermagic
sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
rm -f Packages.gz
# nftables 额外规则
mkdir -p                        files/usr/share/nftables.d/chain-pre/forward/
mv ../PATCH/nftables/10-ios.nft files/usr/share/nftables.d/chain-pre/forward/10-ios.nft
# 删除已有配置
rm -rf .config
# 删除多余的代码库
rm -rf Immortalwrt_SRC/ Immortalwrt_PACKAGES/ Immortalwrt_LUCI/ Coolsnowwolf_SRC/ Coolsnowwolf_PACKAGES/ Coolsnowwolf_LUCI/ Lienol_SRC/ Lienol_PACKAGES/ Jjm2473_PACKAGES/ QiuSimons_ADD/ Wongsyrone_SRC/ Openwrt_SRC_MAIN/ Openwrt_PACKAGES_MSTR/ SSRP_SRC/ Passwall_SRC/ OpenClash_SRC/
unalias wget
sync
