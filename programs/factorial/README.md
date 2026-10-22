# factorial 裸机程序

从仓库根目录执行：

```bash
make -C programs/factorial
```

需要 PATH 中存在 `riscv64-unknown-elf-gcc`、`riscv64-unknown-elf-objdump` 和 `elf2hex`。
也可以通过 `CROSS_COMPILE` 和 `ELF2HEX` 覆盖工具路径。

输出位于 `build/programs/factorial/`：

- `factorial.elf`：32 位小端 RISC-V ELF，入口为 `0x200`。
- `factorial.hex`：`elf2hex 16 32768` 生成的内存镜像，每行 16 字节，共 512 KiB。
- `factorial.dump`：包含源码的反汇编。

代码基于提供的 factorial 示例，唯一的 C 源码兼容性修改是将
`csrw mtohost, 1` 改为 `csrwi 0x780, 1`：地址 `0x780` 对应本仓库
riscv-mini 的旧版 `mtohost` CSR，`csrwi` 使用立即数写入。

`runtime.S` 提供启动入口、栈设置、BSS 清零和 RV32I 软件乘法函数
`__mulsi3`，无需链接 libc 或本机缺失的 RV32I libgcc。
`link.ld` 将入口放在处理器的复位地址 `0x200`，栈顶设为 `0x80000`。
编译选项 `rv32i_zicsr` 允许使用 CSR 指令，不启用 M 或 C 指令扩展；
`-O0` 保留阶乘调用，避免未使用的局部结果被优化掉。

当前示例计算 `factorial(10)`，预期为 `3628800`，结果保存在 `main` 的局部变量
`ans` 中。`exit()` 无条件向 `mtohost` 写入 1，并未检查计算结果。
成功生成 hex 只代表编译与链接成功，处理器仿真和结果检查仍需由验证环境完成。
