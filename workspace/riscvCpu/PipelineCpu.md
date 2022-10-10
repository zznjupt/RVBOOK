# 顺序五级流水CPU设计

## 1、流水线概述

### 参考资料（请提前阅读）

> - 《CPU设计实战》第四章。
> - 《计算机组成与设计 硬件软件接口（第五版）》第四章中关于流水线的部分
> - "一生一芯"讲义：[流水线处理器](https://ysyx.oscc.cc/docs/advanced/2.9.html)

- 组合逻辑：任何时刻，当输入变化时，立刻得到相应的输出，不需要等到时钟上升沿。如ALU运算单元，当传入不同的操作数时，运算结果即刻发生变化。

- 时序逻辑：只有当时钟上升沿时，模块的输出才会根据输入发生变化。如PC模块，当时钟上升沿时，更新pc寄存器的值。

在原有的单周期CPU设计中，除了PC模块外，其余部分均为组合逻辑（包括存储模块），因此可以在一个周期内完成指令的执行。为了提高时钟频率，对电路进行流水化。这里按经典的五级流水进行划分

- 取指（IF）：生成next_pc、取出指令
- 译码（ID）：生成控制信号、读取寄存器获取操作数
- 执行（EXE）：执行指令（算术计算、跳转地址、访存地址）
- 访存（MEM）：从存储器中读取、写入数据
- 写回（WB）：将结果（运算结果、访存结果）写入目标寄存器

流水化本身并不复杂，将原本单周期的组合逻辑按照功能划分成五个阶段，在每一个阶段的组合逻辑之间插入时序器件（称为流水线寄存器），把组合逻辑分开就完成了。**前一阶段的组合逻辑输出接入时序器件的输入,后一阶段的组合逻辑输入来自这些时序器件的输出。**

以两个流水级的名字来命名这些寄存器，如位于取指级、译码级之间的寄存器记为`REG_IF_ID`。

<img src="https://cdn.jsdelivr.net/gh/JiangFang03/images/img/202207221926059.png" alt="image-20220722192559914" style="zoom: 67%;" />

## 2、不考虑冲突和分支指令的流水线设计

### LW的五级流水旅程

以指令`lw	a4,8(s0)`为例:

- 第一个时钟周期（IF）：处于IF阶段，根据当前pc值，从指令存储器IM中获取指令。并将pc、指令存放到`RGE_IF_ID`中（寄存器的值下一个时钟上升沿才会变化，因此需要等第二个时钟周期，下一个阶段才能读取到流水线寄存器中的数据）。
- 第二个时钟周期（ID）：`RGE_IF_ID`中的内容输出到ID模块，译码单元进行译码，生成控制信号（如，rs = s0, imm = 8, rd = a4，mem_read = 1）。需要将寄存器中读取的数据，以及**后续流水需要的所有控制信号**输出到`RGE_ID_EX`流水线寄存器中。
- 第三个时钟周期（EXE）：运算单元从`RGE_ID_EXE`流水线寄存器中，得知操作数1为寄存器，操作数2为立即数，最终会计算得到访存的地址为`R(s0)+imm`。将运算结果（访存地址）和后续流水需要的控制信号存放到`RGE_EX_MEM`中。
- 第四个时钟周期（MEM）：存储单元从`RGE_EX_MEM`流水线寄存器中，获取到访存的地址以及读写信号（mem_read=1,mem_write=0），读取目标地址，获取对应的数据。将读取的数据、运算单元的结果以及写回级需要的控制信号存放到`RGE_MEM_WB`寄存器中。
- 第五个时钟周期（WB）：写回级从`RGE_MEM_WB`寄存器中获取到执行级的运算结果、存储器中读取的数据、选择信号、寄存器写使能信号、目标寄存器号。选择信号`sel_rf_res=1`，因此将存储器读取的数据写回到目标寄存器`a4`中。至此，lw完成了五级流水的全部旅程。

流水线寄存器中需要存放的内容包括：

- 有效位：1bit，用于标识该流水线寄存器中的内容是否有效
- 数据：如pc、指令、操作数、运算结果、访存结果等
- 控制信号：如寄存器读使能、ALU操作类型、存储器读写控制信号等。

一根信号线可能会被多个流水寄存器多次隔断，因此每个流水线寄存器中都要包含这跟信号线携带的信息。如寄存器写使能`rfWen`、目标寄存器号`rd`在译码级就可以得到，但是等到写回级才需要使用。因此需要将其依次写入`REG_ID_EX`、`REG_EX_MEM`、`REG_MEM_WB`流水线寄存器中。

### 流水线寄存器的实现

先明确各流水线寄存器中存放的内容，再去写具体的代码。

以`REG_EX_MEM`为例，需要存放的内容包括：

- 有效位valid、pc、inst（指令）
- 数据内容：执行级运算结果（exe_res)、访存级读取的数据(write_data)
- 控制信号：数据存储器相关控制信号（fuOpType、mem_read、mem_write)、寄存器堆控制信号（rfWen、rfDest）、写回数据选择信号（sel_rf_res)

```scala
class BUS_EX_MEM extends Bundle{
    val valid       = Bool()
    val pc          = UInt(64.W) 
    val inst        = UInt(32.W)

    val write_data  = UInt(64.W)
    val exe_res     = UInt(64.W)

    val fuOpType    = UInt(7.W)
    val mem_read    = UInt(1.W)
    val mem_write   = UInt(1.W)
    
    val rfWen       = UInt(1.W)
    val rfDest      = UInt(5.W)
    val sel_rf_res  = UInt(1.W)

}
```

