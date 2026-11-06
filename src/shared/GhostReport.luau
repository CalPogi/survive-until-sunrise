--!strict
--[[
	GhostReport: whether to draw a ghost from where its client says it is. Spec: docs/specs/ghost-polish.md

	Physics takes a while to reach the server, so a client's own report is fresher. The client is
	hostile, so a report is only used while it's recent and close to where the server sees the player.
	That means a ghost can be up to MAX_DISTANCE off: it's for drawing only, and must never decide a hit.

	Pure logic.
]]

local MAX_AGE = 0.25 -- seconds; older means the player stopped reporting, so physics has caught up
local MAX_DISTANCE = 15 -- studs; a default player covers about 5 in the time physics takes

local GhostReport = {}

-- dx, dy and dz are the report's position minus the server's.
function GhostReport.isUsable(age: number, dx: number, dy: number, dz: number): boolean
	return age >= 0 and age <= MAX_AGE and dx * dx + dy * dy + dz * dz <= MAX_DISTANCE * MAX_DISTANCE
end

return GhostReport
