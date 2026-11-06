--!strict
-- Test entry point. Run from the repo root:  lune run tests/run
-- Add every new spec file to the list below.

local Harness = require("./Harness")

local failed = Harness.run({
	{ name = "Validate", spec = require("./Validate.spec") },
	{ name = "RateLimiter", spec = require("./RateLimiter.spec") },
	{ name = "GhostCodec", spec = require("./GhostCodec.spec") },
	{ name = "GhostInterpolator", spec = require("./GhostInterpolator.spec") },
	{ name = "GhostPacer", spec = require("./GhostPacer.spec") },
	{ name = "GhostPose", spec = require("./GhostPose.spec") },
	{ name = "GhostReport", spec = require("./GhostReport.spec") },
	{ name = "RewindBuffer", spec = require("./RewindBuffer.spec") },
	{ name = "GhostBudget", spec = require("./GhostBudget.spec") },
	{ name = "GhostArea", spec = require("./GhostArea.spec") },
	{ name = "GhostBots", spec = require("./GhostBots.spec") },
	{ name = "LatencyStats", spec = require("./LatencyStats.spec") },
})

if failed > 0 then
	error(`{failed} test(s) failed`, 0)
end
