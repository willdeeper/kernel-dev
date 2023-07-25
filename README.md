kernel-dev仓库

buildroot生成kernel开发调试



## 构建initramfs

1. 编译rootfs系统，内核加载initramfs

### Buildroot

buildroot用来编译内核镜像，glibc，gcc，各种三方package(compiler, curl等包),root filesystem 生成，bootloader构建。

换句话说，`一键式linux生态工具链构建`

编译完成后，在output下会生成 bootloader，kernel image，initramfs 等文件

-----
buildroot也提供内核编译能力，但本文只使用它生成rootfs

```
git clone https://git.buildroot.net/buildroot
make menuconfig
```

修改以下配置

```
Target options
    Target Architecture
    select "x86_64"
Filesystem images
    check "rootfs cpio"
```

rootfs.tar不能用，需要转换为cpio或者image格式

## 编译内核

1. 推荐用clang编译内核

```bash
make CC=clang menuconfig
make CC=clang -j16
```

2. GCC编译

```bash
make menuconfig
make -j16
```

修改配置，开启Debug symbol

```
Kernel Hacking
    -> Compile-time checks and compiler options
        -> CONFIG_DEBUG_INFO=y
        -> CONFIG_DEBUG_INFO_DWARF4=y
```

`arch/x86/boot/bzImage`是编译出的内核文件, vmlinux是debug symbol和kernel symbol表

## 运行内核

1. 安装qemu

```bash
apt install qemu-system-x86
```

2. 更改gdb配置
让gdb加载linux的gdb helper代码
将下面内容写入 `~/.gdbinit`，注意将 `/data00/codes/linux/scripts/gdb/vmlinux-gdb.py`改成你linux目录的位置

```bash
add-auto-load-safe-path /data00/codes/linux/scripts/gdb/vmlinux-gdb.py
```

3. 启动qemu，使内核在入口点stop

[lldb 也支持 gdb-server，所以不管上面是clang还是gcc，qemu都用`-gdb`](https://wiki.osdev.org/Kernel_Debugging#:~:text=(gdb)%20si-,Use%20LLDB%20with%20QEMU,-LLDB%20supports%20GDB)

```bash
qemu-system-x86_64 --kernel ./arch/x86/boot/bzImage -initrd ./rootfs.cpio -append "nokaslr console=ttyS0" -S -nographic -gdb tcp::1234
```

可能不好使
```bash
qemu-system-x86_64 --kernel ../buildroot/output/images/bzImage -initrd ../buildroot/output/images/rootfs.cpio -device e1000,netdev=eth0 -netdev user,id=eth0,hostfwd=tcp::5555-:22,net=192.168.76.0/24,dhcpstart=192.168.76.9  -append "nokaslr console=ttyS0" -S -nographic -gdb tcp::1234 -virtfs local,path=/,security_model=none,mount_tag=guestroot
```

4. 配置网络
在`/etc/network/interfaces`添加以下内容

```

auto eth0
iface eth0 inet dhcp

```

运行 `ifup -a` reload 网络接口

## 调试内核

1. gdb 远程调试kernel

```bash
# 让gdb加载vmlinux 内核符号表
gdb vmlinux
# 在gdb界面远程连接qemu
target remote localhost:1234
# start_kernel处下断点
b start_kernel
c
```

## 生成compile_commands.json

```
./scripts/clang-tools/gen_compile_commands.py
```

## FAQ

### 如何在非图形界面下退出qemu

在tmux里 ctrl + a被 tmux hook了，输入`Ctrl + a x`不能传递给qemu

使用 `ctrl-a :`打开tmux命令输入界面，输入`send-keys C-a x`再回车就能退出qemu
