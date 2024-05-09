#!/usr/bin/env bash
BOOT=/mnt/boot

dd if=/dev/zero of=boot.ext4 bs=1M count=1024

mkfs.ext4 boot.ext4
mkdir -p $BOOT

mount -o loop boot.ext4 $BOOT
# cp kernel, System.map, .config into boot partition

# create efi partition

# install grub to /boot and /boot/efi
