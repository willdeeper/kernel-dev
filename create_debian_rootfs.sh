#!/usr/bin/env bash

set -x
FS=/mnt/ext4

apt install debootstrap -y
if [[ "$(mount | grep $FS)" != "" ]]; then
    umount $FS
fi
# create rootfs
# 10G
dd if=/dev/zero of=rootfs.ext4 bs=1M count=10480
mkfs.ext4 rootfs.ext4
mkdir -p $FS
mount -o loop rootfs.ext4 $FS
debootstrap --arch amd64 sid $FS https://mirrors.tuna.tsinghua.edu.cn/debian
cp -rf debianrootfs/* $FS
cd $FS
mount -t proc /proc proc/
mount --rbind /sys sys/
mount --rbind /dev dev/
# https://unix.stackexchange.com/questions/362870/unmount-sys-fs-cgroup-systemd-after-chroot-without-rebooting
mount --make-rslave sys/
mount --make-rslave dev/
chroot $FS /bin/bash /root/rootfs_init.sh
# make umount happy
cd ../
umount -R $FS
