--!strict
-- Turns the clips tools/blender/anim_bone_kit.py exported (JSON, one per clip) into KeyframeSequence .rbxm files Rojo
-- syncs to ReplicatedStorage.MonsterAnimations/<model> (docs/animations.md "Bone rigs"). Each JSON frame becomes a
-- keyframe (linear easing) with one Pose per bone, flat (Util/ClipPlayer reads them by name): its MODEL-space rotation
-- (Roblox axes) and, for the top bone, its offset. The sequence's attribute Space = "Model" says so. Markers (Hit) go
-- on the keyframe nearest their time.
-- Usage: lune run tools/anim/build_bone_clips <model>   (assets/blender/Animations/<model> -> assets/monster-animations/<model>)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local MODEL = process.args[1]
assert(MODEL, "usage: lune run tools/anim/build_bone_clips <model>")
local SOURCE = `assets/blender/Animations/{MODEL}`
local OUTPUT = `assets/monster-animations/{MODEL}`

type Frame = { t: number, r: { [string]: { number } }, p: { [string]: { number } } }
type Clip = { name: string, length: number, markers: { [string]: number }, frames: { Frame } }

local function build(clip: Clip): any
	local sequence = roblox.Instance.new("KeyframeSequence")
	sequence.Name = clip.name
	sequence.Loop = false
	sequence:SetAttribute("Space", "Model")
	local keyframes = {}
	for _, frame in clip.frames do
		local keyframe = roblox.Instance.new("Keyframe")
		keyframe.Time = frame.t
		for bone, q in frame.r do
			local offset = frame.p[bone] or { 0, 0, 0 }
			local pose = roblox.Instance.new("Pose")
			pose.Name = bone
			pose.CFrame = roblox.CFrame.new(offset[1], offset[2], offset[3], q[1], q[2], q[3], q[4])
			pose.EasingStyle = roblox.Enum.PoseEasingStyle.Linear
			pose.Parent = keyframe
		end
		keyframe.Parent = sequence
		table.insert(keyframes, keyframe)
	end
	for name, time in clip.markers do
		local nearest = keyframes[1]
		for _, keyframe in keyframes do
			if math.abs(keyframe.Time - time) < math.abs(nearest.Time - time) then
				nearest = keyframe
			end
		end
		local marker = roblox.Instance.new("KeyframeMarker")
		marker.Name = name
		marker.Parent = nearest
	end
	return sequence
end

if not fs.isDir(OUTPUT) then
	fs.writeDir(OUTPUT)
end
local count = 0
for _, file in fs.readDir(SOURCE) do
	if string.sub(file, -5) == ".json" then
		local clip = serde.decode("json", fs.readFile(`{SOURCE}/{file}`)) :: Clip
		fs.writeFile(`{OUTPUT}/{clip.name}.rbxm`, roblox.serializeModel({ build(clip) }))
		count += 1
		print(`{OUTPUT}/{clip.name}.rbxm: {#clip.frames} keyframes`)
	end
end
print(`{count} clip(s) built`)
