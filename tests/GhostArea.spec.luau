--!strict
local GhostArea = require("../src/shared/GhostArea")
local Harness = require("./Harness")

return function(t: Harness.T)
	t.test("one server has no peers and no pairs", function()
		local summary = GhostArea.summarize({ { serverId = "me", area = "a" } }, "a", "me")
		t.eq(summary, { totalServers = 1, peers = {}, pairCount = 0 })
	end)

	t.test("two areas of different sizes give the right pair count", function()
		local summary = GhostArea.summarize({
			{ serverId = "me", area = "a" },
			{ serverId = "p1", area = "a" },
			{ serverId = "p2", area = "a" },
			{ serverId = "o1", area = "b" },
			{ serverId = "o2", area = "b" },
		}, "a", "me")
		t.eq(summary.totalServers, 5)
		t.eq(summary.pairCount, 8, "3 x 2 + 2 x 1")
	end)

	t.test("peers are only other servers in my area, in a stable order", function()
		local summary = GhostArea.summarize({
			{ serverId = "p2", area = "a" },
			{ serverId = "me", area = "a" },
			{ serverId = "o1", area = "b" },
			{ serverId = "p1", area = "a" },
		}, "a", "me")
		t.eq(summary.peers, { "p1", "p2" })
	end)

	t.test("my own server counts even if the registry hasn't shown it yet", function()
		local summary = GhostArea.summarize({ { serverId = "p1", area = "a" } }, "a", "me")
		t.eq(summary.totalServers, 2)
		t.eq(summary.peers, { "p1" })
		t.eq(summary.pairCount, 2)
	end)

	t.test("malformed entries are skipped", function()
		local summary = GhostArea.summarize({
			{ serverId = "me", area = "a" },
			"nonsense",
			42,
			{ serverId = 7, area = "a" },
			{ serverId = "no-area" },
			{ serverId = "", area = "a" },
		}, "a", "me")
		t.eq(summary.totalServers, 1)
		t.eq(summary.peers, {})
	end)

	t.test("an empty registry still counts me", function()
		t.eq(GhostArea.summarize({}, "a", "me"), { totalServers = 1, peers = {}, pairCount = 0 })
	end)
end
