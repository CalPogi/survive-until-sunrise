--!strict
--[[
	Generates a PNG with the local ComfyUI server (start it first: ./tools/comfy.sh).

	lune run tools/image "<prompt>" <out.png> [width] [height]

	SDXL works best at 1024x1024 or similar (e.g. 1152x896). No transparency: cut out
	backgrounds separately when an icon needs alpha.
]]
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local SERVER = "http://127.0.0.1:8188"
local CHECKPOINT = "sd_xl_base_1.0.safetensors"
local NEGATIVE = "blurry, low quality, watermark, text, signature, jpeg artifacts"

local prompt, out = process.args[1], process.args[2]
if not prompt or not out then
	print('usage: lune run tools/image "<prompt>" <out.png> [width] [height]')
	process.exit(1)
end
local width = tonumber(process.args[3]) or 1024
local height = tonumber(process.args[4]) or width

local workflow = {
	["4"] = { class_type = "CheckpointLoaderSimple", inputs = { ckpt_name = CHECKPOINT } },
	["5"] = { class_type = "EmptyLatentImage", inputs = { width = width, height = height, batch_size = 1 } },
	["6"] = { class_type = "CLIPTextEncode", inputs = { text = prompt, clip = { "4", 1 } } },
	["7"] = { class_type = "CLIPTextEncode", inputs = { text = NEGATIVE, clip = { "4", 1 } } },
	["3"] = {
		class_type = "KSampler",
		inputs = {
			seed = math.random(0, 2147483646),
			steps = 25,
			cfg = 7,
			sampler_name = "dpmpp_2m",
			scheduler = "karras",
			denoise = 1,
			model = { "4", 0 },
			positive = { "6", 0 },
			negative = { "7", 0 },
			latent_image = { "5", 0 },
		},
	},
	-- Tiled decode: a full 1024px decode runs out of the RX 6600's memory under DirectML.
	["8"] = {
		class_type = "VAEDecodeTiled",
		inputs = {
			samples = { "3", 0 },
			vae = { "4", 2 },
			tile_size = 512,
			overlap = 64,
			temporal_size = 64,
			temporal_overlap = 8,
		},
	},
	["9"] = { class_type = "SaveImage", inputs = { filename_prefix = "roblox", images = { "8", 0 } } },
}

local ok, res = pcall(net.request, {
	url = SERVER .. "/prompt",
	method = "POST",
	headers = { ["Content-Type"] = "application/json" },
	body = serde.encode("json", { prompt = workflow }),
})
if not ok then
	error("ComfyUI is not running. Start it with ./tools/comfy.sh", 0)
end
assert(res.ok, `ComfyUI rejected the job {res.statusCode}: {res.body}`)
local id = serde.decode("json", res.body).prompt_id

-- ponytail: polls every 2s for up to 15 min; switch to the websocket API if that ever matters.
for _ = 1, 450 do
	task.wait(2)
	local history = serde.decode("json", net.request(`{SERVER}/history/{id}`).body)[id]
	if history then
		if history.status.status_str == "error" then
			error(`ComfyUI failed; see the ComfyUI console. {serde.encode("json", history.status.messages)}`, 0)
		end
		local image = history.outputs["9"].images[1]
		local query =
			`filename={net.urlEncode(image.filename)}&subfolder={net.urlEncode(image.subfolder)}&type={image.type}`
		local file = net.request(`{SERVER}/view?{query}`)
		assert(file.ok, `download failed {file.statusCode}`)
		local folder = string.match(out, "^(.*)[/\\]")
		if folder then
			fs.writeDir(folder)
		end
		fs.writeFile(out, file.body)
		print(`saved {out}`)
		process.exit(0)
	end
end
error("timed out after 15 minutes", 0)
