## kernel-dev仓库

一站式内核开发调试工具链

如果编译失败，每个项目都运行`make clean`，重试一遍

比如之前编译过x86，在此之上编译arm的kernel可能会出现奇怪的报错。

clean之后再编译报错就没了

总之，计算机是完全人造的，我们总是要依赖别人的代码，出错很正常，而且有些错误很难搞明白，死磕就是浪费时间，能绕过，走大家都走的路，实现你的目标才最重要。

proxychains make -j$(nproc) 会导致getaddrinfo bug

<https://github.com/pyenv/pyenv/issues/430#issuecomment-142270500>

配透明代理保险些

## 开发流程

**vscode C++ 插件难用，建议编译kernel加`CC=clang`，配合vscode clangd**

**在X86编译其他arch的kernel时，还是都加上 ARCH=xxx，比如x86编译arm，加`ARCH=arm`**

不加在编译时总发现奇奇怪怪的问题

### presetup

```bash
apt install make gcc flex bison clang libelf-dev bc libssl-dev -y
git submodule update --init --remote --recursive
git submodule foreach "git branch -D master & git checkout -b master origin/master"
```

### x86初始化

```bash
# 初始化 linux
cd linux
make weichao_x86_64_defconfig

# 如果需要
# make menuconfig

make CC=clang -j$(nproc)

# 初始化buildroot
cd ../buildroot
make weichao_x86_64_defconfig

# 如果需要
# make menuconfig

make
```

### arm 初始化

在 x86 编译arm的内核，需要 `ARCH=arm`

linux/

```bash
make ARCH=arm sunxi_deconfig
make ARCH=arm -j$(nproc)
```

## 开发循环

### linux/

1. make CC=clang menuconfig
2. make CC=clang -j$(nproc)
3. 保存 `linux/.config`:

    ```bash
    make savedefconfig 
    cp defconfig arch/x86/configs/weichao_x86_64_defconfig
    ```

4. 修改代码，跳转 2

buildroot/

`make linux-update-defconfig`

## buildroot/

1. make menuconfig
2. make savedefconfig
3. `make` or `make linux-rebuild` (加上第二步一共编译两次kernel，幸好内核开发文件变动不频繁，所以linux/ 有compile_commands.json 后不需要经常编译)

# 编译内核

buildroot用 `rsync` 将 `linux/` 同步到 `buildroot/output/build/linux-custom`。在 linux/ 修改后 make 并不会复用上次的编译缓存

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

    根据测试，rsync同步后还会有编译缓存。在 linux/ 开发编译之后 `make linux-rebuild`会重新编译 `linux/` 修改的内容，而不是全量编译

2. 编译生成rootfs

    ```bash
    # https://buildroot.org/downloads/manual/manual.html#:~:text=8.3.-,Understanding%20how%20to%20rebuild%20packages,-One%20of%20the\
    make all
    ```

3. 启动qemu

    ```bash
    qemu-system-x86_64 --kernel ./buildroot/output/images/bzImage -initrd ./buildroot/output/images/rootfs.cpio -device e1000,netdev=eth0 -netdev user,id=eth0,hostfwd=tcp::5555-:22,net=192.168.76.0/24,dhcpstart=192.168.76.9  -append "nokaslr console=ttyS0" -S -nographic -gdb tcp::1234 -virtfs local,path=/,security_model=none,mount_tag=guestroot

    ```

    gdb attach

    ```bash
    gdb buildroot/output/build/linux-custom/vmlinux
    target remote localhost:1234
    ```

    或者一行

    ```bash
    gdb buildroot/output/build/linux-custom/vmlinux --ex="target remote localhost:1234"
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

### Gdb breakpoing set error Cannot execute this command while the target is running

<https://marketplace.visualstudio.com/items?itemName=webfreak.debug#:~:text=Adding%20breakpoints%20while%20the%20program%20runs%20will%20not%20interrupt%20it%20immediately.%20For%20that%20you%20need%20to%20pause%20%26%20resume%20the%20program%20once%20first.%20However%20adding%20breakpoints%20while%20its%20paused%20works%20as%20expected>.

Adding breakpoints while the program runs will not interrupt it immediately. For that you need to pause & resume the program once first. However adding breakpoints while its paused works as expected.

1. 先点vscode debug的pause
2. 设置断点
3. 再点continue

### Windows 启动qemu

```txt
.\qemu-system-x86_64.exe --kernel C:\Users\qaq13\Desktop\bzImage -initrd C:\Users/qaq13/Desktop/rootfs.cpio -device e1000,netdev=eth0 -netdev user,id=eth0,hostfwd=tcp::5555-:22,net=192.168.76.0/24,dhcpstart=192.168.76.9  -append "nokaslr console=ttyS0" -S -nographic -gdb tcp::1234
```

### 为什么需要编译两次内核？

linux/ 和 buildroot/ 都需要编译一次内核，buildroot的编译会复用linux/的编译缓存进行少量编译

buildroot/ 编译依赖 linux-header，而 buildroot 默认的linux-header和 linux/ 的版本可能不一致，为避免不必要的麻烦，buildroot总是使用和linux/版本一致的linux-header编译，所以buildroot需要使用 linux/ 代码重新编译一次
