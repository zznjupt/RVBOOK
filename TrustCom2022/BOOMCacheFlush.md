smallBoomConfg的参数：

```c
#define L1_BLOCK_SZ_BYTES 64// L1缓存行大小为64bytes
#define L1_BLOCK_BITS 6 // 对应6位offset

#define L1_SETS 64 // 64个SET
#define L1_SET_BITS 6 // 对应6位set index（Idx）

#define L1_WAYS 4 //4路组相连
#define L1_SZ_BYTES (L1_SETS*L1_WAYS*L1_BLOCK_SZ_BYTES) // cache size，代表cache可以缓存最大数据的大小

#define FULL_MASK 0xFFFFFFFFFFFFFFFF
// tag中保存的是整个地址位宽去除index和offset使用的bit剩余部分
#define TAG_MASK (FULL_MASK << (L1_SET_BITS + L1_BLOCK_BITS)) 
// offset mask
#define OFF_MASK (~(FULL_MASK << L1_BLOCK_BITS))
// cache line (set) mask
#define SET_MASK (~(TAG_MASK | OFF_MASK))
```

冲刷函数流程：

入口参数：

* 需要从cache中冲刷掉的内容在主存中的起始地址`addr`
* 冲刷的数据长度`sz`（以字节bytes为单位）

流程：

* 申请一个五倍cache大小的数组，由于未初始化，数组里的数据为随机垃圾数据，其所在地址起点为
```c
uint8_t dummyMem[5 * L1_SZ_BYTES];
```

* 首先计算出想要冲刷`sz`大小的数据需要冲刷的Set数：
```c
uint64_t numSetsClear = sz >> L1_BLOCK_BITS;
if ((sz & OFF_MASK) != 0) {
		numSetsClear += 1;
}
if (numSetsClear > L1_SETS) {
  numSetsClear = L1_SETS;
}
```

可以看出计算方式为 需要冲刷的set数 = 冲刷的数据长度 $sz\div 64$ (缓存行大小)，如果冲刷的数据长度大于整个L1 cache大小，那么就冲刷所有的set

* 准备中间变量和指定内存地址对应cache仲裁器的tag部分

```c
uint8_t dummy = 0;
uint64_t alignedMem = (((uint64_t)dummyMem) + L1_SZ_BYTES) & TAG_MASK;
```

* 进入flush循环

```c
for (uint64_t i = 0; i < numSetsClear; ++i) {
		uint64_t setOffset = (((addr & SET_MASK) >> L1_BLOCK_BITS) + i) << L1_BLOCK_BITS;
  	//计算需要冲刷的每一个set的指定内存地址对应cache仲裁器的idx部分
  	for(uint64_t j = 0; j < 4 * L1_WAYS; ++j) {
   			uint64_t wayOffset = j << (L1_BLOCK_BITS + L1_SET_BITS);
 				//由于采取随机替换策略，因此驱逐4*4次不同的tag，驱逐概率 = 1-0.75^16 ≈ 0.99
    		dummy = *((uint8_t*)(alignedMem + setOffset + wayOffset));
  	}
}
```

* 通过这条语句`dummy = *((uint8_t*)(alignedMem+setOffset+wayOffset))` 来加载指定地址的垃圾数据到`dummy`数组中，同时CPU会把这些垃圾数据更新到data cache根据映射关系对应的相应部分，从而实现对data cache指定空间的刷新操作