<img src='https://img.shields.io/badge/-Verilog-8985F0.svg'>

# 详解脉动阵列

## 脉动算法

### 脉动算法和脉动阵列

脉动算法（systolic algorithm）是指基于 H. T. Kung 所提倡的脉动阵列（systolic array）所实现的进行并行处理的算法的总称。脉动阵列是一种由众多简单的运算元件（Processing Element，PE）按规则排列的硬件架构，具有以下特征：

* 由单一或多种构造 PE 按规则排列
* 只有相邻的 PE 互相连接，数据每次只能在局部范围内移动。<br>
除了局部连接，同时还采用总线等连接方式的架构被称为半脉动阵列（semi-systolic array）
* PE 只重复进行简单的数据处理和必要的数据收发
* 所有 PE 由统一的时钟同步工作

每个 PE 都和相邻 PE 同步进行数据收发和运算。数据从外部流入，PE 阵列一边搬运数据，一边采用流水型或并行方式对其进行处理。各个 PE 的运算和数据收发动作和心脏规律性地收缩（systolic）促进血液流动的过程非常相似，因此此类架构被命名为脉动阵列。此外，PE 又是也被称为单元（cell）

### 基于一维脉动阵列的部分排序（TopK）

> 将 $n$ 个数据组成的数组按数值从大到小排列，再输出其中数值最大的 $N$ 个数据

* 一维排列上的 $N$ 个 PE 都具有寄存器，用来保存临时最大值 $$X_{\text{max}}$$
* 当输入 $$X_{\text{in}}$$ 比 $$X_{\text{max}}$$ 大时将 $$X_{\text{max}}$$ 更新为 $$X_{\text{in}}$$ 
* 临时最大值更新时将原本的 $$X_{\text{max}}$$ 输出到右侧的 PE，没有更新时则将 $$X_{\text{in}}$$ 输出到右侧的 PE
* 不断重复这个过程直到最后第 $$N$$ 个数据进入 PE

数值最大的 $$N$$ 个数据就会从左到右按顺序存放在各个 PE 的寄存器中，采用 $$N$$ 个 PE 组成的脉动阵列对 $$n$$ 个数据进行部分排序，总共需要 $$(N+n-1)$$ 个步骤。

```verilog
module PE (
    input  wire         clk;
    input  wire         rst_n;
    input  wire         mode;
    input  wire         shiftRead;
    input  wire [7:0]   Xin;
    input  wire [7:0]   Zin;
    output wire [7:0]   Xout;
    output wire [7:0]   Zout;
);

reg  [7:0] Xmax;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        Xmax <= 'd0;
    else if(mode) begin
        if(Xin > Xmax)
            Xmax <= Xin;
    end else begin
        if(shiftRead)
            Xmax <= Zin;
    end
end

assign Xout = Xin > Xmax ? Xmax : Xin;
assign Zout = Xmax; 

endmodule

```
### 基于一维脉动阵列的矩阵-向量相乘

> 矩阵向量相乘运算 $$Y = AX$$ 可以采用一维脉动阵列实现

* 运算元素数为 $$N \times N$$ 的矩阵所需 PE 个数为 $$N$$

待续...
### 基于二维脉动阵列的矩阵-矩阵相乘

> 矩阵相乘运算 $$C = AB$$ 

* 运算元素数为 $$N \times N$$ 的矩阵，需要 $$N^2$$ 个 PE 构成的 $$N\times N$$ 纵横排列的脉动阵列 

AI处理器的矩阵处理单元专用于专用于**矩阵乘法**和**卷积运算**

脉动阵列是用于实现矩阵处理器最为常见的微架构，它本身的数学原理其实非常简单。<br>
为了将脉动阵列应用于不同场景（经典场景：**矩阵乘法、卷积运算**），理解其数据流是关键。<br>
理解了数据流，那么微架构的设计就呼之欲出、顺理成章了。

待续...


