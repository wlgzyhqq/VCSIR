# 当前 CPU-only 90 MHz 结果

当前为非AI功能验收修正版，位流SHA256：`d9737ea9df4cb56620d413a5af22e38f860020a9bd2d5a8aa055f6562261ccce`。修复前d17073版保存在baseline/cpu-only90-before-non-ai。

## 正式实板结果

| 种子 | 迭代 | 周期 | 秒 | CoreMark | CoreMark/MHz |
|---|---:|---:|---:|---:|---:|
| 0 | 3000 | 1262495327 | 14.0277258556 | 213.862177725 | 2.376246419 |
| 1 | 3000 | 1265759613 | 14.0639957000 | 213.310645423 | 2.370118282 |

每次运行均超过10秒，官方CRC正确；CPU与mtime均为90MHz。第二组同时核对电脑墙钟，偏差小于3%。原始依据：output/reports/cpu-only-board.json及cpu-only-COM12.log。

GCC14.2，RV32IM、O3、无LTO、标准调用松弛、禁用GP松弛；软件浮点库用于格式输出。CoreMark算法与官方头文件未改。固件BIN仍25820字节，SHA前缀7117734cf95e。本轮为正确性补完，两组周期与修复前完全一致，没有跑分收益或回退。

## 时序与资源

90MHz最终多角STA全部约束通过，setup余量+0.639ns。工具估计Fmax95.492MHz，实板仅验证90MHz，不宣称95MHz已验证。

| 口径 | 当前修正版 | 修复前d17073 |
|---|---:|---:|
| CPU含Cache综合LUT | 6293 | 6014 |
| CPU含Cache综合FF | 5139 | 5107 |
| CPU含Cache DRM / APM | 18 / 4 | 18 / 4 |
| 最小SoC布局后LUT | 7099 | 6825 |
| 最小SoC布局后FF | 5686 | 5654 |
| 最小SoC DRM / APM / PLL | 82 / 4 / 1 | 82 / 4 / 1 |
| setup余量ns | +0.639 | +0.799 |

CPU综合取synthesize/cpu_bench_top.snr的u_cpu层级，含两个Cache，排除外设、64KiB程序RAM及分析仪；SoC物理资源取place_route/cpu_bench_top.prr的两类LUT/FF总和。当前CoreMark/CPU综合LUT=0.033984138。本轮CPU综合LUT增加279（约4.64%），最小SoC物理LUT增加274；这是功能修复和综合映射变化的实际成本，不能继续引用旧6014资源。

诊断版8491 LUT/6720 FF/87 DRM属于另一配置，不用于正式版CoreMark/LUT。时序原始文件为report_timing/cpu_bench_top.rtr。

## 功能与限制

诊断版正常与等待/背压模式各55项通过，正式版CPU/Cache功能与其一致，仅去除只读观察端口。41个上游RV32UI程序原生通过，ma_data按EEI未对齐陷阱策略核验；另13项定向程序覆盖缓存、流水线、预测、机器模式异常/中断和嵌套、计数器、UART/GPIO、M扩展。这不是官方ISA认证；未启用S/U、MMU、A/C/F/D。

详细证据见NON_AI_ACCEPTANCE.md；自建片上逻辑分析器采集和流水线分析见NON_AI_WAVEFORM_ANALYSIS.md。LED流水已由用户确认正常，KEY2已采到稳定按下；其余按键由用户确认并要求停止追加验证，未宣称四组合自动通过。电子GPIO和UART路径已自动实测。原FINAL、TF卡和Flash均未修改。

50/75/85/原90MHz基线和历史优化试验保留在baseline/variants。CPU_90MHZ_OPTIMIZATION.md是历史对比，当前修正版以本文件为准，不混用历史资源、当前位流与诊断版波形。
