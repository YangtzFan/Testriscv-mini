# Testriscv-mini

面向 [riscv-mini](https://github.com/ucb-bar/riscv-mini) 的硬件验证工程，使用 Mill 将 Chisel 源码编译为 SystemVerilog，并以 xmake 和 [Verilua](https://github.com/cyril0124/verilua) 组织后续仿真验证。

`riscv-mini` 是实现 RV32I 的三级流水线处理器，包含指令缓存和数据缓存。本仓库通过 Git 子模块引入其源码，在验证仓库根目录维护独立的 Mill 构建配置。

## 当前状态

- **RTL 生成已跑通**：执行 `xmake build rtl`，通过 Mill 调用 `mini.Main`，直接生成 `build/rtl/Tile.sv`。
- **仿真环境正在迁移**：现有 Lua 环境和用例仍来自加法器模板，尚未适配 riscv-mini，当前没有已跑通的处理器仿真或指令测试。

## 目录结构

```text
Testriscv-mini/
├── riscv-mini/         # 处理器源码子模块
├── build.sc            # 验证仓库的 Mill 构建配置
├── .mill-version       # 固定 Mill 版本
├── xmake.lua           # RTL 生成、仿真和清理目标
├── main.lua            # Verilua 仿真入口
├── src/
│   ├── cfg.lua         # Lua 环境配置
│   └── env.lua         # 待迁移的信号绑定、复位与辅助函数
├── test_cases/         # 待替换的加法器示例用例
├── build/
│   └── rtl/            # 生成的 SystemVerilog，顶层为 Tile
└── out/                # Mill 构建缓存
```

`build/` 和 `out/` 均为构建产物目录，已加入 Git 忽略规则。

## 环境准备

RTL 生成需要以下工具：

| 工具或依赖 | 当前配置与用途 |
| --- | --- |
| Git | 获取仓库及 riscv-mini 子模块 |
| Java | 运行 Mill 和 Scala 编译器；当前流程已在 Java 11 下验证 |
| Mill | `.mill-version` 固定为 `0.11.2` |
| xmake | 提供统一构建入口 |
| Verilua 的 xmake 规则与工具链 | `xmake.lua` 中的 `sim` 目标使用 `verilua` 规则及 `@vcs`、`@verilator` 工具链，需要按 Verilua 文档配置 |

Scala `2.13.7`、Chisel `6.2.0` 以及对应的 Chisel 编译器插件由 `build.sc` 声明，首次构建时由 Mill 解析依赖。首次运行还需要能够获取依赖及 Chisel 所需的 firtool。

初始化子模块：

```bash
git submodule update --init --recursive
```

当前 `.gitmodules` 使用 GitHub SSH 地址，拉取子模块需要配置相应的 SSH 访问权限。

## 生成 SystemVerilog

在仓库根目录执行：

```bash
xmake build rtl
```

该命令使用根目录的 `build.sc`，编译 `riscv-mini/src/main/scala/` 中的源码，再调用 `mini.Main` 将 RTL 直接写入 `build/rtl/`。构建结束时会检查 `Tile.sv` 是否存在，并输出：

```text
[INFO] RTL 已生成到 build/rtl/
[100%]: build ok, ...
```

顶层模块为 `Tile`，顶层文件为 `build/rtl/Tile.sv`。生成过程只使用这一份 RTL 输出目录，无中间复制目录。Mill 的编译缓存单独保存在 `out/`。

如需直接调用 Mill，在仓库根目录执行等价命令：

```bash
mill -i riscvMini.runMain mini.Main --target-dir "$PWD/build/rtl"
```

修改处理器 Scala 源码后，重新运行 `xmake build rtl` 即可更新 RTL。本流程使用验证仓库的 Mill 配置，不依赖子模块中的 sbt 或 Makefile 构建入口。

## 仿真环境迁移

`xmake.lua` 已保留 VCS 和 Verilator 的仿真目标，但使用前还需要完成以下适配：

1. 将 `sim` 目标的 `cfg.top` 从模板的 `Top` 改为实际顶层 `Tile`，核对 testbench 生成参数和仿真器选项。
2. 将 `src/env.lua` 中的加法器信号绑定、输入驱动函数替换为处理器所需的接口和驱动逻辑。
3. 将 `test_cases/` 下的加法器示例替换为处理器测试，并补充内存响应、程序加载和结果检查等验证逻辑。

完成适配后，可使用已有目标组织仿真。`sim` 不会自动触发 `rtl`，应先生成 RTL，再构建和运行仿真：

```bash
# VCS（默认仿真器）
xmake build rtl
SIM=vcs TC=000 xmake build sim
SIM=vcs TC=000 xmake run sim

# Verilator
xmake build rtl
SIM=verilator TC=000 xmake build sim
SIM=verilator TC=000 xmake run sim
```

以上为适配完成后的命令入口，当前加法器模板用例不能用于验证 `Tile`。

### 用例与环境变量

| 变量 | 默认值 | 当前代码中的作用 |
| --- | --- | --- |
| `SIM` | `vcs` | 选择仿真器；设为 `verilator` 时使用 Verilator 工具链 |
| `TC` | `000` | 取前三个字符匹配 `test_cases/` 下的 Lua 文件名前缀 |
| `DUMP` | 未设置 | 设置后由 `main.lua` 请求导出 VCD 波形；文件名为 `${TC}.vcd`，未设置 `TC` 时为 `sim.vcd` |
| `HEART` | `true` | 控制心跳日志任务每 10000 个周期输出一次日志 |

用例文件名沿用 `NNN_name.lua` 格式，并返回一个可调用函数。xmake 将匹配的模块名传入 `TC_NAME`，`main.lua` 加载环境和用例，执行复位、启动心跳日志任务，然后调用用例函数。每个三位编号应对应唯一用例。

## 清理构建产物

```bash
xmake run clean
```

该目标删除整个 `build/` 目录，包括生成的 RTL 和该目录下的仿真产物。Mill 的 `out/` 缓存会保留。

## 相关项目

- [riscv-mini](https://github.com/ucb-bar/riscv-mini)：处理器源码；原项目的架构与测试说明见 [子模块 README](riscv-mini/README.md)。
- [Verilua](https://github.com/cyril0124/verilua)：Lua 硬件验证框架。
- [Mill](https://mill-build.org/)：Scala 构建工具。
- [xmake](https://xmake.io/)：本工程的构建命令入口。
