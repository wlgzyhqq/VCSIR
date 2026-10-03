# 当前 DDR3 构建状态

2026-10-02，PDS 2022.2-SP1-Lite，`FINAL.pds` / `final_top`，PGL50H-6IFBG484。

## 实现结果

- 当前 DDR3 RTL 已完成 Compile、Synthesize、Device Map、Place & Route。
- 布线报告：`Design 'final_top' has been placed and routed successfully.`
- 最终快/慢角时序汇总：**All Constraints Met**；setup、hold、recovery、removal 的失败端点和 TNS/THS 均为零。
- CPU 50 MHz：慢角 setup WNS **0.937 ns**；慢角 hold **0.255 ns**，快角 hold **0.197 ns**。
- DDR UI 100 MHz：慢角 setup WNS **0.502 ns**；慢角 hold **0.154 ns**，快角 hold **0.068 ns**。
- 资源映射：LUT **11590/42800**，DRM **18/134**，IO **88/296**。原 64 KiB DRM 主存已移除；DDR3 为 1 GiB 主存。18 块 DRM 全部属于 I/D Cache，DDR 控制器内部缓冲使用 70 个分布式 RAM 资源；布线后的物理 LUT 分类合计为 11601。
- 固件编译产物共 46 份；当前 C demo 二进制为 680 字节，补齐为 704 字节启动镜像。启动装载器写入 DDR3 并逐行读回比较后才释放 CPU。
- 比特流生成结果与摘要在流程结束后记录于 `build/ddr-delivery.json`。

证据：

- `../build/pds-ddr-build.log`
- `../place_route/final_top_timing_summary_after_hold_fix.txt`
- `../place_route/final_top.prr`
- `../device_map/final_top.dmr`

## 时钟域与复位

CPU 使用独立 GTP_CLKBUFG。CPU/UI 请求与响应采用双级 toggle 同步，多位载荷在整个握手期间保持不变，并接受 15 ns 数据路径约束。复位例外限定到异步复位同步器和 IP 启动 IO 复位；正常 CPU、DDR 控制器及 PHY 数据路径保留检查。DDR 控制器增加 UI 域同步释放复位，PHY 训练错误状态增加参考域两级同步。详细设计见 `ddr3-memory.md`。

## 验证边界

按用户要求没有运行仿真，也没有下载到板上。以上结果证明当前工程可以综合、布线并满足已声明的时序约束，不能证明实际 DDR 初始化/训练、总线功能或 CPU 指令测试已通过。此前已确认的串口/按键运行属于旧片内主存版本。

仍有共享管脚提示、参考核心未使用信号、异步 UART/按键/LED 外部延迟提示，以及 PDS 对部分 IP IO 模型引脚的 Timing-4096 警告。全部 88 个 IO 的位置已检查；`All Constraints Met` 只覆盖已声明的时序检查，不能代替板上电气与功能验收。

原片内主存版本及原比特流保存在 `../backups/BRAM_20261002/`。旧 `sim/soc_tb.sv` 依赖原 RAM，需要接入 DDR 模型后才能用于当前顶层。
