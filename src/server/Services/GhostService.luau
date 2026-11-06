--!strict
--[[
	GhostService: shares this server's players with other servers in the same area, and forwards
	theirs to clients. Spec: docs/specs/ghost-live.md

	Test attributes, set on ServerScriptService from the developer console (server only):
		GhostBots = N                  adds N fake walkers
		GhostIntervalOverride = secs   replaces the computed send interval, here and on area peers

	Only the owner can read a server's console, so each server also shares its report through the
	registry, and the owner's server prints its peers' reports too.

	In Studio there is no registry or MessagingService. Bot snapshots loop back with a fake delay.
]]

-- ponytail: every server reads the whole registry, which costs about servers squared in MemoryStore
-- units. Fine for the test. Read per area or use a coordinator before going past a few hundred servers.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local GhostArea = require(ReplicatedStorage.Shared.GhostArea)
local GhostBots = require(ReplicatedStorage.Shared.GhostBots)
local GhostBudget = require(ReplicatedStorage.Shared.GhostBudget)
local GhostCodec = require(ReplicatedStorage.Shared.GhostCodec)
local GhostPacer = require(ReplicatedStorage.Shared.GhostPacer)
local GhostReport = require(ReplicatedStorage.Shared.GhostReport)
local LatencyStats = require(ReplicatedStorage.Shared.LatencyStats)
local Net = require(script.Parent.Parent.Net)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)
local Validate = require(ReplicatedStorage.Shared.Validate)

local AREA = "test"
local REGISTRY_NAME = "GhostServers"
local REGISTRY_REFRESH = 15
local REGISTRY_EXPIRY = 45
local REGISTRY_PAGE = 200
local REGISTRY_MAX_PAGES = 20
local PROBE_INTERVAL = 5
local REPORT_INTERVAL = 30
local MAX_BOTS = 200
local STUDIO_BOTS = 5
local STUDIO_DELAY = 0.2
local STUDIO_JITTER = 0.05
local MAX_ROUND_TRIP = 60
local MAX_PEER_REPORT = 500
local SEND_CHECK = 0.05 -- seconds between checks for something worth sending
-- Seconds after the jump signal, covering a 0.54 s jump plus some jitter.
local JUMP_HOLD = 0.7
local JUMP_HOLD_RANGE = 9 -- studs; a default jump is 7.2, and a teleport, fall or lying client goes beyond this
local JUMP_RATE: Net.Rate = { capacity = 2, perSecond = 2 } -- a default jump can repeat about 1.8 times a second
local POSITION_RATE: Net.Rate = { capacity = 30, perSecond = 25 } -- clients report 20 times a second
local MAX_POSITION = 100000 -- studs; well past the map, and reports must also be near the server's position
local MAX_REPORTED_SPEED = 200 -- studs/s

type JumpHold = { y: number, untilTime: number }
type PositionReport = { x: number, y: number, z: number, yaw: number, vx: number, vz: number, at: number }

local isStudio = RunService:IsStudio()
local rawId = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)
local serverId = string.gsub(rawId, "-", "")
local botIdBase = 4000000000000 + math.random(0, 1000000000) * 100

local snapshotEvent: Net.ClientEvent
local summary: GhostArea.Summary = { totalServers = 1, peers = {}, pairCount = 0 }
local peerConnections: { [string]: RBXScriptConnection } = {}
local probeConnection: RBXScriptConnection? = nil
local peerOverride: number? = nil
local peerReports: { [string]: string } = {}
local rotation = 1
local pacer = GhostPacer.new()
local waitingActions: { [number]: number } = {}
local jumpHolds: { [number]: JumpHold } = {}
local positionReports: { [number]: PositionReport } = {}
local transit = LatencyStats.new(200)
local clockDifference: number? = nil
local GhostService = { Name = "GhostService" }
local counters = {
	sent = 0,
	received = 0,
	decodeFailures = 0,
	publishFailures = 0,
	registryReadFailures = 0,
	registryWriteFailures = 0,
	subscribeFailures = 0,
	loopErrors = 0,
	longestMessage = 0,
}

local function ghostTopic(id: string): string
	return `g_{id}`
end

local function probeTopic(id: string): string
	return `gp_{id}`
end

local function numberAttribute(name: string): number?
	local value = ServerScriptService:GetAttribute(name)
	if type(value) == "number" and value == value then
		return value
	end
	return nil
end

