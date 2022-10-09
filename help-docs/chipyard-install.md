# Chipyard 1.8.0安装



## 0 版本

| 名称      | 版本                                                         |
| --------- | ------------------------------------------------------------ |
| Ubuntu    | 20.04                                                        |
| chipyard  | 1.5.0                                                        |
| conda     | 4.12.0 或更高版本                                            |
| verilator | 4.226                                                        |
| boom      | 头指针位于 commit **fac2c370c9deae97ca52aca6b34857e9ac0f6e9d** |

细节请参考chipyard 1.8.0[安装文档](https://chipyard.readthedocs.io/en/1.8.0/Chipyard-Basics/Initial-Repo-Setup.html)。

## 1 、安装Conda

在chipyard1.8.0中，使用Conda管理项目依赖。参阅 [Conda 安装说明](https://github.com/conda-forge/miniforge/#download)，了解如何使用 Miniforge 安装程序安装 Conda。具体操作：

```shell
curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-$(uname)-$(uname -m).sh"
bash Mambaforge-$(uname)-$(uname -m).sh
```

关闭终端，重新打开后，会生效。终端前出现 (base)。运行`conda --version` 查看版本。要求conda版本大于等于4.12.0。

接着，安装conda-lock（Conda lock is a lightweight library that can be used to generate fully reproducible lock files for [conda](https://docs.conda.io/projects/conda) environments.）

```
conda install -n base conda-lock
conda activate base
```

## 2、 初始化子模块&安装工具链

**① 拉取chipyard仓库，并切换到1.8.0版本**

```shell
git clone https://github.com/ucb-bar/chipyard.git
cd chipyard
git checkout 1.8.0
```

**② 运行初始化脚本**

该脚本将会创建chipyard Conda环境，包括riscv工具链

运行该脚本时，还会运行`init-submodules-no-riscv-tools.sh` 和 `build-toolchain-extra.sh` 两个脚本

建议阅读相应脚本，弄清大致完成了哪些操作

```shell
./build-setup.sh riscv-tools
```

运行完成后，通过命令`conda env list`，将会有一个chipyard相关的环境：`$CHIPYARD_DIRECTORY/.conda-env`

<img src="https://cdn.jsdelivr.net/gh/fangjiangff/images/img/202210091532177.png" alt="image-20221009153212893" style="zoom:80%;" />

**③ 设置环境变量**

通过运行以下命令，进而：

- 激活在 build-setup.sh 中创建的 conda 环境

- 设置将来 Chipyard 步骤所需的必要环境变量（PATH、RISCV 、LD_LIBRARY_PATH）

```shell
source ./env.sh
```

注：每次运行make命令时，都需要进行这一步


## 3、 修补部分缺失模块

因为网络问题，会有子模块拉取失败的情况。这样会导致在编译Boom时出现很多错误，如：

<img src="https://cdn.jsdelivr.net/gh/fangjiangff/images/img/202210091542990.png" alt="image-20221009154232885" style="zoom:50%;" />

在上一步，运行`build-setup.sh`脚本时，会在chipyard目录下，生成`init-submodules-no-riscv-tools.log`文件。记录了该脚本运行的情况，可以通过查看日志，看到哪些子模块拉取失败了。

同时，可以在chipyard/.gitmodules中查看，chipyard具体有哪些子模块。

接下来，面对缺失的子模块，如`tools/torture`，你可以通过以下命令来获取。

```shell
git submodule update --init --recursive tools/torture
```

**请确保`generators`和`tools`目录下的所有子模块都拉取下来了**。有时候，它只有文件夹，里面的内容不全，最好一个个文件夹点进去确认一下。

<img src="https://cdn.jsdelivr.net/gh/fangjiangff/images/img/202210091549653.png" alt="image-20221009154957589" style="zoom:60%;" />

## 4、 生成Boom

chipyard可以使用Verilator下载、构建和执行仿真。通过CONFIG指定编译的项目。可以在`chipyard/generators/chipyard/src/main/scala/config/BoomConfigs.scala` 查看可选的BOOM配置名称。

将会生成一个名为``的可执行文件。可以使用此可执行文件运行任何兼容的 RV64 代码。例如，运行其中一个 riscv 工具链中集成的测试文件。

```shell
# Enter Verilator directory
cd sims/verilator
make CONFIG=SmallBoomConfig
./simulator-chipyard-RocketConfig $RISCV/riscv64-unknown-elf/share/riscv-tests/isa/rv64ui-p-simple
```

编译的过程，会在终端上，输出大量的内容，可以将终端的内容输入到日志文件中：

```
make CONFIG=SmallBoomConfig 2>&1 | tee > LOGNAME.log
```

可以通过阅读日志，了解Makefile文件具体帮你完成了什么，verilator的顶层模块是哪一个，如何得到最终的可执行文件的。