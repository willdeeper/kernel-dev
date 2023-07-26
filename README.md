# kernel-dev仓库

一站式内核开发调试工具链

# 开发流程

以x86架构为例

1. buildroot/
   1. make weichao_x86_defconfig
   2. make menuconfig
   3. make -j8
2. linux/
   1. make menuconfig
   2. make -j8
   3. 经常运行`make linux-update-defconfig`: 将.config存放到buildroot/board/weichao/<arch>/linux.config

# 编译内核

buildroot用rsync将 `linux/` 同步到 `buildroot/output/build/linux-custom`。你在linux/修改，make 并不会同步最新的代码

每个包都有 `package-<rebuild|reconfigure>`的形式

1. 重新编译运行linux

```bash
# 只会在target/生成bzImage
# 如果需要rootfs，需要全量编译 make all
# 另外此命令会报错 comm files-list.before: No such file or directory
# https://yhbt.net/lore/all/20201105221643.707bba76@windsurf.home/T/
# 但还是会生成bzImage，没发现什么印象，现阶段忽略就好
make linux-rebuild
```

根据我的测试，rsync同步后还是会有编译缓存。在linux/下开发编译之后 `make linux-rebuild`会重新编译linux/编译的内容，而不是全量编译
2. 编译生成rootfs

```bash
# https://buildroot.org/downloads/manual/manual.html#:~:text=8.3.-,Understanding%20how%20to%20rebuild%20packages,-One%20of%20the\
make all
```

3. 启动qemu

```bash
qemu-system-x86_64 --kernel ./packages/buildroot/output/images/bzImage -initrd ./packages/buildroot/output/images/rootfs.cpio -device e1000,netdev=eth0 -netdev user,id=eth0,hostfwd=tcp::5555-:22,net=192.168.76.0/24,dhcpstart=192.168.76.9  -append "nokaslr console=ttyS0" -S -nographic -gdb tcp::1234 -virtfs local,path=/,security_model=none,mount_tag=guestroot

```

gdb attach

```bash
gdb packages/buildroot/output/build/linux-custom/vmlinux
target remote localhost:1234
```

或者一行

```
gdb packages/buildroot/output/build/linux-custom/vmlinux --ex="target remote localhost:1234"
```

ssh连接

```bash
ssh root@127.0.0.1 -p 5555 
```
