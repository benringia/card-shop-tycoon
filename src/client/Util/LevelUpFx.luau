--!strict
-- The level-up light pillar (spec 2026-11-04-round4-design section 9; owner's pick 2026-11-04, "pillar and spinning
-- circle is enough"): a spinning rune circle opens on the ground, a pillar of light (a white core in a coloured glow,
-- motes rising in it) shoots up and the one levelling up lights for a moment, then a star badge pops with the number
-- rolling up and "LEVEL UP!" under it; the beam thins and the circle fades. Every 10th level the pillar is the five
-- baby colours and a pack flies out ("+1 pack"). A creature gets a smaller pillar in its element's colour and a
-- "Lv 19 -> 20" chip. Numbers, textures and sounds: Config/LevelUpFx. Played by LevelUpController.
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
local function play(part: "sound" | "sting", at: Vector3?, quiet: boolean, creature: boolean)
	local player = Players.LocalPlayer
	local set = SOUNDS.sets[LevelUpRules.soundSet(SOUNDS, if player then player:GetAttribute("LevelSoundSet") else nil)]
	local spec = set[part]
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

-- The words over the one levelling up: the star badge with the rolling number and "LEVEL UP!" (a shop), or a white
-- chip "Lv 19 -> 20" (a creature). Returns the gui, its pop scale and a setter for its fade (0 shown, 1 gone).
local function badge(adornee: BasePart, height: number, from: number, to: number, creature: boolean, milestone: boolean, folder: Instance): (BillboardGui, (t: number) -> (), (fade: number) -> ())
	local gui = Instance.new("BillboardGui")
	gui.Adornee = adornee
	-- Drawn in the world (not on top): sure to show, and placed high enough to clear hats
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Size = if creature then UDim2.new(4.2, 0, 1.2, 0) else UDim2.new(6, 0, 4.6, 0)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = LevelUpConfig.RANGE * 1.5
	gui.ResetOnSpawn = false
	-- A BillboardGui is only drawn under a part, an attachment or PlayerGui (not in a workspace folder)
	local player = Players.LocalPlayer
	gui.Parent = if player then player:FindFirstChildOfClass("PlayerGui") or folder else folder
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = holder
	local fades: { (number) -> () } = {}
	local roll: (number) -> () = function() end
	if creature then
		local chip = Instance.new("Frame")
		chip.Size = UDim2.fromScale(1, 1)
		chip.BackgroundColor3 = WHITE
		chip.Parent = holder
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = chip
		local text = scaledLabel(chip, `Lv {from} -> {to}`, INK)
		text.Position = UDim2.fromScale(0.08, 0.15)
		text.Size = UDim2.fromScale(0.84, 0.7)
		table.insert(fades, function(f)
			chip.BackgroundTransparency = f
			text.TextTransparency = f
		end)
	else
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
		roll = function(t: number)
			number.Text = tostring(XpPill.countUp(from, to, t))
		end
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
	end
	local function setFade(f: number)
		for _, fade in fades do
			fade(f)
		end
	end
	-- Pops in (a little over, then settles) and rolls the number
	local function pop(t: number)
		scale.Scale = if t < 0.6 then 1.2 * (t / 0.6) else 1.2 - 0.2 * ((t - 0.6) / 0.4)
		roll(math.clamp((t - 0.3) / 0.7, 0, 1))
	end
	return gui, pop, setFade
end

-- The whole effect at `root` (the one levelling up) on `model`: one timeline drives the circle, the beams, the light and
-- the words, then everything is cleaned up
local function run(root: BasePart, model: Instance, sizes: Sizes, colors: Look, words: { from: number, to: number, creature: boolean, milestone: boolean, height: number }, quiet: boolean, own: boolean)
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
	local gui, pop, setFade = badge(root, words.height, words.from, words.to, words.creature, words.milestone, folder)
	local creature = words.creature
	local soundAt = if own then nil else root.Position

	task.delay(T.badge, function()
		play("sound", soundAt, quiet, creature)
		if words.milestone and not creature then
			play("sting", soundAt, quiet, false)
		end
	end)

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= T.done or not root.Parent then
			connection:Disconnect()
			folder:Destroy()
			gui:Destroy()
			light:Destroy()
			return
		end
		-- The circle: fades in over 0.3 s, spins all the time, fades out from `fade`
		local shown = if t < 0.3 then t / 0.3 elseif t > T.fade then 1 - (t - T.fade) / (T.done - T.fade) else 1
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
			pop(math.min(1, (t - T.badge) / 0.35))
			setFade(if t > T.fade + 0.6 then math.min(1, (t - T.fade - 0.6) / (T.done - T.fade - 0.6)) else 0)
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
	run(root, model, LevelUpConfig.SIZES.creature, look(false, element), { from = from, to = to, creature = true, milestone = false, height = height + 1.2 }, quiet, not quiet)
end

return LevelUpFx
