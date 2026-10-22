local utils = require "verilua.LuaUtils"

---@class test_template.CFG
local cfg = {}
local get_env_or_else = utils.get_env_or_else

cfg.enable_heart_beat = get_env_or_else("HEART", "boolean", true)

return cfg
