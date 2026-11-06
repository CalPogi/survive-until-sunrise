--!strict
--[[
	RewindBuffer: recent positions of one local player, so a later hit claim can be checked against
	where the target was. Spec: docs/specs/ghost-presence.md

	Pure logic: times are on this server's own clock and are passed in.
]]

export type Position = { x: number, y: number, z: number }

type Stored = Position & { time: number }

local MAX_AHEAD = 0.25 -- seconds past the newest sample that still count as "now"

local RewindBuffer = {}
RewindBuffer.__index = RewindBuffer

export type RewindBuffer = typeof(setmetatable(
	{} :: {
		_maxAge: number,
		_samples: { Stored },
	},
	RewindBuffer
))

function RewindBuffer.new(maxAge: number): RewindBuffer
	assert(maxAge > 0, "maxAge must be positive")
	return setmetatable({ _maxAge = maxAge, _samples = {} }, RewindBuffer)
end

function RewindBuffer.push(self: RewindBuffer, time: number, x: number, y: number, z: number)
	local samples = self._samples
	local newest = samples[#samples]
	if newest and time <= newest.time then
		return
	end
	table.insert(samples, { time = time, x = x, y = y, z = z })

	-- Keep one sample at or before the cutoff, so the oldest allowed moment can still interpolate.
	local cutoff = time - self._maxAge
	while #samples >= 2 and samples[2].time <= cutoff do
		table.remove(samples, 1)
	end
end

-- Position at `time`, or nil if that moment is outside what the buffer may answer for.
function RewindBuffer.at(self: RewindBuffer, time: number): Position?
	local samples = self._samples
	local newest = samples[#samples]
	if newest == nil or time < newest.time - self._maxAge or time > newest.time + MAX_AHEAD then
		return nil
	end
	if time >= newest.time then
		return { x = newest.x, y = newest.y, z = newest.z }
	end

	for i = #samples - 1, 1, -1 do
		local older = samples[i]
		if older.time <= time then
			local newer = samples[i + 1]
			local alpha = (time - older.time) / (newer.time - older.time)
			return {
				x = older.x + (newer.x - older.x) * alpha,
				y = older.y + (newer.y - older.y) * alpha,
				z = older.z + (newer.z - older.z) * alpha,
			}
		end
	end
	return nil
end

return RewindBuffer
