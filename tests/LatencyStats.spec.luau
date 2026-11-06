--!strict
local Harness = require("./Harness")
local LatencyStats = require("../src/shared/LatencyStats")

return function(t: Harness.T)
	t.test("known samples give known percentiles", function()
		local stats = LatencyStats.new(1000)
		for i = 100, 1, -1 do
			stats:add(i)
		end
		t.eq(stats:percentile(50), 50)
		t.eq(stats:percentile(95), 95)
		t.eq(stats:percentile(100), 100)
		t.eq(stats:count(), 100)
	end)

	t.test("a single sample is every percentile", function()
		local stats = LatencyStats.new(10)
		stats:add(0.2)
		t.eq(stats:percentile(1), 0.2)
		t.eq(stats:percentile(100), 0.2)
	end)

	t.test("an empty set returns nil", function()
		t.eq(LatencyStats.new(10):percentile(50), nil)
	end)

	t.test("memory is bounded to the most recent samples", function()
		local stats = LatencyStats.new(3)
		for _, value in { 100, 1, 2, 3 } do
			stats:add(value)
		end
		t.eq(stats:count(), 3)
		t.eq(stats:percentile(100), 3, "the oldest sample is gone")
	end)
end
