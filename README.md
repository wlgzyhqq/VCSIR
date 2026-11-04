本项目面向 **2026 年 FPGA 创新设计大赛紫光同创赛道赛题 1（RISC-V CPU 设计）**。

# RISC-V 处理器与离线视觉检测系统

基于 MES50HP（PGL50H）开发板，将 RISC-V 处理器与 YOLOv5n 卷积加速器集成在 FPGA 上，实现从 TF 卡读取图像、板上目标检测和 HDMI 结果显示。

- **处理器**：RV32IM，90 MHz，支持两路组相联指令与数据缓存、动态分支预测及机器模式异常和中断。
- **视觉加速**：64 路 INT8 卷积计算，CPU 完成图像预处理、非卷积算子和检测框后处理。
- **独立运行**：QSPI Flash 保存 FPGA 配置，TF 卡保存固件、模型和图像，上电后自动启动。

当前完整工程位于 [`submission2026/`](submission2026/)。仓库根目录其余工程文件保留为早期开发版本。

## 目录

| 目录 | 内容 |
|---|---|
| [cpu_bench/](submission2026/cpu_bench/) | CPU 源码、独立跑分工程和功能验证 |
| [yolo/](submission2026/yolo/) | YOLO 应用 RTL、固件、模型及 PDS 工程 |
| [tools/](submission2026/tools/) | 跑分复测与 TF 镜像生成工具 |
| [release/](submission2026/release/) | 已验证的 FPGA 位流和固化文件 |
| [docs/](submission2026/docs/) | 技术报告、构建说明及 Flash 操作说明 |
| [evidence/](submission2026/evidence/) | 原始串口日志、推理对照和固化验收记录 |

详细设计见 [技术报告](submission2026/docs/技术报告.docx)，重建与运行方法见 [构建说明](submission2026/docs/BUILD.md)。开源组件来源和许可证说明一并保留。

**关键词：RISC-V 处理器、FPGA 异构加速、边缘目标检测。**
