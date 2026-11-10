--!strict
-- A dog drawn on a marker, Pish or Chikin (his combat tutorial; the same rig and clips): Pish here (spec
-- 2026-11-09-tutorial-pish-design 3, 4): his model (ReplicatedStorage.NpcModels.Pish)
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
local Chikin = require(Config:WaitForChild("Chikin"))
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
	dog: string, -- "Pish" or "Chikin"
}

-- Each dog's size and sounds (Config/Pish, Config/Chikin)
local DOGS: { [string]: { HEIGHT: number, SOUNDS: { [string]: string }, SOUND_PITCH: { [string]: number }, SOUND_VOLUME: number } } = {
	Pish = Pish :: any,
	Chikin = Chikin :: any,
}

local PishVisual = {}

local HEART_COUNT = 3
local HEART_RISE = 3 -- studs the hearts float up
local HEART_SECONDS = 1.2
local TAG_WIDTH, TAG_HEIGHT = 260, 80 -- px: the name tag's board (the pill sits at its bottom)
local TAG_LIFT = 0.4 -- studs over his height (his root sits above his feet) where the tag's bottom sits
local TAG_DISTANCE = 70 -- studs: further away the tag hides
-- Owner 2026-11-10: "pish nametag hard to see": an orange pill with white outlined words, not orange on white
local TAG_FILL = Color3.fromRGB(240, 140, 40)
local TAG_EDGE = Color3.new(1, 1, 1)
local TAG_INK = Color3.new(1, 1, 1)
local TAG_OUTLINE = Color3.fromRGB(110, 55, 15)
local DIRT_RATE = 40 -- dirt bits a second while he digs

-- A sound from Config/Pish SOUNDS on his body (nothing until its id is set)
local function sound(visual: Visual, key: string)
	local dog = DOGS[visual.dog] or DOGS.Pish
	local id = dog.SOUNDS[key]
	if not id or id == "" then
		return
	end
	local made = Instance.new("Sound")
	made.SoundId = id
	made.Volume = dog.SOUND_VOLUME * SoundLevel.gain(SoundLevels, id)
	made.PlaybackSpeed = dog.SOUND_PITCH[key] or 1
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
local function makeDirt(root: BasePart, height: number): ParticleEmitter
	local paws = Instance.new("Attachment")
	paws.Name = "Paws"
	paws.Position = Vector3.new(0, 0.2, -height * 0.35)
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

-- The dog's model on `marker` (`dog`: "Pish", the default, or "Chikin"), or nil when it isn't in the game yet
function PishVisual.new(marker: BasePart, dog: string?): Visual?
	local name = dog or "Pish"
	local config = DOGS[name] or DOGS.Pish
	local folder = ReplicatedStorage:FindFirstChild("NpcModels")
	local template = if folder then folder:FindFirstChild(name) else nil
	if not template or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	CreatureVisuals.strip(model)
	local body = CreatureVisuals.build(model, marker, config.HEIGHT, false, name)
	local clips, clipPlayer = ClipPlayer.loadSet(name, model)
	return {
		dog = name,
		marker = marker,
		body = body,
		clips = clips,
		clipPlayer = clipPlayer,
		doneAt = 0,
		onDone = nil,
		dirt = makeDirt(body.root, config.HEIGHT),
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

-- His name over his head (owner 2026-11-10: "show that he's an npc and he's interactable"), with a second line when
-- there's something to do with him ("pet me for luck!"); nil leaves just the name
function PishVisual.nameTag(visual: Visual, subtitle: string?)
	local root = visual.body.root
	local board = root:FindFirstChild("PishName") :: BillboardGui?
	if not board then
		local made = Instance.new("BillboardGui")
		made.Name = "PishName"
		made.Size = UDim2.fromOffset(TAG_WIDTH, TAG_HEIGHT)
		made.StudsOffset = Vector3.new(0, Pish.HEIGHT + TAG_LIFT, 0)
		-- The board stands on that point (not centred on it): far away it stays above him instead of over his head
		made.SizeOffset = Vector2.new(0, 0.5)
		made.LightInfluence = 0
		made.MaxDistance = TAG_DISTANCE
		made.Adornee = root
		local pill = Instance.new("Frame")
		pill.Name = "Pill"
		pill.AnchorPoint = Vector2.new(0.5, 1)
		pill.Position = UDim2.fromScale(0.5, 1)
		pill.AutomaticSize = Enum.AutomaticSize.XY
		pill.Size = UDim2.fromOffset(0, 0)
		pill.BackgroundColor3 = TAG_FILL
		pill.Parent = made
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 16)
		corner.Parent = pill
		local edge = Instance.new("UIStroke")
		edge.Color = TAG_EDGE
		edge.Thickness = 3
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Parent = pill
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 14)
		padding.PaddingRight = UDim.new(0, 14)
		padding.PaddingTop = UDim.new(0, 4)
		padding.PaddingBottom = UDim.new(0, 5)
		padding.Parent = pill
		local list = Instance.new("UIListLayout")
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = pill
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.LayoutOrder = 1
		name.BackgroundTransparency = 1
		name.AutomaticSize = Enum.AutomaticSize.X
		name.Size = UDim2.fromOffset(0, 32)
		name.Font = Enum.Font.FredokaOne
		name.TextSize = 28
		name.TextColor3 = TAG_INK
		name.Text = "🐾 " .. visual.dog
		name.Parent = pill
		local nameOutline = Instance.new("UIStroke")
		nameOutline.Color = TAG_OUTLINE
		nameOutline.Thickness = 2
		nameOutline.Parent = name
		local sub = Instance.new("TextLabel")
		sub.Name = "Sub"
		sub.LayoutOrder = 2
		sub.BackgroundTransparency = 1
		sub.AutomaticSize = Enum.AutomaticSize.X
		sub.Size = UDim2.fromOffset(0, 20)
		sub.Font = Enum.Font.GothamBold
		sub.TextSize = 16
		sub.TextColor3 = TAG_INK
		sub.Parent = pill
		local subOutline = Instance.new("UIStroke")
		subOutline.Color = TAG_OUTLINE
		subOutline.Thickness = 1.5
		subOutline.Parent = sub
		made.Parent = root
		board = made
	end
	local sub = (board :: BillboardGui):FindFirstChild("Sub", true) :: TextLabel?
	if sub then
		sub.Text = subtitle or ""
		sub.Visible = subtitle ~= nil
	end
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
