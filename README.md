# kernel-dev仓库

一站式内核开发调试工具链

# 编译内核

buildroot用rsync将 `linux/` 同步到 `buildroot/output/build/linux-custom`。你在linux/修改，make 并不会同步最新的代码

每个包都有 `package-<rebuild|reconfigure>`的形式

针对linux的重新编译运行

```
make linux-rebuild
```
