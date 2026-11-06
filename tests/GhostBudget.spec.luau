--!strict
local GhostBudget = require("../src/shared/GhostBudget")
local Harness = require("./Harness")

-- Pair count when every area holds the same number of servers.
local function uniformPairs(totalServers: number, serversPerArea: number): number
	return totalServers / serversPerArea * serversPerArea * (serversPerArea - 1)
end

return function(t: Harness.T)
	local function near(actual: number, expected: number, message: string?)
		t.ok(math.abs(actual - expected) <= 0.05, `{message or ""} expected {expected}, got {actual}`)
	end

	t.test("matches every row of the spec's budget table", function()
		near(GhostBudget.rawInterval(2, uniformPairs(2, 2)), 0.3)
		near(GhostBudget.rawInterval(10, uniformPairs(10, 2)), 0.5)
		near(GhostBudget.rawInterval(100, uniformPairs(100, 2)), 0.6)
		near(GhostBudget.rawInterval(100, uniformPairs(100, 3)), 1.2)
		near(GhostBudget.rawInterval(10, uniformPairs(10, 5)), 2.0)
		near(GhostBudget.rawInterval(100, uniformPairs(100, 5)), 2.4)
		near(GhostBudget.rawInterval(100, uniformPairs(100, 10)), 5.3)
	end)

	t.test("zero pairs returns the minimum interval", function()
		t.eq(GhostBudget.interval(50, 0), GhostBudget.MIN_INTERVAL)
	end)

	t.test("results clamp at both ends", function()
		t.eq(GhostBudget.interval(1000, 2), GhostBudget.MIN_INTERVAL)
		t.eq(GhostBudget.interval(100, uniformPairs(100, 10)), GhostBudget.MAX_INTERVAL)
		near(GhostBudget.interval(100, uniformPairs(100, 3)), 1.2)
	end)

	t.test("two servers stay under the per-topic limit of 200 a minute", function()
		t.ok(60 / GhostBudget.interval(2, 2) < 200)
	end)

	t.test("canOpenServer allows growth while the interval stays within the limit", function()
		t.ok(GhostBudget.canOpenServer(5, 20, 5), "one area of 5 going to 6 is about 2.25 s")
		t.ok(GhostBudget.canOpenServer(1, 0, 1), "a second server is always fine")
		t.ok(GhostBudget.canOpenServer(1, 0, 0), "a new area costs nothing")
	end)

	t.test("canOpenServer refuses once the interval would pass the limit", function()
		t.notOk(GhostBudget.canOpenServer(6, 30, 6), "one area of 6 going to 7 is about 2.8 s")
		t.notOk(GhostBudget.canOpenServer(9, 72, 9), "one area of 9 going to 10 is about 4.5 s")
	end)
end
