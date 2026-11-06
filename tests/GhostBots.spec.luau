--!strict
local GhostBots = require("../src/shared/GhostBots")
local GhostCodec = require("../src/shared/GhostCodec")
local Harness = require("./Harness")

local ID_BASE = 4000000000000

return function(t: Harness.T)
	t.test("the same inputs give the same output", function()
		t.eq(GhostBots.entries(5, 12.5, ID_BASE), GhostBots.entries(5, 12.5, ID_BASE))
	end)

	t.test("returns the requested count, and none for zero", function()
		t.eq(#GhostBots.entries(7, 0, ID_BASE), 7)
		t.eq(#GhostBots.entries(0, 0, ID_BASE), 0)
	end)

	t.test("ids are unique, outside real player ids, and survive the codec", function()
		local bots = GhostBots.entries(42, 3, ID_BASE)
		local seen = {}
		for _, bot in bots do
			t.notOk(seen[bot.userId], "duplicate id")
			seen[bot.userId] = true
			t.ok(bot.userId > 1000000000000, "must not look like a real player")
		end
		local text = GhostCodec.encode(1, bots)
		local decoded = GhostCodec.decode(text)
		assert(decoded, "bots must decode")
		t.eq(#decoded.entries, 42)
	end)

	t.test("every bot moves at walking speed, so ghosts blend and never snap", function()
		local before = GhostBots.entries(42, 10, ID_BASE)
		local after = GhostBots.entries(42, 11, ID_BASE)
		for i, bot in before do
			local dx, dz = after[i].x - bot.x, after[i].z - bot.z
			local moved = math.sqrt(dx * dx + dz * dz)
			t.ok(moved > 1 and moved <= 16, `bot {i} moved {moved} studs in a second`)
		end
	end)

	t.test("reported velocity matches actual movement", function()
		local before = GhostBots.entries(3, 10, ID_BASE)
		local after = GhostBots.entries(3, 10.01, ID_BASE)
		for i, bot in before do
			t.ok(math.abs((after[i].x - bot.x) / 0.01 - bot.vx) < 0.5, "vx")
			t.ok(math.abs((after[i].z - bot.z) / 0.01 - bot.vz) < 0.5, "vz")
		end
	end)
end
