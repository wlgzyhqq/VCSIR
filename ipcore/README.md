# DDR3 IP 来源

`ddr3_test` 使用本机用户已有竞赛/开发板配套资料：

- `D:/BaiduNetdiskDownload/【竞赛】2026FPGA创新设计竞赛紫光同创杯资料包/盘古50K开发板资料/盘古50K开发板/2_Demo/07_ddr3_test.rar`
- 同一资料包中 `PDS开发软件安装包/lite版本的软件，不用license/system_ip_lite/system_ip_lite/ipsxb_hmic_s_v1_4_lite.iar`

保留例程的 PGL50H/FBG484/-6、50 MHz 输入、32 位 DDR3 配置和生成的 PHY 分组。RTL 使用配套 Lite IP 包，保留 Pango 加密/版权。`import_ddr_ip.py` 将包导入工程目录，不安装到全局工具路径；导入时对文件摘要校验并限制解包路径。

`board-ddr3-reference.fdc` 是参考例程约束，**不直接加入工程**。生成器剔除其外围和时钟配置，改写当前层次，并逐项核对硬件手册，输出实际的 `constraints/mes50hp_ddr3.fdc`。不要将两个约束同时加入。

后续修改 DDR 频率、几何或 PHY 分组应通过匹配版本的 IP Compiler 重新生成。当前外围电平、CDC 和 CPU 全局时钟由项目生成器维护。

`generate_ddr_soc.py` 在可读的 `ddr3_test.v` 封装中加入 UI 域控制器复位同步，保留参考域 PHY/PLL 复位；加密实现和 PHY 参数保持原样。

可读的 `ddr3_test_ddrphy_top.v` 封装增加训练错误状态到参考域的两级同步，供原复位/重训状态机使用。这两项定制由生成器维护，重新导入 IP 后重建工程会自动恢复。
