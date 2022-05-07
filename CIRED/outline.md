# **CIRED论文大纲**

# **0、切入点**

聚焦于电力**主控芯片？配电融合终端？**

# **摘要**

泛在电力物联网要求电力系统从原来的集中监控模式转变为分布式、物联网化的泛在模式。配电物联网终端需要高性能、低功耗（、安全性）的微处理器（MCU）作为支撑。而RISC-V指令集因其精简、开源、支持自定义扩展等优势，在配电融合终端中具有广泛的使用前景。本文针对基于RISC-V指令集架构的融合终端，研究和探索MCU级的攻击和防御策略对其在安全、性能、应用支持等方面的影响。该研究采用*软件仿真方法结合FPGA原型验证*进行，为面向配电终端应用的MCU架构设计提供新方案。

**关键词：**电力终端、数据保护、RISC-V、攻击与防御

# 1.**引言**

介绍电力融合终端与芯片安全的关系，引入对芯片安全的讨论；

电力网络系统中的安全防护要防止信息数据被非授权访问者的窃取、篡改和破坏。利用幽灵攻击读取终端的秘密数据对电力网络系统的安全造成威胁。

BOOM高性能乱序处理器——>可用于电力行业？

- - 通用芯片可满足电力领域当前的需求
  - BOOM开源、高性能、低功耗

## **1.1 配电终端安全防护现状及风险**

## **1.2  开源 RISC-V 处理器 BOOM**

## **1.3 幽灵与熔断**

# 2.**Speculative attack replication** 

## **2.1 Implementation Details**

## **2.2 Bounds Check Bypass Attack（V1）**

## **2.3** **Branch Target Injection Attack（V2）**

# 3.**Result and analysis of XXX**

## **3.1 Experimental Setup** **and Results**

## **3.2**  **Experimental analysis on hardware platforms**

3.1 安全性分析security analysis

3.2 性能开销评估

# 4.**Mitigation Options**

芯片层级防御方法总结

通过提出幽灵攻击防御策略 增强RISC-V安全性

能否提出针对电力芯片安全的轻量级的缓解措施

# 5.**相关工作**

- 电网安全保护措施，从不同层的措施—》芯片层、终端层等
- RISC-V架构安全

# 6.**总结**

## **6.1 主要贡献**

- 基于RISC-V架构用于电网保护的研究工作目前较少
- 进行了电力芯片常见攻击及防御方法的验证

# **参考文献**

# **参考资料**

1. [电力主控芯片有了“中国芯”](https://m.thepaper.cn/baijiahao_14373394)
2. [RISC-V’s Role in Securing IoT-Connected Devices](https://www.allaboutcircuits.com/industry-articles/risc-vs-role-in-securing-iot-devices/)
3. [基于RISC-V的MCU内核TaiShan200](https://www.eet-china.com/news/202112201755.html)
4. [Spectre and Meltdown explained: A comprehensive guide for professionals](https://www.techrepublic.com/article/spectre-and-meltdown-explained-a-comprehensive-guide-for-professionals/)
