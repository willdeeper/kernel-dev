#!/usr/bin/env bash
set -ex
FS=/mnt/ext4

apt install debootstrap -y
# create rootfs
# 1G
umount $FS
dd if=/dev/zero of=rootfs.ext4 bs=1M count=1024
mkfs.ext4 rootfs.ext4
mkdir -p $FS
mount -o loop rootfs.ext4 $FS
debootstrap --arch amd64 sid $FS
cp -rf debianrootfs/* $FS
umount $FS
