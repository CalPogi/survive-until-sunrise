--!strict
-- Template smoke test for the Net layer. Delete or replace with the first real feature.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Parent.Parent.Net)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local PingController = { Name = "PingController" }

function PingController.Start()
	Net.onEvent(RemoteNames.Pong, function(message)
		print("[Ping] pong:", message)
	end)
	Net.fire(RemoteNames.Ping, "hello")
	print("[Ping] echo 21 ->", Net.invoke(RemoteNames.Echo, 21))
	Net.fire(RemoteNames.Ping, 12345) -- invalid on purpose: the server should log a drop
end

return PingController
