#!/bin/bash
MYWORKDIR=$(mktemp -d)
case ${MYOPENWRTTARGET} in
  R2S)
    mv -f *squashfs* *manifest* ${MYWORKDIR}/
    ;;
  x86)
    mv -f *combined* *manifest* ${MYWORKDIR}/
    ;;
esac
rm -rf ./*
pushd ${MYWORKDIR} > /dev/null
  gzip -d *.gz
  gzip --best --keep *.img
  echo && echo
  sha256sum openwrt* | tee sha256_$(date "+%Y%m%d").hash
  md5sum    openwrt* | tee    md5_$(date "+%Y%m%d").hash
  echo && echo
  rm -f *.img
popd  > /dev/null
mv -f ${MYWORKDIR}/* ./
rmdir ${MYWORKDIR}
exit 0
