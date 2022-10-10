
## 2022-06-15
#### 1.qemu-riscv64运行spectre V1代码时出现：**Illegal instruction**
通过gdb调试发现，问题在于src/crt.S:52，相应的指令为`csrs mstatus, t0`
