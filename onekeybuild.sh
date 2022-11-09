#!/bin/bash
set -e

echo "Start            $(date)" | tee buildtime.txt
git clone --single-branch -b master https://github.com/KaneGreen/OpenWrt-builder_R2S-x86.git
cd OpenWrt-builder_R2S-x86

echo "Clone Openwrt    $(date)" | tee -a ../buildtime.txt
cp -f ./SCRIPTS/01_get_ready.sh ./01_get_ready.sh
/bin/bash ./01_get_ready.sh
cd openwrt

echo "Prepare Package  $(date)" | tee -a ../../buildtime.txt
cp -f ../SCRIPTS/*.sh ./
/bin/bash ./02_prepare_package.sh

echo "Modification     $(date)" | tee -a ../../buildtime.txt
/bin/bash ./03_convert_translation.sh
/bin/bash ./05_create_acl_for_luci.sh -a

echo "Make Defconfig   $(date)" | tee -a ../../buildtime.txt
[ -f "../SEED/${MYOPENWRTTARGET}.config.seed" ] || MYOPENWRTTARGET='R2S'
cp -f "../SEED/${MYOPENWRTTARGET}.config.seed" .config
cat ../SEED/crypto.seed >> .config
cat ../SEED/more.seed >> .config
make defconfig

echo "Make Download    $(date)" | tee -a ../../buildtime.txt
make download -j8

echo "Make Toolchain   $(date)" | tee -a ../../buildtime.txt
[[ ${MYMAKENUMBER} =~ ^[0-9]+$ ]] && MYMAKENUMBER=4
make toolchain/install -j${MYMAKENUMBER}

echo "Compile Openwrt  $(date)" | tee -a ../../buildtime.txt
make -j${MYMAKENUMBER} V=w

cd ../..
echo "Finished         $(date)" | tee -a buildtime.txt

