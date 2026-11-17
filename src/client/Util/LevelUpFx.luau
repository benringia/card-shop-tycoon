--!strict
-- The level-up light pillar (spec 2026-11-04-round4-design section 9; owner's pick 2026-11-04, "pillar and spinning
-- circle is enough"): a spinning rune circle opens on the ground, a pillar of light (a white core in a coloured glow,
-- motes rising in it) shoots up and the one levelling up lights for a moment, then a star badge pops with the number
-- rolling up and "LEVEL UP!" under it; the beam thins and the circle fades. Every 10th level the pillar is the five
-- baby colours and a pack flies out ("+1 pack"). A creature gets a smaller pillar in its element's colour and its level
-- chip (owner 2026-11-17, mockup B: a LEVEL UP! tab on a pill in its element's colour, "Lv 19" then three arrows
-- lighting and "Lv 20" popping in gold, a shine, "+1"). Numbers, textures and sounds: Config/LevelUpFx. Played by
-- LevelUpController.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local LevelUpConfig = require(Config:WaitForChild("LevelUpFx"))
local BabyColors = require(Config:WaitForChild("BabyColors"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local UIIcons = require(Config:WaitForChild("UIIcons"))
local XpPill = require(Shared:WaitForChild("Util"):WaitForChild("XpPill"))
local LevelUpRules = require(Shared:WaitForChild("Util"):WaitForChild("LevelUpRules"))
local SoundBank = require((script.Parent :: Instance):WaitForChild("SoundBank"))

local IMAGES = LevelUpConfig.IMAGES
local T = LevelUpConfig.TIMING
local SOUNDS = LevelUpConfig.SOUNDS
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(91, 61, 110)
local DROP = Color3.fromRGB(194, 65, 12)
local GROUND_LIFT = 0.12 -- studs the circle floats over the ground (no z-fighting)
local SPIN_SPEED = 1.6 -- radians a second (the inner ring turns the other way)
local GLOW_BRIGHTNESS = 3 -- the coloured glow is soft and wide: brighter so it reads in daylight
local CORE_BRIGHTNESS = 2
local BADGE_HEIGHT = 7.6 -- studs over the character's root to the badge's middle (clear of a tall hat and a title tag)
local SOUND_LIFETIME = 10 -- seconds before a played sound (and its anchor) is cleaned up; the longest sting is ~7 s

local LevelUpFx = {}

type Sizes = { rune: number, beamHeight: number, beamWidth: number, core: number }
type Look = { glow: ColorSequence, runeOuter: Color3, runeInner: Color3, mote: ColorSequence }

local function rgb(value: { number }): Color3
	return Color3.fromRGB(value[1], value[2], value[3])
end

local function baby(name: string): Color3
	local shades = UIStyle.BABY[name]
	return if shades then shades.fill else WHITE
end

-- The colours for a shop level (gold), a 10th level (the five baby colours) or a creature (its element's colour)
local function look(milestone: boolean, element: string?): Look
	if element then
		local color = baby(BabyColors.ELEMENTS[element] or "butter")
		local light = color:Lerp(WHITE, 0.55)
		return { glow = ColorSequence.new(color, light), runeOuter = color, runeInner = light, mote = ColorSequence.new(light) }
	end
	if milestone then
		local keys = {}
		local names = LevelUpConfig.COLORS.rainbow
		for index, name in names do
			table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#names - 1), baby(name)))
		end
		local pair = LevelUpConfig.COLORS.runeMilestone
		return { glow = ColorSequence.new(keys), runeOuter = rgb(pair[1]), runeInner = rgb(pair[2]), mote = ColorSequence.new(keys) }
	end
	local gold = LevelUpConfig.COLORS.gold
	local rune = rgb(LevelUpConfig.COLORS.rune)
	return { glow = ColorSequence.new(rgb(gold[1]), rgb(gold[2])), runeOuter = rune, runeInner = rune:Lerp(WHITE, 0.3), mote = ColorSequence.new(rgb(gold[2])) }
end

-- The ground under a root (a ray down), or a little under its feet when there's nothing below
local function groundUnder(root: BasePart, model: Instance): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -20, 0), params)
	return if hit then hit.Position else root.Position - Vector3.new(0, root.Size.Y / 2 + 2, 0)
end

-- A level-up sound (round 5: one per level-up, a sting on a 10th shop level): the "sound" or "sting" of the set picked in
-- Studio (/levelsound sets LevelSoundSet, and LevelSoundVolume for the sound) or the default set; flat for your own, at
-- `at` for others (quieter, fading with distance)
local function play(part: "sound" | "sting", at: Vector3?, quiet: boolean, creature: boolean, layer: any?)
	local player = Players.LocalPlayer
	local set = SOUNDS.sets[LevelUpRules.soundSet(SOUNDS, if player then player:GetAttribute("LevelSoundSet") else nil)]
	local spec = layer or set[part]
	local id, volume, pitch = spec.id, spec.volume, spec.pitch
	local picked = if player then player:GetAttribute("LevelSoundVolume") else nil
	if part == "sound" and typeof(picked) == "number" then
		volume = picked
	end
	if creature then
		volume *= SOUNDS.creature.volumeScale
		pitch *= SOUNDS.creature.pitch
	end
	if quiet then
		volume *= 0.5
	end
	local sound = SoundBank.make(id)
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	local holder: Instance = SoundService
	if at then
		local anchor = Instance.new("Attachment")
		anchor.Position = at -- Terrain sits at the origin, so this is the world position
		anchor.Parent = workspace.Terrain
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMaxDistance = LevelUpConfig.RANGE
		holder = anchor
	end
	sound.Parent = holder
	sound:Play()
	local cleanup: Instance = if holder ~= SoundService then holder else sound
	task.delay(SOUND_LIFETIME, function()
		cleanup:Destroy()
	end)
end

local function decal(part: BasePart, color: Color3): Decal
	local face = Instance.new("Decal")
	face.Face = Enum.NormalId.Top
	face.Texture = IMAGES.rune
	face.Color3 = color
	face.Transparency = 1
	face.Parent = part
	return face
end

local function flatPart(size: number, at: CFrame, folder: Instance): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(size, 0.05, size)
	part.CFrame = at
	part.Parent = folder
	return part
end

local function beam(a0: Attachment, a1: Attachment, color: ColorSequence, brightness: number, folder: Instance): Beam
	local light = Instance.new("Beam")
	light.Attachment0 = a0
	light.Attachment1 = a1
	light.Texture = IMAGES.beam
	light.TextureMode = Enum.TextureMode.Stretch
	light.Color = color
	light.LightEmission = 1
	light.LightInfluence = 0
	light.Brightness = brightness
	light.FaceCamera = true
	light.Segments = 1
	light.Width0, light.Width1 = 0, 0
	light.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.6, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	light.Parent = folder
	return light
end

-- A label filling its box, scaled (setting TextWrapped false afterwards would turn TextScaled off)
local function scaledLabel(parent: Instance, text: string, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = parent
	return label
end

local function stroke(label: TextLabel, color: Color3, thickness: number): UIStroke
	local edge = Instance.new("UIStroke")
	edge.Color = color
	edge.Thickness = thickness
	edge.LineJoinMode = Enum.LineJoinMode.Round
	edge.Parent = label
	return edge
end

-- 0 before `at` seconds, rising to 1 over `length` seconds
local function window(since: number, at: number, length: number): number
	return math.clamp((since - at) / length, 0, 1)
end

-- A pop's ease: a little past 1, then settles
local function backOut(x: number): number
	local p = x - 1
	return 1 + 2.70158 * p * p * p + 1.70158 * p * p
end

-- See-through `own`, faded further by `fade` (0 shown, 1 gone)
local function faded(own: number, fade: number): number
	return 1 - (1 - own) * (1 - fade)
end

-- The words' billboard over the one levelling up, `size` in studs, `height` studs over `adornee`: drawn in the world
-- (not on top), sure to show, and high enough to clear hats
local function billboard(adornee: BasePart, size: UDim2, height: number, folder: Instance): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Adornee = adornee
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Size = size
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = LevelUpConfig.RANGE * 1.5
	gui.ResetOnSpawn = false
	-- A BillboardGui is only drawn under a part, an attachment or PlayerGui (not in a workspace folder)
	local player = Players.LocalPlayer
	gui.Parent = if player then player:FindFirstChildOfClass("PlayerGui") or folder else folder
	return gui
end

-- A frame of the chip: `round` makes it a pill (or a circle)
local function chipFrame(parent: Instance, color: Color3, position: UDim2, size: UDim2, z: number, round: boolean): Frame
	local made = Instance.new("Frame")
	made.BackgroundColor3 = color
	made.BorderSizePixel = 0
	made.Position = position
	made.Size = size
	made.ZIndex = z
	made.Parent = parent
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = made
	end
	return made
end

-- A creature's level chip (Config/LevelUpFx CHIP; owner 2026-11-17, mockup B): a gold LEVEL UP! tab on a white pill
-- edged in its element's colour, its element's icon, the old level muted, three arrows lighting one after another,
-- then the new level popping in big and gold, a shine across it, "+1" floating up and two sparkles. Returns the gui and
-- its animation: `since` seconds since it popped, `fade` 0 shown to 1 gone (it rises as it fades)
local function levelChip(adornee: BasePart, height: number, from: number, to: number, element: string, folder: Instance): (BillboardGui, (since: number, fade: number) -> ())
	local CHIP = LevelUpConfig.CHIP
	local shades = UIStyle.BABY[BabyColors.ELEMENTS[element] or "butter"]
	local gui = billboard(adornee, UDim2.new(CHIP.size[1], 0, CHIP.size[2], 0), height, folder)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global -- its pieces layer by ZIndex (the tab's foot behind the pill)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = holder

	-- The gold tab on top, its foot tucked behind the pill
	local tab = chipFrame(holder, WHITE, UDim2.fromScale(0.5, 0), UDim2.fromScale(0.44, 0.36), 1, false)
	tab.AnchorPoint = Vector2.new(0.5, 0)
	local tabCorner = Instance.new("UICorner")
	tabCorner.CornerRadius = UDim.new(0.3, 0)
	tabCorner.Parent = tab
	local tabGold = Instance.new("UIGradient")
	tabGold.Rotation = 90
	tabGold.Color = ColorSequence.new(Color3.fromRGB(255, 214, 90), Color3.fromRGB(255, 138, 60))
	tabGold.Parent = tab
	local tabText = scaledLabel(tab, "LEVEL UP!", WHITE)
	tabText.Position = UDim2.fromScale(0.08, 0.1)
	tabText.Size = UDim2.fromScale(0.84, 0.52)
	tabText.ZIndex = 2
	local tabEdge = stroke(tabText, DROP, 1.5)

	-- The pill: a shadow in the element's deep shade under its colour, a white middle `edge` studs in
	local pillTop, pillHeight = 0.28, 0.68
	local shadow = chipFrame(holder, shades.deep, UDim2.fromScale(0, pillTop + 0.06), UDim2.fromScale(1, pillHeight), 3, true)
	local edge = chipFrame(holder, shades.fill, UDim2.fromScale(0, pillTop), UDim2.fromScale(1, pillHeight), 4, true)
	local edgeX = CHIP.edge / CHIP.size[1]
	local edgeY = CHIP.edge / (CHIP.size[2] * pillHeight)
	local inner = chipFrame(edge, WHITE, UDim2.fromScale(edgeX, edgeY), UDim2.fromScale(1 - 2 * edgeX, 1 - 2 * edgeY), 5, true)
	-- the element's icon on a soft circle of its colour
	local circle = chipFrame(inner, shades.light, UDim2.fromScale(0.018, 0.5), UDim2.fromScale(0.82, 0.82), 6, true)
	circle.AnchorPoint = Vector2.new(0, 0.5)
	circle.SizeConstraint = Enum.SizeConstraint.RelativeYY
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Image = (UIIcons :: any)[element] or ""
	icon.ScaleType = Enum.ScaleType.Fit
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.74, 0.74)
	icon.ZIndex = 7
	icon.Parent = circle
	local fromText = scaledLabel(inner, `Lv {from}`, UIStyle.BABY.greyLilac.deep)
	fromText.Position = UDim2.fromScale(0.205, 0.2)
	fromText.Size = UDim2.fromScale(0.18, 0.6)
	fromText.ZIndex = 7
	local arrows: { TextLabel } = {}
	for index = 1, 3 do
		local arrow = scaledLabel(inner, ">", shades.deep)
		arrow.Position = UDim2.fromScale(0.39 + (index - 1) * 0.05, 0.16)
		arrow.Size = UDim2.fromScale(0.05, 0.68)
		arrow.ZIndex = 7
		table.insert(arrows, arrow)
	end
	local toText = scaledLabel(inner, `Lv {to}`, WHITE)
	toText.Position = UDim2.fromScale(0.545, 0.04)
	toText.Size = UDim2.fromScale(0.42, 0.92)
	toText.ZIndex = 7
	local toGold = Instance.new("UIGradient")
	toGold.Rotation = 90
	toGold.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 243, 160)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 201, 63)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 138, 60)),
	})
	toGold.Parent = toText
	local toEdge = stroke(toText, DROP, 2)
	local toScale = Instance.new("UIScale")
	toScale.Scale = 0
	toScale.Parent = toText
	-- the shine: a white band on a copy of the middle's shape, swept across once
	local shine = chipFrame(inner, WHITE, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 8, true)
	shine.BackgroundTransparency = 1
	local band = Instance.new("UIGradient")
	band.Rotation = 20
	band.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	band.Parent = shine

	-- "+1" floating up by the new level, and two sparkles at its ends
	local plus = scaledLabel(holder, "+1", WHITE)
	plus.AnchorPoint = Vector2.new(0.5, 1)
	plus.Size = UDim2.fromScale(0.16, 0.34)
	plus.ZIndex = 9
	local plusEdge = stroke(plus, shades.deep, 2)
	local sparkles: { { image: ImageLabel, scale: UIScale } } = {}
	for index, spot in { { 0.03, 0.42 }, { 0.98, 0.3 } } do
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = IMAGES.mote
		image.ImageColor3 = if index == 1 then Color3.fromRGB(255, 220, 110) else WHITE
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(spot[1], spot[2])
		image.Size = UDim2.fromScale(0.42, 0.42)
		image.SizeConstraint = Enum.SizeConstraint.RelativeYY
		image.ZIndex = 9
		image.Parent = holder
		local twinkle = Instance.new("UIScale")
		twinkle.Scale = 0
		twinkle.Parent = image
		table.insert(sparkles, { image = image, scale = twinkle })
	end

	return gui, function(since: number, fade: number)
		scale.Scale = backOut(window(since, 0, 0.45))
		for _, piece in { shadow, edge, inner, circle } do
			piece.BackgroundTransparency = fade
		end
		icon.ImageTransparency = fade
		fromText.TextTransparency = fade
		-- the tab drops into place
		local tabIn = window(since, 0.08, 0.3)
		tab.Position = UDim2.fromScale(0.5, 0.14 * (1 - backOut(tabIn)))
		tab.BackgroundTransparency = faded(1 - tabIn, fade)
		tabText.TextTransparency = tab.BackgroundTransparency
		tabEdge.Transparency = tab.BackgroundTransparency
		-- the arrows light one after another, then breathe
		for index, arrow in arrows do
			local lit = window(since, CHIP.arrows[index], 0.15)
			local breathe = if since > CHIP.newLevel + 0.5 then 0.3 * (0.5 + 0.5 * math.sin((since - CHIP.newLevel) * 5 - index)) else 0
			arrow.TextTransparency = faded(0.82 * (1 - lit) + breathe * lit, fade)
		end
		-- the new level pops in
		toScale.Scale = backOut(window(since, CHIP.newLevel, 0.45))
		toText.TextTransparency = faded(1 - window(since, CHIP.newLevel, 0.1), fade)
		toEdge.Transparency = toText.TextTransparency
		-- "+1" floats up and away
		local up = window(since, CHIP.plus, 1.1)
		plus.Position = UDim2.fromScale(0.86, 0.36 - 0.36 * up)
		local plusSee = if up <= 0 or up >= 1 then 1 elseif up < 0.2 then 1 - up / 0.2 else (up - 0.2) / 0.8
		plus.TextTransparency = faded(plusSee, fade)
		plusEdge.Transparency = plus.TextTransparency
		-- the shine sweeps across once
		local sweep = window(since, CHIP.shine, CHIP.shineSeconds)
		band.Offset = Vector2.new(-1.1 + 2.2 * sweep, 0)
		shine.BackgroundTransparency = if sweep <= 0 or sweep >= 1 then 1 else fade
		-- the sparkles twinkle
		for index, sparkle in sparkles do
			local twinkle = window(since, CHIP.sparkles[index], 0.7)
			sparkle.scale.Scale = math.sin(twinkle * math.pi) * 1.15
			sparkle.image.Rotation = twinkle * 90
			sparkle.image.ImageTransparency = fade
		end
		gui.StudsOffset = Vector3.new(0, height + CHIP.rise * fade, 0)
	end
