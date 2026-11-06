--!strict
-- Template smoke test for the Net layer. Delete or replace with the first real feature.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Parent.Parent.Net)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)
local Validate = require(ReplicatedStorage.Shared.Validate)

local PingService = { Name = "PingService" }

function PingService.Init()
	local pong = Net.clientEvent(RemoteNames.Pong)

	Net.onEvent(RemoteNames.Ping, {
		checks = { Validate.string(32) },
		handler = function(player, args)
			pong.fire(player, args[1])
		end,
	})

	Net.onFunction(RemoteNames.Echo, {
		checks = { Validate.integerBetween(1, 100) },
		handler = function(_player, args)
			return (args[1] :: number) * 2
		end,
	})
end

return PingService
