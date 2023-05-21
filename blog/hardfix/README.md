<img src='https://img.shields.io/badge/SPEC-IEEE_754-green.svg'> <img src='https://img.shields.io/badge/语言-systemverilog_(IEEE1800_2005)-CAD09D.svg'> 

# 漫谈单精度浮点数、定点数与硬件实现

## 单精度浮点数格式

> 单精度浮点数格式是一种数据类型，在计算机存储器中占用4个字节（32 bits），利用“浮点”（浮动小数点）的方法，可以表示一个范围很大的数值。<br>
> IEEE 754-1985 **single**<br>
> IEEE 754-2008 **binary32**

第1位表示正负，中间8位表示指数，后23位储存有效数位（有效数位是24位）

<img src='./images/single.png'>

* 第一位的正负号0代表正，1代表负
* 中间八位共可表示2^8=256个数，指数可以是二补码；或0到255，0到126代表-127到-1，127代表零，128-255代表1-128
* 有效数位最左手边的1并不会储存，因为它一定存在（二进制的第一个有效数字必定是1）<br>换言之，有效数位是24位，实际储存23位

## 定点数格式

定点数由若干位整数和若干位小数组成。其值= **该二进制码对应的整数补码** 除以 **2^小数位数** 

例如，若整数位数为8，小数位数为8，举例如下表：

|     二进制码     | 整数补码 | 定点数值 (8位整数，8位小数) |   备注   |
| :--------------: | :------: | :-------------------------: | :------: |
| 0000_0000_0000_0000 |    0    |             0.0             |   零值   |
| 0000_0001_0000_0000 |   256   |             1.0             |    /    |
| 1111_1111_0000_0000 |   -256   |            -1.0            |    /    |
| 0000_0000_0000_0001 |    1    |         0.00390625         | 正最小值 |
| 1111_1111_1111_1111 |    -1    |         -0.00390625         | 负最大值 |
| 0111_1111_1111_1111 |  32767  |        127.99609375        | 正最大值 |
| 1000_0000_0000_0000 |  -32768  |           -128.0           | 负最小值 |
| 0001_0101_1100_0011 |   5571   |         21.76171875         |    /    |
| 1001_0101_1010_0110 |  -27226  |        -106.3515625        |    /    |


## 浮点数转定点数

### 组合逻辑

```verilog
module Float2Fix #(
    parameter WID_INT     = 8, // 输入浮点数的整数位宽，默认=8
    parameter WID_DEC     = 8, // 输入浮点数的小数位宽，默认=8
    parameter ROUND       = 1  // 结果小数截断时，是否四舍五入，默认开启四舍五入
)(
    input  wire [31:0]                in,       // 输入浮点数(IEEE 754 单精度)
    output reg  [WID_INT+WID_DEC-1:0] out,      // 输出定点数
    output reg                        overflow  // 结果是否溢出，若溢出则为 1'b1
                                                // 若为上溢出，则out被置为最大正值
                                                // 若为下溢出，则out被置为最小负值
);

initial {out, overflow} = '0; // 初始化置0

always @(*) begin
    logic               round;  // 四舍五入标志位
    logic               sign;   // 符号位
    logic        [7:0]  exp2;   // 指数位
    logic        [23:0] val;    // 有效数位
    logic signed [31:0] expi;
    round = '0;
    overflow = '0;
    {sign, exp2, val[22:0]} = in;
    val[23] = 1'b1;
    expi = exp2 - 127 + WID_DEC;
    if(&exp2) // 指数位全1
        overflow = 1'b1;
    else if(in[30:0] != 0) begin
        for(int i = 23; i >= 0; i--) begin
            if(val[i]) begin
                if(expi >= WID_INT + WID_DEC -1)
                    overflow = 1'b1;
                else if(expi >= 0)
                    out[expi]  =1'b1;
                else if(ROUND && expi == -1)
                    round = 1'b1
            end
            expi--;
        end
        if(round) out++;
    end
    if(overflow) begin
        if(sign) begin
            out[WID_INT+WID_DEC-1]      = 1'b1;
            out[WID_INT+WID_DEC-2:0]    = '0;
        end else begin
            out[WID_INT+WID_DEC-1]      = 1'b0;
            out[WID_INT+WID_DEC-2:0]    = '1;
        end
    end else begin
        if(sign)
            out = (~out) + (WID_INT+WID_DEC)'(1);
    ebd
end

endmodule
```

### 流水线

```verilog
module Float2Fix_pipe #(
    parameter WID_INT     = 8, // 输入浮点数的整数位宽，默认=8
    parameter WID_DEC     = 8, // 输入浮点数的小数位宽，默认=8
    parameter ROUND       = 1  // 结果小数截断时，是否四舍五入，默认开启四舍五入
)(
    input  wire [31:0]                in,       // 输入浮点数(IEEE 754 单精度)
    output reg  [WID_INT+WID_DEC-1:0] out,      // 输出定点数
    output reg                        overflow  // 结果是否溢出，若溢出则为 1'b1
                                                // 若为上溢出，则out被置为最大正值
                                                // 若为下溢出，则out被置为最小负值
);

initial {out, overflow} = '0;

// input comb
wire            sign;
wire [7:0]      exp;
wire [23:0]     val;

assign {sign, exp, val[22:0]} = in;
assign val[23] = |exp;

// pipeline-stage1
reg                     signinit    = 1'b0;
reg                     roundinit   = 1'b0; 
reg signed [31:0]       expinit     = '0;
reg [WID_INT+WID_DEC-1] outinit     = '0;


endmodule
```