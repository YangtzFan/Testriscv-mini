---@diagnostic disable: undefined-global, undefined-field

local prj_dir = os.projectdir()
local build_dir = path.join(prj_dir, "build")
local rtl_dir = path.join(build_dir, "rtl")
local src_dir = path.join(prj_dir, "src")
local tc_dir  = path.join(prj_dir, "test_cases")

local sim = os.getenv "SIM" or "vcs" -- 默认使用 VCS 仿真器

-- ============================================================================
-- target: rtl —— 将 riscv-mini 中的 Chisel 源码编译为 SystemVerilog，直接生成到 rtl_dir
-- ============================================================================
target("rtl", function()
    set_kind("phony")
    set_default(false)
    on_build(function()
        os.execv("mill", {
            "-i", "riscvMini.runMain", "mini.Main",
            "--target-dir", rtl_dir
        }, {curdir = prj_dir})

        assert(os.isfile(path.join(rtl_dir, "Tile.sv")),
            "riscv-mini 未生成预期的 Tile.sv")
        cprint("${green underline}[INFO]${clear} RTL 已生成到 build/rtl/")
    end)
end)

-- ============================================================================
-- target: sim —— 主仿真入口
-- ============================================================================
target("sim", function()
    set_default(true)
    add_rules("verilua")

    if sim == "verilator" then
        add_toolchains("@verilator")
    else
        add_toolchains("@vcs")
    end

    -- Generated riscv-mini RTL and Lua environment.
    add_files(
        path.join(tc_dir, "*.lua"),
        path.join(src_dir, "*.lua"),
        path.join(rtl_dir, "*.sv")
    )

    set_values("verilua.build_dir_name", "sim")
    set_values("verilua.top", "Tile")
    add_values("verilua.tb_gen_flags", "--single-unit")
    add_values("verilator.flags", "--trace", "--no-trace-top", "--threads 4")

    local TC = os.getenv("TC") -- 根据用户设置的 TC 寻找对应的用例并将名称存入 TC_NAME 环境变量
    if TC then
        TC = TC:sub(1, 3)
    else
        TC = "000" -- 指定默认用例 000
    end
    local test_cases = os.files(path.join(tc_dir, "*.lua"))
    for _, test_case in ipairs(test_cases) do
        local test_case_file = path.filename(test_case)
        if test_case_file:startswith(TC) then
            add_runenvs("TC_NAME", path.basename(test_case_file))
        end
    end

    set_values("verilua.lua_main", "main.lua") -- Lua 主脚本执行入口
end)

-- ============================================================================
-- target: clean
-- ============================================================================
target("clean", function()
    set_kind("phony")
    set_default(false)
    on_run(function()
        os.tryrm(path.join(prj_dir, "build"))
        cprint("${green underline}[INFO]${clear} 已清空 build/")
    end)
end)
