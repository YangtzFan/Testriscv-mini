local utils = require "verilua.LuaUtils"

---@class test_template.CFG
local cfg = {}
local get_env_or_else = utils.get_env_or_else

cfg.enable_test_template_monitor = get_env_or_else("ENABLE", "boolean", true)
cfg.verbose_test_template_monitor = get_env_or_else("VER", "boolean", true)
cfg.enable_heart_beat = get_env_or_else("HEART", "boolean", true)

return cfg
