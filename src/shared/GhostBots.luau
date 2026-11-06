--!strict
--[[
	GhostBots: fake walkers for testing ghosts without a crowd. Spec: docs/specs/ghost-live.md

	Each bot walks its own circle around the origin at a fixed speed. Pure logic: the same inputs
	always give the same positions. The returned tables match GhostCodec.Entry.
]]

local WALK_SPEED = 12 -- studs/s, under Roblox's default of 16
local FIRST_RADIUS = 30
local RADIUS_STEP = 4
local GROUND_Y = 3

local GhostBots = {}

function GhostBots.entries(count: number, time: number, idBase: number)
	local bots = table.create(count)
	for i = 1, count do
		local radius = FIRST_RADIUS + (i - 1) * RADIUS_STEP
		local direction = if i % 2 == 0 then -1 else 1
		local angle = direction * time * WALK_SPEED / radius + i
		local vx = -math.sin(angle) * WALK_SPEED * direction
		local vz = math.cos(angle) * WALK_SPEED * direction
		bots[i] = {
			userId = idBase + i,
			x = math.cos(angle) * radius,
			y = GROUND_Y,
			z = math.sin(angle) * radius,
			yaw = math.deg(math.atan2(-vx, -vz)),
			vx = vx,
			vz = vz,
			anim = 0,
			held = 0,
		}
	end
	return bots
end

return GhostBots
