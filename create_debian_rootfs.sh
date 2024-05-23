#!/usr/bin/env bash
# 只在 x86-64 测试通过
set -ex
FS=/mnt/ext4
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [[ "`id -u`" -ne 0 ]]; then
    echo "Switching from `id -un` to root"
    exec sudo "$0"
    exit 99
fi
apt install debootstrap -y
if [[ "$(mount | grep $FS)" != "" ]]; then
    umount -l  $FS
fi
ARCH=$(dpkg --print-architecture)
# create rootfs
# 10G
dd if=/dev/zero of=rootfs.ext4 bs=1M count=10480
mkfs.ext4 rootfs.ext4

# create efi
# 参考archlinux安装文档
# https://wiki.archlinux.org/title/Installation_guide#Format_the_partitions
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

# 如何生成vmlinuz?
# https://www.linfo.org/vmlinuz.html
# https://unix.stackexchange.com/questions/38773/vmlinuz-and-initrd-not-found-after-building-the-kernel
# https://tldp.org/LDP/lame/LAME/linux-admin-made-easy/kernel-custom.html

# copy vmlinuz, System.map .config, initrd into /boot
install_kernel() {
    # https://packages.debian.org/sid/amd64/linux-image-6.8.9-amd64/filelist
    # 看 debian linux-image 包内容，/boot 下只有
    # /boot/System.map-6.8.9-amd64
    # /boot/config-6.8.9-amd64
    # /boot/vmlinuz-6.8.9-amd64
    # 按照包结构复制到/boot
    # https://sources.debian.org/src/linux-signed-amd64/6.8.9%2B1/debian/rules.real/
    # 再call grub 生成bootloader
    # https://gist.github.com/superboum/1c7adcd967d3e15dfbd30d04b9ae6144
    local version=$(make kernelversion -C $ROOT/linux --no-print-directory)
    local suffix=$version-$ARCH
    cd $FS
    cp $ROOT/linux/System.map boot/System.map-$suffix
    cp $ROOT/linux/.config boot/config-$suffix
    cp $ROOT/linux/arch/$(arch)/boot/bzImage boot/vmlinuz-$suffix
    # copy kernel modules.builtin.modinfo modules.order modules.builtin
    mkdir -p lib/modules/$suffix/
    cp $ROOT/linux/modules.builtin.modinfo lib/modules/$suffix/modules.builtin.modinfo
    cp $ROOT/linux/modules.order lib/modules/$suffix/modules.order
    cp $ROOT/linux/modules.builtin lib/modules/$suffix/modules.builtin
    # create initrd.img
    update-initramfs -c -k $suffix -b boot
}

# install grub on /boot and /boot/efi
install_grub_efi() {
    # https://wiki.archlinux.org/title/GRUB#Generated_grub.cfg
    cd $FS
    grub-install --target="$(arch)-efi" --efi-directory=boot/efi --bootloader-id=GRUB --boot-directory=boot/
    grub-mkconfig -o boot/grub/grub.cfg
}

mount -t proc /proc proc/
mount --rbind /sys sys/
mount --rbind /dev dev/
mount "$ROOT/efi.fat32" boot/efi
# https://unix.stackexchange.com/questions/362870/unmount-sys-fs-cgroup-systemd-after-chroot-without-rebooting
mount --make-rslave sys/
mount --make-rslave dev/
install_kernel
install_grub_efi
chroot $FS /bin/bash /root/.rootfs_init.sh
cd $ROOT
# make umount happy
umount -R $FS
# 最后生成 bootable image
ROOTPATH_TMP="$(mktemp -d)"
genimage --rootpath "$ROOTPATH_TMP" --inputpath "$ROOT" --outputpath "$ROOT" --config ./scripts/genimage-efi.cfg

