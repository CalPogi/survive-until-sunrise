--!strict
local GhostInterpolator = require("../src/shared/GhostInterpolator")
local Harness = require("./Harness")

-- A 1 s send interval gives a render delay of 1.1 s and a removal timeout of 5 s.
local DELAY = 1.1

local function at(x: number, overrides: { yaw: number?, vx: number?, anim: number? }?): GhostInterpolator.Sample
	local o = overrides or {}
	return {
		x = x,
		y = 0,
		z = 0,
		yaw = o.yaw or 0,
		vx = o.vx or 0,
		vz = 0,
		anim = o.anim or 0,
		held = 0,
	}
end

return function(t: Harness.T)
	local function near(actual: number, expected: number, tolerance: number?, message: string?)
		local allowed = tolerance or 0.001
		t.ok(math.abs(actual - expected) <= allowed, `{message or ""} expected {expected}, got {actual}`)
	end

	t.test("the midpoint between two samples gives the midpoint position", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10.2, at(0))
		ghost:push(11, 11.2, at(10))
		local state = ghost:sample(10.5 + 0.2 + DELAY)
		t.eq(state.status, "interpolating")
		near(state.x, 5)
		near(state.renderTime, 10.5)
	end)

	t.test("yaw takes the shortest path across zero", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10, at(0, { yaw = 350 }))
		ghost:push(11, 11, at(0, { yaw = 10 }))
		local yaw = ghost:sample(10.5 + DELAY).yaw
		t.ok(yaw < 1 or yaw > 359, `expected about 0, got {yaw}`)
	end)

	t.test("yaw takes the shortest path the other way too", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10, at(0, { yaw = 10 }))
		ghost:push(11, 11, at(0, { yaw = 350 }))
		local yaw = ghost:sample(10.5 + DELAY).yaw
		t.ok(yaw < 1 or yaw > 359, `expected about 0, got {yaw}`)
	end)

	t.test("a sender clock 500 s off gives the same motion", function()
		local matching = GhostInterpolator.new(1)
		local skewed = GhostInterpolator.new(1)
		for i = 0, 3 do
			matching:push(10 + i, 10.2 + i, at(i * 10))
			skewed:push(510 + i, 10.2 + i, at(i * 10))
		end
		local now = 11.4 + 0.2 + DELAY
		near(skewed:sample(now).x, matching:sample(now).x)
		near(skewed:sample(now).renderTime, matching:sample(now).renderTime + 500)
	end)

	t.test("a one-off latency spike does not move the offset", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10.2, at(0))
		ghost:push(11, 13.7, at(10))
		near(ghost:sample(14).renderTime, 14 - 0.2 - DELAY, 0.05)
	end)

	t.test("the offset drifts up slowly when latency really rises", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(0, 0.2, at(0))
		for i = 1, 120 do
			ghost:push(i, i + 1.2, at(0))
		end
		local offset = 121 - DELAY - ghost:sample(121).renderTime
		t.ok(offset > 0.5, `expected the offset to adapt, got {offset}`)
		t.ok(offset <= 1.2001, `must not pass the real latency, got {offset}`)
	end)

	t.test("a late out-of-order sample is ignored", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10, at(0))
		ghost:push(12, 12, at(20))
		ghost:push(11, 12.1, at(999))
		near(ghost:sample(11 + DELAY).x, 10)
	end)

	t.test("extrapolates from velocity up to 0.25 s, then holds", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10, at(0, { vx = 10 }))
		local moving = ghost:sample(10.1 + DELAY)
		t.eq(moving.status, "extrapolating")
		near(moving.x, 1)
		near(ghost:sample(10.25 + DELAY).x, 2.5)
		local held = ghost:sample(11 + DELAY)
		t.eq(held.status, "holding")
		near(held.x, 2.5)
	end)

	t.test("before the first sample's time it holds at that sample", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10, at(7))
		local state = ghost:sample(10)
		t.eq(state.status, "holding")
		near(state.x, 7)
	end)

	t.test("a jump above 200 studs/s snaps with no blending", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10, at(0))
		ghost:push(11, 11, at(500))
		near(ghost:sample(10.9 + DELAY).x, 0)
		near(ghost:sample(11 + DELAY).x, 500)
	end)

	t.test("a fast but legal move still blends", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10, at(0))
		ghost:push(11, 11, at(150))
		near(ghost:sample(10.5 + DELAY).x, 75)
	end)

	t.test("discrete fields come from the older sample until the newer one is reached", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10, at(0, { anim = 1 }))
		ghost:push(11, 11, at(0, { anim = 2 }))
		t.eq(ghost:sample(10.9 + DELAY).anim, 1)
		t.eq(ghost:sample(11 + DELAY).anim, 2)
	end)

	t.test("status is gone before any sample and after the timeout", function()
		local ghost = GhostInterpolator.new(1)
		t.eq(ghost:sample(0).status, "gone")
		ghost:push(10, 10, at(0))
		t.eq(ghost:sample(14.9).status, "holding")
		t.eq(ghost:sample(15.1).status, "gone")
	end)

	t.test("the timeout grows with the send interval", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10, at(0))
		ghost:setSendInterval(2.5)
		t.ok(ghost:sample(17).status ~= "gone", "3 x 2.5 s is 7.5 s")
		t.eq(ghost:sample(17.6).status, "gone")
	end)

	t.test("memory stays bounded", function()
		local ghost = GhostInterpolator.new(1)
		for i = 1, 1000 do
			ghost:push(i, i, at(i))
		end
		t.ok(#(ghost :: any)._samples <= 16, "too many samples kept")
		near(ghost:sample(999.5 + DELAY).x, 999.5)
	end)

	t.test("a sample from the future cannot poison the ghost", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10, at(0))
		ghost:push(11, 11, at(10))
		ghost:push(70, 11.5, at(99999))
		ghost:push(12, 12, at(20))
		local state = ghost:sample(11.5 + DELAY)
		t.eq(state.status, "interpolating")
		near(state.x, 15)
	end)

	t.test("a duplicate timestamp is ignored", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10, at(0))
		ghost:push(10, 10.1, at(999))
		near(ghost:sample(10 + DELAY).x, 0)
	end)

	t.test("ignored samples do not keep a ghost alive", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10, at(0))
		ghost:push(9, 14, at(0))
		t.eq(ghost:sample(15.5).status, "gone")
	end)

	t.test("gone still reports render time on the sender's clock", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(510, 10, at(0))
		local state = ghost:sample(30)
		t.eq(state.status, "gone")
		near(state.renderTime, 530 - DELAY)
	end)

	t.test("all three axes interpolate", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10, { x = 0, y = 0, z = 0, yaw = 0, vx = 0, vz = 0, anim = 0, held = 0 })
		ghost:push(11, 11, { x = 10, y = 20, z = 30, yaw = 0, vx = 0, vz = 0, anim = 0, held = 0 })
		local state = ghost:sample(10.5 + DELAY)
		near(state.x, 5)
		near(state.y, 10)
		near(state.z, 15)
	end)

	t.test("extrapolation uses both velocities", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10, { x = 0, y = 0, z = 0, yaw = 0, vx = 10, vz = -20, anim = 0, held = 0 })
		local state = ghost:sample(10.1 + DELAY)
		near(state.x, 1)
		near(state.z, -2)
	end)

	t.test("a vertical teleport snaps", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10, { x = 0, y = 0, z = 0, yaw = 0, vx = 0, vz = 0, anim = 0, held = 0 })
		ghost:push(11, 11, { x = 0, y = 500, z = 0, yaw = 0, vx = 0, vz = 0, anim = 0, held = 0 })
		near(ghost:sample(10.5 + DELAY).y, 0)
	end)

	t.test("the snap threshold is 200 studs/s, and render time stays right during a snap", function()
		local under = GhostInterpolator.new(1)
		under:push(10, 10, at(0))
		under:push(11, 11, at(199))
		near(under:sample(10.5 + DELAY).x, 99.5)

		local over = GhostInterpolator.new(1)
		over:push(10, 10, at(0))
		over:push(11, 11, at(201))
		local state = over:sample(10.5 + DELAY)
		near(state.x, 0)
		near(state.renderTime, 10.5)
	end)

	t.test("held comes from the older sample too", function()
		local ghost = GhostInterpolator.new(1)
		ghost:push(10, 10, { x = 0, y = 0, z = 0, yaw = 0, vx = 0, vz = 0, anim = 0, held = 7 })
		ghost:push(11, 11, { x = 0, y = 0, z = 0, yaw = 0, vx = 0, vz = 0, anim = 0, held = 8 })
		t.eq(ghost:sample(10.9 + DELAY).held, 7)
	end)

	t.test("raising the send interval moves render time gradually", function()
		local ghost = GhostInterpolator.new(0.35)
		for i = 0, 40 do
			ghost:push(i * 0.35, i * 0.35, at(i))
		end
		local before = ghost:sample(14)
		ghost:setSendInterval(2.5)
		local after = ghost:sample(14.1)
		t.ok(after.renderTime > before.renderTime, "render time must keep moving forward")
		local settled = ghost:sample(30)
		near(settled.renderTime, 30 - 2.6)
	end)

	t.test("enough history is kept for the longest delay at the fastest rate", function()
		local ghost = GhostInterpolator.new(2.5)
		for i = 0, 60 do
			ghost:push(i * 0.35, i * 0.35, at(i))
		end
		t.eq(ghost:sample(21).status, "interpolating")
	end)
end
