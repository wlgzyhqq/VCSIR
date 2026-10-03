# 仿真入口状态

用户要求先写且不运行仿真。本次 DDR3 改动没有运行任何仿真软件。

`soc_tb.sv` 是原片内主存版本的测试平台，它引用 `dut.u_bus.ram`，不能直接用于当前 DDR3 顶层。原测试程序仍可编译，但没有本次 DDR3 功能通过报告。

DDR IP 的官方 Micron 器件模型和示例在 `build/ddr-reference/07_ddr3_test/ipcore/ddr3_test/example_design/bench/`。后续需要将两个 x16 模型接到新顶层并更新固件装载、reset/boot等待与性能统计，再开展回归。
