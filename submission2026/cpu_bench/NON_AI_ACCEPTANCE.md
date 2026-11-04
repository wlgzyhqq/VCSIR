# 非 AI 任务核查与实板验收

本报告对应当前 90 MHz CPU-only 功能修正版。原 FINAL 应用、TF 卡和 Flash 均未修改。当前正式位流为 `output/bitstream/cpu_only_90MHz_verified.sbit`，SHA256：`d9737ea9df4cb56620d413a5af22e38f860020a9bd2d5a8aa055f6562261ccce`。原 d17073 跑分版及其代码、固件、报告已保存在 `baseline/cpu-only90-before-non-ai`。

## 1. 按赛题逐项对应

依据本地 `../task-doc-sources/2026赛题指南.txt` 的选题一：基础三项、高阶前两项，以及 CoreMark 和片上波形分析要求。高阶第三项 AI 不在本次工作范围。

| 项目 | 当前实现和证据 | 结论 |
|---|---|---|
| B01 RV32I CPU | 41 个上游 RV32UI 程序原生通过；另 1 个原生未对齐访问程序按本平台 EEI 陷阱策略核验；含 FENCE、ECALL、EBREAK | 实现及平台验收完成，非 ISA 官方认证 |
| B02 至少三级流水线与冲突处理 | 取指、译码缓冲、E1、E2、WB 的时序边界；真实依赖、伪操作数匹配、load-use、WAW、错误路径非法指令/访存/CSR/MMIO、调用返回及变延迟测试 | 完成 |
| B03 UART/GPIO | CPU 执行的 UART 原始字节回显、接收中断、溢出检测；GPIO 双向引脚实际输入回读和引脚触发中断 | 自动外设验收完成；LED用户确认正常、KEY2已实测，其余按键由用户确认并要求停止追加验证 |
| H01 两路 I/D Cache 与突发传输 | I/D 各 16 KiB、两路、256 组、32 字节行；同组双行驻留、第三行替换、脏写回、字节写使能；8 拍 INCR；等待/背压下协议监测 | 完成 |
| H02 动态预测与异常/中断 | 32 项 BTB、两位饱和方向计数；23 项异常/中断入口现场、屏蔽与优先级、直接/向量入口、两层嵌套、MRET；64 位计数器 | 本工程 M 模式范围内完成 |
| P01/P02 CoreMark、频率、资源 | 正式版两组种子、各 3000 次迭代、官方 CRC 正确、均超过 10 秒；90 MHz 最终多角 STA；资源口径分别列明 | 完成 |
| D02 实板片上波形与流水线分析 | 链表、矩阵、状态机各有入口和内循环两份256周期实际采样；二进制、CSV、VCD、PNG 和分析说明 | 完成；使用自建片上逻辑分析器，不是 PDS 原厂 DebugCore |

55 项平台测试在正常总线和注入等待/背压两种模式下均通过。55 项由 42 个上游测试入口和 13 个自定义程序组成；其中 `rv32ui-ma_data` 是明确的 EEI 策略验证，不能写成“42 个上游原生测试全部通过”。

## 2. 本轮查出并修复的问题

1. **FENCE.I 与脏数据缓存。** 原实现只使指令缓存失效，CPU 写入 D-Cache 的新指令未保证写回，原 `rv32ui-fence_i` 实板返回 `dead0002`。现在 FENCE.I 发起 D-Cache flush，流水线等待完成确认，再使 I-Cache 失效并重取后续指令。标准 FENCE.I 测试及缓存别名读回已通过。这个行为不等于普通 FENCE 自动刷新缓存。
2. **未对齐跳转的 mtval。** 原现场中 `mepc=0x2298, mtval=0x2298`，实际非法目标为 `0x2`。现保留 mepc 指向跳转指令，并让 mtval 记录非法目标。23 项现场检查通过。
3. **控制指令退休计数。** 原 `retired_o` 排除了所有内部控制事件，连合法的 FENCE.I、MRET 也排除。现在将这两类合法退休包含在内，真正的异常/中断不计为退休指令。

