#!/usr/bin/env bash
# setup in rootfs

PASSWD=123456

apt update
apt install wget curl libbpf-dev libssl-dev build-essential clang git bpftool linux-perf pkg-config tcpdump llvm \
    automake m4 autoconf libpcap-dev openssh-server libelf libc6-dev-i386 -y
echo -e "$PASSWD\n$PASSWD\n" | passwd root
exit