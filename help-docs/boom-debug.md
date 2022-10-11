# Boom调试过程[更新中]



## 1、生成波形文件

- 运行`make help`查看帮助文档
- 可尝试阅读`chipyard/sims/verilator/Makefile`、 `chipyard/common.mk`、 `chipyard/variables.mk` 已经编译时打印的内容，理解编译过程。
- `chipyard/generators/chipyard/src/main/resources/csrc/emulator.cc`为verilator的仿真文件
- 最终在`chipyard/sims/verilator/output`文件夹下生成日志文件和波形文件

```shell
cd sims/verilator
make debug CONFIG=SmallBoomConfig run-binary-debug BINARY=[BINARY_NAME]
```

## 2、转换文件格式

生成的VCD波形文件太大了，卡了半天也没有打开。根据提示，转为fst格式的文件。

```shell
cd output
vcd2fst -v dcacheTest.vcd -f dcacheTest.fst
gtkwave dcacheTest.fst
```

再次打开，非常滴快速。

<img src="https://cdn.jsdelivr.net/gh/fangjiangff/images/img/202210111745873.png" alt="image-20221011164008444" style="zoom:80%;" />

## 3、找到BoomCore

生成的是整个Soc系统，BoomCore只是其中的小部分。

BoomCore所在位置：Top——>TestHarness——>chiptop——>system——>tile_prci_domain——>tile_reset_domian——>boom_tile

![image-20221011165410492](https://cdn.jsdelivr.net/gh/fangjiangff/images/img/202210111654524.png)

就可以找到具体模块的具体输入输出信号，查看每个周期的变化。比如，依次展开模块`boom_tile->fronted->f3`。点击f3，左下方的框框里将会出现该模块的所有信号，点击ram_pc[0]，就能在右边看到波形。

值得注意的是，n多个周期后，才会从8000_0000处执行我们自己写的代码。

<img src="https://cdn.jsdelivr.net/gh/fangjiangff/images/img/202210111723404.png" alt="image-20221011172330319" style="zoom: 80%;" />