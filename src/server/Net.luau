--!strict
--[[
	Net (server): the only place that touches remotes.

	Every client call goes: rate limit (per player.UserId) -> Validate.args -> handler.
	Calls that fail either step are dropped and logged. Handlers get args as a packed table.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)
local Validate = require(ReplicatedStorage.Shared.Validate)

export type Rate = { capacity: number, perSecond: number }

export type EventOptions = {
	checks: { Validate.Check },
	rate: Rate?,
	handler: (player: Player, args: { unknown }) -> (),
}

export type FunctionOptions = {
	checks: { Validate.Check },
	rate: Rate?,
	handler: (player: Player, args: { unknown }) -> unknown,
}

export type ClientEvent = {
	fire: (player: Player, ...unknown) -> (),
	fireAll: (...unknown) -> (),
}

local DEFAULT_RATE: Rate = { capacity = 10, perSecond = 5 }

local Net = {}

local limiters: { RateLimiter.RateLimiter } = {}
local claimed: { [string]: boolean } = {}
-- Caps log lines per player so a spamming client cannot flood the server output.
local logLimiter = RateLimiter.new(5, 1, time)
table.insert(limiters, logLimiter)

local function claim(name: string)
	local known = false
	for _, value in RemoteNames do
		if value == name then
			known = true
		end
	end
	assert(known, `unknown remote "{name}", add it to RemoteNames`)
	assert(not claimed[name], `remote "{name}" is already registered`)
	claimed[name] = true
end

local function getFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		if existing:IsA("Folder") then
			return existing
		end
		error("ReplicatedStorage.Remotes must be a Folder")
	end
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
	return folder
end

-- Parent last, after handlers are connected.
local function publish(remote: Instance, name: string)
	remote.Name = name
	remote.Parent = getFolder()
end

local function newLimiter(rate: Rate?): RateLimiter.RateLimiter
	local r = rate or DEFAULT_RATE
	local limiter = RateLimiter.new(r.capacity, r.perSecond, time)
	table.insert(limiters, limiter)
	return limiter
end

local function drop(player: Player, name: string, reason: string)
	if logLimiter:allow(player.UserId) then
		warn(`[Net] dropped {name} from {player.UserId}: {reason}`)
	end
end

-- True if the call may reach the handler.
local function admit(
	limiter: RateLimiter.RateLimiter,
	checks: { Validate.Check },
	player: Player,
	name: string,
	...: unknown
): boolean
	if not limiter:allow(player.UserId) then
		drop(player, name, "rate limited")
		return false
	end
	if not Validate.args(checks, ...) then
		drop(player, name, "invalid arguments")
		return false
	end
	return true
end

function Net.onEvent(name: string, options: EventOptions)
	claim(name)
	local limiter = newLimiter(options.rate)
	local remote = Instance.new("RemoteEvent")
	remote.OnServerEvent:Connect(function(player: Player, ...: unknown)
		if admit(limiter, options.checks, player, name, ...) then
			options.handler(player, { ... })
		end
	end)
	publish(remote, name)
end

-- For replaceable data. Calls may be dropped or reordered, and over 1000 bytes is dropped.
function Net.onUnreliableEvent(name: string, options: EventOptions)
	claim(name)
	local limiter = newLimiter(options.rate)
	local remote = Instance.new("UnreliableRemoteEvent")
	remote.OnServerEvent:Connect(function(player: Player, ...: unknown)
		if admit(limiter, options.checks, player, name, ...) then
			options.handler(player, { ... })
		end
	end)
	publish(remote, name)
end

function Net.onFunction(name: string, options: FunctionOptions)
	claim(name)
	local limiter = newLimiter(options.rate)
	local remote = Instance.new("RemoteFunction")
	remote.OnServerInvoke = function(player: Player, ...: unknown): unknown
		if not admit(limiter, options.checks, player, name, ...) then
			return nil
		end
		-- pcall so a handler error never sends server error text back to the client.
		local ok, result = pcall(options.handler, player, { ... })
		if not ok then
			warn(`[Net] {name} handler error: {result}`)
			return nil
		end
		return result
	end
	publish(remote, name)
end

-- Server-to-client event. No validation needed in this direction.
function Net.clientEvent(name: string): ClientEvent
	claim(name)
	local remote = Instance.new("RemoteEvent")
	publish(remote, name)
	return {
		fire = function(player: Player, ...: unknown)
			remote:FireClient(player, ...)
		end,
		fireAll = function(...: unknown)
			remote:FireAllClients(...)
		end,
	}
end

-- Server-to-client event for replaceable data. May be dropped or reordered; over 1000 bytes is dropped.
function Net.unreliableClientEvent(name: string): ClientEvent
	claim(name)
	local remote = Instance.new("UnreliableRemoteEvent")
	publish(remote, name)
	return {
		fire = function(player: Player, ...: unknown)
			remote:FireClient(player, ...)
		end,
		fireAll = function(...: unknown)
			remote:FireAllClients(...)
		end,
	}
end

Players.PlayerRemoving:Connect(function(player: Player)
	for _, limiter in limiters do
		limiter:remove(player.UserId)
	end
end)

return Net
