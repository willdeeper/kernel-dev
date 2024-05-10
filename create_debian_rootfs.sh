#!/usr/bin/env bash
# 只在 x86-64 测试通过
FS=/mnt/ext4
PWD=$(pwd)
if [[ "`id -u`" -ne 0 ]]; then
    echo "Switching from `id -un` to root"
    exec sudo "$0"
    exit 99
fi
apt install debootstrap -y
if [[ "$(mount | grep $FS)" != "" ]]; then
    umount $FS
fi

# create rootfs
# 10G
dd if=/dev/zero of=rootfs.ext4 bs=1M count=10480
mkfs.ext4 rootfs.ext4

# create efi
dd if=/dev/zero of=efi.fat32 bs=1M count=1024
mkfs.vfat -F 32 efi.fat32

mkdir -p $FS
mount -o loop rootfs.ext4 $FS

# libc 和 kernel（kernel加新syscall，需要glibc支持才行）可能有版本依赖关系，sid保不准哪一天和自己的内核不兼容。
# 除非高版本内核删除了一些驱动，否则高版本内核一直兼容低libc
# 所以用debian 12制作 rootfs，kernel版本随便升级。等用多少年之后再升级到最新debian stable，循环往复
# debootstrap --arch amd64 sid $FS https://mirrors.tuna.tsinghua.edu.cn/debian
debootstrap --components=main,contrib,non-free-firmware --arch amd64 bookworm $FS https://mirrors.tuna.tsinghua.edu.cn/debian

cp -rf debianrootfs/* $FS

cd $FS
# 创建efi文件夹，为之后efi分区挂载做准备
mkdir -p boot/efi

# copy linuz, System.map .config, initrd into /boot

# install grub on /boot and /boot/efi


mount -t proc /proc proc/
mount --rbind /sys sys/
mount --rbind /dev dev/
mount "$PWD/efi.fat32" boot/efi
# https://unix.stackexchange.com/questions/362870/unmount-sys-fs-cgroup-systemd-after-chroot-without-rebooting
mount --make-rslave sys/
mount --make-rslave dev/
chroot $FS /bin/bash /root/.rootfs_init.sh
# make umount happy
cd ../
umount -R $FS
cd $PWD
# 最后生成 bootable image
ROOTPATH_TMP="$(mktemp -d)"
genimage --rootpath "$ROOTPATH_TMP" --inputpath "$PWD" --outputpath "$PWD" --config ./scripts/genimage-efi.cfg