​	如下代码所示，`REG_EX_MEM`寄存器的输入输出类型均为上述定义的`BUS_EX_MEM`。ex_mem_reg初始化为`BUS_EX_MEM`类型的寄存器。下一个周期才能从io.out中读出当拍的流水线寄存器中的内容。(如果这里很难理解，请查阅chisel中RegInit、RegNext的用法，或者查看生成的Verilog代码)。

```scala
class PipelineReg_EX_MEM extends Module{
    val io = IO(new Bundle{
        val in      = Input(new BUS_EX_MEM)
        val out     = Output(new BUS_EX_MEM)
    })
    val ex_mem_reg  = RegInit(0.U.asTypeOf(new BUS_EX_MEM))
    ex_mem_reg := io.in
    io.out  := ex_mem_reg
}
```

### 顶层模块

顶层TOP模块需要实例化五大模块、模块间的寄存器，并进行控制信号的连接。

```scala
    val ifu         = Module(new IFU())
    val reg_if_id   = Module(new PipelineReg_IF_ID())
    val idu         = Module(new IDU())
    ……
  	ifu.io.out          <> reg_if_id.io.in
    reg_if_id.io.out    <> idu.io.in
    idu.io.out          <> reg_id_ex.io.in
	……
```



## 3、考虑指令数据相关性冲突

关于相关性冲突的原理可以参考《计算机组成与设计 硬件软件接口（第五版）》中4.7章的内容。sub指令要在第五个周期才能写回x2的值（第六个周期才能读出正确的x2)，但是and、or、add指令分别在第3、4、5周期就需要访问寄存器堆，获取x2寄存器的值。如果不对流水线进行任何干扰，则and、or、add都会读出错误的x2。解决的一个办法是流水线停顿：当译码阶段发现有数据冲突时，暂停后续流水的执行，直到数据冲突被解决。

<img src="https://cdn.jsdelivr.net/gh/JiangFang03/images/img/202207222038591.png" alt="image-20220722203852246" style="zoom: 33%;" />

需要考虑两个问题：①如何判断数据冲突②如何停顿流水线

### 数据冲突的判定条件

关于如何判断数据冲突：当译码级，发现处于执行、访存、写回级的指令的目的寄存器和当前指令的某一个源寄存器相同时，则存在数据冲突。然而并不是所有的指令都会写回寄存器，一个简单的方法是，判断流水线寄存器中rfWen信号是否有效。另一方面，RISC-V中规定，x0寄存器的值恒为零，因此对x0寄存器的操作并不会引发数据冲突。据此，可以将RAW数据冲突的判定条件归为三点。以判定执行级和译码级间是否有数据冲突为例进行说明：

- `REG_ID_EXE`中`rd != x0`
- `REG_ID_EXE`中`rfWen == 1`
- `REG_ID_EXE`中`rd == rs1 || rd == rs2`,其中rs1、rs2位于译码级

你需要引入一个新的硬件单元`HazardDection`，该模块的输出一个`stall`信号(Bool类型），用于标识是否存在数据冲突。

### 流水线停顿

当检测到存在数据冲突时，需要停顿流水线。

> 只需要简单地禁止**PC寄存器和IF/ID流水线寄存器的改变**就可以阻止这两条指令的执行。如果这些寄存器被保护，在IF阶段的指令就会继续使用相同的PC值取指令，同时在ID阶段的寄存器就会继续使用IF/ID流水线寄存器中相同的字段读寄存器。再回到我们的洗衣例子中，这就像是你重新开启洗衣机洗相同的衣服并且让烘干机继续空转一样。当然，就像烘干机那样，**EX阶段开始的流水线后半部分必须执行没有任何效果的指令**,也就是空指令。
>
> ​																																			----《计算机组成与设计 硬件软件接口（第五版）》P216

- HazardDection单元stall输出接入到IFU、REG_IF_ID、IDU中。
- IFU检测到stall为1时，使用相同的PC再次取值
- `REG_IF_ID`：当stall为1时，不更新寄存器内容，因此输出与上一拍一致，IDU会使用相同的指令译码
- IDU：stall为1时，将输出到`REG_ID_EX`的控制信号全部置为0，这样后续流水不会对存储器、寄存器写入任何值，相当于执行了空指令。

## 4、考虑跳转

在本文的设计中，分支跳转与否、分支跳转目标在执行级确定。流水线停顿可以解决分支指令，也就是当分支跳转、分支目标被确定后再继续IF阶段。但这样非常的耗时。一个简单的策略是：**假设分支不发生，继续顺序取指**，如果EXE阶段发现分支跳转了，则进行流水线冲刷。

具体来说，在本文的顺序流水线中，当执行级的分支指令被处理，并确定分支发生时，需要清除处于IF阶段、ID阶段的内容，即将`REG_IF_ID`、`REG_ID_EX`中的内容全部置为0。于此同时，需要将HazardDection的stall值置为false。

```scala
    when(exeu.io.redirect.valid){
        reg_if_id.io.flush := true.B
        reg_id_ex.io.flush := true.B
        hd.io.flush        := true.B
    }
```

调整后的五级流水示意图如下

![image-20220722215712549](https://cdn.jsdelivr.net/gh/JiangFang03/images/img/202207222157676.png)