local function currentInterval(): number
	local budget = GhostPacer.spacingFor(GhostBudget.interval(summary.totalServers, summary.pairCount))
	local override = numberAttribute("GhostIntervalOverride") or peerOverride
	return if override then math.max(override, budget) else budget
end

-- The range is checked against both heights, because a report can already be away from the server's.
local function activeHold(userId: number, y: number, serverY: number): JumpHold?
	local hold = jumpHolds[userId]
	if
		hold
		and os.clock() < hold.untilTime
		and math.abs(y - hold.y) <= JUMP_HOLD_RANGE
		and math.abs(serverY - hold.y) <= JUMP_HOLD_RANGE
	then
		return hold
	end
	return nil
end

local function heightToSend(userId: number, y: number, serverY: number): number
	local hold = activeHold(userId, y, serverY)
	return if hold then hold.y else y
end

local function onPositionReport(player: Player, args: { unknown })
	positionReports[player.UserId] = {
		x = args[1] :: number,
		y = args[2] :: number,
		z = args[3] :: number,
		yaw = args[4] :: number,
		vx = args[5] :: number,
		vz = args[6] :: number,
		at = os.clock(),
	}
end

-- The client's report if it can be used, because physics reaches the server late. Otherwise the server's.
local function latestPosition(userId: number, root: BasePart): PositionReport
	local position = root.Position
	local report = positionReports[userId]
	if
		report
		and GhostReport.isUsable(
			os.clock() - report.at,
			report.x - position.X,
			report.y - position.Y,
			report.z - position.Z
		)
	then
		return report
	end
	local look = root.CFrame.LookVector
	local velocity = root.AssemblyLinearVelocity
	return {
		x = position.X,
		y = position.Y,
		z = position.Z,
		yaw = math.deg(math.atan2(-look.X, -look.Z)),
		vx = velocity.X,
		vz = velocity.Z,
		at = os.clock(),
	}
end

