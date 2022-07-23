## 玄铁C910 RTL -- verilator仿真记录

### 环境搭建

玄铁C910 IP 包开源在github：

```bash
git clone https://github.com/T-head-Semi/openc910.git
```

玄铁C910 IP 包由以下两部分组成：

* C910源码包，包含固定功能配置的 C910 RTL 代码；
* C910 Smart平台，提供了 C910 的参考集成设计，仿真环境和测试用例等，帮助熟悉 C910的功能和使用方法，并辅助 C910 的集成工作

该 IP 包所需要的环境在玄铁C910手册里：

* 玄铁C910IP中的 perl 脚本依赖 perl 5.10.1 或以上版本；
* Make 版本为 3.8.1；
* EDA仿真工具：Icarus Verilog（iverilog）10.2，Synopsys VCS 2019.06及以上版本，或者Cadence Xcelium19.09及以上版本；带UPF的低功耗仿真仅在 VCS 2020.12版本上进行了测试
* Smart 平台编译测试用例依赖平头哥玄铁处理器 RISC-V工具链 2.0.3 及以上版本

根据说明，我们方便使用的开源仿真工具只有iverilog，复旦微的研究生在仓库main分支上上传了支持verilator（4.215 or later）仿真的脚本，因此本次环境搭建将使用verilator仿真器

#### verilator安装

本实验机器OS：ubuntu18.04 LTS

安装流程从官网上贴了下来：

```bash
# Prerequisites:
#sudo apt-get install git perl python3 make autoconf g++ flex bison ccache
#sudo apt-get install libgoogle-perftools-dev numactl perl-doc
#sudo apt-get install libfl2  # Ubuntu only (ignore if gives error)
#sudo apt-get install libfl-dev  # Ubuntu only (ignore if gives error)
#sudo apt-get install zlibc zlib1g zlib1g-dev  # Ubuntu only (ignore if gives error)

git clone https://github.com/verilator/verilator   # Only first time

# Every time you need to build:
unsetenv VERILATOR_ROOT  # For csh; ignore error if on bash
unset VERILATOR_ROOT  # For bash
cd verilator
git pull         # Make sure git repository is up-to-date
git tag          # See what versions exist
#git checkout master      # Use development branch (e.g. recent bug fixes)
#git checkout stable      # Use most recent stable release
#git checkout v{version}  # Switch to specified release version

autoconf         # Create ./configure script
./configure      # Configure and create Makefile
make -j `nproc`  # Build Verilator itself (if error, try just 'make')
sudo make install
```

#### 玄铁处理器RISC-V工具链下载

https://occ.t-head.cn/community/download?id=3948120165480468480

我下载的版本是 Xuantie-900-gcc-elf-newlib-x86_64-V2.4.0-20220428.tar.gz

### 仿真流程

* 首先修改openc910 project下的两个用于部署环境的.csh文件修改为.sh文件：

openc910/C910_RTL_FACTORY/setup/setup.csh

```bash
#!/bin/csh

set pattern = "\/setup"`echo '$'`
setenv CODE_BASE_PATH `pwd | perl -pe "s/$pattern//"`
echo "Root of code base has been specified as:\n    $CODE_BASE_PATH"
```
->openc910/C910_RTL_FACTORY/setup/setup.sh

```bash
#!/usr/bin/bash

pattern="\/setup"`echo '$'`
export CODE_BASE_PATH `pwd | perl -pe "s/$pattern//"`
echo "Root of code base has been specified as:\n    $CODE_BASE_PATH"
```

openc910/smart_run/setup/example_setup.csh

```bash
#!/bin/csh

setenv TOOL_EXTENSION /tools/riscv/riscv64-elf-x86_64/bin
echo 'Toolchain path($TOOL_EXTENSION):'
echo "    $TOOL_EXTENSION"
```

->openc910/smart_run/setup/example_setup.sh

```bash
#!/usr/bin/bash

export TOOL_EXTENSION=/home/dios/XUANTIE/Xuantie-900-gcc-elf-newlib-x86_64-V2.4.0-20220428/Xuantie-900-gcc-elf-newlib-x86_64-V2.4.0/bin
echo 'Toolchain path($TOOL_EXTENSION):'
echo "    $TOOL_EXTENSION"
```

* 接着，执行两个setup脚本，注意需要严格按照下面步骤执行，因为启动脚本的位置影响结果

```bash
cd openc910/C910_RTL_FACTORY
source setup/setup.sh
cd ../smart_run
source setup/example_setup.sh
```

如果执行sh脚本报错如下：

```bash
:Syntax error: Bad fd number
```

可能是sh链接到了dash，因此需要检查链接情况：

```bash
ls -l /bin/sh
```
如果得到的结果是

```bash
/bin/sh -> dash
```

那么执行以下命令即可

```bash
sudo mv /bin/sh /bin/sh.orig
sudo ln -s /bin/bash /bin/sh
```

再次检查应该得到正确的结果

```bash
/bin/sh -> /bin/bash
```

* 接着，在/smart_run下创建/work目录

```bash
mkdir work
```

* 然后即可进行仿真工作，本次实验选取的备选CASE为hello_world

```bash
make cleanVerilator
make compile SIM=verilator
make buildVerilator
make buildcase CASE=hello_world
make runVerilator
```

但是每次运行buildVerilator的时候总会运行过程中死机重启，初步认为是内存不够的原因，分配了26G内存依旧存在这个问题，之后在服务器上跑试试看

应该就是内存问题或者是虚拟机性能问题，在服务器上成功helloworld

<img src="https://github.com/JiangFang03/images/img/202207221834622.png" width="100%" height="100%">