--!strict
-- A weapon's glow ladder drawn on its model (spec 2026-11-06-weapons-round1-design 5.1; rules in Util/WeaponLookRules,
-- numbers in Config/WeaponLooks): a Neon glow shell over its glowing parts (brighter with the first upgrades), one
-- aura of its element's particles (from +4), a light in hand (Epic and Legendary), the Grade S twinkle and the +10
-- Awakened effect. The Steel Sword keeps its plain look. SwordController builds the model, then calls apply once and
-- setPlace on every move between hand and back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AttackFx = require(Config:WaitForChild("AttackFx"))
local MoveFx = require(Config:WaitForChild("MoveFx"))
local WeaponLooks = require(Config:WaitForChild("WeaponLooks"))
local Weapons = require(Config:WaitForChild("Weapons"))
local WeaponLookRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponLookRules"))

local WeaponLook = {}

local STEEL, GOLD, LEATHER = Color3.fromRGB(204, 217, 235), Color3.fromRGB(235, 179, 71), Color3.fromRGB(92, 56, 36)

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function texture(key: string): string
	return (AttackFx.TEXTURES :: any)[key] or (MoveFx.TEXTURES :: any)[key] or ""
end

-- A drawn weapon's look entry; nil for the Steel Sword (its plain look) and unknown ids
local function lookOf(weaponId: string): WeaponLooks.Look?
	if weaponId == Weapons.STARTER then
		return nil
	end
	return WeaponLooks.WEAPONS[weaponId]
end

-- The particles' colour: the weapon's glow, or every element's in turn for the Prism Blade
local function particleColor(weaponId: string, look: WeaponLooks.Look): ColorSequence
	local weapon = Weapons.ById[weaponId]
	if not weapon or not weapon.prism then
		return ColorSequence.new(rgb(look.glow))
	end
	local keys = {}
	local order = { "Ember", "Volt", "Bloom", "Tide", "Shade" }
	for index, element in order do
		table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#order - 1), rgb(WeaponLooks.BY_ELEMENT[element].glow)))
	end
	return ColorSequence.new(keys)
end

-- The layers at this level, grade and place; nil for a weapon with no look of its own
function WeaponLook.layers(weaponId: string, grade: string, level: number, place: "hand" | "back"): WeaponLookRules.Layers?
	local weapon = Weapons.ById[weaponId]
	if not weapon or not lookOf(weaponId) then
		return nil
	end
	return WeaponLookRules.layers(WeaponLooks, weapon.rarity, level, grade, place)
end

-- The swing trail and hit colour of a weapon (nil: the moves' own, the Steel Sword's pale steel)
function WeaponLook.trailColor(weaponId: string): { number }?
	local look = lookOf(weaponId)
	return if look then look.trail else nil
end

-- A plain sword from parts, the size of the real models, for while WeaponModels has no model for it: steel and gold
-- for the Steel Sword, tinted with the weapon's glow otherwise (its blade glows)
function WeaponLook.standIn(weaponId: string): Model
	local look = lookOf(weaponId)
	local model = Instance.new("Model")
	model.Name = "StandInSword"
	local function part(name: string, shape: Enum.PartType, size: Vector3, y: number, color: Color3, material: Enum.Material): BasePart
		local made = Instance.new("Part")
		made.Name = name
		made.Shape = shape
		made.Size = size
		made.CFrame = CFrame.new(0, y, 0)
		made.Color = color
		made.Material = material
		made.Parent = model
		return made
	end
	local trim = if look then rgb(look.glow) else GOLD
	local steel = if look then STEEL:Lerp(rgb(look.glow), 0.35) else STEEL
	local grip = part("Handle", Enum.PartType.Cylinder, Vector3.new(0.9, 0.26, 0.26), 0, LEATHER, Enum.Material.SmoothPlastic)
	grip.CFrame = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder lies along X: stand it up
	part("Guard", Enum.PartType.Block, Vector3.new(1.25, 0.24, 0.34), 0.52, trim, Enum.Material.SmoothPlastic)
	local blade = part("Blade", Enum.PartType.Block, Vector3.new(0.5, 3.6, 0.13), 2.42, steel, Enum.Material.Metal)
	part("Pommel", Enum.PartType.Ball, Vector3.new(0.4, 0.4, 0.4), -0.62, trim, Enum.Material.SmoothPlastic)
	if look then
		blade:SetAttribute("Glow", true)
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "Grip"
	attachment.CFrame = grip.CFrame:Inverse() -- the grip's centre, blade up
	attachment.Parent = grip
	model.PrimaryPart = grip
	return model
end

local function emitter(name: string, parent: BasePart, textureKey: string, colors: ColorSequence): ParticleEmitter
	local made = Instance.new("ParticleEmitter")
	made.Name = name
	made.Texture = texture(textureKey)
	made.Color = colors
	made.LightEmission = 1
	made.Rate = 0
	made.Parent = parent
	return made
end