计数器测试曾出现测量边界错误：CSR 在发射处读取，较老的指令还可能在流水线中。现用额外串行 CSR 访问排空测量窗口两端，明确把辅助访问也计入期望数。常规和背压模式结果都是 `[10,3,3,8,8]`，分别代表八 NOP 窗口、FENCE.I 窗口、MRET 窗口以及 cycle/instret 高半部进位。原失败记录和两份实板诊断波形均保留，未通过放宽误差掩盖问题。

修复只涉及 `riscv_core.v`、`riscv_issue.v`、`riscv_lsu.v`、`riscv_pipe_ctrl.v`、`riscv_csr_regfile.v`，补丁在 `output/reports/non-ai-functional-fixes.patch`。CPU/Cache 功能源码与诊断版逐文件比较，正式版仅去掉只读观察端口；验证脚本检查此对应关系。

## 3. 指令与执行环境

| 类别 | 覆盖 |
|---|---|
| 常量、地址 | LUI、AUIPC |
| 跳转 | JAL、JALR，链接返回地址、JALR 清除 bit0 |
| 条件分支 | BEQ、BNE、BLT、BGE、BLTU、BGEU；成立/不成立、预测恢复 |
| 读内存 | LB、LH、LW、LBU、LHU，符号和零扩展 |
| 写内存 | SB、SH、SW，字节使能 |
| 立即数算术 | ADDI、SLTI、SLTIU、XORI、ORI、ANDI、SLLI、SRLI、SRAI |
| 寄存器算术 | ADD、SUB、SLL、SLT、SLTU、XOR、SRL、SRA、OR、AND |
| 顺序/陷阱 | FENCE、ECALL、EBREAK；FENCE.I 单独作为 Zifencei |
| CSR | CSRRW/CSRRS/CSRRC 及立即数形式；只读/未实现 CSR 访问异常；MRET |
| M 扩展 | MUL、MULH、MULHSU、MULHU、DIV、DIVU、REM、REMU；681 组参考向量及三类依赖/目标别名检查 |

当前配置为 RV32IM + Zicsr/Zifencei、小端、机器模式，未启用 S/U 模式、MMU、原子 A、压缩 C 或硬件浮点 F/D。未知指令与不支持的 CSR 按测试范围产生非法指令异常。对齐策略为 LH/SH 要求 2 字节对齐、LW/SW 要求 4 字节对齐，违规分别产生 cause4/cause6；不声称原生支持未对齐访存。

机器模式覆盖：指令目标未对齐/取指访问错误、非法指令、断点、加载/存储未对齐与访问错误、M 模式 ECALL；软件/定时器/外部中断；mstatus 的 MIE/MPIE/MPP；mepc/mcause/mtval；mtvec 直接和向量模式；mie/mip；mscratch；cycle/instret 64 位计数及只读别名。多源优先级为 external > software > timer。嵌套由软件保存和恢复 mepc、mstatus、现场与栈帧，不是硬件自动保存通用寄存器。

“完整”限定在本工程实现的 M 模式与已列事件，不表示实现全部 RISC-V 可选特权设施，也不表示形式验证或官方一致性认证。

## 4. 缓存、预测和总线实测

I/D Cache 各 2 路 × 256 组 × 32 字节 = 16 KiB。D-Cache 写回、写分配，跟踪 valid/dirty；替换选择使用源码中的轮转/有限伪随机方式，不宣称 LRU。地址相差 8192 字节映射同组。

`test_cache_contract` 在两种模式都得到 `[0,2,0,3]`：两条同组 D 行暖机后反复交替访问，新增 D RAM 补行数 0；第三条 D 行加入后观察到 2 次脏写回；两个同组指令函数反复调用，新增 I RAM 补行数 0；第三函数加入后新增 3 次 I 补行。这比单纯比较读写结果更直接地验证两路驻留。

