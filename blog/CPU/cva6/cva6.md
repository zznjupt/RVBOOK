<img src='https://img.shields.io/badge/语言-systemverilog_(IEEE1800_2017)-CAD09D.svg'> 

# 顺序单发六级流水线标量处理器核-RV64GC cva6(Ariane)

> cva6系列文章(一) 处理器解析<br>
> reference:<br>
> [kaitoukito: Ariane处理器源码解析系列](https://zhuanlan.zhihu.com/p/444233485)<br>
> [sazc: cva6架构概述](https://sazczmh.github.io/sazc-tech-notes/cva6-analysis-notes/cva6-jia-gou-gai-shu/)<br>
> [cva6 github仓库](https://github.com/openhwgroup/cva6)

## 总览

PULP(Parallel Ultra-Low-Power) 平台在2019年启动了 Ariane 开源处理器项目，由 OpenHW Group 维护，后改名为cva6。<br>
cva6 core 是一个可配置的 core，在典型64bit配置下，cva6 是一个 **RV64GC** ISA、**6-stage** **顺序单发射** **64bit** CPU core，完全实现了 Volume I: User-Level ISA V 2.1 中指定的 I、M 和 C 扩展以及 draft privilege extension 1.10，且实现了三个**特权级 M、S、U** 以完全支持类Unix操作系统。



![cva6 overview](./image/ariane_overview.png)

PULP 平台的设计理念之一就是低功耗，所以目前还没有见到Superscalar&OoO的 CPU core 项目，cva6 作为PULP-RVcore系列的性能大哥，是本菜鸡的研究重点，它的设计目标也很纯粹简单：以合理的速度和 IPC 运行完整的OS，为达到必要的速度，core采用 6-stage 流水线设计。为了提升 IPC，core 使用了记分板技术(scoreboard)，该记分板应通过发布与数据无关的指令来隐藏data RAM(cache)的延迟。instruction RAM（or L1 I-cache）在命中时有1个周期的访问延迟，而访问数据 RAM（or L1 D-cache）在命中时有3个周期的延迟。core 拥有独立的 TLBs，一个硬件 PTW和基于分支预测(BHT(PHT)+BTB)的**推测执行机制**，设计的首要设计目标是减少关键路径的长度。

处理器总览

* **RV64GC**
    * 实现了RV64IMAFDC(RV64GC)，即支持整数指令I、整数乘除M、单精度浮点F、双精度浮点D、原子指令A、压缩指令C。一个可以运行的RISC-V处理器仅支持整数指令集I即可，其他均为配置选项
* **6级流水线**
    * PC Generation—PC生成级
    * Instruction Fetch—取指级
    * Instruction Decode—指令译码级
    * Issue—指令发射级
    * Execute—指令执行级
    * Commit—指令提交级
* **流水线的动态调度**
    * **Scoreboard**：计分板技术，起源于1965年交付的CDC6000，记录并避免WAW、WAR、RAW数据依赖性，通过动态调度流水线的方式，实现乱序执行，提高流水线效率
    * **Register renaming**：寄存器重命名，解决数据依赖性问题，支持乱序执行，但cva6暂未完全实现
* **动态分支预测**
    * **BTB**：branch target buffer，类似cache结构的分支目标缓冲区，与cache不同的地方大概是用于索引表项的Tag为压缩后的PC/历史信息，功能为缓存预测的分支目标地址
    * **BHT**：branch history table 基于2bit饱和计数器的模式历史表(PHT)，这两个名字指代同一个部件，功能为预测跳转方向
    * **RAS**：return address stack 分支返回栈(aka **RSB** return stack buffer)，功能为存储最近的系统调用指令地址，遇到ret指令时弹出存储的地址
* **OS 支持**
    * 实现了RISC-V的三种特权模式，分别是**机器模式M**-Machine Mode、**监督模式S**-Supervisor Mode、**用户模式U**-User Mode
    * 拥有ITLB、DTLB、PTW实现虚拟地址到物理地址的快速翻译
    * 拥有可灵活配置的4路组相连L1-ICache与L1-DCache


本文选择的 core configuration 为项目工程中`core/include/cv64a6_imafdc_sv39_config_pkg.sv`配置文件，并使用[RISC-V sv39虚拟内存系统](https://zhuanlan.zhihu.com/p/444233485)：
```verilog
package cva6_config_pkg;

    typedef enum logic {
      WB = 0,
      WT = 1
    } cache_type_t ;

    localparam CVA6ConfigXlen = 64;

    localparam CVA6ConfigFpuEn = 1;
    localparam CVA6ConfigF16En = 0;
    localparam CVA6ConfigF16AltEn = 0;
    localparam CVA6ConfigF8En = 0;
    localparam CVA6ConfigFVecEn = 0;

    localparam CVA6ConfigCvxifEn = 1;
    localparam CVA6ConfigCExtEn = 1;
    localparam CVA6ConfigAExtEn = 1;
    localparam CVA6ConfigBExtEn = 1;

    localparam CVA6ConfigAxiIdWidth = 4;
    localparam CVA6ConfigAxiAddrWidth = 64;
    localparam CVA6ConfigAxiDataWidth = 64;
    localparam CVA6ConfigFetchUserEn = 0;
    localparam CVA6ConfigFetchUserWidth = CVA6ConfigXlen;
    localparam CVA6ConfigDataUserEn = 0;
    localparam CVA6ConfigDataUserWidth = CVA6ConfigXlen;

    localparam CVA6ConfigRenameEn = 0;

    localparam CVA6ConfigIcacheByteSize = 16384;
    localparam CVA6ConfigIcacheSetAssoc = 4;
    localparam CVA6ConfigIcacheLineWidth = 128;
    localparam CVA6ConfigDcacheByteSize = 32768;
    localparam CVA6ConfigDcacheSetAssoc = 8;
    localparam CVA6ConfigDcacheLineWidth = 128;

    localparam CVA6ConfigDcacheIdWidth = 1;
    localparam CVA6ConfigMemTidWidth = 2;

    localparam CVA6ConfigWtDcacheWbufDepth = 8;

    localparam CVA6ConfigNrCommitPorts = 2;
    localparam CVA6ConfigNrScoreboardEntries = 8;

    localparam CVA6ConfigFPGAEn = 0;

    localparam CVA6ConfigNrLoadPipeRegs = 1;
    localparam CVA6ConfigNrStorePipeRegs = 0;

    localparam CVA6ConfigInstrTlbEntries = 16;
    localparam CVA6ConfigDataTlbEntries = 16;

    localparam CVA6ConfigRASDepth = 2;
    localparam CVA6ConfigBTBEntries = 32;
    localparam CVA6ConfigBHTEntries = 128;

    localparam CVA6ConfigNrPMPEntries = 8;

    localparam CVA6ConfigPerfCounterEn = 1;

    localparam CVA6ConfigDcacheType = WT;

    localparam CVA6ConfigMmuPresent = 1;

    `define RVFI_PORT

    // Do not modify
    `ifdef RVFI_PORT
       localparam CVA6ConfigRvfiTrace = 1;
    `else
       localparam CVA6ConfigRvfiTrace = 0;
    `endif

endpackage
```

## Frontend(处理器前端流水线)








