--!strict
--[[
	Uploads a file to Roblox with the Open Cloud Assets API and prints its asset id.

	lune run tools/upload <file> "<display name>"

	Type comes from the extension: audio -> Audio, models -> Model, images -> Decal.
	For UI images prefer the Studio MCP `upload_image` tool, which returns an Image id.
	Needs ROBLOX_API_KEY (assets: read + write) and ROBLOX_USER_ID in .env.
]]
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")
local env = require("./env")

local TYPES: { [string]: { assetType: string, mime: string } } = {
	mp3 = { assetType = "Audio", mime = "audio/mpeg" },
	ogg = { assetType = "Audio", mime = "audio/ogg" },
	wav = { assetType = "Audio", mime = "audio/wav" },
	flac = { assetType = "Audio", mime = "audio/flac" },
	fbx = { assetType = "Model", mime = "model/fbx" },
	glb = { assetType = "Model", mime = "model/gltf-binary" },
	gltf = { assetType = "Model", mime = "model/gltf+json" },
	rbxm = { assetType = "Model", mime = "model/x-rbxm" },
	png = { assetType = "Decal", mime = "image/png" },
	jpg = { assetType = "Decal", mime = "image/jpeg" },
	jpeg = { assetType = "Decal", mime = "image/jpeg" },
}

local path, name = process.args[1], process.args[2]
if not path or not name then
	print('usage: lune run tools/upload <file> "<display name>"')
	process.exit(1)
end

local kind = TYPES[string.lower(string.match(path, "%.(%w+)$") or "")]
assert(kind, `unsupported file type: {path}`)

local apiKey = env("ROBLOX_API_KEY")
local request = serde.encode("json", {
	assetType = kind.assetType,
	displayName = name,
	description = name,
	creationContext = { creator = { userId = env("ROBLOX_USER_ID") } },
})

local boundary = "----roblox-upload-" .. tostring(os.time())
local body = table.concat({
	`--{boundary}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n`,
	request,
	`\r\n--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{string.match(path, "[^/\\]+$")}"\r\n`,
	`Content-Type: {kind.mime}\r\n\r\n`,
	fs.readFile(path),
	`\r\n--{boundary}--\r\n`,
})

local res = net.request({
	url = "https://apis.roblox.com/assets/v1/assets",
	method = "POST",
	headers = { ["x-api-key"] = apiKey, ["Content-Type"] = `multipart/form-data; boundary={boundary}` },
	body = body,
})
assert(res.ok, `upload failed {res.statusCode}: {res.body}`)
local operation = serde.decode("json", res.body).path

for _ = 1, 30 do
	task.wait(2)
	local poll = net.request({
		url = `https://apis.roblox.com/assets/v1/{operation}`,
		headers = { ["x-api-key"] = apiKey },
	})
	assert(poll.ok, `poll failed {poll.statusCode}: {poll.body}`)
	local data = serde.decode("json", poll.body)
	if data.done then
		assert(not data.error, `upload error: {serde.encode("json", data.error)}`)
		local asset = data.response
		print(`{asset.assetType} rbxassetid://{asset.assetId} ({asset.moderationResult.moderationState})`)
		process.exit(0)
	end
end
error("upload still processing after 60s; check Creator Dashboard", 0)