背压模式同一测试统计 I 读突发25次/200拍、D读突发8次/64拍、D写突发6次/48拍，均为每行8拍。I AR、D AR、AW、W等待分别13、14、7、61周期；协议错误0。检查包括保持 VALID 时地址/数据稳定、ID、拍数、RLAST/WLAST、INCR 与合法长度。当前主设备 RREADY 基本持续有效，没有人为制造 RREADY 拉低；R 通道停顿计数为0，应与从设备插入 RVALID 间隙区别说明。

访问非法地址的异常测试故意产生总线错误响应：`test_privileged` 的 B 错误1次、R错误9拍属于预期刺激，不是协议错误；CPU 已核对其异常原因和地址。

BTB 32 项直接映射，完整 tag 区分 PC，两位饱和计数；预测元数据随取指保存，执行阶段发现错误后重定向和清空错误路径。实板 `test_predictor` 在暖机后的200次循环测得3次重定向，两种总线模式一致。该数字包含测量段中的调用/返回等控制流，不是全 CoreMark 的预测准确率，也不是一次关闭预测器的 A/B 跑分。

## 5. 外设与地址分配

| 地址 | 用途 |
|---|---|
| 0x00000000–0x0000FFFF | 64 KiB 片上 RAM；生产版 CoreMark 固件 |
| 0x80000000 / 0x80000004 | UART 数据 / 状态；bit0 TX busy、bit1 RX valid、bit2 overrun |
| 0x80001000 / 04 / 08 | GPIO 输出 / 同步输入 / 方向 |
| 0x8000100C / 10 | GPIO 中断使能 / 上升沿 pending（写1清除） |
| 0x80002000 / 04 | 64位 mtime 低/高 |
| 0x80002008 / 0C | 64位 mtimecmp 低/高 |
| 0x80002010 / 14 | 软件中断 / 诊断外部中断强制源 |
| 0x80002018 | 测试完成码 |

GPIO bit[15:8] 控制8个LED，输入 bit[9:8] 为按键，bit[1:0] 为两个双向GPIO实际管脚反馈。异步按键、GPIO、UART输入先同步；不宣称本次增加机械按键消抖。

UART 固定验收115200、8N1、无流控，90MHz 整数分频781，实际约115236.9波特，误差约+0.032%。已回显0、1、256、4096、32768字节及33字节UTF-8/控制字符，字节与CRC均正确；32个GPIO输出/实际引脚输入模式通过。CPU-only UART 是单字节保持寄存器：固件及时取数时可接收上述连续块，不等于硬件有32KiB FIFO。故意停止读取约111ms并发送256字节，实测状态6、最后字节255，读出后标志清除，溢出能够被软件检测。此最小外设不替代原 FINAL 中更完整的聊天 UART 接口。

补充人工观察：用户确认LED流水正常。长窗口实测KEY2按下，输入寄存器连续为0x00000103（KEY2状态bit8置1，低两位为未驱动GPIO输入），采到状态集合[0,1]。随后用户确认其余按键部分正确，并明确要求不再验证，因此停止剩余操作；不宣称KEY3和双键已取得自动四组合记录。本次提前终止，逐次采样JSON保留，完整UART最终转储未取得；前一轮未观察日志已另名保存。B03 的UART/GPIO电子路径已自动验证。

## 6. 诊断版与正式版必须分开

正式版：90MHz、SHA前缀 `d9737ea9df4c`，无分析仪；最小SoC布局后7099 LUT/5686 FF/82 DRM/4 APM/1 PLL；CPU含I/D Cache综合6293 LUT/5139 FF/18 DRM/4 APM。CoreMark/LUT按后一个6293口径为0.033984138，不包含应用、外设、测试采样器或64KiB程序RAM。

诊断版：`validation/cpu90/generate_bitstream/cpu_bench_top.sbit`，SHA前缀 `fa45ba747cb6`，90MHz setup +0.139ns，布局后8491 LUT/6720 FF/87 DRM/4 APM/1 PLL；额外分析模块层级为1317 LUT/1015 FF/5 DRM。它与正式版共享CPU/Cache功能，但增加只读观察端口、诊断MMIO、RAM装载别名、超时复位及可变等待从设备。55项是在诊断版上实际执行，正式版另外通过时序与完整CoreMark；不能把两者的资源、哈希和执行记录混作一个位流。

