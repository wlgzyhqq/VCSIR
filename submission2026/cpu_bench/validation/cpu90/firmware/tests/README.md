# 待运行的指令测试源

`rv32ui` 的42个测试及其共享的 `rv64ui` 实现、`include/test_macros.h` 来自 riscv-software-src/riscv-tests，固定提交 bcffa2b3188b040c611f90dc0b6e422f54775a09，保留 LICENSE。共享目录名不表示本CPU支持RV64。

`include/riscv_test.h` 是本工程适配：PASS写0x80002018=1，FAIL写错误码。工程另有 `firmware/test_cache.S`、`test_pipeline.S`、`test_traps.S`。

运行 `./build_all.ps1 -BuildTests` 只编译这些测试到 `build/tests`，不会执行、仿真或替换当前DEMO启动镜像。本工程尚未提供DDR版自动运行这些镜像的验收入口，因此不能把“编译成功”当作逐项通过。
