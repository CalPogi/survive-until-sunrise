--!strict
--[[
    Validate: input checks for anything a client can send.

    The client is hostile. Every remote argument must pass a Check before it is used.
    This module has no Roblox API dependencies, so it is unit tested under Lune.

    Example:
        Net.onEvent(RemoteNames.Buy, {
            checks = { Validate.identifier(32), Validate.integerBetween(1, 99) },
            handler = function(player, args) ... end,
        })
]]

export type Check = (value: unknown) -> boolean

local Validate = {}

local function isFinite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Validate.isBoolean(value: unknown): boolean
	return type(value) == "boolean"
end

-- A number that is not NaN and not +/- infinity.
function Validate.isFiniteNumber(value: unknown): boolean
	return isFinite(value)
end

-- Finite number within [min, max], inclusive.
function Validate.numberBetween(min: number, max: number): Check
	return function(value: unknown): boolean
		return type(value) == "number" and isFinite(value) and value >= min and value <= max
	end
end

-- Whole number within [min, max], inclusive.
function Validate.integerBetween(min: number, max: number): Check
	return function(value: unknown): boolean
		return type(value) == "number" and isFinite(value) and value % 1 == 0 and value >= min and value <= max
	end
end

-- String whose length is within [minLength, maxLength]. Length is in bytes (#), which is
-- stricter than characters for non-ASCII text.
function Validate.string(maxLength: number, minLength: number?): Check
	local min = minLength or 0
	return function(value: unknown): boolean
		return type(value) == "string" and #value <= maxLength and #value >= min
	end
end

-- Letters, digits, underscore and hyphen only (1 to maxLength bytes, default 64).
-- Use for ids and keys such as item ids.
function Validate.identifier(maxLength: number?): Check
	local limit = maxLength or 64
	return function(value: unknown): boolean
		return type(value) == "string"
			and #value >= 1
			and #value <= limit
			and string.match(value, "^[A-Za-z0-9_%-]+$") ~= nil
	end
end

-- String that is exactly one of the allowed values.
function Validate.oneOf(allowed: { string }): Check
	return function(value: unknown): boolean
		if type(value) ~= "string" then
			return false
		end
		return table.find(allowed, value) ~= nil
	end
end

-- A real array (keys 1..n, no holes, no extra keys) of at most maxLength items,
-- where every item passes `item`.
function Validate.arrayOf(item: Check, maxLength: number): Check
	return function(value: unknown): boolean
		if type(value) ~= "table" then
			return false
		end
		local tbl = value :: { [unknown]: unknown } -- luau-lsp does not narrow unknown via type()
		local length = #tbl
		if length > maxLength then
			return false
		end
		local count = 0
		for key, element in tbl do
			count += 1
			if type(key) ~= "number" or key < 1 or key > length or key % 1 ~= 0 then
				return false
			end
			if not item(element) then
				return false
			end
		end
		return count == length
	end
end

-- True only if the number of arguments equals #checks and each argument passes its check.
-- Optional arguments are not supported: have the client send an explicit value instead.
function Validate.args(checks: { Check }, ...: unknown): boolean
	if select("#", ...) ~= #checks then
		return false
	end
	for index, check in checks do
		if not check((select(index, ...))) then
			return false
		end
	end
	return true
end

return Validate
