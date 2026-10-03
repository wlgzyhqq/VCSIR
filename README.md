# FINAL：MES50HP RV32I SoC

顶层 `rtl/final_top.v`，PDS 工程 `FINAL.pds`。复用 UltraEmbedded BSD CPU/Cache，加入本板引脚约束、动态预测、机器模式中断、UART/GPIO、板载 1 GiB DDR3 主存及软件。原 64 KiB DRM 主存已移除，片内 RAM 仅用于 Cache/控制器缓存。按用户要求不运行仿真；此前片内主存版本已有串口和按键上板结果，DDR3 版本尚未上板验证。

## 交付内容

| 要求 | 实现 | 验收材料 |
|---|---|---|
| B01 | RV32I 单发射 CPU；Zicsr/Zifencei；关闭 M、C、MMU | 42 个 rv32ui 程序、C demo；待执行 |
| B02 | IF/ID/EX/MEM/WB 五级；旁路、load-use 等待、访存暂停、错误预测清空 | `firmware/test_pipeline.S`；`sim/soc_tb.sv` 波形/统计；待执行 |
| B03 | UART 115200 8N1、GPIO、按键/LED；CPU 软件输出结果 | `firmware/demo.c`、`platform.h`；旧版已上板，新版待验收 |
| H01 | I/D 各 16 KiB、2 路、256 组、32 字节行；8 拍 AXI 回填 | `firmware/test_cache.S`；突发/停顿计数；待执行 |
| H02 | 32 项 BTB、2 位饱和计数；M 模式陷阱/中断、MRET、直接/向量入口 | `firmware/test_traps.S`；待执行 |

完整范围、地址表、流水线与硬件映射见 [架构说明](docs/architecture.md)。H02 的实现范围是单核 M 模式，不含 S/U、虚拟内存、PMP、多核、NMI 和调试规范；不能据此宣称完整 RISC-V 特权架构认证。

## 构建

本机工具：PDS 2022.2-SP1-Lite，`C:/msys64/ucrt64/bin/riscv32-unknown-elf-gcc.exe`，Codex bundled Python。PowerShell：

```powershell
cd 'C:\Users\33791\Desktop\project\learn verilog\FINAL'
.\build_all.ps1                 # 重建导入 RTL、固件和工程，不运行仿真
.\build_all.ps1 -RunImplementation # 再执行 PDS 综合、映射、布局布线
.\build_all.ps1 -GenerateBitstream # 完整实现并生成 FPGA 配置；不会下载到板子
```

脚本会重新生成参考 RTL；定制修改应同步维护 `setup_project.py` 和 `apply_adaptations.py`。参考来源路径由上一级 `reference-projects/sources.json` 固定，本机路径也记录在生成工程中；移机需修改工具路径并重新生成。不要只复制 PDS 文件。`firmware/demo.hex` 保留作为固件产物；DDR3 不支持 `$readmemh` 上电初始化。构建将 `demo.bin` 的实际字节生成为 `boot_image.vh` 只读逻辑常量，上电由装载器写入 DDR3 并逐行读回校验后释放 CPU。常量不是 CPU 可寻址的主存。

日志：`build/pds-ddr-build.log`；固件：`build/firmware/`。`sim/soc_tb.sv` 是旧片内主存版本的测试入口，直接引用了旧 RAM，不能用于当前 DDR3 顶层。新增接口目前通过代码检查和 PDS 构建验证，没有 DDR3 仿真通过报告或实测波形。

当前 DDR3 版本构建记录见 [构建记录](docs/build-status.md)，具体改动、启动和状态灯见 [DDR3 主存说明](docs/ddr3-memory.md)。原片内主存版本的源代码与构建说明保存在 `backups/BRAM_20261002/`。旧版时序结论不适用于当前版本。

2026-10-02 21:53 完成当前 DDR3 版本的综合、布线与比特流生成，最终时序为 `All Constraints Met`。下载文件是 `generate_bitstream/final_top.sbit`，摘要与验证范围见 `build/ddr-delivery.json`；尚未下载和上板验证。

## 上板预期

板载 50 MHz；KEY1 复位，KEY2/KEY3 输入；USB UART 115200/8N1。软件先检查多个 DDR3 地址，预期发送 `FINAL DDR3: memory PASS`，再发送 `FINAL RV32I: C PASS`，无按键时 LED=01，有按键时 LED=A5，并回显串口输入。下载/板上验收仍待进行。

参考核心固定版本 `ultraembedded/riscv` commit `7ae6f803e30f78c6ea3121e73c3adf50ff912730`；保留各源文件 BSD 版权与许可。测试源来自本地 manifest 固定的 riscv-tests，遵守其原始许可。新增平台代码及改动可从生成脚本审阅。
