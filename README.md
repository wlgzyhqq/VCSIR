# FINAL：MES50HP RV32I SoC

顶层 `rtl/final_top.v`，PDS 工程 `FINAL.pds`。复用 UltraEmbedded BSD CPU/Cache，加入本板引脚约束、动态预测、机器模式中断、UART/GPIO、64 KiB 主存及软件。当前按用户要求不运行仿真；测试源代码与固件编译成功不等于指令测试通过，也没有板上运行结果。

## 交付内容

| 要求 | 实现 | 验收材料 |
|---|---|---|
| B01 | RV32I 单发射 CPU；Zicsr/Zifencei；关闭 M、C、MMU | 42 个 rv32ui 程序、C demo；待执行 |
| B02 | IF/ID/EX/MEM/WB 五级；旁路、load-use 等待、访存暂停、错误预测清空 | `firmware/test_pipeline.S`；`sim/soc_tb.sv` 波形/统计；待执行 |
| B03 | UART 115200 8N1、GPIO、按键/LED；CPU 软件输出结果 | `firmware/demo.c`、`platform.h`；待上板 |
| H01 | I/D 各 16 KiB、2 路、256 组、32 字节行；8 拍 AXI 回填 | `firmware/test_cache.S`；突发/停顿计数；待执行 |
| H02 | 32 项 BTB、2 位饱和计数；M 模式陷阱/中断、MRET、直接/向量入口 | `firmware/test_traps.S`；待执行 |

完整范围、地址表、流水线与硬件映射见 [架构说明](docs/architecture.md)。H02 的实现范围是单核 M 模式，不含 S/U、虚拟内存、PMP、多核、NMI 和调试规范；不能据此宣称完整 RISC-V 特权架构认证。

## 构建

本机工具：PDS 2022.2-SP1-Lite，`C:/msys64/ucrt64/bin/riscv32-unknown-elf-gcc.exe`，Codex bundled Python。PowerShell：

```powershell
cd 'C:\Users\33791\Desktop\project\learn verilog\FINAL'
.\build_all.ps1                 # 重建导入 RTL、固件和工程，不运行仿真
.\build_all.ps1 -RunImplementation # 再执行 PDS 综合、映射、布局布线
```

脚本会重新生成参考 RTL；定制修改应同步维护 `setup_project.py` 和 `apply_adaptations.py`。参考来源路径由上一级 `reference-projects/sources.json` 固定，本机路径也记录在生成工程中；移机需修改工具路径并重新生成。不要只复制 PDS 文件。默认 ROM 内容 `firmware/demo.hex` 已填满 16384 个 32 位字，供 RAM 初始化。

日志：`build/pds-build.log`；固件：`build/firmware/`。测试入口 `sim/soc_tb.sv` 预留固件加载、结果检查、UART 解码、AXI 握手检查和统计，当前未运行。没有通过报告和实测波形。

本机 PDS 综合、器件映射、布局布线已全部成功，50 MHz 内部时序通过（setup WNS 0.337 ns）。具体资源、警告与验证边界见 [构建记录](docs/build-status.md)。

## 上板预期

板载 50 MHz；KEY1 复位，KEY2/KEY3 输入；USB UART 115200/8N1。软件预期发送 `FINAL RV32I: C PASS`，无按键时 LED=01，有按键时 LED=A5，并回显串口输入。下载/板上验收仍待进行。

参考核心固定版本 `ultraembedded/riscv` commit `7ae6f803e30f78c6ea3121e73c3adf50ff912730`；保留各源文件 BSD 版权与许可。测试源来自本地 manifest 固定的 riscv-tests，遵守其原始许可。新增平台代码及改动可从生成脚本审阅。
