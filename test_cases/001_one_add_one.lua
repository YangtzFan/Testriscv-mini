local env = (require "env") --[[@as test_template.Env]]

local clock = env.clock
local set_input = env.set_input

local function task_1()
    set_input(1, 1)
    clock:posedge()
end

return function ()
    task_1()
end
