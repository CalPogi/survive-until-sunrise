--!strict
--[[
	GhostArea: turns the server registry into what GhostBudget and GhostService need.
	Spec: docs/specs/ghost-live.md

	Pure logic. Registry values come from a shared store, so malformed entries are skipped.
]]

export type Summary = {
	totalServers: number,
	peers: { string }, -- other servers in my area, sorted
	pairCount: number, -- sum of s x (s - 1) over all areas
}

local GhostArea = {}

function GhostArea.summarize(entries: { unknown }, myArea: string, myServerId: string): Summary
	local areaOf: { [string]: string } = { [myServerId] = myArea }
	for _, entry in entries do
		if type(entry) == "table" then
			local serverId = (entry :: any).serverId
			local area = (entry :: any).area
			if type(serverId) == "string" and serverId ~= "" and type(area) == "string" then
				areaOf[serverId] = if serverId == myServerId then myArea else area
			end
		end
	end

	local totalServers = 0
	local sizes: { [string]: number } = {}
	local peers: { string } = {}
	for serverId, area in areaOf do
		totalServers += 1
		sizes[area] = (sizes[area] or 0) + 1
		if area == myArea and serverId ~= myServerId then
			table.insert(peers, serverId)
		end
	end
	table.sort(peers)

	local pairCount = 0
	for _, size in sizes do
		pairCount += size * (size - 1)
	end
	return { totalServers = totalServers, peers = peers, pairCount = pairCount }
end

return GhostArea
