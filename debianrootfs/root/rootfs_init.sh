#!/usr/bin/env bash
# setup in rootfs

PASSWD=123456

apt update
apt install wget curl libbpf-dev libssl-dev build-essential -y
echo -e "$PASSWD\n$PASSWD\n" | passwd root
exit