# kernel-dev仓库

一站式内核开发调试工具链

# 开发流程

以x86架构为例
## 初始化
```bash
# 初始化 linux
cd linux
make weichao_x86_64_defconfig

# 如果需要
# make menuconfig

make -j$(nproc)

# 初始化buildroot
cd ../buildroot
make weichao_x86_defconfig

# 如果需要
# make menuconfig

make -j$(nproc)
```
## 开发循环

### linux/
1. make menuconfig
2. make -j8
3. 
4. 如果长期使用，将 `.config` 保存到 `arch/x86/configs/weichao_x86_64_defconfig`
## buildroot/
1. make menuconfig
2. make savedefconfig
3. `make` or `make linux-rebuild` (加上第二步一共编译两次kernel，幸好内核开发文件变动不频繁，所以linux/ 有compile_commands.json 后不需要经常编译)

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
## FAQ
### 修改 linux的.config

linux/.config只用于开发，最后调试用的.config在 `buildroot/output/build/linux-custom/.config`

修改开发.config: linux/ 下 `make menuconfig`
修改编译调试的.config: buildroot下 `make linux-menuconfig`

注意: `make linux-update-config`复制的是 linux-custom/.config，所以在 `linux/.config` 的修改并不会影响 `board/weichao/<arch>/linux.config`

### Gdb breakpoing set error Cannot execute this command while the target is running.

https://marketplace.visualstudio.com/items?itemName=webfreak.debug#:~:text=Adding%20breakpoints%20while%20the%20program%20runs%20will%20not%20interrupt%20it%20immediately.%20For%20that%20you%20need%20to%20pause%20%26%20resume%20the%20program%20once%20first.%20However%20adding%20breakpoints%20while%20its%20paused%20works%20as%20expected.

Adding breakpoints while the program runs will not interrupt it immediately. For that you need to pause & resume the program once first. However adding breakpoints while its paused works as expected.

1. 先点vscode debug的pause
2. 设置断点
3. 再点continue