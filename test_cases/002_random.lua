local env = (require "env") --[[@as test_template.Env]]

local clock = env.clock
local set_input = env.set_input

local random = math.random

local function task_random()
    for _ = 1, 10 do
        set_input(random(0, 100), random(0, 100))
        clock:posedge()
    end
end

return function()
    task_random()
end
