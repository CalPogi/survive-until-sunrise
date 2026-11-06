--!strict
local Harness = require("./Harness")
local RateLimiter = require("../src/shared/RateLimiter")

local function makeClock()
	local now = 0
	return {
		read = function(): number
			return now
		end,
		advance = function(seconds: number)
			now += seconds
		end,
	}
end

return function(t: Harness.T)
	t.test("allows a burst up to capacity, then denies", function()
		local clock = makeClock()
		local limiter = RateLimiter.new(3, 1, clock.read)
		t.ok(limiter:allow(1))
		t.ok(limiter:allow(1))
		t.ok(limiter:allow(1))
		t.notOk(limiter:allow(1))
	end)

	t.test("refills over time at the sustained rate", function()
		local clock = makeClock()
		local limiter = RateLimiter.new(2, 1, clock.read)
		t.ok(limiter:allow(1))
		t.ok(limiter:allow(1))
		t.notOk(limiter:allow(1))
		clock.advance(0.5)
		t.notOk(limiter:allow(1), "half a token is not enough")
		clock.advance(0.5)
		t.ok(limiter:allow(1), "one full token has refilled")
		t.notOk(limiter:allow(1))
	end)

	t.test("never refills beyond capacity", function()
		local clock = makeClock()
		local limiter = RateLimiter.new(2, 10, clock.read)
		t.ok(limiter:allow(1))
		clock.advance(1000)
		t.ok(limiter:allow(1))
		t.ok(limiter:allow(1))
		t.notOk(limiter:allow(1))
	end)

	t.test("keys are independent", function()
		local clock = makeClock()
		local limiter = RateLimiter.new(1, 0, clock.read)
		t.ok(limiter:allow(1))
		t.notOk(limiter:allow(1))
		t.ok(limiter:allow(2))
		t.ok(limiter:allow("player-3"))
	end)

	t.test("cost spends multiple tokens and can exceed capacity", function()
		local clock = makeClock()
		local limiter = RateLimiter.new(5, 0, clock.read)
		t.ok(limiter:allow(1, 3))
		t.notOk(limiter:allow(1, 3), "only 2 left")
		t.ok(limiter:allow(1, 2))
		t.notOk(limiter:allow(2, 6), "cost above capacity is never allowed")
	end)

	t.test("remove forgets a key so it starts full again", function()
		local clock = makeClock()
		local limiter = RateLimiter.new(1, 0, clock.read)
		t.ok(limiter:allow(1))
		t.notOk(limiter:allow(1))
		limiter:remove(1)
		t.ok(limiter:allow(1))
	end)

	t.test("a clock that goes backwards does not grant tokens", function()
		local clock = makeClock()
		local limiter = RateLimiter.new(1, 100, clock.read)
		clock.advance(10)
		t.ok(limiter:allow(1))
		clock.advance(-5)
		t.notOk(limiter:allow(1))
	end)

	t.test("constructor rejects invalid settings", function()
		local clock = makeClock()
		t.throws(function()
			RateLimiter.new(0, 1, clock.read)
		end)
		t.throws(function()
			RateLimiter.new(-1, 1, clock.read)
		end)
		t.throws(function()
			RateLimiter.new(1, -1, clock.read)
		end)
	end)
end
