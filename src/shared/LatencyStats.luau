--!strict
-- LatencyStats: percentiles over the most recent samples. Spec: docs/specs/ghost-live.md

local LatencyStats = {}
LatencyStats.__index = LatencyStats

export type LatencyStats = typeof(setmetatable(
	{} :: {
		_maxSamples: number,
		_samples: { number },
	},
	LatencyStats
))

function LatencyStats.new(maxSamples: number): LatencyStats
	return setmetatable({ _maxSamples = maxSamples, _samples = {} }, LatencyStats)
end

function LatencyStats.add(self: LatencyStats, value: number)
	table.insert(self._samples, value)
	if #self._samples > self._maxSamples then
		table.remove(self._samples, 1)
	end
end

function LatencyStats.count(self: LatencyStats): number
	return #self._samples
end

-- Nearest-rank percentile, p from 1 to 100. Nil when there are no samples.
function LatencyStats.percentile(self: LatencyStats, p: number): number?
	local count = #self._samples
	if count == 0 then
		return nil
	end
	local sorted = table.clone(self._samples)
	table.sort(sorted)
	return sorted[math.clamp(math.ceil(p / 100 * count), 1, count)]
end

return LatencyStats
