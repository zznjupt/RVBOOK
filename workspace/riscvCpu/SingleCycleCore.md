## 单周期CPU设计

## 参考内容

> - The RISC-V Instruction Set Manual ([Volume I](https://github.com/riscv/riscv-isa-manual/releases/download/draft-20210813-7d0006e/riscv-spec.pdf)）
> - 《CPU设计实战》第四章P75-P92
> - 《计算机组成与设计 硬件软件接口（第五版）》第四章4.1-4.4小节
> - [NutShell源码](https://github.com/OSCPU/NutShell)
> - [Trigger：chisel写的4级流水线顺序单发射处理器核](https://github.com/yuhanzhu612/Trigger)

在次之前，你需要对RISC-V指令集有个简单的了解。本文的单周期处理器支持**RISCV64IM**指令。

![image-20220722223959062](https://cdn.jsdelivr.net/gh/JiangFang03/images/img/202207222239163.png)

## 1、译码模块

### 指令集

这里仿照果壳Nutshell的译码方式。通过BitPat匹配指令，同时每一条指令都绑定了具体的指令类型、操作单元以及具体的操作。

```scala
  //RV64MInstr
  def MULW    = BitPat("b0000001_?????_?????_000_?????_0111011")
  def DIVW    = BitPat("b0000001_?????_?????_100_?????_0111011")
  def DIVUW   = BitPat("b0000001_?????_?????_101_?????_0111011")
  def REMW    = BitPat("b0000001_?????_?????_110_?????_0111011")
  def REMUW   = BitPat("b0000001_?????_?????_111_?????_0111011")

  val RV64M_Table = Array(
    MULW           -> List(InstrR, FuType.mdu, MDUOpType.mulw),
    DIVW           -> List(InstrR, FuType.mdu, MDUOpType.divw),
    DIVUW          -> List(InstrR, FuType.mdu, MDUOpType.divuw),
    REMW           -> List(InstrR, FuType.mdu, MDUOpType.remw),
    REMUW          -> List(InstrR, FuType.mdu, MDUOpType.remuw)
  )
```

在译码单元，通过以下命令就可以获取指令的类型和操作类型。

```scala
    val decodeList = ListLookup(instr, Instructions.DecodeDefault, Instructions.DecodeTable)
    val instrType = decodeList(0) 
    val fuType  = decodeList(1)
    val fuOpType = decodeList(2)
```

### 控制信号

译码模块根据`instrType`、`fuType`、`fuOpType`生成以下控制信号：

| 控制信号   | 含义                                              |
| ---------- | ------------------------------------------------- |
| instrType  | 指令类型（I、R、S、B、U、J）                      |
| fuType     | 操作单元（ALU、LSU、MDU等）                       |
| fuOpType   | 具体操作（如add、sub、jal等）                     |
| alu1Type   | ALU操作数1类型，0：寄存器，1：PC                  |
| alu2Type   | ALU操作数2类型，0：寄存器，1：imm                 |
| rfSrc1     | 源寄存器rs                                        |
| rfSrc2     | 源寄存器rt                                        |
| rfWen      | 寄存器堆写使能                                    |
| rfDest     | 目的寄存器                                        |
| imm        | 立即数                                            |
| sel_rf_res | 写回寄存器堆的来源。0：ALU运算结果，1：存储器数据 |
| mem_write  | 存储器写使能                                      |
| mem_read   | 存储器读使能                                      |

## 2、ALU单元

ALU单元根据传入的`aluopType`进行不同的计算。同时负责计算next_Pc和访存的地址

```scala
    val res = LookupTreeDefault(aluOpType, adderRes, List(
        ALUOpType.sll   -> ((src1  << shamt)(XLEN-1, 0)), //逻辑左移
        ALUOpType.srl   -> (src1  >> shamt),
        ALUOpType.sra   -> ((src1.asSInt >> shamt).asUInt),

        ALUOpType.slt   -> ZeroExt(less, XLEN),
        ALUOpType.sltu  -> ZeroExt(less_u, XLEN),

        ALUOpType.xor   -> (src1 ^ src2),
        ALUOpType.or    -> (src1 | src2),
        ALUOpType.and   -> (src1 & src2),
        
        ALUOpType.addw  -> SignExt((adderRes)(31,0), 64),
        ALUOpType.subw  -> SignExt((adderRes)(31,0), 64),
        ALUOpType.sllw  -> SignExt((src1  << shamt)(31, 0),64),
        ALUOpType.srlw  -> SignExt((shsrc1  >> shamt)(31,0),64),
        ALUOpType.sraw  -> SignExt(((shsrc1.asSInt >> shamt).asUInt)(31,0) ,64),

        ALUOpType.beq   -> !(src1 ^ src2).orR,
        ALUOpType.bne   -> (src1 ^ src2).orR,
        ALUOpType.blt   -> less,
        ALUOpType.bltu  -> less_u,
        ALUOpType.bge   -> !less,
        ALUOpType.bgeu  -> !less_u,
    ))
```

### 特殊指令的处理

需要特别关注的指令：

#### **`LUI：`**

加载长立即数到rd中。操作数1：0号寄存器。操作数2：立即数。零号寄存器加上立即数写入rd寄存器

💡 ALU加法操作：rd = reg(0)+imm

#### **`AUIPC：`**

PC加上立即数。操作数1：pc；操作数2：立即数

 💡 ALU加法操作：rd = PC+imm

#### `JAL：`无条件跳转 

（JAL、JALR可以在译码阶段就能获得跳转地址。）操作数1：pc；操作数2：立即数(offset)

记录下一条pc值(rd = pc+4), pc+4应该作为ALU的运算结果，最终写回寄存器。同时，需要计算目标地址（nextPc)设为 pc + offset（imm)

💡 ALU加法操作：res = pc + 4;  target = pc+offset

#### **`JALR：`**链接并跳转

操作数1：rs1（寄存器读端口1的值）操作数2：立即数（offset)。

记录下一条pc值(rd = pc+4), pc+4应该作为ALU的运算结果，最终写回寄存器。同时，需要计算目标地址（nextPc)设为 reg + offset（imm)

 💡 ALU加法操作：res = pc + 4;  target = reg+offset

