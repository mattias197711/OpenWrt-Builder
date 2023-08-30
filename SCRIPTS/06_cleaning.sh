#!/bin/bash
MYWORKDIR=$(mktemp -d)
case ${MYOPENWRTTARGET} in
  R2S)
    mv -a *squashfs* *manifest* ${MYWORKDIR}/
    ;;
  x86)
    mv -f *combined* *manifest* ${MYWORKDIR}/
    ;;
esac
rm -rf ./*
pushd ${MYWORKDIR}
  gzip -d *.gz
  gzip --best --keep *.img
  sha256sum openwrt* | tee sha256_$(date "+%Y%m%d").hash
  md5sum    openwrt* | tee    md5_$(date "+%Y%m%d").hash
  rm -f *.img
popd
mv -f ${MYWORKDIR}/* ./
rmdir ${MYWORKDIR}
exit 0