-- Adds the look to a fresh model (before it's welded: the shells are its parts too). The glowing parts get a shell:
-- its Blade when it has one (the made models: Blade, Guard, Grip), else every MeshPart, and a stand-in's Glow parts;
-- the effects go on the biggest of them.
function WeaponLook.apply(model: Model, weaponId: string, grade: string, level: number)
	local look = lookOf(weaponId)
	local layers = WeaponLook.layers(weaponId, grade, level, "hand")
	if not look or not layers then
		return
	end
	local glow = rgb(look.glow)
	local blade: BasePart? = nil
	local named = model:FindFirstChild("Blade", true)
	local onlyBlade = named ~= nil and named:IsA("MeshPart")
	for _, item in model:GetDescendants() do
		if not item:IsA("BasePart") or not (item:IsA("MeshPart") or item:GetAttribute("Glow") == true) then
			continue
		end
		if onlyBlade and item.Name ~= "Blade" then
			continue
		end
		local shell = item:Clone()
		shell:ClearAllChildren() -- no SurfaceAppearance, welds or attachments
		shell.Name = "GlowShell"
		shell.Size = item.Size * WeaponLooks.SHELL_SCALE
		shell.CFrame = item.CFrame
		shell.Material = Enum.Material.Neon
		shell.Color = glow
		shell.Transparency = 1 - layers.edge
		shell.CastShadow = false
		shell:SetAttribute("Glow", nil)
		if shell:IsA("MeshPart") then
			shell.TextureID = ""
		end
		shell.Parent = model
		if not blade or item.Size.Magnitude > blade.Size.Magnitude then
			blade = item
		end
	end
	if not blade then
		return
	end
	local colors = particleColor(weaponId, look)
	local auraLook = WeaponLooks.AURA[look.aura]
	if auraLook then
		local aura = emitter("Aura", blade, auraLook.texture, colors)
		aura.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, auraLook.size * 0.4),
			NumberSequenceKeypoint.new(0.3, auraLook.size),
			NumberSequenceKeypoint.new(1, 0),
		})
		aura.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.6, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		aura.LightEmission = 0.6
		aura.Lifetime = NumberRange.new(auraLook.lifetime[1], auraLook.lifetime[2])
		aura.Speed = NumberRange.new(auraLook.speed[1], auraLook.speed[2])
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Acceleration = Vector3.new(0, auraLook.rise, 0)
		aura.RotSpeed = NumberRange.new(-90, 90)
	end
	if layers.twinkle then
		local spec = WeaponLooks.TWINKLE
		local twinkle = emitter("Twinkle", blade, spec.texture, ColorSequence.new(Color3.new(1, 1, 1), glow))
		twinkle.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.4, spec.size),
			NumberSequenceKeypoint.new(1, 0),
		})
		twinkle.Lifetime = NumberRange.new(spec.lifetime)
		twinkle.Speed = NumberRange.new(0)
		twinkle.RotSpeed = NumberRange.new(120)
	end
	local awakenedLook = if layers.awakened then WeaponLooks.AWAKENED[look.awakened] else nil
	if awakenedLook then
		local awakened = emitter("Awakened", blade, awakenedLook.texture, colors)
		awakened.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, awakenedLook.size),
			NumberSequenceKeypoint.new(1, awakenedLook.size * 0.6),
		})
		awakened.Transparency = NumberSequence.new(0.2, 1)
		awakened.Lifetime = NumberRange.new(awakenedLook.lifetime)
		awakened.Speed = NumberRange.new(0)
		awakened.LockedToPart = true
		awakened.RotSpeed = NumberRange.new(awakenedLook.spin)
		awakened.Rotation = NumberRange.new(0, 360)
	end
	local light = Instance.new("PointLight")
	light.Name = "WeaponLight"
	light.Color = glow
	light.Range = WeaponLooks.LIGHT_LOOK.range
	light.Brightness = WeaponLooks.LIGHT_LOOK.brightness
	light.Enabled = false
	light.Parent = blade
end

-- In hand or on the back: the aura's rate (fewer on the back), the twinkle and Awakened's, the light (hand only)
function WeaponLook.setPlace(model: Model, weaponId: string, grade: string, level: number, place: "hand" | "back")
	local layers = WeaponLook.layers(weaponId, grade, level, place)
	if not layers then
		return
	end
	local share = if place == "back" then WeaponLooks.BACK.auraShare else 1
	for _, item in model:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			if item.Name == "Aura" then
				item.Rate = layers.aura
			elseif item.Name == "Twinkle" then
				item.Rate = WeaponLooks.TWINKLE.rate * share
			elseif item.Name == "Awakened" then
				local awakenedLook = WeaponLooks.AWAKENED[(lookOf(weaponId) :: WeaponLooks.Look).awakened]
				item.Rate = if awakenedLook then awakenedLook.rate * share else 0
			end
		elseif item:IsA("PointLight") and item.Name == "WeaponLight" then
			item.Enabled = layers.light
		end
	end
end

return WeaponLook
