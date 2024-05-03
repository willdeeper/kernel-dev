#!/usr/bin/env bash
# setup in rootfs

PASSWD=123456
echo -e "$PASSWD\n$PASSWD\n" | passwd root
exit