-- File is MIT license
-- See: @ayios/util/Bitfield
-- Basically swiped from Discord's implementation, and put into Luau and modified a bit
-- Compiled with roblox-ts v3.0.0
local function hasBit(raw, bit)
	return (bit32.band(raw, bit)) == bit
end
local function hasAll(raw, bits)
	-- ▼ ReadonlyArray.every ▼
	local _result = true
	local _callback = function(bit)
		return hasBit(raw, bit)
	end
	for _k, _v in bits do
		if not _callback(_v, _k - 1, bits) then
			_result = false
			break
		end
	end
	-- ▲ ReadonlyArray.every ▲
	return _result
end
local function hasAny(raw, bits)
	-- ▼ ReadonlyArray.some ▼
	local _result = false
	local _callback = function(bit)
		return hasBit(raw, bit)
	end
	for _k, _v in bits do
		if _callback(_v, _k - 1, bits) then
			_result = true
			break
		end
	end
	-- ▲ ReadonlyArray.some ▲
	return _result
end
local function apply(raw, bits)
	local _readable = raw
	-- ▼ ReadonlyArray.reduce ▼
	local _result = 0
	local _callback = function(a, b)
		return bit32.bor(a, b)
	end
	for _i = 1, #bits do
		_result = _callback(_result, bits[_i], _i - 1, bits)
	end
	-- ▲ ReadonlyArray.reduce ▲
	raw = bit32.bor(_readable, _result)
	return raw
end
local Bitfield
do
	Bitfield = setmetatable({}, {
		__tostring = function()
			return "Bitfield"
		end,
	})
	Bitfield.__index = Bitfield
	function Bitfield.new(...)
		local self = setmetatable({}, Bitfield)
		return self:constructor(...) or self
	end
	function Bitfield:constructor(raw)
		self.raw = raw
	end
	function Bitfield:has(bit)
		return hasBit(self.raw, bit)
	end
	function Bitfield:hasAll(bits)
		-- return bits.every((bit) => this.has(bit));
		return hasAll(self.raw, bits)
	end
	function Bitfield:hasAny(bits)
		return hasAny(self.raw, bits)
	end
	function Bitfield:apply(bits)
		self.raw = apply(self.raw, bits)
		return self
	end
end
return {
	hasAll = hasAll,
	hasAny = hasAny,
	hasBit = hasBit,
	apply = apply,
	Class = Bitfield,
}