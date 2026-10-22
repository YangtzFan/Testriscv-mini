local class = require "pl.class"
local Memory = require "test_zhujiang_utils.Memory"

-- Nasti slave driver backed exclusively by the shared 32-byte Memory entries.
---@class test_template.NastiSlave
---@overload fun(bus: table<string, verilua.handles.AliasBundle>, clock: verilua.handles.CallableHDL, size: integer): test_template.NastiSlave
local NastiSlave = class()

function NastiSlave:_init(bus, clock, size)
    self.bus = bus
    self.clock = clock
    self.size = size
    self.storage = Memory("TileMemory", false)
    self.state = "idle"
    self.reads, self.writes = 0, 0
    self.read_beats, self.write_beats = 0, 0
end

function NastiSlave:check_range(addr, count)
    assert(addr >= 0 and addr + count <= self.size,
        string.format("Memory access out of range: addr=0x%x bytes=%d", addr, count))
end

-- elf2hex 16 places the lower-addressed bytes at the right of each line.
function NastiSlave:load_hex(filename)
    local file = assert(io.open(filename, "r"))
    local addr = 0
    for line in file:lines() do
        local hex = line:gsub("%s", "")
        assert(#hex == 32 and hex:match("^%x+$"), "Expected 128-bit elf2hex entries")
        self:check_range(addr, 16)
        self:write_hex(addr, hex:sub(17, 32), 255)
        self:write_hex(addr + 8, hex:sub(1, 16), 255)
        addr = addr + 16
    end
    file:close()
    assert(addr > 0, "Empty program image")
    print(string.format("Loaded %s: %d bytes, entry=0x200", filename, addr))
end

function NastiSlave:read_hex(addr)
    self:check_range(addr, 8)
    assert(addr % 8 == 0, "Unaligned 64-bit memory read")
    local line = self.storage:read(addr, true)
    local first = 49 - (addr % 32) * 2
    return line:sub(first, first + 15)
end

function NastiSlave:write_hex(addr, hex, strobe)
    self:check_range(addr, 8)
    assert(addr % 8 == 0, "Unaligned 64-bit memory write")
    assert(#hex <= 16 and hex:match("^%x+$"), "Invalid 64-bit write data")
    assert(strobe >= 0 and strobe <= 255 and strobe % 1 == 0, "Invalid 8-bit write strobe")
    hex = string.rep("0", 16 - #hex) .. hex
    local offset = addr % 32
    local data = string.rep("0", (24 - offset) * 2) .. hex .. string.rep("0", offset * 2)
    local mask = string.format("%08x", strobe * 2 ^ offset)
    self.storage:write(addr, data, mask)
end

function NastiSlave:accept_address(channel, state)
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

-- Drive at falling edges, sample at rising edges; hold responses under stalls.
function NastiSlave:step()
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

return NastiSlave
