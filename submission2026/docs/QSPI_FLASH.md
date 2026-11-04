# YOLO step2e 的 QSPI Flash 固化

本次固化对象是用户指定的 `output/bitstream/yolo_step2e.sbit`，使用 PDS 2025.2 build 211867。

## 板卡与型号

- 开发板：MES50HP，FPGA：PGL50H。
- 实际扫描出的 JEDEC ID：`0x0B4018`，对应教程中说明的 XT25BF128。
- 容量：128 Mbit，即 16 MiB。
- 扫描起初报“不支持的 Flash ID”；添加用户 Flash 后扫描成功。不能仅根据开发板型号选择 W25Q128，因为板卡存在不同 Flash 用料。

## PDS 2025 中的操作顺序

1. 打开 `D:\pango\PDS_2025.2-ads\bin\cdt_cfg.exe`，连接本机 JtagServer，扫描 PGL50H。
2. 右键 FPGA，选择 **Scan Outer Flash**。如果报告 `0xb4018` 未识别，进入 **Operations → Flash Operator → Add Flash**。
3. 按所附下载固化教程的自定义流程填写：Family `ADESTO`、Set `AT45D`、名称 `XT25BF128`、ID `b4018`、容量 `128Mbits`。这里的 Family/Set 是教程指定的自定义入口，不代表 Flash 的实际厂商。点击 Finish 后，还必须点击 Flash Operator 的 **OK**。保存时应已连接 JtagServer。
4. 通过 **Operations → Convert File → Generate Flash Programming File** 转换指定 `.sbit`。本次选 `XT25BF128`、读命令 `0x0B`、起始地址 `0`、fast_mode=false，得到 `output/bitstream/yolo_step2e_xt25bf128.sfc`。
5. 给 **Outer Flash** 关联上述 `.sfc`。先执行 **Erase**，再执行 **Program**。本次命令行默认 Program 没有预先擦除，已通过显式 Erase 纠正；不能省略擦除。
6. 校验写入结果。本机内置 Verify 报打不开相对路径临时回读文件，因此最终采用 **Read Back 到绝对路径 + 电脑端逐字节比对**，全部 2,101,696 字节一致。
7. 断电约 5 秒再上电，保留匹配的 TF 卡，不执行 JTAG 下载，检查显示及自动推理。

`.sfc` 由 PDS 正式转换生成。本次转换结果与源 `.sbit` 的字节和 SHA256 相同，这是此次转换的实际结果；不能把其他模式的位流都当成改后缀即可。

## 文件与证据

- 源位流：`output/bitstream/yolo_step2e.sbit`。
- 固化文件：`output/bitstream/yolo_step2e_xt25bf128.sfc`。
- 二者 SHA256：`cc757766bc2e0942f013bf9bd349eef6a23d04e047eba3c18eb98883f79acd40`。
- 原配置区域备份：`output/reports/flash-step2e/before-program.sfc`，只备份前 2,101,696 字节，不是整个 16 MiB Flash 的备份。
- 成功编程报告：`output/reports/flash-step2e/program-erase.json`。
- 擦除、编程及回读日志：`output/reports/flash-step2e/program-erase.log`。
- 最终回读：`output/reports/flash-step2e/after-erase-program.sfc`，与目标逐字节一致。
- 从 Flash 重载的命令与串口记录：`reload-from-flash.tcl`、`reload-from-flash.log`、`boot-reload.json`、`boot-reload.log`，均在同一报告目录。
- 冷启动观察：用户已确认“已断电重启，画面正常”；`boot-listen.log` 也完整记录了这次启动、TF 校验与首图推理。原在线判定因启动前的一个 NUL 字节未匹配到标记，修正并对原始数据复核通过，最终验收为 `boot-listen-validated.json`。原 `boot-listen.json` 保留作判定脚本问题的历史记录。

重载测试只发出 `cfg_reset_fpga`，没有 `cfg_program`，也没有 UART 固件上传。状态寄存器 `done=1`、CRC 错误为 0；CPU/CNN 为 90 MHz、64 路，主固件从 TF 加载并通过 CRC，首张照片输出公交车和 3 个人的检测结果。

原始首次编程失败记录 `program.json`/`program.log` 和第一次不一致回读仍保留，不能当成最终验收报告。

## 上电后的加载关系

`QSPI Flash → FPGA 硬件配置（含 stage0）→ TF 主固件加载到 DDR → TF 模型与图像 → YOLO 推理与 HDMI 显示`。

本次只写 QSPI Flash，没有重写 TF。模型、图片和主固件仍保存在 TF 卡，独立演示时应保留这张卡。这里的“独立启动”指不需要电脑再次下载位流或上传固件，不代表不需要 TF 卡和供电。

## 可复用脚本

本次执行脚本为 `tools/program_qspi_step2e.py --program`，固定校验指定文件的 SHA256，显式擦除、编程，再回读全量比较；已有最终回读时拒绝直接重复写入。

`tools/accept_qspi_boot.py --mode reload` 只通过 JTAG 请求重新加载，并监听串口；`--mode listen` 只监听串口，配合人工断电重启。二者均不下载位流、不上传固件、不写 TF。

参考资料：用户提供的《MES50HP开发板硬件使用手册_1V1》2.2.4，以及 `test1/05_FPGA&CPLD的下载与固化_v1.1.pdf` 第 4–9 页；PDS 2025 自带 `UG990401_Fabric_Configuration_User_Guide.pdf`。
