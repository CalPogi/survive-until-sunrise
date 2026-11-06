--!strict
local GhostPose = require("../src/shared/GhostPose")
local Harness = require("./Harness")

return function(t: Harness.T)
	t.test("jumping beats everything", function()
		t.eq(GhostPose.next("run", 16, -40, true), "jump")
	end)

	t.test("falling beats moving", function()
		t.eq(GhostPose.next("run", 16, -30, false), "fall")
		t.eq(GhostPose.next("run", 16, -20, false), "run")
	end)

	t.test("default walking speed runs", function()
		t.eq(GhostPose.next("idle", 16, 0, false), "run")
	end)

	t.test("a slow speed walks", function()
		t.eq(GhostPose.next("idle", 6, 0, false), "walk")
	end)

	t.test("a speed near the moving limits doesn't flicker", function()
		t.eq(GhostPose.next("idle", 1, 0, false), "idle")
		t.eq(GhostPose.next("walk", 1, 0, false), "walk")
		t.eq(GhostPose.next("walk", 0.5, 0, false), "idle")
		t.eq(GhostPose.next("idle", 2, 0, false), "walk")
	end)

	t.test("a speed near the run limits doesn't flicker", function()
		t.eq(GhostPose.next("walk", 10, 0, false), "walk")
		t.eq(GhostPose.next("run", 10, 0, false), "run")
		t.eq(GhostPose.next("run", 8, 0, false), "walk")
		t.eq(GhostPose.next("walk", 12, 0, false), "run")
	end)

	t.test("landing at speed goes straight back to running", function()
		t.eq(GhostPose.next("jump", 16, 0, false), "run")
	end)

	t.test("playback follows ground speed within its limits", function()
		t.eq(GhostPose.playbackSpeed("run", 16), 1)
		t.eq(GhostPose.playbackSpeed("run", 24), 1.5)
		t.eq(GhostPose.playbackSpeed("run", 500), 2)
		t.eq(GhostPose.playbackSpeed("walk", 8), 1)
		t.eq(GhostPose.playbackSpeed("walk", 1), 0.5)
	end)

	t.test("other poses play at normal speed", function()
		t.eq(GhostPose.playbackSpeed("idle", 0), 1)
		t.eq(GhostPose.playbackSpeed("jump", 16), 1)
		t.eq(GhostPose.playbackSpeed("fall", 16), 1)
	end)

	t.test("a jump across the map is a teleport, and a jump's arc isn't", function()
		t.ok(GhostPose.isTeleport(500, 1 / 60), "500 studs in a frame")
		t.ok(not GhostPose.isTeleport(53 / 60, 1 / 60), "the fastest part of a jump")
		t.ok(not GhostPose.isTeleport(16 / 20, 1 / 20), "running at a low frame rate")
	end)

	t.test("smoothing moves toward the target without overshooting", function()
		local value = GhostPose.smooth(0, 10, 1 / 60)
		t.ok(value > 0 and value < 10, `got {value}`)
		local long = GhostPose.smooth(0, 10, 100)
		t.ok(long <= 10 and long > 9.99, `got {long}`)
		t.eq(GhostPose.smooth(5, 10, 0), 5)
	end)
end
