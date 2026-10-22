# TestTemplate

基于 [Verilua](https://github.com/cyril0124/verilua) 的硬件验证模板工程，支持 VCS 和 Verilator 两种仿真器。RTL 由 [ChiselTemplate](https://github.com/YangtzFan/ChiselTemplate) 子模块生成，验证逻辑用 Lua 编写。

## 目录结构

```
TestTemplate/
├── ChiselTemplate/     # Chisel RTL 子模块（Scala → SystemVerilog）
├── src/                # 验证基础设施（env、monitor、cfg）
│   ├── cfg.lua
│   ├── env.lua
│   └── test_template
│       └── TestTemplateMonitor.lua
├── test_cases/         # 测试用例（Lua）
│   ├── 000_smoke.lua   # 冒烟用例：验证后 0+0
│   ├── 001_one_add_one.lua  # 用例：验证 1+1=2
│   └── 002_random.lua  # 用例：随机输入 10 拍
├── main.lua            # Verilua 入口
└── xmake.lua           # 构建脚本
```

## Quick Start

### Step 1. 初始化子模块

```bash
git submodule update --init
```

### Step 2. 生成 RTL

使用验证仓库根目录的 `build.sc`（Mill 版本由 `.mill-version` 固定）编译
`riscv-mini/src/main/scala` 中的 Chisel 源码，通过 `mini.Main` 生成 SystemVerilog，
再复制到 `build/rtl/`。需要预先安装 Java 和 Mill。

```bash
xmake build rtl
```

生成的原始 RTL 位于 `build/generated-rtl/`，复制后的顶层文件为 `build/rtl/Tile.sv`。
Mill 的 Scala 编译缓存位于 `out/`。

### 3. 运行仿真

```bash
# 默认仿真器 VCS 
xmake build sim # 编译得到 testbench 文件
xmake run sim # 默认运行 TC=000（冒烟用例）
TC=001 xmake run sim
TC=002 xmake run sim

# 修改仿真器为 verilator
SIM=verilator xmake build sim # 编译得到 testbench 文件
SIM=verilator xmake run sim # 默认运行 TC=000（冒烟用例）
SIM=verilator TC=001 xmake run sim
SIM=verilator TC=002 xmake run sim
```

用例编号取 `test_cases/` 下文件名的前三位数字。

### 4. 清理构建产物

```bash
xmake run clean
```

## 执行流程原理简介

以 `TC=000 xmake r sim` 为例，完整执行链路如下：

```
TC=000 xmake r sim
│
├─ [xmake] 解析 TC=000
│   └─ 在 test_cases/ 中匹配前缀 "000" → 000_smoke.lua
│       将 TC_NAME=000_smoke 注入运行时环境
│
├─ [xmake] 调用已编译的 simv（VCS 仿真二进制）
│
├─ [VCS/simv] 加载 libverilua_vcs.so，Verilua 初始化 Lua 运行时
│   └─ 入口：main.lua
│
├─ [main.lua] require "env"
│   └─ env.lua 初始化 DUT 信号句柄（clock、input_a/b、output_sum）
│       并构造 TestTemplateMonitor 实例
│
├─ [main.lua] fork { main_task }  ← 创建主协程
│
├─ [main_task] require(TC_NAME)  →  加载 000_smoke.lua
│              得到 tc.tasks = { task_single }
│
├─ [main_task] env.dut_reset()
│   └─ reset 拉高 → posedge × 10 → reset 拉低
│
├─ [main_task] env.launch_monitor_task()
│   └─ 向调度器追加 monitor_task 协程（并发运行）
│       每拍采样信号 → TestTemplateMonitor:sample()
│       每 10000 周期输出日志
│
├─ [main_task] 遍历 tc.tasks，依次调用
│   └─ task_single(): set_input(0, 0) → posedge × 1
│
├─ [main_task] env.test_success()  →  打印 "=== TEST PASSED ==="
│
└─ [main_task] sim.finish()  →  仿真结束
```

结合具体程序代码可以更好地理解上述流程。

## 验证环境

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `TC` | `000` | 测试用例编号前缀 |
| `SIM` | `vcs` | 仿真器（`vcs` / `verilator`） |
| `ENABLE` | `true` | 是否启用 TestTemplateMonitor |
| `VER` | `true` | 是否启用 Monitor 日志输出 |
| `HEART` | `true` | 是否启用每 10000 个时钟周期的日志输出 |

### 添加新用例

在 `test_cases/` 下新建 `NNN_name.lua`，返回一个 `test_template.TestCase` 表，仿照其他用例编写风格即可。

### 修改 RTL

编辑 `ChiselTemplate/src/` 下的 Scala 源码后，重新运行 `xmake build rtl` 再重新编译仿真即可。
