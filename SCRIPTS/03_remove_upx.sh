#!/bin/bash
# [CTCGFW]immortalwrt
# Use it under GPLv3, please.
# --------------------------------------------------------
# Remove upx commands
MAKEFILE_FILES=$({ find package | grep 'Makefile' | sed '/Makefile./d' ; } 2>/dev/null)
for a in ${MAKEFILE_FILES}
do
	grep -q 'upx' "$a" 2>/dev/null && sed -i '/upx/d' "$a"
done
exit 0
