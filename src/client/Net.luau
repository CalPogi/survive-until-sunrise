--!strict
-- Net (client): fire and invoke server remotes, listen to server events. Names come from RemoteNames.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Net = {}

local function event(name: string): RemoteEvent
	local remote = Remotes:WaitForChild(name)
	if remote:IsA("RemoteEvent") then
		return remote
	end
	error(`remote "{name}" is not a RemoteEvent`)
end

function Net.fire(name: string, ...: unknown)
	event(name):FireServer(...)
end

function Net.fireUnreliable(name: string, ...: unknown)
	local remote = Remotes:WaitForChild(name)
	if remote:IsA("UnreliableRemoteEvent") then
		remote:FireServer(...)
		return
	end
	error(`remote "{name}" is not an UnreliableRemoteEvent`)
end

function Net.invoke(name: string, ...: unknown): ...any
	local remote = Remotes:WaitForChild(name)
	if remote:IsA("RemoteFunction") then
		return remote:InvokeServer(...)
	end
	error(`remote "{name}" is not a RemoteFunction`)
end

function Net.onEvent(name: string, callback: (...any) -> ()): RBXScriptConnection
	return event(name).OnClientEvent:Connect(callback)
end

function Net.onUnreliableEvent(name: string, callback: (...any) -> ()): RBXScriptConnection
	local remote = Remotes:WaitForChild(name)
	if remote:IsA("UnreliableRemoteEvent") then
		return remote.OnClientEvent:Connect(callback)
	end
	error(`remote "{name}" is not an UnreliableRemoteEvent`)
end

return Net
