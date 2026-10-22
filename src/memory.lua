local ffi = require "ffi"
local class = require "pl.class"

-- Tile exposes a unified 64-bit Nasti port for I-cache refills and D-cache
-- refills/writebacks. Keep byte-addressed storage so elf2hex endianness and
-- write strobes do not depend on Lua's floating-point integer precision.
---@class test_template.Memory
---@overload fun(bus: table<string, verilua.handles.AliasBundle>, clock: verilua.handles.CallableHDL, size: integer): test_template.Memory
local Memory = class()

---@param bus table<string, verilua.handles.AliasBundle>
---@param clock verilua.handles.CallableHDL
---@param size integer
function Memory:_init(bus, clock, size)
    self.bus = bus
    self.clock = clock
    self.size = size
    self.bytes = ffi.new("uint8_t[?]", size)
    self.state = "idle"
    self.reads, self.writes = 0, 0
    self.read_beats, self.write_beats = 0, 0
end

function Memory:check_range(addr, count)
    assert(addr >= 0 and addr + count <= self.size,
        string.format("Memory access out of range: addr=0x%x bytes=%d", addr, count))
end

-- elf2hex 16 emits one 128-bit value per line, most significant byte first.
-- The rightmost byte belongs at the lowest address of each 16-byte entry.
function Memory:load_hex(filename)
    local file = assert(io.open(filename, "r"))
    local addr = 0
    for line in file:lines() do
        local hex = line:gsub("%s", "")
        assert(#hex == 32 and hex:match("^%x+$"), "Expected 128-bit elf2hex entries")
        self:check_range(addr, 16)
        for byte = 0, 15 do
            local last = #hex - byte * 2
            self.bytes[addr + byte] = assert(tonumber(hex:sub(last - 1, last), 16))
        end
        addr = addr + 16
    end
    file:close()
    assert(addr > 0, "Empty program image")
    print(string.format("Loaded %s: %d bytes, entry=0x200", filename, addr))
end

function Memory:read_hex(addr)
    self:check_range(addr, 8)
    local bytes = {}
    for i = 7, 0, -1 do
        bytes[#bytes + 1] = string.format("%02x", tonumber(self.bytes[addr + i]))
    end
    return table.concat(bytes)
end

function Memory:write_hex(addr, hex, strobe)
    self:check_range(addr, 8)
    assert(#hex <= 16 and hex:match("^%x+$"), "Invalid 64-bit write data")
    hex = string.rep("0", 16 - #hex) .. hex
    for i = 0, 7 do
        if math.floor(strobe / 2 ^ i) % 2 == 1 then
            local last = 16 - 2 * i
            self.bytes[addr + i] = assert(tonumber(hex:sub(last - 1, last), 16))
        end
    end
end

function Memory:accept_address(channel, state)
    self.addr = channel.addr:get()
    self.id = channel.id:get()
    self.len = channel.len:get()
    self.beat = 0
    assert(channel.size:get() == 3, "Tile must use 8-byte Nasti beats")
    assert(channel.burst:get() == 1, "Only INCR bursts are supported")
    assert(self.addr % 8 == 0, "Unaligned Nasti address")
    self:check_range(self.addr, (self.len + 1) * 8)
    self.state = state
end

-- Drive on falling edges and sample handshakes on rising edges. State changes
-- take effect at the next falling edge; responses remain stable under stalls.
function Memory:step()
    local bus = self.bus
    self.clock:negedge()
    bus.aw.ready:set(self.state == "idle" and 1 or 0)
    bus.ar.ready:set(self.state == "idle" and 1 or 0)
    bus.w.ready:set(self.state == "write" and 1 or 0)
    bus.b.valid:set(self.state == "ack" and 1 or 0)
    bus.b.id:set(self.id or 0)
    bus.b.resp:set(0)
    bus.r.valid:set(self.state == "read" and 1 or 0)
    bus.r.id:set(self.id or 0)
    bus.r.resp:set(0)
    bus.r.last:set(self.state == "read" and self.beat == self.len and 1 or 0)
    if self.state == "read" then
        bus.r.data:set_hex_str(self:read_hex(self.addr + self.beat * 8))
    end
    self.clock:posedge()

    if self.state == "idle" then
        assert(not (bus.aw.valid:get() == 1 and bus.ar.valid:get() == 1),
            "Tile issued simultaneous read and write addresses")
        if bus.aw.valid:get() == 1 then
            self:accept_address(bus.aw, "write")
            self.writes = self.writes + 1
        elseif bus.ar.valid:get() == 1 then
            self:accept_address(bus.ar, "read")
            self.reads = self.reads + 1
        end
    elseif self.state == "read" and bus.r.ready:get() == 1 then
        self.read_beats = self.read_beats + 1
        if self.beat == self.len then
            self.state = "idle"
        else
            self.beat = self.beat + 1
        end
    elseif self.state == "write" and bus.w.valid:get() == 1 then
        assert(bus.w.last:get() == (self.beat == self.len and 1 or 0), "Incorrect WLAST")
        self:write_hex(self.addr + self.beat * 8, bus.w.data:get_hex_str(), bus.w.strb:get())
        self.write_beats = self.write_beats + 1
        if self.beat == self.len then
            self.state = "ack"
        else
            self.beat = self.beat + 1
        end
    elseif self.state == "ack" and bus.b.ready:get() == 1 then
        self.state = "idle"
    end
end

return Memory