#### **B类**指令

操作数1：rs1（寄存器读端口1的值）操作数2：rs2（寄存器读端口1的值）

ALU比较rs1和rs2（相等、小于、大于……）。ALU得出是否跳转：taken。如果taken，

设置target_pc = pc + offset

## 3、MDU乘除法单元

乘除法计算。目前直接用`*`、`/`和`%`

```scala
    val mulRes = src1 * src2
    val res = LookupTreeDefault(mduOpType, mulRes, List(
        MDUOpType.mul       -> (src1 * src2)(63, 0),
        MDUOpType.mulh      -> ((src1.asSInt * src2.asSInt).asUInt >> 32),

        MDUOpType.div        ->  (src1.asSInt / src2.asSInt).asUInt,
        MDUOpType.divu       -> (src1 / src2)(63,0),

        MDUOpType.rem        -> (src1.asSInt % src2.asSInt).asUInt,
        MDUOpType.remu       -> (src1 % src2),
		……
    ))
```

## 4、存储模块

①使用C语言申请一个可读写的大数组，模拟内存。

```c
uint8_t pmem[CONFIG_MSIZE];
extern "C" void pmem_read(long long raddr, long long *rdata) {
  // 总是读取地址为`raddr & ~0x7ull`的8字节返回给`rdata`
}
extern "C" void pmem_write(long long waddr, long long wdata, char wmask) {
  // 总是往地址为`waddr & ~0x7ull`的8字节按写掩码`wmask`写入`wdata`
  // `wmask`中每比特表示`wdata`中1个字节的掩码,
  // 如`wmask = 0x3`代表只写入最低2个字节, 内存中的其它字节保持不变
}
```

②用verilog写存储器部分，使用DPI-C机制，调用读写存储器函数

```verilog
import "DPI-C" function void pmem_read(
  input longint raddr, output longint rdata);
import "DPI-C" function void pmem_write(
  input longint waddr, input longint wdata, input byte wmask);

XXXX
always @(*) begin
      if(mem_read == 1'b1)
      begin
         pmem_read(address, read_data);
      end
      if(mem_write == 1'b1) 
      begin
         pmem_write(address, write_data, w_mask);
      end
end
```

③使用chisel的blackbox机制包裹PmemHarness.v

```verilog
class PmemHarness extends BlackBox with HasBlackBoxResource {
    val io = IO(new Bundle{
        val clock = Input(Clock())
        val reset = Input(Bool())
        val mem_read = Input(UInt(1.W))//control signal
        val mem_write = Input(UInt(1.W))//control signal
     	……
    })
  addResource("/vsrc/PmemHarness.v")
}
```

pmem_read和pmem_write中模拟了64位总线的行为: 它们只支持地址按8字节对齐的读写, 其中读操作总是返回按8字节对齐读出的数据, 需要由RTL代码根据读地址选择出需要的部分:

```scala
val mask = LookupTreeDefault(lsuOpType, "b1111_1111".U, List(
      LSUOpType.sb -> "b0000_0001".U,
      LSUOpType.sh -> "b0000_0011".U,
      LSUOpType.sw -> "b0000_1111".U,
      LSUOpType.sd -> "b1111_1111".U
  ))
  mem.io.w_mask := mask

  val rdataSel = mem.io.read_data
  val rdataPartialLoad = LookupTreeDefault(lsuOpType, "b0".U(64.W), List(
      LSUOpType.lb   -> SignExt(rdataSel(7, 0) , 64),
      LSUOpType.lh   -> SignExt(rdataSel(15, 0), 64),
      LSUOpType.lw   -> SignExt(rdataSel(31, 0), 64),
      LSUOpType.ld   -> SignExt(rdataSel(63, 0), 64),
      LSUOpType.lbu  -> ZeroExt(rdataSel(7, 0) , 64),
      LSUOpType.lhu  -> ZeroExt(rdataSel(15, 0), 64),
      LSUOpType.lwu  -> ZeroExt(rdataSel(31, 0), 64)
  ))
  io.read_data := rdataPartialLoad
```