正式版最终90MHz setup +0.639ns，工具估计95.492MHz；后者不是上板测试主频。两组3000迭代：14.0277258556秒 / 213.862177725，14.0639957000秒 / 213.310645423；与旧版周期相同。功能修复代价为CPU综合LUT增加279、最小SoC布局后LUT增加274。PGL50H最小系统仍剩约35701 LUT、52 DRM、80 APM；这些余量只对应CPU-only，不能套用到原FINAL完整AI SoC。

## 7. 可复现命令

以下命令在对应目录执行，`python` 可替换为本机 Python 的绝对路径。工具链为 GCC14.2、PDS2022.2-SP1-Lite、PGL50H-6IFBG484。串口须由测试工具独占；JTAG只配置SRAM，不写Flash，不涉及TF卡。

正式版 `final2`：

```powershell
python scripts/build_cpu_only.py
python scripts/run_cpu_only.py
python scripts/accept_cpu_only.py --ports COM12
python scripts/verify_non_ai.py
```

诊断版 `final2/validation/cpu90`：

```powershell
python scripts/build_monitor.py
python scripts/build_validation_tests.py
python scripts/build_c_payloads.py
python scripts/run_cpu_only.py
python scripts/run_validation.py --program --delay 0 --output repeat-zero.json
python scripts/run_validation.py --delay 1 --output repeat-backpressure.json
python scripts/capture_coremark.py
python scripts/capture_coremark.py --region inner
python scripts/render_waveforms.py
python scripts/render_waveforms.py --region inner
python scripts/verify_io.py
python scripts/manual_gpio.py --seconds 120
```

当前卡住时，诊断看门狗默认3秒后暖复位，保留超时PC/原因；CoreMark采集将超时设为40秒。上传程序都带长度和CRC，使用不缓存RAM别名避免依赖待测FENCE.I的正确性。手动重放前必须下载诊断位流，否则正式版没有Monitor命令接口。跑完如需恢复正式版，返回 `final2` 执行 `accept_cpu_only.py`。

`prepare_validation.py` 是历史一次性生成脚本，当前工程已完成增强，不能反复执行；它现有保护检查。正常复现直接构建检入的源码。

## 8. 原始证据位置与状态

- `validation/cpu90/output/validation/board-tests-v3-zero-final.json`：常规模式55项的逐项汇总；只用修正后的计数器重测替换该单项，明确记录各行来源。
- `board-tests-v3-backpressure.json`：同一轮完整55项背压实测，包含23项陷阱现场、嵌套现场、缓存与计数器读数。
- 同目录的 `*.uart.bin`：原始串口字节；失败结果仍保留。
- `coremark-captures/{list,matrix,state}`：实际波形、CSV、VCD、原始采样、采集条件与有效基准运行日志。
- `io-v3.json`、`manual-gpio-v3.json`：自动外设验收和独立人工观察状态。
- `output/reports/cpu-only-board.json`、`cpu-only-COM12.log`：正式版实际成绩和原始CRC。
- `report_timing/cpu_bench_top.rtr`、`place_route/cpu_bench_top.prr`、`synthesize/cpu_bench_top.snr`：正式版最终STA和资源。
- `output/reports/non-ai-evidence-verification.json`、`non-ai-evidence-files.json`：对应关系检查与文件校验清单。

RV32UI来自上游 riscv-tests 固定提交 bcffa2b3188b040c611f90dc0b6e422f54775a09，许可保留；只适配终止/返回接口，不改测试主体。CPU源码原有 Ultra-Embedded BSD 许可和来源声明保留；技术材料应如实区分已有开源基础与本工程改进。CoreMark算法和头文件保持官方源码，平台移植层单列。
