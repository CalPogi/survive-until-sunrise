--!strict
--[[
	GhostInterpolator: turns one remote player's snapshots into smooth motion.
	Spec: docs/specs/ghost-presence.md

	Timing never assumes server clocks agree. It tracks the lowest (receive time - sender time) seen,
	which cancels clock difference and base latency, and shows the ghost slightly in the past.
	renderTime in the result is on the sender's clock, so a later hit claim can quote it directly.

	Pure logic: times are passed in. Yaw is in degrees.
]]

-- ponytail: an extrapolated ghost jumps back when the next sample lands. The default render delay
-- makes extrapolation rare. Add error smoothing if the two-server test shows visible pops.

export type Sample = {
	x: number,
	y: number,
	z: number,
	yaw: number,
	vx: number,
	vz: number,
	anim: number,
	held: number,
}

export type Status = "interpolating" | "extrapolating" | "holding" | "gone"

export type State = {
	status: Status,
	x: number,
	y: number,
	z: number,
	yaw: number,
	anim: number,
	held: number,
	renderTime: number,
}

type Stored = Sample & { time: number }

-- Calibration knobs: tune these from the two-server test.
local RENDER_BUFFER = 0.1 -- seconds added to the send interval to absorb jitter
local MAX_EXTRAPOLATION = 0.25 -- seconds
local SNAP_SPEED = 200 -- studs/s; faster than this is a respawn or teleport, not movement
local OFFSET_DRIFT = 0.01 -- seconds per second the offset may rise, to follow real latency changes
local MIN_GONE_AFTER = 5 -- seconds
local GONE_INTERVALS = 3
local MAX_SAMPLES = 16 -- covers the longest render delay (2.6 s) at the fastest send rate
local MAX_CLOCK_JUMP = 5 -- seconds; a sample claiming to be this far ahead is ignored as forged or broken
local DELAY_SLEW = 0.25 -- seconds per second the render delay may change, so ghosts never jump back

local GhostInterpolator = {}
GhostInterpolator.__index = GhostInterpolator

export type GhostInterpolator = typeof(setmetatable(
	{} :: {
		_samples: { Stored },
		_offset: number?,
		_lastReceive: number,
		_renderDelay: number,
		_targetDelay: number,
		_lastSampleAt: number?,
		_goneAfter: number,
	},
	GhostInterpolator
))

-- A ghost that reports "gone" should be discarded, and a new interpolator made if it comes back.
function GhostInterpolator.new(sendInterval: number): GhostInterpolator
	local self = setmetatable({
		_samples = {},
		_offset = nil,
		_lastReceive = 0,
		_renderDelay = sendInterval + RENDER_BUFFER,
		_targetDelay = 0,
		_lastSampleAt = nil,
		_goneAfter = 0,
	}, GhostInterpolator)
	self:setSendInterval(sendInterval)
	return self
end

function GhostInterpolator.setSendInterval(self: GhostInterpolator, sendInterval: number)
	self._targetDelay = sendInterval + RENDER_BUFFER
	self._goneAfter = math.max(MIN_GONE_AFTER, GONE_INTERVALS * sendInterval)
end

function GhostInterpolator.push(self: GhostInterpolator, senderTime: number, receiveTime: number, sample: Sample)
	local seen = receiveTime - senderTime
	local offset = self._offset
	if offset ~= nil and seen < offset - MAX_CLOCK_JUMP then
		return
	end

	local samples = self._samples
	local newest = samples[#samples]
	if newest and senderTime <= newest.time then
		return
	end

	if offset == nil then
		self._offset = seen
	else
		local elapsed = math.max(0, receiveTime - self._lastReceive)
		self._offset = math.min(offset + elapsed * OFFSET_DRIFT, seen)
	end
	self._lastReceive = receiveTime

	table.insert(samples, {
		time = senderTime,
		x = sample.x,
		y = sample.y,
		z = sample.z,
		yaw = sample.yaw,
		vx = sample.vx,
		vz = sample.vz,
		anim = sample.anim,
		held = sample.held,
	})
	if #samples > MAX_SAMPLES then
		table.remove(samples, 1)
	end
end

local function lerp(from: number, to: number, alpha: number): number
	return from + (to - from) * alpha
end

local function lerpYaw(from: number, to: number, alpha: number): number
	local delta = (to - from + 180) % 360 - 180
	return (from + delta * alpha) % 360
end

local function stateOf(status: Status, sample: Stored, renderTime: number, ahead: number): State
	return {
		status = status,
		x = sample.x + sample.vx * ahead,
		y = sample.y,
		z = sample.z + sample.vz * ahead,
		yaw = sample.yaw,
		anim = sample.anim,
		held = sample.held,
		renderTime = renderTime,
	}
end

local function between(older: Stored, newer: Stored, renderTime: number): State
	local dx, dy, dz = newer.x - older.x, newer.y - older.y, newer.z - older.z
	local span = newer.time - older.time
	if math.sqrt(dx * dx + dy * dy + dz * dz) / span > SNAP_SPEED then
		return stateOf("interpolating", older, renderTime, 0)
	end
	local alpha = (renderTime - older.time) / span
	return {
		status = "interpolating",
		x = lerp(older.x, newer.x, alpha),
		y = lerp(older.y, newer.y, alpha),
		z = lerp(older.z, newer.z, alpha),
		yaw = lerpYaw(older.yaw, newer.yaw, alpha),
		anim = older.anim,
		held = older.held,
		renderTime = renderTime,
	}
end

local function moveToward(from: number, to: number, maxStep: number): number
	return from + math.clamp(to - from, -maxStep, maxStep)
end

function GhostInterpolator.sample(self: GhostInterpolator, now: number): State
	local elapsed = math.max(0, now - (self._lastSampleAt or now))
	self._lastSampleAt = now
	self._renderDelay = moveToward(self._renderDelay, self._targetDelay, elapsed * DELAY_SLEW)

	local samples = self._samples
	local offset = self._offset
	if offset == nil or now - self._lastReceive > self._goneAfter then
		local last = samples[#samples]
		return {
			status = "gone",
			x = if last then last.x else 0,
			y = if last then last.y else 0,
			z = if last then last.z else 0,
			yaw = if last then last.yaw else 0,
			anim = if last then last.anim else 0,
			held = if last then last.held else 0,
			renderTime = if offset then now - offset - self._renderDelay else now,
		}
	end

	local renderTime = now - offset - self._renderDelay
	local newest = samples[#samples]
	if renderTime >= newest.time then
		local ahead = renderTime - newest.time
		if ahead <= MAX_EXTRAPOLATION then
			return stateOf("extrapolating", newest, renderTime, ahead)
		end
		return stateOf("holding", newest, renderTime, MAX_EXTRAPOLATION)
	end

	for i = #samples - 1, 1, -1 do
		if samples[i].time <= renderTime then
			return between(samples[i], samples[i + 1], renderTime)
		end
	end
	return stateOf("holding", samples[1], renderTime, 0)
end

return GhostInterpolator
