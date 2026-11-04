# RISC V处理器与离线视觉检测系统

2026 FPGA创新设计赛道选题一。完整源码、固定版本位流和原始证据，基于MES50HP PGL50H。

| 配置 | 用途 | 验收 |
|---|---|---|
| cpu_bench/cpu_bench.pds | 独立CPU，RV32IM，90 MHz，关闭AI/DDR/SD/HDMI | 213.862178 CoreMark，2.376246 CoreMark/MHz |
| yolo/yolo_frozen.pds | 冻结的应用RTL综合输入 | PDS2022兼容综合DDR |
| yolo/pds2025/final_top_netlist.pds | 冻结GTP网表与约束，PDS2025布局布线 | CPU/CNN90、DDR100；全部多角时序通过 |
| cpu_bench/validation/cpu90 | 独立诊断、功能测试与片上分析仪 | 两模式各55项；六份真实片上采样 |

应用网络输入160×160，显示素材320×320。64路INT8引擎执行卷积，CPU执行预处理、非卷积节点及NMS。八图检测与参考匹配，首图85节点CRC一致。应用与CPU配置分别报告，禁止把独立CPU成绩当成完整应用配置成绩。计时与资源口径见技术报告和evidence。

## 复现与版本

正式位流在release，CPU位流SHA前缀d9737ea9df4c，YOLO位流及SFC为cc757766bc2e。TF主固件38964字节、CRC56d0cd28。建议先使用交付位流复测。重新构建的位流必须重新检查多角STA及上板结果，不能复用旧成绩。

CPU固件编译：进入cpu_bench运行`python scripts/build_cpu_only.py`；工具链默认C:/msys64/ucrt64/bin/riscv32-unknown-elf-gcc.exe。CPU重建使用PDS2022打开cpu_bench.pds，强制从编译重新运行。程序RAM初始化文件是firmware/cpu_only/coremark.hex。CPU RTL和固件依赖均已保留。

YOLO优先使用PDS2025.2打开yolo/pds2025/final_top_netlist.pds，强制重新编译和布局布线，输入结构网表已保留，无需导入旧加密DDR RTL。若修改RTL，先用2022兼容综合yolo/yolo_frozen.pds生成新GTP网表，再替换2025工程输入。工程路径已相对化；工作目录选工程所在目录。旧开发辅助脚本可能保留开发目录名，正式入口以上述两份冻结工程为准。

TF镜像由tools/make_release_image.py依据编译时资产表生成，包含原始图片、240帧素材、权重和主固件；不写物理磁盘。当前板上TF无需重写。读卡器Write/Verify与Flash操作详见docs/QSPI_FLASH.md。电脑参考需要PyTorch、NumPy、Pillow、OpenCV；部署与镜像工具无需训练环境。全部模型来源、量化配置和逐节点参考在yolo/model。

## 源码和许可证

core/cache基于Ultra-Embedded的BSD组件修改与适配，版权保留在各源文件。CoreMark为EEMBC官方算法，许可保留在third_party/coremark。YOLOv5 v7.0源码及许可位于yolo/third_party/yolov5，权重来源与SHA位于yolo/model/source/provenance.json。PDS生成IP为原厂组件，使用需具备相应PDS环境；不包含许可证、工具链或破解内容。视频为筛选后的演示帧，不能作为无偏精度评估集，帧CRC和原素材名称保存在assets/video/manifest.json。仓库不另行替第三方内容授予许可证。

SOURCE_MANIFEST保留原始来源与路径调整记录；SHA256SUMS列出最终包内文件校验值。未纳入开发环境、历史失败构建、重复布线数据库和原始视频压缩文件。
