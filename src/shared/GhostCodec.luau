--!strict
--[[
	GhostCodec: the cross-server snapshot format. Spec: docs/specs/ghost-presence.md

	A message is printable ASCII from a 64-character alphabet, so JSON adds no escaping and one
	character is one byte. Header (9): version, type, sender time in ms. Entry (21): see writeEntry.

	Pure logic. decode never errors on bad input, because message text comes from outside this server.
]]

-- ponytail: user id is sent in every entry instead of a slot table with a roster message. It caps a
-- message at 42 players, so fuller servers update each player less often. Add slots if that shows.

export type Entry = {
	userId: number,
	x: number,
	y: number,
	z: number,
	yaw: number, -- degrees
	vx: number,
	vz: number,
	anim: number, -- an action from GhostCodec.Action, or 0
	held: number,
}

export type Decoded = {
	senderTime: number, -- seconds, on the sender's clock
	entries: { Entry },
}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local VERSION = 1
local TYPE_SNAPSHOT = "S"
local HEADER_LENGTH = 9
local ENTRY_LENGTH = 21

local POSITION_STEP = 0.25
local POSITION_MIN = -32768
local HEIGHT_STEP = 0.5
local HEIGHT_MIN = -1024
local YAW_STEP = 5.625
local VELOCITY_STEP = 2
local VELOCITY_MIN = -64
-- Studio test players have negative ids, so ids are stored with this added.
local USER_ID_OFFSET = 1024

local CHAR_FOR_DIGIT: { [number]: string } = {}
local DIGIT_FOR_BYTE: { [number]: number } = {}
for i = 1, 64 do
	local char = string.sub(ALPHABET, i, i)
	CHAR_FOR_DIGIT[i - 1] = char
	DIGIT_FOR_BYTE[string.byte(char)] = i - 1
end

local GhostCodec = {}

GhostCodec.MAX_CHARS = 900
GhostCodec.MAX_ENTRIES = (GhostCodec.MAX_CHARS - HEADER_LENGTH) // ENTRY_LENGTH

-- Values for Entry.anim. 0 means no action. Unknown values are ignored on receipt.
GhostCodec.Action = {
	Jump = 1,
}

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function writeInt(value: number, width: number): string
	local chars = table.create(width, "")
	local rest = value
	for i = width, 1, -1 do
		chars[i] = CHAR_FOR_DIGIT[rest % 64]
		rest = rest // 64
	end
	return table.concat(chars)
end

-- Nil if any character is outside the alphabet.
local function readInt(text: string, start: number, width: number): number?
	local value = 0
	for i = start, start + width - 1 do
		local digit = DIGIT_FOR_BYTE[string.byte(text, i)]
		if digit == nil then
			return nil
		end
		value = value * 64 + digit
	end
	return value
end

-- Rounds to the nearest step and clamps into what `width` characters can hold.
local function writeStepped(value: number, min: number, step: number, width: number): string
	local steps = math.round((value - min) / step)
	return writeInt(math.clamp(steps, 0, 64 ^ width - 1), width)
end

local function writeWhole(value: number, width: number): string
	return writeInt(math.clamp(math.floor(value), 0, 64 ^ width - 1), width)
end

local function isSendable(entry: Entry): boolean
	for _, value in { entry.x, entry.y, entry.z, entry.yaw, entry.vx, entry.vz, entry.anim, entry.held } do
		if not isFinite(value) then
			return false
		end
	end
	-- A bad id is skipped, not clamped, so it can never turn into someone else.
	local stored = entry.userId + USER_ID_OFFSET
	return isFinite(stored) and stored >= 0 and stored < 64 ^ 7 and stored == math.floor(stored)
end

