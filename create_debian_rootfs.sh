#!/usr/bin/env bash
set -ex
FS=/mnt/ext4/

apt install debootstrap -y
# create rootfs
# 1G
if [[ "$(mount | grep $FS)" != "" ]]; then
    umount $FS
fi
dd if=/dev/zero of=rootfs.ext4 bs=1M count=1024
mkfs.ext4 rootfs.ext4
mkdir -p $FS
mount -o loop rootfs.ext4 $FS
debootstrap --arch amd64 sid $FS https://mirrors.tuna.tsinghua.edu.cn/debian
cp -rf debianrootfs/* $FS

chroot $FS
# setup in rootfs
printf "123456\n123456" | passwd root -R /mnt/ext4
exit
umount $FS