end

-- A shop level-up's words: the star badge with the number rolling up and "LEVEL UP!" under it, and on a 10th level a
-- pack flying out with "+1 pack". Returns the gui and its animation: `since` seconds since it popped, `fade` 0 shown
-- to 1 gone
local function starBadge(adornee: BasePart, height: number, from: number, to: number, milestone: boolean, folder: Instance): (BillboardGui, (since: number, fade: number) -> ())
	local gui = billboard(adornee, UDim2.new(6, 0, 4.6, 0), height, folder)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = holder
	local fades: { (number) -> () } = {}
	local star = Instance.new("ImageLabel")
	star.BackgroundTransparency = 1
	star.Image = UIIcons.Star
	star.ScaleType = Enum.ScaleType.Fit
	star.AnchorPoint = Vector2.new(0.5, 0)
	star.Position = UDim2.fromScale(0.5, 0)
	star.Size = UDim2.fromScale(0.5, 0.62)
	star.Parent = holder
	local number = scaledLabel(star, tostring(from), WHITE)
	number.Position = UDim2.fromScale(0.2, 0.3)
	number.Size = UDim2.fromScale(0.6, 0.42)
	local numberEdge = stroke(number, DROP, 2.5)
	local words = scaledLabel(holder, "LEVEL UP!", WHITE)
	words.AnchorPoint = Vector2.new(0.5, 0)
	words.Position = UDim2.fromScale(0.5, 0.64)
	words.Size = UDim2.fromScale(0.96, 0.3)
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 243, 160)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 201, 63)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 138, 60)),
	})
	fill.Parent = words
	local wordsEdge = stroke(words, WHITE, 3)
	table.insert(fades, function(f)
		star.ImageTransparency = f
		number.TextTransparency = f
		numberEdge.Transparency = f
		words.TextTransparency = f
		wordsEdge.Transparency = f
	end)
	if milestone then
		-- Every 10th level: a pack flies out to the side with "+1 pack"
		local pack = Instance.new("ImageLabel")
		pack.BackgroundTransparency = 1
		pack.Image = UIIcons.BoosterPack
		pack.ScaleType = Enum.ScaleType.Fit
		pack.AnchorPoint = Vector2.new(0.5, 0.5)
		pack.Position = UDim2.fromScale(0.5, 0.4)
		pack.Size = UDim2.fromScale(0.22, 0.3)
		pack.ImageTransparency = 1
		pack.Parent = holder
		local plus = scaledLabel(pack, "+1 pack", WHITE)
		plus.AnchorPoint = Vector2.new(0.5, 0)
		plus.Position = UDim2.fromScale(0.5, 1)
		plus.Size = UDim2.fromScale(1.6, 0.4)
		plus.TextTransparency = 1
		local plusEdge = stroke(plus, INK, 2)
		plusEdge.Transparency = 1
		task.delay(T.badge - T.beam + 0.35, function()
			if not pack.Parent then
				return
			end
			local info = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			TweenService:Create(pack, info, { Position = UDim2.fromScale(0.9, 0.35), ImageTransparency = 0 }):Play()
			TweenService:Create(plus, info, { TextTransparency = 0 }):Play()
			TweenService:Create(plusEdge, info, { Transparency = 0 }):Play()
		end)
		table.insert(fades, function(f)
			if f > 0 then
				pack.ImageTransparency = f
				plus.TextTransparency = f
				plusEdge.Transparency = f
			end
		end)
	end
	return gui, function(since: number, fade: number)
		-- Pops in (a little over, then settles) and rolls the number
		local t = math.min(1, since / 0.35)
		scale.Scale = if t < 0.6 then 1.2 * (t / 0.6) else 1.2 - 0.2 * ((t - 0.6) / 0.4)
		number.Text = tostring(XpPill.countUp(from, to, math.clamp((t - 0.3) / 0.7, 0, 1)))
		for _, each in fades do
			each(fade)
		end
	end
