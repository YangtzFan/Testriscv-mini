local env = (require "env") --[[@as test_template.Env]]

local clock = env.clock
local dut_reset = env.dut_reset
local set_input = env.set_input
local unset_input = env.unset_input

local function task_single()
    dut_reset()
    set_input(0, 0)
    clock:posedge()
end

return function()
    task_single()
end
