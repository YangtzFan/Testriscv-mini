local cfg = require "cfg"

---@class test_template.TestCase
---@field tasks table

local random = math.random

local clock = dut.clock:chdl()

local hier = "tb_top" --[[@type string]]
local prefix = "io_" --[[@type string]]

---@type verilua.handles.AliasBundle
local input_a = ([[
    | a_valid => valid_a
    | a_bits => a
]]):abdl({ hier = hier, prefix = prefix, name = "INPUT_A" })

---@type verilua.handles.AliasBundle
local input_b = ([[
    | b_valid => valid_b
    | b_bits => b
]]):abdl({ hier = hier, prefix = prefix, name = "INPUT_B" })

---@type verilua.handles.AliasBundle
local output_sum = ([[
    | out_valid => valid_sum
    | out_bits => sum
]]):abdl({ hier = hier, prefix = prefix, name = "OUTPUT_SUM" })

local function monitor_task()
    local cycles = dut.cycles:get()
    local enable_heart_beat = cfg.enable_heart_beat

    while true do
        if enable_heart_beat then
            if cycles % 10000 == 0 then
                print("Running...", cycles)
            end
        end
        clock:posedge()
        cycles = cycles + 1
    end
end

local monitor_task_id = 0
local has_monitor_task = false
local function launch_monitor_task()
    if not has_monitor_task then
        has_monitor_task = true
        monitor_task_id = scheduler:append_task(nil, "monitor_task", monitor_task, true)
    end
end

local function dut_reset()
    dut.reset:set_imm(1)
    clock:posedge(10)
    dut.reset:set_imm(0)
end

---@return integer
local function get_random_bit()
    return random(100) % 2
end

---@param a integer
---@param b integer
local function set_input(a, b)
    dut.io_a_bits:set(a)
    dut.io_b_bits:set(b)
    dut.io_a_valid:set(1)
    dut.io_b_valid:set(1)
end

local function unset_input()
    dut.io_a_valid:set(0)
    dut.io_b_valid:set(0)
end

local function test_success()
    print("=== TEST PASSED ===")
    print("\27[32m" .. [[
  _____         _____ _____
 |  __ \ /\    / ____/ ____|
 | |__) /  \  | (___| (___
 |  ___/ /\ \  \___ \\___ \
 | |  / ____ \ ____) |___) |
 |_| /_/    \_\_____/_____/
]] .. "\27[0m")
    io.flush()
end

---@class test_template.Env
local EnvUtils = {
    clock = clock,
    get_random_bit = get_random_bit,
    dut_reset = dut_reset,
    launch_monitor_task = launch_monitor_task,
    set_input = set_input,
    unset_input = unset_input,
    test_success = test_success,
}

return EnvUtils
