# Cache

## 1、Cache 简介



## 2、ICache实现

### 2.1  icache内部状态模型

#### ① state_idle

当接收到IF级的读指令请求时（inst_valid为高），状态切换到查询状态

```scala
    is(state_idle){//空闲状态
      when(in.inst_valid){
        icache_state := state_lookup
      }
    }
```



#### ② state_lookup 查询状态

- 再次IF阶段读请求

  - 为低时，返回空闲状态

  - 将请求的地址存放到地址寄存器addr_reg中
- 判断是否命中

  - 如果命中，直接**状态切换**为空闲状态
  - 如果不命中，**状态切换**到state_refill

```scala
is(state_lookup){//查询cache，判断是否命中
    when(in.inst_valid){
        addr_reg := in.inst_addr
        when(!hit){
            icache_state := state_miss
        }
    }.otherwise{
        icache_state := state_idle
    }
}
```



#### ③ state_refill  发生cache缺失,需要充填cache

- 使用aix_instr_back表明总线是否返回读到的指令

  - 为false，向总线发出读请求
  - 为true，**状态切换**到update_meta状态

- 当总线返回有效指令时

  - 修改aix_instr_back的值为true
  - 同时向data_array中写数据：设置data_array_wen、data_array_data
  - 拉低向总线发出的valid信号

  ```scala
  is(state_refill){//发生cache miss，需要向总线发出读请求
      when(aix_instr_back){
          icache_state  := state_refill_end
      }.otherwise{              //向总线发出读数据请求
          instr_valid_o := true.B 
          instr_req_o   := REQ_READ
          instr_addr_o  := addr_reg
          instr_size_o  := SIZE_W
      }
      when(out.inst_ready){   //总线返回指令。将数据填充到data_array
          aix_instr_back    := true.B 
          data_array_wen    := true.B 
          data_array_data   := out.inst_read
          instr_valid_o     := false.B
      }
  }
  ```
#### ④ state_update_meta 更新

  - **状态切换**到lookup
  - aix_instr_back设为false
  - data_array写使能拉低  
  - 更新valid_table、tag_table、offset_table

  ```scala
  is(state_update_meta){//更新meta_array
      aix_instr_back     := false.B 
      data_array_wen     := false.B 
  
      valid_tb(req_index)   := true.B 
      tag_tb(req_index)     := req_tag
      offset_tb(req_index)  := req_offset
  
      icache_state          := state_lookup
  }
  ```

  ### 2.2 总线与data_array操作

- 总线的读请求
  - 只有在refill阶段才会向总线发出读请求（valid信号为高）
  - 其他状态下要把ivalid信号置为false
- data_array的使能信号
  - 当总线返回内存中的指令时，**写使能**才置为高
  - 每周期都会返回读数据

## 3、DCache实现

### 3.1 Dcache的内部状态转换

#### ① state_idle 空闲状态

- 将data_ready和data_array的写使能设为false
- 当模块输入的data_valid信号为高时，表明有读写请求，**状态转换**到lookup

#### ② state_lookup 查询状态

- cache命中

  - data_ready信号置为高，表明数据准备好
  - 为了更新元数据项表（读操作更新了也不影响）
  - 更新data_array，写使能设为in.data_req(读为0，写为1)
  - 如果是写，更新脏位

- cache未命中

  - 脏位为1，需要将cache内容写回内存。**状态转换**为state_wb
  - 脏为为0，cache和内存内容一致，不需要写回。**状态转换**为state_refill

  

#### ③ state_wb 写回状态

- 向总线发出写请求，将当前cache行数据写出
- 当总线返回ready信号时，数据写入内存完成。拉低valid信号
- 状态转换为wb_end
- wb_end直接**状态转换**为state_refill

#### ④ state_refill 充填状态

- 使用aix_data_back表明总线是否返回读到的内存数据
  - 为false，向总线发出读请求
  - 为true，**状态切换**到update_meta状态

- 当总线返回有效指令时

  - 修改aix_data_back的值为true

  - 同时向data_array中写数据：设置data_array_wen、data_array_data。写掩码设为全1

  - 拉低向总线发出的valid信号

#### ⑤ state_update_meta 更新原数据项状态

  - **状态切换**到idel
  - aix_instr_back设为false
  - data_array写使能拉低  
  - data_ready信号置为高。表明已经读写完成
  - 更新valid_table、tag_table、offset_table、dirty_table

### 3.2总线与data_array操作

- 总线读写
  - 只有在wb状态才会向总线发出**写请求**
  - 只有在refill状态才会向总线发出**读请求**

- data_array
  - cache命中时，若是写数据，更新data_array。同时脏位置为高
  - 总线读，返回有效内存数据时，更新data_array
  - 每个周期都会从data_array中读出cache行
