---@diagnostic disable: undefined-global, undefined-field

local prj_dir = os.projectdir()
local build_dir = path.join(prj_dir, "build")
local rtl_dir = path.join(build_dir, "rtl")
local generated_dir = path.join(build_dir, "generated-rtl")
local src_dir = path.join(prj_dir, "src")
local tc_dir  = path.join(prj_dir, "test_cases")

local sim = os.getenv "SIM" or "vcs" -- 默认使用 VCS 仿真器

-- ============================================================================
-- target: rtl —— 将 riscv-mini 中的 Chisel 源码编译为 SystemVerilog 并复制到 rtl_dir
-- ============================================================================
target("rtl", function()
    set_kind("phony")
    set_default(false)
    on_build(function()
        os.execv("mill", {
            "-i", "riscvMini.runMain", "mini.Main",
            "--target-dir", generated_dir
        }, {curdir = prj_dir})

        assert(os.isfile(path.join(generated_dir, "Tile.sv")),
            "riscv-mini 未生成预期的 Tile.sv")
        os.tryrm(rtl_dir)
        os.mkdir(rtl_dir)
        os.cp(path.join(generated_dir, "*"), rtl_dir)
        cprint("${green underline}[INFO]${clear} RTL 已复制到 build/rtl/")
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

    -- TODO: 修改为实际 RTL 文件路径
    add_files(
        path.join(tc_dir, "*.lua"),
        path.join(src_dir, "*.lua"),
        path.join(src_dir, "test_template", "*.lua"),
        path.join(rtl_dir, "*.sv"),
        path.join(rtl_dir, "verification", "*.sv"),
        path.join(rtl_dir, "verification", "assert", "*.sv"),
        path.join(rtl_dir, "verification", "assume", "*.sv"),
        path.join(rtl_dir, "verification", "cover", "*.sv")
    )

    set_values("cfg.build_dir_name", "sim")     -- 仿真 testbench 文件所生成的目录名
    set_values("cfg.top", "Top")      -- TODO: 修改为实际顶层模块名
    add_values("cfg.tb_gen_flags", 
        "+incdir+" .. path.join(rtl_dir, "verification"),
        "+incdir+" .. path.join(rtl_dir, "verification", "assert"),
        "+incdir+" .. path.join(rtl_dir, "verification", "assume"),
        "+incdir+" .. path.join(rtl_dir, "verification", "cover"),
        "--single-unit"
    )

    add_values("vcs.flags", "+define+ASSERT_VERBOSE_CO0_test_for_smokeND_=1", "+define+STOP_COND_=1")
    add_values("vcs.flags",
        "+incdir+" .. path.join(rtl_dir, "verification"),
        "+incdir+" .. path.join(rtl_dir, "verification", "assert"),
        "+incdir+" .. path.join(rtl_dir, "verification", "assume"),
        "+incdir+" .. path.join(rtl_dir, "verification", "cover")
    )

    add_values("verilator.flags", "+define+ASSERT_VERBOSE_CO0_test_for_smokeND_=1", "+define+STOP_COND_=1")
    add_values("verilator.flags",
        "+incdir+" .. path.join(rtl_dir, "verification"),
        "+incdir+" .. path.join(rtl_dir, "verification", "assert"),
        "+incdir+" .. path.join(rtl_dir, "verification", "assume"),
        "+incdir+" .. path.join(rtl_dir, "verification", "cover"),
        "--trace", "--no-trace-top", "--threads 4"
    )

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

    set_values("cfg.lua_main", "main.lua") -- Lua 主脚本执行入口
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
