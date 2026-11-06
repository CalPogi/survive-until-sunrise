--!strict
--[[
	GhostPacer: decides when a server sends a ghost snapshot. Spec: docs/specs/ghost-polish.md

	Sends when something visibly changed, when a moving player is due, or at a slow heartbeat. Credit
	keeps the average at the budget rate, and steady sends leave some of it spare for changes.

	Pure logic.
]]

-- The same shape as GhostCodec.Entry.
type Entry = {
	userId: number,
	x: number,
	y: number,
	z: number,
	yaw: number,
	vx: number,
	vz: number,
	anim: number,
	held: number,
}

local RESERVE = 1.1 -- higher keeps more credit for turns, but adds delay
local MAX_CREDIT = 3
local HEARTBEAT = 2.5 -- seconds; well inside the 8 s a ghost survives without samples
local MOVING_SPEED = 1 -- studs/s
local SHARP_TURN_COS = math.cos(math.rad(45))
local SHARP_FACING = 45 -- degrees
local HEIGHT_CHANGE = 1 -- studs

local GhostPacer = {}
GhostPacer.__index = GhostPacer

export type GhostPacer = typeof(setmetatable(
	{} :: {
		_credit: number,
		_creditTime: number?,
		_lastSend: number,
		_sent: { [number]: Entry },
	},
	GhostPacer
))

local function isMoving(entry: Entry): boolean
	return entry.vx * entry.vx + entry.vz * entry.vz >= MOVING_SPEED * MOVING_SPEED
end

local function turnedSharply(before: Entry, now: Entry): boolean
	local dot = before.vx * now.vx + before.vz * now.vz
	local lengths = math.sqrt((before.vx * before.vx + before.vz * before.vz) * (now.vx * now.vx + now.vz * now.vz))
	return dot < SHARP_TURN_COS * lengths
end

local function facingDifference(a: number, b: number): number
	local difference = math.abs(a - b) % 360
	return if difference > 180 then 360 - difference else difference
end

local function hasChanged(before: Entry?, now: Entry): boolean
	if before == nil or now.anim ~= 0 then
		return true
	end
	local wasMoving, moving = isMoving(before), isMoving(now)
	return wasMoving ~= moving
		or (moving and turnedSharply(before, now))
		or facingDifference(before.yaw, now.yaw) > SHARP_FACING
		or math.abs(before.y - now.y) > HEIGHT_CHANGE
end

-- The spacing between steady sends for a budget interval, leaving spare credit for changes.
function GhostPacer.spacingFor(budgetInterval: number): number
	return budgetInterval * RESERVE
end

function GhostPacer.new(): GhostPacer
	return setmetatable({
		_credit = MAX_CREDIT,
		_creditTime = nil :: number?,
		_lastSend = -math.huge,
		_sent = {} :: { [number]: Entry },
	}, GhostPacer)
end

-- True means send now. It spends credit and remembers these entries, so call it only when able to send.
function GhostPacer.shouldSend(self: GhostPacer, now: number, spacing: number, entries: { Entry }): boolean
	local elapsedCredit = if self._creditTime then now - self._creditTime else 0
	self._credit = math.min(MAX_CREDIT, self._credit + elapsedCredit * RESERVE / spacing)
	self._creditTime = now
	if self._credit < 1 then
		return false
	end

	local changed, moving = false, false
	for _, entry in entries do
		changed = changed or hasChanged(self._sent[entry.userId], entry)
		moving = moving or isMoving(entry)
	end
	local elapsed = now - self._lastSend
	local due = (moving and elapsed >= spacing) or elapsed >= math.max(HEARTBEAT, spacing)
	if not changed and not due then
		return false
	end

	self._credit -= 1
	self._lastSend = now
	local sent: { [number]: Entry } = {}
	for _, entry in entries do
		sent[entry.userId] = entry
	end
	self._sent = sent
	return true
end

return GhostPacer
