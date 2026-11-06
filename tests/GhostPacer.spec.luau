--!strict
local GhostCodec = require("../src/shared/GhostCodec")
local GhostPacer = require("../src/shared/GhostPacer")
local Harness = require("./Harness")

local SPACING = 1

local function player(
	overrides: { userId: number?, vx: number?, vz: number?, y: number?, yaw: number?, anim: number? }?
): GhostCodec.Entry
	local o = overrides or {}
	return {
		userId = o.userId or 1,
		x = 0,
		y = o.y or 0,
		z = 0,
		yaw = o.yaw or 0,
		vx = o.vx or 0,
		vz = o.vz or 0,
		anim = o.anim or 0,
		held = 0,
	}
end

-- A pacer that has just sent `entries` at time 0.
local function settled(entries: { GhostCodec.Entry }): GhostPacer.GhostPacer
	local pacer = GhostPacer.new()
	pacer:shouldSend(0, SPACING, entries)
	return pacer
end

return function(t: Harness.T)
	t.test("the first call sends", function()
		t.ok(GhostPacer.new():shouldSend(0, SPACING, { player() }), "expected a send")
	end)

	t.test("idle players send only at the heartbeat", function()
		local pacer = settled({ player() })
		t.ok(not pacer:shouldSend(1, SPACING, { player() }), "1 s is too soon")
		t.ok(not pacer:shouldSend(2.4, SPACING, { player() }), "2.4 s is too soon")
		t.ok(pacer:shouldSend(2.5, SPACING, { player() }), "2.5 s is the heartbeat")
	end)

	t.test("the heartbeat stretches when the spacing is longer", function()
		local pacer = GhostPacer.new()
		pacer:shouldSend(0, 3, { player() })
		t.ok(not pacer:shouldSend(2.9, 3, { player() }), "2.9 s is too soon")
		t.ok(pacer:shouldSend(3, 3, { player() }), "3 s is due")
	end)

	t.test("a steadily moving player sends once per spacing", function()
		local moving = { player({ vx = 16 }) }
		local pacer = settled(moving)
		t.ok(not pacer:shouldSend(0.9, SPACING, moving), "0.9 s is too soon")
		t.ok(pacer:shouldSend(1, SPACING, moving), "1 s is due")
		t.ok(not pacer:shouldSend(1.5, SPACING, moving), "only just sent")
		t.ok(pacer:shouldSend(2, SPACING, moving), "2 s is due")
	end)

	t.test("each kind of change sends at once", function()
		local still, walking = player(), player({ vx = 16 })
		local cases: { { name: string, before: GhostCodec.Entry, now: GhostCodec.Entry } } = {
			{ name = "starting", before = still, now = walking },
			{ name = "stopping", before = walking, now = still },
			{ name = "a sharp turn", before = walking, now = player({ vz = 16 }) },
			{ name = "reversing", before = walking, now = player({ vx = -16 }) },
			{ name = "facing away", before = still, now = player({ yaw = 90 }) },
			{ name = "going up", before = still, now = player({ y = 2 }) },
			{ name = "an action", before = still, now = player({ anim = GhostCodec.Action.Jump }) },
		}
		for _, case in cases do
			local pacer = settled({ case.before })
			t.ok(pacer:shouldSend(0.1, SPACING, { case.now }), case.name)
		end
	end)

	t.test("a new player sends at once", function()
		local pacer = settled({ player() })
		t.ok(pacer:shouldSend(0.1, SPACING, { player(), player({ userId = 2 }) }), "expected a send")
	end)

	t.test("small changes wait", function()
		local walking = player({ vx = 16 })
		local cases: { { name: string, now: GhostCodec.Entry } } = {
			{ name = "a small turn", now = player({ vx = 16, vz = 8 }) },
			{ name = "slowing down", now = player({ vx = 4 }) },
			{ name = "a small facing change", now = player({ vx = 16, yaw = 30 }) },
			{ name = "a small height change", now = player({ vx = 16, y = 0.5 }) },
		}
		for _, case in cases do
			local pacer = settled({ walking })
			t.ok(not pacer:shouldSend(0.1, SPACING, { case.now }), case.name)
		end
	end)

	t.test("facing across zero is a small change", function()
		local pacer = settled({ player({ yaw = 350 }) })
		t.ok(not pacer:shouldSend(0.1, SPACING, { player({ yaw = 10 }) }), "20 degrees apart")
	end)

	t.test("an action sends once, not on every check after", function()
		local pacer = settled({ player() })
		t.ok(pacer:shouldSend(0.1, SPACING, { player({ anim = GhostCodec.Action.Jump }) }), "the action")
		t.ok(not pacer:shouldSend(0.2, SPACING, { player() }), "already sent")
	end)

	t.test("constant changes stay within the budget rate", function()
		local pacer = GhostPacer.new()
		local sends = 0
		local flip = false
		for i = 0, 6000 do
			flip = not flip
			if pacer:shouldSend(i * 0.1, SPACING, { player({ vx = if flip then 16 else -16 }) }) then
				sends += 1
			end
		end
		-- 600 s at 1.1 a second, plus the 3 it starts with.
		t.ok(sends <= 663, `sent {sends}`)
		t.ok(sends >= 650, `credit should keep being used, sent {sends}`)
	end)

	t.test("idle time builds credit for a burst, up to the cap", function()
		local still, a, b = player(), player({ vx = 16 }), player({ vx = -16 })
		local pacer = settled({ still })
		local sends = 0
		for i = 1, 10 do
			if pacer:shouldSend(100 + i * 0.001, SPACING, { if i % 2 == 0 then a else b }) then
				sends += 1
			end
		end
		t.eq(sends, 3)
	end)

	t.test("steady walking keeps credit spare for a change", function()
		local walking = { player({ vx = 16 }) }
		local pacer = GhostPacer.new()
		local now = 0
		for _ = 1, 100 do
			pacer:shouldSend(now, SPACING, walking)
			now += SPACING
		end
		t.ok(pacer:shouldSend(now - SPACING + 0.1, SPACING, { player({ vz = 16 }) }), "expected credit for a turn")
	end)

	t.test("players who left are forgotten", function()
		local pacer = settled({ player(), player({ userId = 2 }) })
		pacer:shouldSend(5, SPACING, { player() })
		t.eq((pacer :: any)._sent[2], nil)
	end)

	t.test("spacing leaves a reserve", function()
		t.eq(GhostPacer.spacingFor(1), 1.1)
	end)
end
