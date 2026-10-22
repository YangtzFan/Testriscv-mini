local cfg = require "cfg"

---@class test_template.TestCase
---@field tasks table

local random = math.random

local hier = "tb_top" --[[@type string]]

---@type verilua.handles.AliasBundle
local control = ([[
    | clock
    | reset
]]):abdl({ hier = hier, name = "CONTROL" })

local clock = control.clock

---@type verilua.handles.AliasBundle
local host = ([[
    | fromhost_valid
    | fromhost_bits => fromhost
    | tohost
]]):abdl({ hier = hier, prefix = "io_host_", name = "HOST" })

-- Tile is the Nasti master; the testbench drives the memory slave inputs.
---@type verilua.handles.AliasBundle
local nasti_aw = ([[
    | ready
    | valid
    | bits_id => id
    | bits_addr => addr
    | bits_len => len
    | bits_size => size
    | bits_burst => burst
    | bits_lock => lock
    | bits_cache => cache
    | bits_prot => prot
    | bits_qos => qos
]]):abdl({ hier = hier, prefix = "io_nasti_aw_", name = "NASTI_AW" })

---@type verilua.handles.AliasBundle
local nasti_w = ([[
    | ready
    | valid
    | bits_data => data
    | bits_strb => strb
    | bits_last => last
]]):abdl({ hier = hier, prefix = "io_nasti_w_", name = "NASTI_W" })

---@type verilua.handles.AliasBundle
local nasti_b = ([[
    | ready
    | valid
    | bits_id => id
    | bits_resp => resp
]]):abdl({ hier = hier, prefix = "io_nasti_b_", name = "NASTI_B" })

---@type verilua.handles.AliasBundle
local nasti_ar = ([[
    | ready
    | valid
    | bits_id => id
    | bits_addr => addr
    | bits_len => len
    | bits_size => size
    | bits_burst => burst
    | bits_lock => lock
    | bits_cache => cache
    | bits_prot => prot
    | bits_qos => qos
]]):abdl({ hier = hier, prefix = "io_nasti_ar_", name = "NASTI_AR" })

---@type verilua.handles.AliasBundle
local nasti_r = ([[
    | ready
    | valid
    | bits_id => id
    | bits_data => data
    | bits_resp => resp
    | bits_last => last
]]):abdl({ hier = hier, prefix = "io_nasti_r_", name = "NASTI_R" })

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

-- Hold all memory responses and request acceptance inactive until a driver starts.
local function init_inputs()
    host.fromhost_valid:set_imm(0)
    host.fromhost:set_imm(0)
    nasti_aw.ready:set_imm(0)
    nasti_w.ready:set_imm(0)
    nasti_b.valid:set_imm(0)
    nasti_b.id:set_imm(0)
    nasti_b.resp:set_imm(0)
    nasti_ar.ready:set_imm(0)
    nasti_r.valid:set_imm(0)
    nasti_r.id:set_imm(0)
    nasti_r.data:set_imm(0)
    nasti_r.resp:set_imm(0)
    nasti_r.last:set_imm(0)
end

local function dut_reset()
    control.reset:set_imm(1)
    init_inputs()
    clock:posedge(10)
    control.reset:set_imm(0)
end

---@return integer
local function get_random_bit()
    return random(100) % 2
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
    control = control,
    host = host,
    nasti = {
        aw = nasti_aw,
        w = nasti_w,
        b = nasti_b,
        ar = nasti_ar,
        r = nasti_r,
    },
    init_inputs = init_inputs,
    get_random_bit = get_random_bit,
    dut_reset = dut_reset,
    launch_monitor_task = launch_monitor_task,
    test_success = test_success,
}

return EnvUtils
