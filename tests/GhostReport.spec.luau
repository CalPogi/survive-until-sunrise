--!strict
local GhostReport = require("../src/shared/GhostReport")
local Harness = require("./Harness")

return function(t: Harness.T)
	t.test("a fresh, close report is usable", function()
		t.ok(GhostReport.isUsable(0.05, 3, 0, 4), "expected usable")
	end)

	t.test("a stale report isn't", function()
		t.ok(GhostReport.isUsable(0.25, 0, 0, 0), "the limit is usable")
		t.ok(not GhostReport.isUsable(0.26, 0, 0, 0), "too old")
	end)

	t.test("a report from the future isn't", function()
		t.ok(not GhostReport.isUsable(-0.01, 0, 0, 0), "negative age")
	end)

	t.test("a far report isn't, on any axis", function()
		t.ok(GhostReport.isUsable(0, 15, 0, 0), "the limit is usable")
		t.ok(not GhostReport.isUsable(0, 15.1, 0, 0), "too far on x")
		t.ok(not GhostReport.isUsable(0, 0, -15.1, 0), "too far on y")
		t.ok(not GhostReport.isUsable(0, 0, 0, 15.1), "too far on z")
		t.ok(not GhostReport.isUsable(0, 10, 10, 10), "too far in total")
	end)
end