end

-- The whole effect at `root` (the one levelling up) on `model`: one timeline drives the circle, the beams, the light and
-- the words, then everything is cleaned up
local function run(root: BasePart, model: Instance, sizes: Sizes, colors: Look, words: { from: number, to: number, creature: boolean, milestone: boolean, height: number, element: string? }, quiet: boolean, own: boolean)
	local folder = Instance.new("Folder")
	folder.Name = "LevelUpFx"
	folder.Parent = workspace
	local ground = groundUnder(root, model)
	local base = CFrame.new(ground + Vector3.new(0, GROUND_LIFT, 0))
	local outerPart = flatPart(sizes.rune, base, folder)
	local innerPart = flatPart(sizes.rune * 0.78, base + Vector3.new(0, 0.01, 0), folder)
	local outer = decal(outerPart, colors.runeOuter)
	local inner = decal(innerPart, colors.runeInner)
	local a0 = Instance.new("Attachment")
	a0.Parent = outerPart
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, sizes.beamHeight, 0)
	a1.Parent = outerPart
	local glow = beam(a0, a1, colors.glow, GLOW_BRIGHTNESS, folder)
	local core = beam(a0, a1, ColorSequence.new(WHITE), CORE_BRIGHTNESS, folder)
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = IMAGES.mote
	motes.Color = colors.mote
	motes.LightEmission = 1
	motes.LightInfluence = 0
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, sizes.core * 0.45), NumberSequenceKeypoint.new(1, 0) })
	motes.Transparency = NumberSequence.new(0.1)
	motes.Lifetime = NumberRange.new(1, 1.6)
	motes.Speed = NumberRange.new(sizes.beamHeight * 0.45, sizes.beamHeight * 0.7)
	motes.SpreadAngle = Vector2.new(12, 12)
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Rate = 26
	motes.RotSpeed = NumberRange.new(-120, 120)
	motes.Enabled = false
	motes.Parent = a0
	local light = Instance.new("PointLight")
	light.Color = colors.runeOuter:Lerp(WHITE, 0.4)
	light.Range = sizes.rune
	light.Brightness = 0
	light.Parent = root
	local creature = words.creature
	local CHIP = LevelUpConfig.CHIP
	local gui: BillboardGui
	local animate: (since: number, fade: number) -> ()
	if creature and words.element then
		gui, animate = levelChip(root, words.height, words.from, words.to, words.element, folder)
	else
		gui, animate = starBadge(root, words.height, words.from, words.to, words.milestone, folder)
	end
	-- a creature's chip stays up after the pillar has gone (Config/LevelUpFx CHIP)
	local ends = if creature then math.max(T.done, T.badge + CHIP.hold + CHIP.fade) else T.done
	local soundAt = if own then nil else root.Position

	task.delay(T.badge, function()
		play("sound", soundAt, quiet, creature)
		if words.milestone and not creature then
			play("sting", soundAt, quiet, false)
		end
	end)
	-- the set's layers round the pop (a rise winding up before it, a shimmer after: Config/LevelUpFx SOUNDS)
	local player = Players.LocalPlayer
	local set = SOUNDS.sets[LevelUpRules.soundSet(SOUNDS, if player then player:GetAttribute("LevelSoundSet") else nil)]
	for _, layer in set.layers or {} do
		task.delay(math.max(0, T.badge + layer.at), play, "sound", soundAt, quiet, creature, layer)
	end

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= ends or not root.Parent then
			connection:Disconnect()
			folder:Destroy()
			gui:Destroy()
			light:Destroy()
			return
		end
		-- The circle: fades in over 0.3 s, spins all the time, fades out from `fade`
		local shown = if t < 0.3 then t / 0.3 elseif t > T.fade then math.max(0, 1 - (t - T.fade) / (T.done - T.fade)) else 1
		outer.Transparency = 1 - 0.95 * shown
		inner.Transparency = 1 - 0.8 * shown
		outerPart.CFrame = base * CFrame.Angles(0, t * SPIN_SPEED, 0)
		innerPart.CFrame = (base + Vector3.new(0, 0.01, 0)) * CFrame.Angles(0, -t * SPIN_SPEED * 1.4, 0)
		-- The pillar: shoots up at `beam` (a little wide, then settles), thins to nothing from `fade`
		local open = if t < T.beam then 0 elseif t < T.beam + 0.15 then 1.15 * (t - T.beam) / 0.15 elseif t < T.beam + 0.3 then 1.15 - 0.15 * (t - T.beam - 0.15) / 0.15 else 1
		if t > T.fade then
			open *= math.max(0, 1 - (t - T.fade) / (T.done - T.fade - 0.4))
		end
		glow.Width0, glow.Width1 = sizes.beamWidth * open, sizes.beamWidth * open * 0.8
		core.Width0, core.Width1 = sizes.core * open, sizes.core * open * 0.6
		a1.Position = Vector3.new(0, sizes.beamHeight * math.min(1, if t < T.beam then 0 else (t - T.beam) / 0.18), 0)
		motes.Enabled = t >= T.beam and t < T.fade
		-- The one levelling up lights for a moment as the beam hits
		local flash = if t < T.beam then 0 else math.max(0, 1 - (t - T.beam) / 0.6)
		light.Brightness = 5 * flash
		-- The words pop at `badge` and fade with the rest
		if t >= T.badge then
			local fade = if creature then window(t, T.badge + CHIP.hold, CHIP.fade)
				elseif t > T.fade + 0.6 then math.min(1, (t - T.fade - 0.6) / (T.done - T.fade - 0.6))
				else 0
			animate(t - T.badge, fade)
		end
		gui.Enabled = t >= T.badge
	end)
