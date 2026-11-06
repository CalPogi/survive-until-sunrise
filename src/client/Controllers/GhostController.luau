--!strict
--[[
	GhostController: draws players from other servers as ghosts.
	Specs: docs/specs/ghost-live.md, docs/specs/ghost-avatars.md

	A ghost starts as a grey stand-in with a name label, and swaps to the player's avatar once that
	loads. Ghosts can't be touched or collided with, and exist only on this client.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GhostCodec = require(ReplicatedStorage.Shared.GhostCodec)
local GhostInterpolator = require(ReplicatedStorage.Shared.GhostInterpolator)
local GhostPose = require(ReplicatedStorage.Shared.GhostPose)
local Net = require(script.Parent.Parent.Net)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

type Ghost = {
	interpolator: GhostInterpolator.GhostInterpolator,
	model: Model,
	lastSenderTime: number,
	wasMoving: boolean,
	waitingForAvatar: boolean,
	-- Only once the avatar has loaded.
	tracks: { [GhostPose.Pose]: AnimationTrack }?,
	pose: GhostPose.Pose,
	speed: number,
	verticalSpeed: number,
	lastPosition: Vector3?,
	lastUpdate: number,
}

-- Roblox's default R15 animations.
local ANIMATION_IDS: { [GhostPose.Pose]: string } = {
	idle = "rbxassetid://507766388",
	walk = "rbxassetid://507777826",
	run = "rbxassetid://507767714",
	jump = "rbxassetid://507765000",
	fall = "rbxassetid://507767968",
}
local POSE_FADE = 0.15 -- seconds
local MAX_AVATAR_LOADS = 3 -- at once; each one makes web calls
-- The most tested so far. Others stay stand-ins until a slot frees.
-- ponytail: first come, first served. Give slots to the nearest ghosts if crowds make that matter.
local MAX_AVATARS = 40

local DEFAULT_INTERVAL = 1
local MAX_SPACING = 5 -- seconds; one long pause must not push a ghost far into the past
local LONG_GAP = 1.5 -- times the send interval; a longer gap means this player is updated less often
local FIRST_BOT_ID = 1000000000000 -- GhostBots ids are all above this

local REPORT_INTERVAL = 0.05 -- seconds
local REPORT_MIN_MOVE = 0.05 -- studs
local REPORT_MIN_TURN = 2 -- degrees
local REPORT_MOVING_SPEED = 1 -- studs/s; the same as GhostPacer's

local ghosts: { [number]: Ghost } = {}
local folder: Folder
local lastReportAt = 0
local lastReportedPosition: Vector3? = nil
local lastReportedYaw = 0
local lastReportedMoving = false
local avatarLoads = 0
local avatarCount = 0
local warnedAvatarFailure = false
local startAvatarLoads: () -> ()

local function makePart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return part
end

local function makeLabel(head: BasePart): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 28)
	billboard.StudsOffset = Vector3.new(0, 1.8, 0)
	billboard.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Text = "Ghost"
	label.Parent = billboard
	billboard.Parent = head
	return label
end

local function makeModel(userId: number): Model
	local model = Instance.new("Model")
	model.Name = `Ghost{userId}`

	local torso = makePart("Torso", Vector3.new(2, 4.5, 1), Color3.fromRGB(120, 130, 125))
	torso.CFrame = CFrame.new(0, -0.75, 0)
	torso.Parent = model
	local head = makePart("Head", Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(170, 180, 175))
	head.CFrame = CFrame.new(0, 2.2, 0)
	head.Parent = model
	model.WorldPivot = CFrame.new()

	makeLabel(head)
	model.Parent = folder
	return model
end

local function removeGhost(userId: number)
	local ghost = ghosts[userId]
	if ghost then
		ghost.model:Destroy()
		ghosts[userId] = nil
		if ghost.tracks then
			avatarCount -= 1
			startAvatarLoads()
		end
	end
end

-- Call after parenting: entering the world turns collision back on for the torso.
local function makeUntouchable(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
end

-- Yields on a web call.
local function fetchName(userId: number): string?
	if userId >= FIRST_BOT_ID then
		return "Bot"
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	return if ok then name else nil
end

-- Yields on web calls and errors if they fail.
local function buildAvatar(userId: number, name: string?): Model
	local description = if userId >= FIRST_BOT_ID
		then Instance.new("HumanoidDescription")
		else Players:GetHumanoidDescriptionFromUserId(userId)
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = `Ghost{userId}`

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		end
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	assert(root and root:IsA("BasePart"), "avatar has no root part")
	root.Anchored = true
	model.PrimaryPart = root

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid, "avatar has no Humanoid")
	humanoid.EvaluateStateMachine = false
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	if name then
		humanoid.DisplayName = name
	else
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return model
end

local function loadTracks(model: Model): { [GhostPose.Pose]: AnimationTrack }
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid, "avatar has no Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		local newAnimator = Instance.new("Animator")
		newAnimator.Parent = humanoid
		animator = newAnimator
	end
	assert(animator, "avatar has no Animator")

	local tracks: { [GhostPose.Pose]: AnimationTrack } = {}
	for pose: GhostPose.Pose, id in ANIMATION_IDS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local track = animator:LoadAnimation(animation)
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Movement
		tracks[pose] = track
	end
	local firstPose: GhostPose.Pose = "idle" -- every new ghost starts here
	tracks[firstPose]:Play()
	return tracks
end

-- Errors if the avatar can't be used, and the stand-in stays until then.
local function loadAvatar(userId: number, ghost: Ghost)
	local name = fetchName(userId)
	local label = ghost.model:FindFirstChildWhichIsA("TextLabel", true)
	if name and label and label:IsA("TextLabel") then
		label.Text = name
	end

	local model = buildAvatar(userId, name)
	-- The ghost may have left during the web calls.
	if ghosts[userId] ~= ghost then
		model:Destroy()
		return
	end
	model:PivotTo(ghost.model:GetPivot())
	model.Parent = folder
	makeUntouchable(model)
	local ok, tracksOrError = pcall(loadTracks, model)
	if not ok then
		model:Destroy()
		error(tracksOrError, 0)
	end
	ghost.model:Destroy()
	ghost.model = model
	ghost.tracks = tracksOrError
	avatarCount += 1
end

function startAvatarLoads()
	for userId, ghost in ghosts do
		if avatarLoads >= MAX_AVATAR_LOADS or avatarCount + avatarLoads >= MAX_AVATARS then
			return
		end
		if ghost.waitingForAvatar then
			ghost.waitingForAvatar = false
			avatarLoads += 1
			task.spawn(function()
				local ok, err = (pcall :: any)(loadAvatar, userId, ghost)
				if not ok and not warnedAvatarFailure then
					warnedAvatarFailure = true
					warn(`[Ghost] an avatar is staying as a stand-in: {err}`)
				end
				avatarLoads -= 1
				startAvatarLoads()
			end)
		end
	end
end

local function onSnapshot(text: unknown, interval: unknown)
	local decoded = GhostCodec.decode(text)
	if decoded == nil then
		return
	end
	local sendInterval = if type(interval) == "number"
			and interval > 0
			and interval < math.huge
		then interval
		else DEFAULT_INTERVAL

	local receivedAt = os.clock()
	for _, entry in decoded.entries do
		if Players:GetPlayerByUserId(entry.userId) == nil then
			local ghost = ghosts[entry.userId]
			if ghost == nil then
				ghost = {
					interpolator = GhostInterpolator.new(sendInterval),
					model = makeModel(entry.userId),
					lastSenderTime = decoded.senderTime,
					wasMoving = false,
					waitingForAvatar = true,
					tracks = nil,
					pose = "idle",
					speed = 0,
					verticalSpeed = 0,
					lastPosition = nil,
					lastUpdate = receivedAt,
				}
				ghosts[entry.userId] = ghost
				startAvatarLoads()
			end
			-- Players on full servers update less often than the send interval. A gap next to standing
			-- still is only the heartbeat, and must not add delay when they start walking. Normal send
			-- timing varies, and following it would keep changing the delay and the ghost's speed.
			local moving = entry.vx ~= 0 or entry.vz ~= 0
			local gap = if ghost.wasMoving and moving
				then math.clamp(decoded.senderTime - ghost.lastSenderTime, 0, MAX_SPACING)
				else 0
			ghost.interpolator:setSendInterval(if gap > sendInterval * LONG_GAP then gap else sendInterval)
			ghost.lastSenderTime = decoded.senderTime
			ghost.wasMoving = moving
			ghost.interpolator:push(decoded.senderTime, receivedAt, entry)
			if entry.anim == GhostCodec.Action.Jump then
				ghost.interpolator:playJump(decoded.senderTime)
			end
		end
	end
end

-- Poses follow how the ghost really moves on screen, so they match what the player sees.
local function updatePose(ghost: Ghost, state: GhostInterpolator.State, now: number)
	local position = Vector3.new(state.x, state.y, state.z)
	local last = ghost.lastPosition
	local dt = now - ghost.lastUpdate
	ghost.lastPosition = position
	ghost.lastUpdate = now
	local tracks = ghost.tracks
	if last == nil or dt <= 0 or tracks == nil then
		return
	end

	local step = position - last
	if GhostPose.isTeleport(step.Magnitude, dt) then
		ghost.speed = 0
		ghost.verticalSpeed = 0
		return
	end
	local groundSpeed = Vector3.new(step.X, 0, step.Z).Magnitude / dt
	-- The arc isn't a fall, and counting it would show a fall for a moment after landing.
	local verticalSpeed = if state.jumping then 0 else step.Y / dt
	ghost.speed = GhostPose.smooth(ghost.speed, groundSpeed, dt)
	ghost.verticalSpeed = GhostPose.smooth(ghost.verticalSpeed, verticalSpeed, dt)

	local pose: GhostPose.Pose = GhostPose.next(ghost.pose, ghost.speed, ghost.verticalSpeed, state.jumping)
	if pose ~= ghost.pose then
		tracks[ghost.pose]:Stop(POSE_FADE)
		tracks[pose]:Play(POSE_FADE)
		ghost.pose = pose
	end
	tracks[pose]:AdjustSpeed(GhostPose.playbackSpeed(pose, ghost.speed))
end

local function updateGhosts()
	local now = os.clock()
	for userId, ghost in ghosts do
		local state = ghost.interpolator:sample(now)
		if state.status == "gone" then
			removeGhost(userId)
		else
			local placed = CFrame.new(state.x, state.y, state.z) * CFrame.Angles(0, math.rad(state.yaw), 0)
			-- Moving an avatar's root takes its body with it, and costs about a third of PivotTo.
			local root = ghost.model.PrimaryPart
			if root then
				root.CFrame = placed
			else
				ghost.model:PivotTo(placed)
			end
			updatePose(ghost, state, now)
		end
	end
end

-- Tells the server about this player's jumps directly, because physics takes a while to show them.
local function reportJumps(character: Model)
	local humanoid = character:WaitForChild("Humanoid")
	if humanoid:IsA("Humanoid") then
		humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping then
				Net.fire(RemoteNames.GhostJump)
			end
		end)
	end
