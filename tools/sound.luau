--!strict
--[[
	Free sound effects from Freesound.org, CC0 only (no attribution needed).

	lune run tools/sound search "coin pickup"     -> id, seconds, name
	lune run tools/sound get 12345 assets/audio/coin.mp3
]]
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local env = require("./env")

local API = "https://freesound.org/apiv2"

local function getJson(url: string): any
	local res = net.request({ url = url, headers = { Authorization = "Token " .. env("FREESOUND_API_KEY") } })
	if not res.ok then
		error(`Freesound {res.statusCode}: {res.body}`, 0)
	end
	return serde.decode("json", res.body)
end

local command, arg1, arg2 = process.args[1], process.args[2], process.args[3]

if command == "search" and arg1 then
	local query = net.urlEncode(arg1)
	local filter = net.urlEncode('license:"Creative Commons 0"')
	local data = getJson(`{API}/search/text/?query={query}&filter={filter}&fields=id,name,duration&page_size=15`)
	for _, sound in data.results do
		print(string.format("%-9d %5.1fs  %s", sound.id, sound.duration, sound.name))
	end
elseif command == "get" and arg1 and arg2 then
	local sound = getJson(`{API}/sounds/{arg1}/?fields=name,license,previews`)
	assert(string.find(sound.license, "publicdomain/zero"), `sound {arg1} is not CC0: {sound.license}`)
	local res = net.request(sound.previews["preview-hq-mp3"])
	assert(res.ok, `download failed: {res.statusCode}`)
	local folder = string.match(arg2, "^(.*)[/\\]")
	if folder then
		fs.writeDir(folder)
	end
	fs.writeFile(arg2, res.body)
	print(`saved {sound.name} -> {arg2}`)
else
	print('usage: lune run tools/sound search "<words>" | get <id> <out.mp3>')
	process.exit(1)
end