end

-- A shop level-up on a character (from -> to); `milestone` for a 10th level; `quiet` for someone else's
function LevelUpFx.playShop(character: Model, from: number, to: number, milestone: boolean, quiet: boolean)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end
	local own = Players.LocalPlayer ~= nil and character == Players.LocalPlayer.Character
	run(root, character, LevelUpConfig.SIZES.shop, look(milestone, nil), { from = from, to = to, creature = false, milestone = milestone, height = BADGE_HEIGHT }, quiet, own)
end

-- A creature's level-up on its drawn model's root (`height` studs tall), in its element's colour
function LevelUpFx.playCreature(root: BasePart, height: number, element: string, from: number, to: number, quiet: boolean)
	if not root.Parent then
		return
	end
	local model = root:FindFirstAncestorOfClass("Model") or root
	-- its chip's middle over its head, clear of its top (its name tag hides meanwhile: LevelUpController)
	local chipHeight = height + LevelUpConfig.CHIP.size[2] / 2 + 0.4
	run(root, model, LevelUpConfig.SIZES.creature, look(false, element), { from = from, to = to, creature = true, milestone = false, height = chipHeight, element = element }, quiet, not quiet)
	-- it glows for a while (owner 2026-11-16: "it should be noticeable. pets should glow for some time")
	local glowLook = LevelUpConfig.CREATURE_GLOW
	local glow = Instance.new("Highlight")
	glow.Name = "LevelUpGlow"
	glow.Adornee = model
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.FillColor = Color3.fromRGB(glowLook.fill[1], glowLook.fill[2], glowLook.fill[3])
	glow.OutlineColor = Color3.fromRGB(glowLook.outline[1], glowLook.outline[2], glowLook.outline[3])
	glow.Parent = model
	local started = os.clock()
	local glowing: RBXScriptConnection
	glowing = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= glowLook.seconds or not model.Parent then
			glowing:Disconnect()
			glow:Destroy()
			return
		end
		local wave = 0.5 + 0.5 * math.cos(t * glowLook.pulseSpeed * math.pi * 2)
		local fade = math.clamp((glowLook.seconds - t) / glowLook.fade, 0, 1)
		glow.FillTransparency = 1 - (1 - (glowLook.low + (glowLook.high - glowLook.low) * (1 - wave))) * fade
		glow.OutlineTransparency = 1 - fade
	end)
end

return LevelUpFx
