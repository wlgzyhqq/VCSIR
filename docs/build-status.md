# 实际构建结果

2026-10-02，PDS 2022.2-SP1-Lite，本机 `build_all.ps1 -RunImplementation` 返回 0。

- 46 份 RV32I/Zicsr/Zifencei 固件编译成功：C demo、42 个 rv32ui、3 个专项程序。
- PDS Compile、Synthesize、Device Map、Place & Route 均完成；完整日志没有 `E:` 错误。
- 布线报告：`Design 'final_top' has been placed and routed successfully.`
- 50 MHz sys_clk：慢角 setup WNS=0.337 ns；慢角 hold WHS=0.310 ns；快角 hold WHS=0.249 ns；TNS/THS=0，报告 `All Constraints Met`。
- DRM 82/134（62%）；IO 16/296；布局后 LUT 6254（两类资源3979+2275）。

证据：`../build/pds-build.log`、`../place_route/final_top_timing_summary_after_hold_fix.txt`、`../place_route/final_top_prr.prt`。

仍有共享引脚提示（K18、AB13、Y13）、参考核心未使用信号/复位等警告，以及异步按键/串口/LED 无同步外部输入输出延迟的 Timing-4086/4087 提示。16 个 IO 的物理管脚均已约束；这里没有外部同步器件接口的时序预算，内部 50 MHz 时序通过不能代替板上电气和功能验收。此前 `cpu_jtag_tck` 的 GLOBAL_CLOCK 错误未在 FINAL 出现。

按用户要求不运行仿真：没有逐指令执行通过证据，没有流水线实测波形，没有预测/Cache 性能实测，没有板上 UART/LED 运行结果。未运行 bitstream 生成和下载。上述构建结果证明当前 RTL 能综合并布线，不能替代功能验证。
