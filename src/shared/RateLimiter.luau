--!strict
--[[
    RateLimiter: token bucket, one bucket per key (usually player.UserId).

    capacity        = largest burst a key may spend at once
    refillPerSecond = sustained rate

    Pure logic: the clock is injected so tests control time. In Roblox pass `time`.
]]

type Bucket = { tokens: number, updated: number }

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_capacity: number,
		_refillPerSecond: number,
		_clock: () -> number,
		_buckets: { [string | number]: Bucket },
	},
	RateLimiter
))

function RateLimiter.new(capacity: number, refillPerSecond: number, clock: () -> number): RateLimiter
	assert(capacity > 0, "capacity must be positive")
	assert(refillPerSecond >= 0, "refillPerSecond must not be negative")
	return setmetatable({
		_capacity = capacity,
		_refillPerSecond = refillPerSecond,
		_clock = clock,
		_buckets = {},
	}, RateLimiter)
end

-- Spends `cost` tokens (default 1) and returns true, or returns false if the key is out of tokens.
function RateLimiter.allow(self: RateLimiter, key: string | number, cost: number?): boolean
	local price = cost or 1
	local now = self._clock()
	local bucket = self._buckets[key]
	if bucket == nil then
		bucket = { tokens = self._capacity, updated = now }
		self._buckets[key] = bucket
	else
		local elapsed = math.max(0, now - bucket.updated)
		bucket.tokens = math.min(self._capacity, bucket.tokens + elapsed * self._refillPerSecond)
		bucket.updated = now
	end
	if bucket.tokens >= price then
		bucket.tokens -= price
		return true
	end
	return false
end

-- Call when a key goes away (for example on PlayerRemoving) so buckets do not leak.
function RateLimiter.remove(self: RateLimiter, key: string | number)
	self._buckets[key] = nil
end

return RateLimiter
