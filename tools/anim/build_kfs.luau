--!strict
-- Turns the moves tools/blender/anim_kit.py exported (JSON, one per move) into KeyframeSequence .rbxm files Rojo
-- syncs to ReplicatedStorage.SwordAnimations (docs/animations.md). Each JSON frame becomes a keyframe (linear easing)
-- with a Pose for every joint it moves; a joint's parents are added at weight 0 when the move leaves them alone (the
-- upper-body moves leave the hips and legs to Roblox's own animations). Markers (Hit, Grab, Release, Hold) go on the
-- keyframe nearest their time.
-- Usage: lune run tools/anim/build_kfs [source dir] [output dir]
--   default: assets/blender/Animations/StarterSword -> assets/animations/StarterSword
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local SOURCE = process.args[1] or "assets/blender/Animations/StarterSword"
local OUTPUT = process.args[2] or "assets/animations/StarterSword"

-- Each joint's part and the part it hangs from (the R15 tree under the HumanoidRootPart)
local PARENT = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	RightFoot = "RightLowerLeg",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
	LeftFoot = "LeftLowerLeg",
}

type PoseData = { q: { number }, p: { number }? }
type Move = {
	name: string,
	loop: boolean,
	priority: string,
	markers: { { name: string, t: number } },
	frames: { { t: number, poses: { [string]: PoseData } } },
}

-- One keyframe's Pose tree: the moved joints and, at weight 0, every parent on the way up
local function buildPoses(keyframe: any, poses: { [string]: PoseData })
	local made: { [string]: any } = {}
	local function poseFor(part: string): any
		if made[part] then
			return made[part]
		end
		local pose = roblox.Instance.new("Pose")
		pose.Name = part
		pose.EasingStyle = roblox.Enum.PoseEasingStyle.Linear
		local data = poses[part]
		if data then
			local q, p = data.q, data.p or { 0, 0, 0 }
			pose.CFrame = roblox.CFrame.new(p[1], p[2], p[3], q[1], q[2], q[3], q[4])
			pose.Weight = 1
		else
			pose.Weight = 0
		end
		local parent = PARENT[part]
		pose.Parent = if parent then poseFor(parent) else keyframe
		made[part] = pose
		return pose
	end
	poseFor("HumanoidRootPart")
	for part in poses do
		poseFor(part)
	end
end

local function build(move: Move): any
	local sequence = roblox.Instance.new("KeyframeSequence")
	sequence.Name = move.name
	sequence.Loop = move.loop
	sequence.Priority = (roblox.Enum.AnimationPriority :: any)[move.priority]
	local keyframes = {}
	for _, frame in move.frames do
		local keyframe = roblox.Instance.new("Keyframe")
		keyframe.Time = frame.t
		buildPoses(keyframe, frame.poses)
		keyframe.Parent = sequence
		table.insert(keyframes, keyframe)
	end
	for _, marker in move.markers do
		local nearest = keyframes[1]
		for _, keyframe in keyframes do
			if math.abs(keyframe.Time - marker.t) < math.abs(nearest.Time - marker.t) then
				nearest = keyframe
			end
		end
		local instance = roblox.Instance.new("KeyframeMarker")
		instance.Name = marker.name
		instance.Value = ""
		instance.Parent = nearest
	end
	return sequence
end

if not fs.isDir(OUTPUT) then
	fs.writeDir(OUTPUT)
end
local count = 0
for _, file in fs.readDir(SOURCE) do
	if string.sub(file, -5) == ".json" then
		local move = serde.decode("json", fs.readFile(`{SOURCE}/{file}`)) :: Move
		fs.writeFile(`{OUTPUT}/{move.name}.rbxm`, roblox.serializeModel({ build(move) }))
		count += 1
		print(`{move.name}: {#move.frames} keyframes, {#move.markers} markers{if move.loop then ", loops" else ""}`)
	end
end
print(`{count} KeyframeSequences written to {OUTPUT}`)
