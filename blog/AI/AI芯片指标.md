# AI 芯片指标与比特位

## 算力单位

**OPS**

* OPS(Operations Per Second)
* 1 TOPS 代表处理器每秒进行一万亿次 $(10^{12})$ 计算
* OPS/W 每瓦特运算性能
* TOPS/W 评价处理器在 1W 功耗下运算能力的性能指标

**MACs**

* Multiply-Accumulate Operations，乘加累积操作
* 1MACs 包含一个乘法操作和一个加法操作
* ～ 2FLOPs，通常 MACs 与 FLOPs 存在一个2倍的关系

**FLOPs**

* Floating Point Operations，浮点运算次数，用来衡量模型计算复杂度，常用作神经网络模型速度的间接衡量标准。对于卷积层而言，FLOPs的计算公式如下：

$$
    \text{FLOPs} = 2 * H * W * C_{\text{in}} * K * K * C_{\text{out}}
$$

**MAC**

* Memory Access Cost，内存占用量，用来评价模型在运行时的内存占用情况。 $$1\times 1$$卷积 FLOPs 为 $$2 * H * W * C_{\text{in}} * C_{\text{out}}$$, 其对应MAC为：

$$
    2 * H * W * (C_{\text{in}} + C_{\text{out}}) + (C_{\text{in}} * C_{\text{out}})
$$

## AI 芯片关键指标（Key Metrics）

**精度 Accuracy**

* 计算精度 (FP32/FP16 etc.)
* 模型结果精度 (ImageNet 78%)

**吞吐量 Throughput**

* 高维张量处理 (high dimension tensor)
* 实时性能 (30 fps or 20 tokens)