end

-- Reports this player's position while it changes, because physics reaches the server late.
-- ponytail: reports even when no other server exists. Skip it then if upload ever matters.
local function reportPosition()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local now = os.clock()
	if not (root and root:IsA("BasePart")) or now - lastReportAt < REPORT_INTERVAL then
		return
	end
	local position = root.Position
	local look = root.CFrame.LookVector
	local yaw = math.deg(math.atan2(-look.X, -look.Z))
	local velocity = root.AssemblyLinearVelocity
	local moving = velocity.X * velocity.X + velocity.Z * velocity.Z >= REPORT_MOVING_SPEED * REPORT_MOVING_SPEED
	local moved = lastReportedPosition == nil or (position - lastReportedPosition).Magnitude > REPORT_MIN_MOVE
	-- Also reports a stop, or the server would keep seeing the last speed until the report went stale.
	local stopped = lastReportedMoving and not moving
	if moved or stopped or math.abs(yaw - lastReportedYaw) > REPORT_MIN_TURN then
		Net.fireUnreliable(RemoteNames.GhostPosition, position.X, position.Y, position.Z, yaw, velocity.X, velocity.Z)
		lastReportAt = now
		lastReportedPosition = position
		lastReportedYaw = yaw
		lastReportedMoving = moving
	end
end

local GhostController = { Name = "GhostController" }

function GhostController.Start()
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Ghosts"
	newFolder.Parent = Workspace
	folder = newFolder

	-- A ghosted player who joins this server is now real here, so the ghost must not stand beside them.
	Players.PlayerAdded:Connect(function(player)
		removeGhost(player.UserId)
	end)
	local localPlayer = Players.LocalPlayer
	localPlayer.CharacterAdded:Connect(reportJumps)
	if localPlayer.Character then
		task.spawn(reportJumps, localPlayer.Character)
	end
	RunService.Heartbeat:Connect(reportPosition)
	RunService.RenderStepped:Connect(updateGhosts)
	Net.onUnreliableEvent(RemoteNames.GhostSnapshot, onSnapshot)
end

return GhostController