local function writeEntry(entry: Entry): string
	return writeInt(entry.userId + USER_ID_OFFSET, 7)
		.. writeStepped(entry.x, POSITION_MIN, POSITION_STEP, 3)
		.. writeStepped(entry.y, HEIGHT_MIN, HEIGHT_STEP, 2)
		.. writeStepped(entry.z, POSITION_MIN, POSITION_STEP, 3)
		.. writeInt(math.round(entry.yaw / YAW_STEP) % 64, 1)
		.. writeStepped(entry.vx, VELOCITY_MIN, VELOCITY_STEP, 1)
		.. writeStepped(entry.vz, VELOCITY_MIN, VELOCITY_STEP, 1)
		.. writeWhole(entry.anim, 1)
		.. writeWhole(entry.held, 2)
end

-- Nil if any character is outside the alphabet.
local function readEntry(text: string, at: number): Entry?
	local userId = readInt(text, at, 7)
	local x = readInt(text, at + 7, 3)
	local y = readInt(text, at + 10, 2)
	local z = readInt(text, at + 12, 3)
	local yaw = readInt(text, at + 15, 1)
	local vx = readInt(text, at + 16, 1)
	local vz = readInt(text, at + 17, 1)
	local anim = readInt(text, at + 18, 1)
	local held = readInt(text, at + 19, 2)
	if not (userId and x and y and z and yaw and vx and vz and anim and held) then
		return nil
	end
	return {
		userId = userId - USER_ID_OFFSET,
		x = POSITION_MIN + x * POSITION_STEP,
		y = HEIGHT_MIN + y * HEIGHT_STEP,
		z = POSITION_MIN + z * POSITION_STEP,
		yaw = yaw * YAW_STEP,
		vx = VELOCITY_MIN + vx * VELOCITY_STEP,
		vz = VELOCITY_MIN + vz * VELOCITY_STEP,
		anim = anim,
		held = held,
	}
end

--[[
	Packs entries from `startIndex` (default 1) until the message is full. Returns the text and how
	many input entries were consumed, including skipped ones, so the caller's next startIndex is
	startIndex + consumed. Entries with NaN, infinity or an unusable user id are skipped.
]]
function GhostCodec.encode(senderTime: number, entries: { Entry }, startIndex: number?): (string, number)
	-- Throws instead of clamping: a clamped clock would freeze every ghost without any error.
	local millis = if isFinite(senderTime) then math.round(senderTime * 1000) else -1
	assert(millis >= 0 and millis < 64 ^ 7, "senderTime out of range")

	local parts = { writeInt(VERSION, 1), TYPE_SNAPSHOT, writeInt(millis, 7) }
	local first = startIndex or 1
	local written = 0
	local consumed = 0
	for i = first, #entries do
		if written == GhostCodec.MAX_ENTRIES then
			break
		end
		consumed += 1
		if isSendable(entries[i]) then
			table.insert(parts, writeEntry(entries[i]))
			written += 1
		end
	end
	return table.concat(parts), consumed
end

-- Returns the decoded message, or nil and a reason.
function GhostCodec.decode(text: unknown): (Decoded?, string?)
	if type(text) ~= "string" then
		return nil, "not a string"
	end
	if #text < HEADER_LENGTH or #text > GhostCodec.MAX_CHARS then
		return nil, "bad length"
	end
	if (#text - HEADER_LENGTH) % ENTRY_LENGTH ~= 0 then
		return nil, "partial entry"
	end
	if readInt(text, 1, 1) ~= VERSION then
		return nil, "wrong version"
	end
	if string.sub(text, 2, 2) ~= TYPE_SNAPSHOT then
		return nil, "wrong type"
	end
	local millis = readInt(text, 3, 7)
	if millis == nil then
		return nil, "bad character"
	end

	local entries: { Entry } = {}
	for at = HEADER_LENGTH + 1, #text, ENTRY_LENGTH do
		local entry = readEntry(text, at)
		if entry == nil then
			return nil, "bad character"
		end
		table.insert(entries, entry)
	end
	return { senderTime = millis / 1000, entries = entries }, nil
end

return GhostCodec
