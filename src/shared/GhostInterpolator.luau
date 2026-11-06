--!strict
--[[
	GhostInterpolator: turns one remote player's snapshots into smooth motion.
	Spec: docs/specs/ghost-presence.md

	Timing never assumes server clocks agree. It tracks the lowest (receive time - sender time) seen,
	which cancels clock difference and base latency, and shows the ghost slightly in the past.
	renderTime in the result is on the sender's clock, so a later hit claim can quote it directly.

	Prediction (showing the ghost ahead of its newest sample) was tried and rejected: on live servers
	at a 1 s send interval, real players turn too often and it looked like teleporting.

	Pure logic: times are passed in. Yaw is in degrees.
]]

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
	jumping: boolean,
}

type Stored = Sample & { time: number }

-- Calibration knobs: tune these from the two-server test.
local RENDER_BUFFER = 0.1 -- seconds added to the send interval to absorb jitter
local MAX_EXTRAPOLATION = 0.25 -- seconds
local CORRECTION_TIME = 0.12 -- seconds; how quickly a correction fades (about 3x this to vanish)
local MAX_CORRECTION = 40 -- studs; a bigger difference is a teleport, so it snaps
local SNAP_SPEED = 200 -- studs/s; faster than this is a respawn or teleport, not movement
local OFFSET_DRIFT = 0.01 -- seconds per second the offset may rise, to follow real latency changes
local MIN_GONE_AFTER = 8 -- seconds; survives a lost 2.5 s heartbeat on a full server
local GONE_INTERVALS = 3
local MAX_SAMPLES = 16 -- covers the longest render delay (2.6 s) at the fastest send rate
local MAX_CLOCK_JUMP = 5 -- seconds; a sample claiming to be this far ahead is ignored as forged or broken
local DELAY_SLEW = 0.25 -- seconds per second the render delay may change, so ghosts never jump back
local JUMP_SPEED = 53.15 -- studs/s; a default jump: JumpHeight 7.2 at gravity 196.2
local JUMP_GRAVITY = 196.2
local JUMP_TIME = 2 * JUMP_SPEED / JUMP_GRAVITY
local JUMP_RESTART_HEIGHT = 1 -- studs

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
		_correction: { x: number, y: number, z: number, yaw: number },
		_jumps: { number }, -- sender times, oldest first
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
		_correction = { x = 0, y = 0, z = 0, yaw = 0 },
		_jumps = {},
	}, GhostInterpolator)
	self:setSendInterval(sendInterval)
	return self
end

function GhostInterpolator.setSendInterval(self: GhostInterpolator, sendInterval: number)
	self._targetDelay = sendInterval + RENDER_BUFFER
	self._goneAfter = math.max(MIN_GONE_AFTER, GONE_INTERVALS * sendInterval)
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
		jumping = false,
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
		jumping = false,
	}
end

local function moveToward(from: number, to: number, maxStep: number): number
	return from + math.clamp(to - from, -maxStep, maxStep)
end

local function applyCorrection(self: GhostInterpolator, state: State, elapsed: number)
	local correction = self._correction
	local fade = math.exp(-elapsed / CORRECTION_TIME)
	correction.x *= fade
	correction.y *= fade
	correction.z *= fade
	correction.yaw *= fade

	state.x += correction.x
	state.y += correction.y
	state.z += correction.z
	state.yaw = (state.yaw + correction.yaw) % 360
end

local function latestState(self: GhostInterpolator, renderTime: number): State
	local samples = self._samples
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

-- Blends away the jump a new sample causes. Measured at one moment with and without the sample, so
-- the ghost's normal movement between frames never counts as an error.
local function addCorrection(self: GhostInterpolator, before: State, after: State)
	local correction = self._correction
	local dx, dy, dz = before.x - after.x, before.y - after.y, before.z - after.z
	if math.sqrt(dx * dx + dy * dy + dz * dz) > MAX_CORRECTION then
		correction.x, correction.y, correction.z, correction.yaw = 0, 0, 0, 0
	else
		correction.x += dx
		correction.y += dy
		correction.z += dz
		correction.yaw += (before.yaw - after.yaw + 180) % 360 - 180
	end
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

	-- Nothing to blend from until a frame has been drawn.
	local drawn = newest and offset and self._lastSampleAt
	local before = if drawn then latestState(self, receiveTime - (offset :: number) - self._renderDelay) else nil

	local newOffset = seen
	if offset ~= nil then
		local elapsed = math.max(0, receiveTime - self._lastReceive)
		newOffset = math.min(offset + elapsed * OFFSET_DRIFT, seen)
	end
	self._offset = newOffset
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

	if before then
		addCorrection(self, before, latestState(self, receiveTime - newOffset - self._renderDelay))
	end
end

local function arcHeight(airTime: number): number
	if airTime < 0 or airTime >= JUMP_TIME then
		return 0
	end
	return JUMP_SPEED * airTime - 0.5 * JUMP_GRAVITY * airTime * airTime
end

-- Queues a jump at its time on the sender's clock, so it plays where the ghost's body made it. The
-- sender leaves jumps out of its height samples. A jump that would start high in the previous arc is
-- ignored, because it would drop the ghost in one frame.
function GhostInterpolator.playJump(self: GhostInterpolator, senderTime: number)
	local jumps = self._jumps
	local last = jumps[#jumps]
	if last == nil or (senderTime > last and arcHeight(senderTime - last) <= JUMP_RESTART_HEIGHT) then
		table.insert(jumps, senderTime)
	end
end

local function jumpHeight(self: GhostInterpolator, renderTime: number): number
	local jumps = self._jumps
	while jumps[2] and jumps[2] <= renderTime do
		table.remove(jumps, 1)
	end
	return if jumps[1] then arcHeight(renderTime - jumps[1]) else 0
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
			jumping = false,
		}
	end

	local state = latestState(self, now - offset - self._renderDelay)
	applyCorrection(self, state, elapsed)
	local height = jumpHeight(self, state.renderTime)
	state.y += height
	state.jumping = height > 0
	return state
end

return GhostInterpolator
