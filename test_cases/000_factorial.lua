local env = (require "env") --[[@as test_template.Env]]
local Memory = require "memory"

-- This example's main stores ans at __stack_top - 20 (see factorial.dump).
-- Observe the CPU-side store because this write-back cache need not evict the
-- result to external memory before the program signals completion.
local stores = ([[
    | req_valid => valid
    | req_bits_addr => addr
    | req_bits_data => data
    | req_bits_mask => mask
]]):abdl({ hier = "tb_top.u_Tile.core", prefix = "io_dcache_", name = "CPU_STORES" })

return function()
    local memory = Memory(env.nasti, env.clock, 0x80000)
    local image = os.getenv("HEX") or "build/programs/factorial/factorial.hex"
    if image:sub(1, 1) ~= "/" then
        image = cfg.prj_dir .. "/" .. image
    end
    memory:load_hex(image)
    -- Check the first instruction too, catching a shifted or byte-swapped image.
    assert(memory:read_hex(0x200):sub(9) == "00080117", "Unexpected reset instruction")

    local result
    local max_cycles = tonumber(os.getenv("MAX_CYCLES") or "100000")
    assert(max_cycles and max_cycles >= 1, "MAX_CYCLES must be positive")
    for cycle = 1, max_cycles do
        memory:step()
        if stores.valid:get() == 1 and stores.addr:get() == 0x7ffec and stores.mask:get() == 15 then
            result = stores.data:get()
        end
        local tohost = env.host.tohost:get()
        if tohost ~= 0 then
            assert(tohost == 1, string.format("Program failed: tohost=0x%x", tohost))
            assert(result == 3628800, string.format("factorial(10): expected 3628800, got %s", tostring(result)))
            print(string.format("factorial(10) = %d; tohost=%d; cycles=%d", result, tohost, cycle))
            print(string.format("Nasti: %d reads (%d beats), %d writebacks (%d beats)",
                memory.reads, memory.read_beats, memory.writes, memory.write_beats))
            return
        end
    end
    error(string.format("factorial timed out after %d cycles (memory state=%s)", max_cycles, memory.state))
end
