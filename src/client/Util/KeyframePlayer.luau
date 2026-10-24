--!strict
-- Plays a creature model's own saved animations (KeyframeSequences named Idle, Walk and Run in its Animations
-- folder, as the Accretion Stud Pet Packs ship them) by setting its bones each frame on this client: no upload,
-- no animation ownership needed. Blends idle, walk and run by speed (Util/KeyframeTiming); keyframes are blended
-- linearly. Numbers: Config/Party KEYFRAME_ANIM.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Party = require(Shared:WaitForChild("Config"):WaitForChild("Party"))
local KeyframeTiming = require(Shared:WaitForChild("Util"):WaitForChild("KeyframeTiming"))

type Track = { times: { number }, loop: boolean, poses: { [string]: { CFrame } }, time: number }

export type Player = {
	bones: { [string]: Bone },
	tracks: { Track? }, -- idle, walk, run
	weights: { number },
}

local KeyframePlayer = {}

local NAMES = { "Idle", "Walk", "Run" }

local function buildTrack(sequence: KeyframeSequence): Track
	local keyframes = sequence:GetKeyframes()
	table.sort(keyframes, function(a, b)
		return (a :: Keyframe).Time < (b :: Keyframe).Time
	end)
	local times = {}
	local poses: { [string]: { CFrame } } = {}
	for index, keyframe in keyframes do
		table.insert(times, (keyframe :: Keyframe).Time)
		for _, pose in keyframe:GetDescendants() do
			if pose:IsA("Pose") then
				local list = poses[pose.Name]
				if not list then
					list = {}
					poses[pose.Name] = list
				end
				list[index] = pose.CFrame
			end
		end
	end
	return { times = times, loop = sequence.Loop, poses = poses, time = 0 }
end

-- The model's bones and its Idle (required), Walk and Run animations; nil if it has none
function KeyframePlayer.attach(model: Model): Player?
	local folder = model:FindFirstChild("Animations")
	local idle = folder and folder:FindFirstChild("Idle")
	if not idle or not idle:IsA("KeyframeSequence") then
		return nil
	end
	local bones: { [string]: Bone } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") then
			bones[descendant.Name] = descendant
		end
	end
	local tracks: { Track? } = {}
	for index, name in NAMES do
		local sequence = (folder :: Instance):FindFirstChild(name)
		tracks[index] = if sequence and sequence:IsA("KeyframeSequence") then buildTrack(sequence) else nil
	end
	return { bones = bones, tracks = tracks, weights = { 1, 0, 0 } }
end

-- A turn made `amount` times bigger about the same axis (the move kept as it is)
local function amplify(cf: CFrame, amount: number): CFrame
	if amount == 1 then
		return cf
	end
	local axis, angle = cf:ToAxisAngle()
	return CFrame.new(cf.Position) * CFrame.fromAxisAngle(axis, angle * amount)
end

local function sample(track: Track, name: string): CFrame?
	local list = track.poses[name]
	if not list then
		return nil
	end
	local a, b, alpha = KeyframeTiming.between(track.times, track.time, track.loop)
	local from = list[a] or CFrame.identity
	local to = list[b] or from
	return from:Lerp(to, alpha)
end

-- One frame. speed: studs a second; size: the creature's size (height / Party.CREATURE_HEIGHT); scale: how much the
-- model was scaled from its file (the animations' moves are in the file's size)
function KeyframePlayer.step(player: Player, dt: number, speed: number, size: number, scale: number)
	local cfg = Party.KEYFRAME_ANIM
	local relative = speed / math.max(size, 0.1)
	local targets = { KeyframeTiming.weights(cfg, relative) }
	local blend = math.min(1, dt / cfg.BLEND_SECONDS)
	for index = 1, 3 do
		local track = player.tracks[index]
		local target = if track then targets[index] else 0
		player.weights[index] += (target - player.weights[index]) * blend
		if track then
			-- Idle plays at its own pace; walk and run speed up with how fast the creature moves
			local rate = if index == 1 then 1 else math.clamp(relative / (if index == 2 then cfg.WALK_SPEED else cfg.RUN_SPEED), 0.5, 2)
			track.time += dt * rate
		end
	end
	for name, bone in player.bones do
		local result: CFrame? = nil
		local total = 0
		for index = 1, 3 do
			local track = player.tracks[index]
			local weight = player.weights[index]
			if track and weight > 1e-3 then
				local value = sample(track, name)
				if value then
					value = amplify(value, cfg.AMPLIFY[index] or 1)
					total += weight
					result = if result then (result :: CFrame):Lerp(value, weight / total) else value
				end
			end
		end
		if result then
			local cf = result :: CFrame
			bone.Transform = CFrame.new(cf.Position * scale) * cf.Rotation
		end
	end
end

return KeyframePlayer
