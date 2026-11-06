--!strict
-- Reads KEY=value lines from .env at the repo root (gitignored). Real environment variables win.
local fs = require("@lune/fs")
local process = require("@lune/process")

local values: { [string]: string } = {}
if fs.isFile(".env") then
	for line in string.gmatch(fs.readFile(".env"), "[^\r\n]+") do
		local key, value = string.match(line, "^%s*([%w_]+)%s*=%s*(.-)%s*$")
		if key and value ~= "" then
			values[key] = value
		end
	end
end

return function(key: string): string
	local value = process.env[key] or values[key]
	if value == nil or value == "" then
		error(`{key} is not set. Copy .env.example to .env and fill it in.`, 0)
	end
	return value
end
