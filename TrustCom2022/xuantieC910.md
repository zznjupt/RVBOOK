## 资料
1. [平头哥快速上手文档](https://yoc.docs.t-head.cn/linuxbook/)
2. [BuildRoot发行版（重要！）](https://github.com/c-sky/buildroot/releases)
3. [T-HEAD CPU调试技巧(GDB)](https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource/1355977/1606876665617/T-HEAD+CPU%E8%B0%83%E8%AF%95%E6%8A%80%E5%B7%A7.pdf)
4. [XuanTie QEMU 用户手册](https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource/1356021/1640154503082/XuanTie_QEMU_User_Guide.pdf)


## 1、下载C910 Qemu
打开xuantie发行版页面：
https://github.com/c-sky/buildroot/releases
C910对应的版本是： `c9xx linux-5.10`
阅读readme.txt,这是官方给的使用手册。
![](../TrustCom2022/img/c910-releases.png)

新建一个工作目录，如xuantie，下面所有操作都将在该文件夹下进行。

参考 readme.txt -> Quick Start for qemu run 章节，并运行相应的代码。你将获得：
- fw_jump.elf
- host 
- Image  
- rootfs.ext2
  
>相关工具（如qemu、gcc、gdb）等在host中。具体路径需要你自己探索。你需要将该路径加入到PATH中，这样在使用时就不需要写绝对路径了。

## 2、添加共享文件夹
请参考Qemu相关章节，为主机和qemu模拟出的系统，添加共享文件夹。
需要在qemu中执行的文件，请放入共享文件夹中。

## 3、启动qemu，运行攻击代码

1. 在xuantie文件夹下，运行：
```shell
LD_LIBRARY_PATH=./host/lib \
qemu-system-riscv64 \
-M virt \
-cpu c910 \
-kernel fw_jump.elf \
-device loader,file=Image,addr=0x80200000 -append "rootwait root=/dev/vda ro" \
-drive file=rootfs.ext2,format=raw,id=hd0 -device virtio-blk-device,drive=hd0 \
-fsdev local,security_model=passthrough,id=fsdev0,path=/home/jiangfang/share \
-device virtio-9p-device,id=fs0,fsdev=fsdev0,mount_tag=hostshare \
-nographic \
-smp 1
```
2. 输入用户名"root"
3. 挂载共享目录
   
   `mount -t 9p -o trans=virtio,version=9p2000.L hostshare /tmp/share/`
4. 进入共享文件夹
   `cd /tmp/share`
5. 执行
   `./hello`