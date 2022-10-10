# 总线

## 一、概述



## 二、AXI4 总线



## 三、流水线中加入总线

![image-20220808212230696](C:/Users/DELL/AppData/Roaming/Typora/typora-user-images/image-20220808212230696.png)

### 1、取指阶段访问总线

#### ①设置与imem的信号

最终会通过ar通道发送给sram。sram将读出的指令通过r通道返回给取指模块

```scala
    io.imem.inst_valid  := !stall
    io.imem.inst_req    := REQ_READ
    io.imem.inst_addr   := npc
    io.imem.inst_size   := SIZE_W //64
```

#### ②处理分支跳转

- 新增寄存器保存分支跳转结果

在IF阶段，需要使用寄存器保存分支跳转的结果。执行级的分支跳转计算只会保持一个周期，即redirec.valid只会有效一个周期。因此如果不适用寄存器进行保存，会导致后续的npc都会计算错误。当指令返回时，此时的redirect.valid永远为false，pc永远不能正确更新。

```scala
val reg_r_target = RegInit(0.U(64.W))
val reg_r_valid  = RegInit(false.B)    
val branch_stall = RegInit(false.B)
    when(io.redirect.valid){
        reg_r_target := io.redirect.target
        reg_r_valid  := true.B
        branch_stall := true.B
    }   
val snpc        = pc + 4.U 
val npc         = Mux(reg_r_valid, reg_r_target, snpc)
```

- 修改pc更新条件

在单周期的情况下，npc在同一个周期内就能获得分支跳转的结果，进而向总线发送正确的指令地址。但是在五级流水的情况下，分支跳转的结果在执行级才能确定，即无法在当前周期获取正确的分支跳转结果。此时已经向总线发出了分支不发生情况下的pc值，且是无法取消的。因此第一次返回的imem.inst_ready信号是无效的指令。需要继续向总线发出读请求。

因此新增了branch_stall寄存器，表示前一条指令是分支指令，此时应该放弃第一次向总线读出的指令。

  ```scala
      val pc_update = WireInit(false.B)
      when(io.imem.inst_ready && branch_stall){//第一次取得的inst无效
          pc_update       := false.B
          branch_stall    := false.B 
      }.elsewhen(io.imem.inst_ready){
          pc_update       := true.B 
      }
  ```

  

#### ③ 设置给下一级的信号

REG_IF_ID流水线的valid信号置为false，将指令设NOP

当IF阶段正在等待总线返回指令的过程中，还没有正确的指令返回，因此后续阶段不能执行任何有效操作。因此，需要将IF_ID_REG的valid信号置为false，同时将NOP指令插入流水线寄存器中。

```scala
    val inst_valid      = RegInit(false.B)
    when(pc_update && !stall){
        pc          := npc
        inst        := io.imem.inst_read

        inst_valid  := true.B 
        reg_r_target := "b0".U(64.W)
        reg_r_valid  := false.B 
    }.otherwise{
        inst_valid := false.B
    }
    io.out.valid    := Mux(inst_valid, true.B, false.B)
    io.out.pc       := pc
    io.out.inst     := Mux(inst_valid, inst, Instructions.NOP)
```

### 2、访存阶段访问总线

#### ①增加MEM级状态

新增空闲state_idle、state_sram、state_end三种状态。

- state_idle: 处于空闲状态，且当前是访存类指令时，将状态切换到sram
- state_sram：表示正在读或者写数据。当接收到总线发出的data_ready信号时，表明读写操作完成，准备向结束状态切换，同时将out_valid寄存器置为高，表明此时MEM级的输出有效。
- state_end：将out_valid信号置为false，因此该信号只保存一个周期。同时准备向idle状态切换

```scala
 val state_idle :: state_sram :: state_end :: Nil = Enum(3)
  val mem_state     = RegInit(state_idle)
  val rdata         = RegInit(UInt(64.W), 0.U)
  val sram_ready    = io.dmem.data_ready
  //状态机
  val is_valid          =  (mem_state === state_idle) || (mem_state === state_sram && (!sram_ready))
  io.dmem.data_valid    := is_mem && is_valid
	……
  io.mem_busy  := ((mem_state === state_idle) && is_mem) || (mem_state === state_sram)
  
```

#### ②取指、译码执行级内容保存

当前指令为访存类，且处于idle、sram状态表明访存级忙碌。需要向顶层发出访存级忙碌信号，要停顿取指、译码、执行级，保存当前的pc值，已经译码的结果，执行级的运算结果。即需要向IF级、REG_IF_ID、REG_ID_EXE、REG_EXE_MEM的暂停信号（stall)置为高。

```scala
    val mem_busy        = mem.io.mem_busy
    val stall = hd.io.stall || exe_busy || mem_busy
    ifu.io.stall        := stall //指令冲突或执行级忙碌时停顿IF
    reg_if_id.io.stall  := stall
    idu.io.stall        := hd.io.stall
    reg_id_ex.io.stall  := exe_busy || mem_busy
    reg_ex_mem.io.stall := mem_busy 
```

#### ③写回级不进行有效操作

当前访存级处于忙碌状态时，此时写回级修改寄存器的值，且不能提交指令，因为当前指令还一直处于访存阶段。需要将REG_MEM_WB的valid信号置为false。

```scala
 io.out.valid        := Mux(is_mem, Mux(mem_busy, false.B, true.B), io.in.valid)
```

