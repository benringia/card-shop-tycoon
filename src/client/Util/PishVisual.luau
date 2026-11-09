--!strict
-- Pish drawn on a marker (spec 2026-11-09-tutorial-pish-design 3, 4): his model (ReplicatedStorage.NpcModels.Pish)
-- follows the marker with the creature walk (Util/CreatureVisuals, Party.CREATURE_STYLE.Pish), and plays his keyed clips
-- (ReplicatedStorage.MonsterAnimations.Pish, Util/ClipPlayer) on top. A clip's markers make his sounds (Bark1..3, Yawn,
-- DigStart) and kick up dirt between DigStart and DigEnd; hearts float up when he's petted. Town Pish
-- (TownPishController) and the tutorial's own Pish (TutorialController) both use it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Party = require(Config:WaitForChild("Party"))
local Pish = require(Config:WaitForChild("Pish"))
local SoundLevels = require(Config:WaitForChild("SoundLevels"))
local SoundLevel = require(Shared:WaitForChild("Util"):WaitForChild("SoundLevel"))

local ClientUtil = script.Parent :: Instance
local ClipPlayer = require(ClientUtil:WaitForChild("ClipPlayer"))
local CreatureVisuals = require(ClientUtil:WaitForChild("CreatureVisuals"))

export type Visual = {
	marker: BasePart,
	body: CreatureVisuals.Body,
	clips: { [string]: ClipPlayer.Clip },
	clipPlayer: ClipPlayer.Player?,
	doneAt: number, -- os.clock the clip playing ends
	onDone: (() -> ())?,
	dirt: ParticleEmitter,
	shown: boolean,
}

local PishVisual = {}

local HEART_COUNT = 3
local HEART_RISE = 3 -- studs the hearts float up
local HEART_SECONDS = 1.2
local DIRT_RATE = 40 -- dirt bits a second while he digs

-- A sound from Config/Pish SOUNDS on his body (nothing until its id is set)
local function sound(visual: Visual, key: string)
	local id = Pish.SOUNDS[key]
	if not id or id == "" then
		return
	end
	local made = Instance.new("Sound")
	made.SoundId = id
	made.Volume = Pish.SOUND_VOLUME * SoundLevel.gain(SoundLevels, id)
	made.RollOffMaxDistance = 80
	made.Parent = visual.body.root
	made:Play()
	made.Ended:Once(function()
		made:Destroy()
	end)
end

local function onMarker(visual: Visual, name: string)
	if string.match(name, "^Bark") then
		sound(visual, "bark")
	elseif name == "Yawn" then
		sound(visual, "yawn")
	elseif name == "DigStart" then
		sound(visual, "dig")
		visual.dirt.Enabled = true
	elseif name == "DigEnd" then
		visual.dirt.Enabled = false
	end
end

-- Dirt kicked up by his front paws while he digs
local function makeDirt(root: BasePart): ParticleEmitter
	local paws = Instance.new("Attachment")
	paws.Name = "Paws"
	paws.Position = Vector3.new(0, 0.2, -Pish.HEIGHT * 0.35)
	paws.Parent = root
	local dirt = Instance.new("ParticleEmitter")
	dirt.Name = "Dirt"
	dirt.Color = ColorSequence.new(Color3.fromRGB(150, 110, 70), Color3.fromRGB(110, 80, 50))
	dirt.Size = NumberSequence.new(0.35, 0.1)
	dirt.Lifetime = NumberRange.new(0.4, 0.7)
	dirt.Speed = NumberRange.new(4, 7)
	dirt.SpreadAngle = Vector2.new(35, 35)
	dirt.Acceleration = Vector3.new(0, -25, 0)
	dirt.EmissionDirection = Enum.NormalId.Back
	dirt.Rate = DIRT_RATE
	dirt.Enabled = false
	dirt.Parent = paws
	return dirt
end

-- His model on `marker`, or nil when the model isn't in the game yet
function PishVisual.new(marker: BasePart): Visual?
	local folder = ReplicatedStorage:FindFirstChild("NpcModels")
	local template = if folder then folder:FindFirstChild("Pish") else nil
	if not template or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	CreatureVisuals.strip(model)
	local body = CreatureVisuals.build(model, marker, Pish.HEIGHT, false, "Pish")
	local clips, clipPlayer = ClipPlayer.loadSet("Pish", model)
	return {
		marker = marker,
		body = body,
		clips = clips,
		clipPlayer = clipPlayer,
		doneAt = 0,
		onDone = nil,
		dirt = makeDirt(body.root),
		shown = true,
	}
end

-- Plays one of his clips now (replacing one playing); onDone when it ends
function PishVisual.play(visual: Visual, clip: string, onDone: (() -> ())?)
	local found = visual.clips[clip]
	if not found or not visual.clipPlayer then
		if onDone then
			task.defer(onDone)
		end
		return
	end
	visual.dirt.Enabled = false
	ClipPlayer.play(visual.clipPlayer, found, 1, function(name)
		onMarker(visual, name)
	end)
	visual.doneAt = os.clock() + found.length
	visual.onDone = onDone
end

-- A clip's length in seconds (0 for one he doesn't have)
function PishVisual.length(visual: Visual, clip: string): number
	local found = visual.clips[clip]
	return if found then found.length else 0
end

-- A few hearts floating up over him (petted)
function PishVisual.hearts(visual: Visual)
	local root = visual.body.root
	for i = 1, HEART_COUNT do
		local board = Instance.new("BillboardGui")
		board.Size = UDim2.fromOffset(40, 40)
		board.StudsOffset = Vector3.new((i - (HEART_COUNT + 1) / 2) * 0.8, Pish.HEIGHT, 0)
		board.LightInfluence = 0
		board.Adornee = root
		local heart = Instance.new("TextLabel")
		heart.BackgroundTransparency = 1
		heart.Size = UDim2.fromScale(1, 1)
		heart.Text = "❤️"
		heart.TextScaled = true
		heart.Parent = board
		board.Parent = root
		task.delay((i - 1) * 0.15, function()
			local info = TweenInfo.new(HEART_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(board, info, { StudsOffset = board.StudsOffset + Vector3.new(0, HEART_RISE, 0) }):Play()
			TweenService:Create(heart, info, { TextTransparency = 1 }):Play()
			task.delay(HEART_SECONDS, function()
				board:Destroy()
			end)
		end)
	end
	sound(visual, "yip")
end

-- A sound of his by name (Config/Pish SOUNDS key): the tutorial's whimper, the yip
function PishVisual.sound(visual: Visual, key: string)
	sound(visual, key)
end

-- One frame: the walk following the marker, then the clip on top
function PishVisual.step(visual: Visual, dt: number)
	if not visual.shown then
		return
	end
	local camera = workspace.CurrentCamera
	local origin = if camera then camera.CFrame.Position else visual.marker.Position
	CreatureVisuals.step(visual.body, dt, os.clock(), origin, Party.MOTION)
	if visual.clipPlayer then
		ClipPlayer.step(visual.clipPlayer, dt, visual.body.model:GetScale())
	end
	if visual.onDone and os.clock() >= visual.doneAt then
		local done = visual.onDone
		visual.onDone = nil
		done()
	end
end

function PishVisual.setShown(visual: Visual, shown: boolean)
	visual.shown = shown
	visual.body.model.Parent = if shown then workspace else nil
end

function PishVisual.destroy(visual: Visual)
	visual.onDone = nil
	visual.body.model:Destroy()
end

return PishVisual
