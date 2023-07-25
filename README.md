# kernel-dev仓库

一站式内核开发调试工具链

# 编译内核

buildroot用rsync将 `linux/` 同步到 `buildroot/output/build/linux-custom`。你在linux/修改，make 并不会同步最新的代码

每个包都有 `package-<rebuild|reconfigure>`的形式

针对linux的重新编译运行

```
make linux-rebuild
``

启动qemu
```bash
qemu-system-x86_64 --kernel ./packages/buildroot/output/images/bzImage -initrd ./packages/buildroot/output/images/rootfs.cpio -device e1000,netdev=eth0 -netdev user,id=eth0,hostfwd=tcp::5555-:22,net=192.168.76.0/24,dhcpstart=192.168.76.9  -append "nokaslr console=ttyS0" -S -nographic -gdb tcp::1234 -virtfs local,path=/,security_model=none,mount_tag=guestroot

```

gdb attach

```bash
gdb packages/buildroot/output/build/linux-custom/vmlinux
target remote localhost:1234
```

ssh连接

```bash
ssh root@127.0.0.1 -p 5555 
```
