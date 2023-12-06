## kernel-dev仓库

一站式内核开发调试工具链

如果编译失败，每个项目都运行`make clean`，重试一遍

比如之前编译过x86，在此之上编译arm的kernel可能会出现奇怪的报错。

clean之后再编译报错就没了

总之，计算机是完全人造的，我们总是要依赖别人的代码，出错很正常，而且有些错误很难搞明白，死磕就是浪费时间，能绕过，走大家都走的路，实现你的目标才最重要。

`proxychains make -j$(nproc)` 会导致 getaddrinfo bug

<https://github.com/pyenv/pyenv/issues/430#issuecomment-142270500>

配透明代理保险些

### TODO

[] 使用 ext4 rootfs文件系统
[] kernel boot时执行脚本，自动化配置wifi 或者其他的环境

## 开发流程

**vscode C++ 插件难用，建议编译kernel加`CC=clang`，配合vscode clangd**

**在X86编译其他arch的kernel时，还是都加上 ARCH=xxx，比如x86编译arm，加`ARCH=arm`**

不加在编译时总发现奇奇怪怪的问题

### presetup

```bash
apt install make gcc flex bison clang libelf-dev bc libssl-dev -y
git submodule foreach "git checkout HEAD~1 && git branch -D master && git checkout -b master origin/master"
git submodule update --init --remote --recursive
git pull
```

### x86初始化

```bash
# 初始化 linux
cd linux
make CC=clang weichao_x86_64_defconfig

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


## 生成 compile commands

```bash
./linux/scripts/clang-tools/gen_compile_commands.py
```

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
    qemu-system-x86_64 -m 8G -smp cpus=4,cores=4 --kernel ./linux/arch/x86_64/boot/bzImage -initrd ./buildroot/output/images/rootfs.cpio -drive file=./buildroot/output/images/rootfs.ext4,format=raw,index=0,media=disk -device e1000,netdev=eth0 -netdev user,id=eth0,hostfwd=tcp::5555-:22,net=192.168.76.0/24,dhcpstart=192.168.76.9  -append "nokaslr console=ttyS0" -S -nographic -gdb tcp::1234 -virtfs local,path=/,security_model=none,mount_tag=guestroot

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

### 修改 linux 的.config

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

### linux make 弹输入提示符

运行

```bash
make weichao_x86_64_defconfig
# 这里可能会出现kbuild的提示，是否开启关闭某些选项
# 是因为上面的 make weichao_x86_64_defconfig 并没有加 CC=clang
# 而下面却加了 CC=clang
make CC=clang -j$(nproc)
```

解决办法是都加 `CC=clang`

```bash
make CC=clang weichao_x86_64_defconfig
# 这里可能会出现kbuild的提示，是否开启关闭某些选项
# 是因为上面的 make weichao_x86_64_defconfig 并没有加 CC=clang
# 而下面却加了 CC=clang
make CC=clang -j$(nproc)
```

> https://stackoverflow.com/questions/50405217/make-kernel-prompting-for-config-options-even-when-config-is-present

文件系统写100M，但实际物理存储只有30M

其实不是mount的问题，而是你所在的shell哪怕挂载完，还是现实原来的大小，因为init用的就是原来的大小！

### qemu多开terminal，同时调试

已经将 tmux.conf overlay 到rootfs

```
tmux -f /root/.config/tmux/tmux.conf
```

常用的 `ctrl-a` 被 qemu 拦截，需要 `ctrl-a+ctrl-a` 才能发送到内部shell

> https://www.qemu.org/docs/master/system/mux-chardev.html

所以split window变成

```
ctrl-a+ctrl+a \
ctrl-a+ctrl+a -
```


#### move between pane

> Alt-arrow

### 解决kernel panic

尝试重新编译kernel

```bash
cd linux
make CC=clang -j$(nproc)
```
