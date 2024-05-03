#!/usr/bin/env bash
# setup in rootfs

PASSWD=123456

apt update
echo -e "$PASSWD\n$PASSWD\n" | passwd root
exit