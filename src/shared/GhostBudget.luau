--!strict
--[[
	GhostBudget: how often a server may send ghost snapshots within Roblox's MessagingService limits.
	Spec: docs/specs/ghost-presence.md

	Each server publishes on its own topic, so one message costs one receive per other server in its
	area. Across the game that is pairCount receives per send round, where pairCount is the sum of
	s x (s - 1) over all areas and s is the servers in an area.

	The whole-game receive limit is the one that binds. MIN_INTERVAL is 0.35 s, not lower, because two
	servers would otherwise sit exactly on the per-topic limit (40 + 80 x servers, so 200 a minute).
	With it, the per-topic limit and the send limit (600 + 240 x players) can't be reached first.
	Hit claims must use their own topics, so they don't count against a ghost topic.
]]

-- Published limit: 400 + 200 x servers received per minute, across the whole game.
local RECEIVE_BASE = 400
local RECEIVE_PER_SERVER = 200
local GHOST_SHARE = 0.5 -- the rest stays free for hit claims and world events

local GhostBudget = {}

GhostBudget.MIN_INTERVAL = 0.35
GhostBudget.MAX_INTERVAL = 2.5

-- Seconds between sends, before clamping.
function GhostBudget.rawInterval(totalServers: number, pairCount: number): number
	local receivesPerMinute = GHOST_SHARE * (RECEIVE_BASE + RECEIVE_PER_SERVER * totalServers)
	return 60 * pairCount / receivesPerMinute
end

function GhostBudget.interval(totalServers: number, pairCount: number): number
	return math.clamp(
		GhostBudget.rawInterval(totalServers, pairCount),
		GhostBudget.MIN_INTERVAL,
		GhostBudget.MAX_INTERVAL
	)
end

-- Whether adding one more server to an area with `serversInArea` servers keeps ghosts within the limit.
function GhostBudget.canOpenServer(totalServers: number, pairCount: number, serversInArea: number): boolean
	local newPairCount = pairCount + 2 * serversInArea
	return GhostBudget.rawInterval(totalServers + 1, newPairCount) <= GhostBudget.MAX_INTERVAL
end

return GhostBudget
