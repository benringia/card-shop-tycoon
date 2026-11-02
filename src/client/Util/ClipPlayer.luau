--!strict
-- Plays one-shot attack clips on a monster's or boss's bones (spec 2026-11-02-attack-animations-design): the
-- KeyframeSequences tools/anim/build_bone_clips made, in ReplicatedStorage.MonsterAnimations/<model>. Their poses
-- hold each bone's rotation in MODEL space (attribute Space = "Model"), because the FBX importer gives every bone its
-- own axes; here each becomes the bone's Transform from its rest pose:
--   T = R0⁻¹ · Dparent⁻¹ · Dbone · R0   (R0: the bone's rest rotation in the model)
-- and is blended over whatever the procedural motion (Util/PetAnimator) set this frame, in and out over
-- KEYFRAME_ANIM.ONE_SHOT_BLEND (Util/KeyframeTiming). Markers (Hit) call back as the clip passes them. Step it after
-- the procedural motion each frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Party = require(Shared:WaitForChild("Config"):WaitForChild("Party"))
local KeyframeTiming = require(Shared:WaitForChild("Util"):WaitForChild("KeyframeTiming"))

local ClipPlayer = {}

export type Clip = {
	length: number,
	times: { number },
	poses: { [string]: { CFrame } },
	markers: { { name: string, time: number } },
}
type Playing = { clip: Clip, t: number, speed: number, fired: { [number]: boolean }, onMarker: ((name: string) -> ())? }
export type Player = {
	bones: { [string]: Bone },
	parentOf: { [string]: string }, -- a bone's parent bone, if any
	rest: { [string]: CFrame }, -- each bone's rest rotation in the model
	playing: Playing?,
}

local cache: { [KeyframeSequence]: Clip } = {}

-- A clip from its KeyframeSequence (built once)
function ClipPlayer.clip(sequence: KeyframeSequence): Clip
	local cached = cache[sequence]
	if cached then
		return cached
	end
	local keyframes = sequence:GetKeyframes()
	table.sort(keyframes, function(a, b)
		return (a :: Keyframe).Time < (b :: Keyframe).Time
	end)
	local times, poses, markers = {}, {}, {}
	for index, keyframe in keyframes do
		local time = (keyframe :: Keyframe).Time
		table.insert(times, time)
		for _, item in keyframe:GetDescendants() do
			if item:IsA("Pose") then
				local list = poses[item.Name]
				if not list then
					list = {}
					poses[item.Name] = list
				end
				list[index] = item.CFrame
			elseif item:IsA("KeyframeMarker") then
				table.insert(markers, { name = item.Name, time = time })
			end
		end
	end
	local clip = { length = times[#times] or 0, times = times, poses = poses, markers = markers }
	cache[sequence] = clip
	return clip
end

-- The model's bones and their rest rotations in the model (from the bones' CFrames, whatever their Transforms are now)
function ClipPlayer.attach(model: Model): Player
	local pivot = model:GetPivot()
	local bones, parentOf, rest = {}, {}, {}
	local function restOf(bone: Bone): CFrame
		local known = rest[bone.Name]
		if known then
			return known
		end
		local parent = bone.Parent
		local base = if parent and parent:IsA("Bone") then restOf(parent)
			elseif parent and parent:IsA("BasePart") then pivot:ToObjectSpace(parent.CFrame)
			else CFrame.identity
		local value = base * bone.CFrame
		rest[bone.Name] = value
		return value
	end
	for _, item in model:GetDescendants() do
		if item:IsA("Bone") then
			bones[item.Name] = item
			if item.Parent and item.Parent:IsA("Bone") then
				parentOf[item.Name] = item.Parent.Name
			end
		end
	end
	for _, bone in bones do
		restOf(bone)
	end
	return { bones = bones, parentOf = parentOf, rest = rest, playing = nil }
end

-- Starts a clip now (replacing one playing) at `speed` times its pace
function ClipPlayer.play(player: Player, clip: Clip, speed: number?, onMarker: ((name: string) -> ())?)
	player.playing = { clip = clip, t = 0, speed = speed or 1, fired = {}, onMarker = onMarker }
end

function ClipPlayer.isPlaying(player: Player): boolean
	return player.playing ~= nil
end

local function sample(clip: Clip, name: string, t: number): CFrame?
	local list = clip.poses[name]
	if not list then
		return nil
	end
	local a, b, alpha = KeyframeTiming.between(clip.times, t, false)
	local from = list[a] or CFrame.identity
	return from:Lerp(list[b] or from, alpha)
end

-- One frame, after the procedural motion set the bones. scale: how much the model was scaled from its file
function ClipPlayer.step(player: Player, dt: number, scale: number)
	local playing = player.playing
	if not playing then
		return
	end
	playing.t += dt * playing.speed
	local clip = playing.clip
	for index, marker in clip.markers do
		if not playing.fired[index] and playing.t >= marker.time then
			playing.fired[index] = true
			if playing.onMarker then
				task.spawn(playing.onMarker, marker.name)
			end
		end
	end
	if playing.t >= clip.length then
		player.playing = nil
		return
	end
	local weight = KeyframeTiming.oneShotWeight(playing.t, clip.length, Party.KEYFRAME_ANIM.ONE_SHOT_BLEND)
	for name, bone in player.bones do
		local delta = sample(clip, name, playing.t)
		local rest = player.rest[name]
		if delta and rest then
			local parentName = player.parentOf[name]
			local parentDelta = if parentName then sample(clip, parentName, playing.t) else nil
			local turn = (parentDelta or CFrame.identity).Rotation:Inverse() * delta.Rotation
			local r0 = rest.Rotation
			local transform = r0:Inverse() * turn * r0
			local offset = r0:Inverse() * (delta.Position * scale)
			bone.Transform = bone.Transform:Lerp(CFrame.new(offset) * transform, weight)
		end
	end
end

return ClipPlayer
