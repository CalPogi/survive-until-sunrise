--!strict
-- Bootstrap: requires every module under Services, runs each Init in order, then each Start in its own thread.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local modules: { Types.Lifecycle } = {}
for _, child in script.Services:GetChildren() do
	if child:IsA("ModuleScript") then
		table.insert(modules, (require :: any)(child) :: Types.Lifecycle)
	end
end

for _, module in modules do
	local init = module.Init
	if init then
		init()
	end
end

for _, module in modules do
	local start = module.Start
	if start then
		task.spawn(start)
	end
end