-- Ghosts play jumps as an action, so height samples leave the jump out: a jump is shorter than the send
-- spacing, and sampling it costs credit and gives a wrong arc. The signal arrives before the jump shows,
-- so the height now is still the ground. During a hold it may not be, so the first one stays. The range
-- keeps a client that keeps signalling from holding its ghost further off than a normal jump.
local function onJumpSignal(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		GhostService.queueAction(player.UserId, GhostCodec.Action.Jump)
		local y = latestPosition(player.UserId, root).y
		local untilTime = os.clock() + JUMP_HOLD
		local hold = activeHold(player.UserId, y, root.Position.Y)
		if hold then
			hold.untilTime = untilTime
		else
			jumpHolds[player.UserId] = { y = y, untilTime = untilTime }
		end
	end
end

local function gatherEntries(): { GhostCodec.Entry }
	local entries: { GhostCodec.Entry } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			local latest = latestPosition(player.UserId, root)
			table.insert(entries, {
				userId = player.UserId,
				x = latest.x,
				y = heightToSend(player.UserId, latest.y, root.Position.Y),
				z = latest.z,
				yaw = latest.yaw,
				vx = latest.vx,
				vz = latest.vz,
				anim = 0,
				held = 0,
			})
		else
			-- Otherwise the action would wait out their death and play when they respawn.
			waitingActions[player.UserId] = nil
		end
	end

	local botCount = math.clamp(math.floor(numberAttribute("GhostBots") or 0), 0, MAX_BOTS)
	for _, bot in GhostBots.entries(botCount, workspace:GetServerTimeNow(), botIdBase) do
		table.insert(entries, bot)
	end
	for _, entry in entries do
		entry.anim = waitingActions[entry.userId] or 0
	end
	return entries
end

-- Cleared before publishing, because publishing yields and a newer action may be queued meanwhile.
local function clearSentActions(entries: { GhostCodec.Entry }, first: number, count: number)
	for i = first, first + count - 1 do
		waitingActions[entries[i].userId] = nil
	end
end

local function restoreSentActions(entries: { GhostCodec.Entry }, first: number, count: number)
	for i = first, first + count - 1 do
		local entry = entries[i]
		if entry.anim ~= 0 and waitingActions[entry.userId] == nil then
			waitingActions[entry.userId] = entry.anim
		end
	end
end

local function receiveSnapshot(text: unknown)
	local decoded = GhostCodec.decode(text)
	if decoded == nil then
		counters.decodeFailures += 1
		return
	end
	counters.received += 1
	snapshotEvent.fireAll(text, currentInterval())
end

local function sendSnapshot()
	if not isStudio and #summary.peers == 0 then
		-- Nobody to show them to, and they'd be stale by the time a peer appears.
		table.clear(waitingActions)
		return
	end
	local entries = gatherEntries()
	if #entries == 0 or not pacer:shouldSend(os.clock(), currentInterval(), entries) then
		return
	end
	if rotation > #entries or #entries <= GhostCodec.MAX_ENTRIES then
		rotation = 1
	end
	local first = rotation
	local text, consumed = GhostCodec.encode(workspace:GetServerTimeNow(), entries, first)
	rotation += consumed
	counters.longestMessage = math.max(counters.longestMessage, #text)
	clearSentActions(entries, first, consumed)

	if isStudio then
		counters.sent += 1
		task.delay(STUDIO_DELAY + math.random() * STUDIO_JITTER, receiveSnapshot, text)
		return
	end
	local ok = pcall(function()
		MessagingService:PublishAsync(ghostTopic(serverId), text)
	end)
	if ok then
		counters.sent += 1
	else
		counters.publishFailures += 1
		restoreSentActions(entries, first, consumed)
	end
end

local function syncPeers()
	local wanted: { [string]: boolean } = {}
	for _, peer in summary.peers do
		wanted[peer] = true
		if not peerConnections[peer] then
			local ok, connection = pcall(function()
				return MessagingService:SubscribeAsync(ghostTopic(peer), function(message)
					receiveSnapshot(message.Data)
				end)
			end)
			if ok then
				peerConnections[peer] = connection
			else
				counters.subscribeFailures += 1
			end
		end
	end
	for peer, connection in peerConnections do
		if not wanted[peer] then
			connection:Disconnect()
			peerConnections[peer] = nil
		end
	end
end

local function isPeer(id: string): boolean
	return table.find(summary.peers, id) ~= nil
end

-- Pings carry this server's os.clock, so transit needs no clock agreement between servers.
local function handleProbe(data: unknown)
	if type(data) ~= "string" then
		return
	end
	local parts = string.split(data, "|")
	local kind, from = parts[1], parts[2]
	local sentClock = tonumber(parts[3])
	if sentClock == nil or from == nil or not isPeer(from) then
		return
	end

	if kind == "p" then
		local reply = `e|{serverId}|{parts[3]}|{workspace:GetServerTimeNow()}`
		pcall(function()
			MessagingService:PublishAsync(probeTopic(from), reply)
		end)
	elseif kind == "e" then
		local roundTrip = os.clock() - sentClock
		if roundTrip < 0 or roundTrip > MAX_ROUND_TRIP then
			return
		end
		transit:add(roundTrip / 2)
		local theirTime = tonumber(parts[4])
		if theirTime then
			clockDifference = theirTime - (workspace:GetServerTimeNow() - roundTrip / 2)
		end
	end
end

local function formatSeconds(value: number?): string
	return if value then string.format("%.3fs", value) else "n/a"
end

local function statsLine(): string
	return `interval={formatSeconds(currentInterval())} servers={summary.totalServers}`
		.. ` peers={#summary.peers} pairs={summary.pairCount} bots={numberAttribute("GhostBots") or 0}`
		.. ` transitP50={formatSeconds(transit:percentile(50))} transitP95={formatSeconds(transit:percentile(95))}`
		.. ` probes={transit:count()} sent={counters.sent} received={counters.received}`
		.. ` longest={counters.longestMessage} decodeFail={counters.decodeFailures}`
		.. ` publishFail={counters.publishFailures} subscribeFail={counters.subscribeFailures}`
		.. ` registryReadFail={counters.registryReadFailures} registryWriteFail={counters.registryWriteFailures}`
		.. ` loopErrors={counters.loopErrors} clockDiff={formatSeconds(clockDifference)}`
end

local function writeRegistry(registry: MemoryStoreSortedMap)
	local value = {
		area = AREA,
		override = numberAttribute("GhostIntervalOverride"),
		stats = statsLine(),
	}
	local ok = pcall(function()
		registry:SetAsync(serverId, value, REGISTRY_EXPIRY)
	end)
	if not ok then
		counters.registryWriteFailures += 1
	end
end

local function subscribeToProbes()
	if probeConnection then
		return
	end
	local ok, connection = pcall(function()
		return MessagingService:SubscribeAsync(probeTopic(serverId), function(message)
			handleProbe(message.Data)
		end)
	end)
	if ok then
		probeConnection = connection
	else
		counters.subscribeFailures += 1
	end
end

local function readRegistry(registry: MemoryStoreSortedMap)
	local entries: { unknown } = {}
	local override: number? = nil
	local reports: { [string]: string } = {}
	local ok = pcall(function()
		local lower: { key: string, sortKey: any }? = nil
		for _ = 1, REGISTRY_MAX_PAGES do
			local page = registry:GetRangeAsync(Enum.SortDirection.Ascending, REGISTRY_PAGE, lower)
			for _, item in page do
				local value: any = item.value
				local isTable = type(value) == "table"
				table.insert(entries, { serverId = item.key, area = if isTable then value.area else nil })
				if isTable and item.key ~= serverId and value.area == AREA then
					if type(value.override) == "number" and value.override == value.override then
						override = value.override
					end
					if type(value.stats) == "string" and #value.stats <= MAX_PEER_REPORT then
						reports[item.key] = value.stats
					end
				end
			end
			if #page < REGISTRY_PAGE then
				break
			end
			local last = page[#page]
			lower = { key = last.key, sortKey = last.sortKey }
		end
	end)
	if not ok then
		counters.registryReadFailures += 1
		return
	end

	peerOverride = override
	peerReports = reports
	summary = GhostArea.summarize(entries, AREA, serverId)
	syncPeers()
	subscribeToProbes()
end

local function sendProbes()
	for _, peer in summary.peers do
		local ping = `p|{serverId}|{os.clock()}`
		pcall(function()
			MessagingService:PublishAsync(probeTopic(peer), ping)
		end)
	end
end

local function report()
	print(`[Ghost] {statsLine()}`)
	for peer, stats in peerReports do
		print(`[Ghost peer {string.sub(peer, 1, 8)}] {stats}`)
	end
end

-- Runs action, then waits out the rest of the period. An error is counted and the loop keeps going.
local function forever(period: () -> number, action: () -> ())
	task.spawn(function()
		while true do
			local started = os.clock()
			local ok, err = (pcall :: any)(action)
			if not ok then
				counters.loopErrors += 1
				warn(`[Ghost] {err}`)
			end
			task.wait(math.max(0, period() - (os.clock() - started)))
		end
	end)
end

local function every(seconds: number): () -> number
	return function()
		return seconds
	end
end

function GhostService.Init()
	snapshotEvent = Net.unreliableClientEvent(RemoteNames.GhostSnapshot)
	-- Physics takes a while to show a jump to the server, so the client says so directly. It's cosmetic
	-- and takes no arguments. A lying client can only make its own ghost hop, or sit within the hold range.
	Net.onEvent(RemoteNames.GhostJump, {
		checks = {},
		rate = JUMP_RATE,
		handler = onJumpSignal,
	})
	local position = Validate.numberBetween(-MAX_POSITION, MAX_POSITION)
	local speed = Validate.numberBetween(-MAX_REPORTED_SPEED, MAX_REPORTED_SPEED)
	Net.onUnreliableEvent(RemoteNames.GhostPosition, {
		checks = { position, position, position, Validate.numberBetween(-360, 360), speed, speed },
		rate = POSITION_RATE,
		handler = onPositionReport,
	})
end

-- Shows a cosmetic action on this player's ghost on other servers. Delivery isn't guaranteed.
function GhostService.queueAction(userId: number, action: number)
	waitingActions[userId] = action
end

function GhostService.Start()
	if isStudio then
		if numberAttribute("GhostBots") == nil then
			ServerScriptService:SetAttribute("GhostBots", STUDIO_BOTS)
		end
	else
		local registry = MemoryStoreService:GetSortedMap(REGISTRY_NAME)
		game:BindToClose(function()
			pcall(function()
				registry:RemoveAsync(serverId)
			end)
		end)
		forever(every(REGISTRY_REFRESH), function()
			writeRegistry(registry)
		end)
		forever(every(REGISTRY_REFRESH), function()
			readRegistry(registry)
		end)
		forever(every(PROBE_INTERVAL), sendProbes)
	end

	Players.PlayerRemoving:Connect(function(player)
		waitingActions[player.UserId] = nil
		jumpHolds[player.UserId] = nil
		positionReports[player.UserId] = nil
	end)

	forever(every(REPORT_INTERVAL), report)
	forever(every(SEND_CHECK), sendSnapshot)
end

return GhostService
