--!strict
--[[
	GhostPose: which animation a ghost should play, from how it's moving on screen.
	Spec: docs/specs/ghost-avatars.md

	Pure logic.
]]

export type Pose = "idle" | "walk" | "run" | "jump" | "fall"

-- Calibration knobs, in studs/s. Each pair has a gap so a speed near a limit doesn't flicker.
local START_MOVING = 1.5
local STOP_MOVING = 0.75
local START_RUN = 11
local STOP_RUN = 9
local FALL_SPEED = -25 -- walking down a steep slope stays above this
local WALK_ANIMATION_SPEED = 8 -- the ground speed each animation was made for
local RUN_ANIMATION_SPEED = 16
local MIN_PLAYBACK = 0.5
local MAX_PLAYBACK = 2
local SMOOTH_TIME = 0.1 -- seconds
local TELEPORT_SPEED = 200 -- studs/s; the same as GhostInterpolator's snap speed

local GhostPose = {}

function GhostPose.next(current: Pose, speed: number, verticalSpeed: number, jumping: boolean): Pose
	if jumping then
		return "jump"
	end
	if verticalSpeed < FALL_SPEED then
		return "fall"
	end
	local wasMoving = current == "walk" or current == "run"
	if speed < (if wasMoving then STOP_MOVING else START_MOVING) then
		return "idle"
	end
	if speed >= (if current == "run" then STOP_RUN else START_RUN) then
		return "run"
	end
	return "walk"
end

function GhostPose.playbackSpeed(pose: Pose, speed: number): number
	if pose == "walk" then
		return math.clamp(speed / WALK_ANIMATION_SPEED, MIN_PLAYBACK, MAX_PLAYBACK)
	elseif pose == "run" then
		return math.clamp(speed / RUN_ANIMATION_SPEED, MIN_PLAYBACK, MAX_PLAYBACK)
	end
	return 1
end

-- A teleport or respawn isn't movement, so it mustn't show as running or falling.
function GhostPose.isTeleport(distance: number, dt: number): boolean
	return distance / dt > TELEPORT_SPEED
end

function GhostPose.smooth(current: number, target: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-dt / SMOOTH_TIME))
end

return GhostPose
