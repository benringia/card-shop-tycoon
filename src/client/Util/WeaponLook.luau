--!strict
-- A weapon's glow drawn on its model (owner 2026-11-06: an aura like the reference picture, hybrid for performance;
-- rules in Util/WeaponLookRules, numbers in Config/WeaponLooks):
-- - the inner glow: the model's baked glow map (its "Glow" SurfaceAppearances, tools/weapons/add_glow_maps) lit by
--   level, so the painted runes, gems and crystal shine;
-- - the full aura: flames, core, smoke and sparks filling the weapon in its element's colours, thicker with upgrades,
--   ribbons streaming off it at +10;
-- - the cheap glow: sparkles a second (creature-style) and a light (Epic and Legendary).
-- The full aura shows only when SwordController's budget says so (setDetail); the rest stays cheap. The Steel Sword
-- keeps its plain look. SwordController builds the model, then calls apply once, setPlace on every move between hand
-- and back, and setDetail when the budget changes; the reveals call apply and setPlace (always full).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AttackFx = require(Config:WaitForChild("AttackFx"))
local Combat = require(Config:WaitForChild("Combat"))
local WeaponLooks = require(Config:WaitForChild("WeaponLooks"))
local Weapons = require(Config:WaitForChild("Weapons"))
local WeaponLookRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponLookRules"))
local WeaponRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponRules"))
local PackEmitter = require((script.Parent :: Instance):WaitForChild("PackEmitter"))

local WeaponLook = {}

local STEEL, GOLD, LEATHER = Color3.fromRGB(204, 217, 235), Color3.fromRGB(235, 179, 71), Color3.fromRGB(92, 56, 36)
local WHITE = Color3.new(1, 1, 1)
local PRISM_ORDER = { "Ember", "Volt", "Bloom", "Tide", "Shade" }

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function texture(key: string): string
	return (AttackFx.TEXTURES :: any)[key] or ""
end

local function sizes(points: { number }): NumberSequence
	if #points == 2 then
		return NumberSequence.new(points[1], points[2])
	end
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, points[1]),
		NumberSequenceKeypoint.new(0.35, points[2]),
		NumberSequenceKeypoint.new(1, points[3]),
	})
end

-- Fades in, holds at `peak`, fades out
local function fade(peak: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, peak),
		NumberSequenceKeypoint.new(0.7, math.min(1, peak + 0.25)),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- A drawn weapon's look entry; nil for the Steel Sword (its plain look) and unknown ids
local function lookOf(weaponId: string): WeaponLooks.Look?
	if weaponId == Weapons.STARTER then
		return nil
	end
	return WeaponLooks.WEAPONS[weaponId]
end

-- The layers at this level, grade and place; nil for a weapon with no look of its own
function WeaponLook.layers(weaponId: string, grade: string, level: number, place: "hand" | "back"): WeaponLookRules.Layers?
	local weapon = Weapons.ById[weaponId]
	if not weapon or not lookOf(weaponId) then
		return nil
	end
	return WeaponLookRules.layers(WeaponLooks, weapon.rarity, level, grade, place)
end

-- The swing trail and hit colour of a weapon (nil: the moves' own, the Steel Sword's pale steel). In a fight the Prism
-- Blade takes the colour of the element strong against the foe (spec 3.4: the element its hits count as,
-- WeaponRules.hitElement)
function WeaponLook.trailColor(weaponId: string, foeElement: string?): { number }?
	local look = lookOf(weaponId)
	if not look then
		return nil
	end
	local weapon = Weapons.ById[weaponId]
	local hit = if weapon and weapon.prism and foeElement then WeaponRules.hitElement(Weapons, weaponId, foeElement, Combat) else nil
	local strong = if hit then WeaponLooks.BY_ELEMENT[hit] else nil
	return if strong then strong.trail else look.trail
end

-- A plain sword from parts, the size of the real models, for while WeaponModels has no model for it: steel and gold
-- for the Steel Sword, tinted with the weapon's glow otherwise
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
	blade:SetAttribute("Glow", true)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Grip"
	attachment.CFrame = grip.CFrame:Inverse() -- the grip's centre, blade up
	attachment.Parent = grip
	model.PrimaryPart = grip
	return model
end

-- One aura emitter: fills its part's box, its rate kept as an attribute (setPlace scales it by the aura's density)
local function auraEmitter(parent: BasePart, kind: string, rate: number, colors: ColorSequence): ParticleEmitter
	local spec = (WeaponLooks.AURA :: any)[kind]
	local made = Instance.new("ParticleEmitter")
	made.Name = "Aura"
	made:SetAttribute("Kind", kind)
	made:SetAttribute("FullRate", rate)
	made.Texture = texture(spec.texture)
	made.Shape = Enum.ParticleEmitterShape.Box
	made.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	made.Color = colors
	made.LightEmission = spec.emission or 1
	made.LightInfluence = 0
	made.Brightness = spec.brightness
	made.Lifetime = NumberRange.new(spec.lifetime[1], spec.lifetime[2])
	made.Speed = if spec.speed then NumberRange.new(spec.speed[1], spec.speed[2]) else NumberRange.new(0)
	made.Rate = 0
	made.Enabled = false
	made.LockedToPart = true -- the glow sticks to the sword: no trail left behind as you walk (owner 2026-11-06)
	if kind == "flame" or kind == "smoke" then
		made.Acceleration = Vector3.new(0, spec.rise, 0)
		made.Drag = spec.drag or 1
		made.Rotation = NumberRange.new(-30, 30)
		made.RotSpeed = NumberRange.new(-50, 50)
		made.Size = sizes(spec.size)
		made.Transparency = fade(spec.transparency)
	elseif kind == "core" then
		made.Size = sizes(spec.size)
		made.Transparency = fade(spec.transparency)
	elseif kind == "spark" then
		made.SpreadAngle = Vector2.new(180, 180)
		made.Acceleration = Vector3.new(0, 1, 0)
		made.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, spec.size * 0.7),
			NumberSequenceKeypoint.new(0.5, spec.size),
			NumberSequenceKeypoint.new(1, 0),
		})
		made.Transparency = NumberSequence.new(0, 1)
	elseif kind == "ribbon" then
		-- Streaks flung off the blade, stretched along their flight (the reference's streaming flames)
		made.Orientation = Enum.ParticleOrientation.VelocityParallel
		made.SpreadAngle = Vector2.new(70, 70)
		made.Acceleration = Vector3.new(0, 2, 0)
		made.Drag = 1
		made.Size = sizes(spec.size)
		made.Transparency = fade(spec.transparency)
	end
	made.Parent = parent
	return made
end

-- The aura's colours: deep to bright for the flames (the Prism Blade: one flame emitter per element), its core and
-- sparks bright, its smoke deep. Ember, Tide and Bloom weapons wear their pack aura (Config/WeaponLooks ELEMENT_AURA)
-- in place of the flames, core and smoke: each emitter an "Aura" of kind "element" filling the part's box, its rate
-- scaled by setPlace like the flames', thinner at low grades for an aura with `byGrade`, sizes `otherScale` on the
-- guard and grip (`blade`: the part carrying the aura at full rate)
local function auraEmitters(parent: BasePart, share: number, weaponId: string, look: WeaponLooks.Look, grade: string, blade: boolean)
	local deep, glow = rgb(look.deep), rgb(look.glow)
	local weapon = Weapons.ById[weaponId]
	local aura = WeaponLooks.AURA :: any
	local style = WeaponLookRules.auraStyle(WeaponLooks, if weapon then weapon.element else nil, if weapon then weapon.prism else nil)
	if style then
		local pack = (WeaponLooks.ELEMENT_AURA :: any)[style]
		local strength = WeaponLookRules.auraGrade(WeaponLooks, style, grade)
		for _, spec in pack.emitters do
			local made = PackEmitter.make(spec, if blade then 1 else pack.otherScale or 1, deep)
			made.Name = "Aura"
			made:SetAttribute("Kind", "element")
			made:SetAttribute("FullRate", spec.rate * share * strength)
			made:SetAttribute("BaseZ", made.ZOffset) -- drawPastBody moves it nearer while the wearer's body hides it
			made.Enabled = false
			made.LockedToPart = true -- the glow sticks to the weapon: no trail left behind as you walk
			made.Parent = parent
		end
		if pack.sparks then
			auraEmitter(parent, "spark", aura.spark.rate * share, ColorSequence.new(WHITE, glow))
		end
		return
	end
	if weapon and weapon.prism then
		for _, element in PRISM_ORDER do
			local colors = WeaponLooks.BY_ELEMENT[element]
			auraEmitter(parent, "flame", aura.flame.rate * share / #PRISM_ORDER, ColorSequence.new(rgb(colors.deep), rgb(colors.glow)))
		end
	else
		auraEmitter(parent, "flame", aura.flame.rate * share, ColorSequence.new(deep, glow))
	end
	auraEmitter(parent, "core", aura.core.rate * share, ColorSequence.new(glow:Lerp(WHITE, 0.4), glow))
	auraEmitter(parent, "smoke", aura.smoke.rate * share, ColorSequence.new(deep))
	auraEmitter(parent, "spark", aura.spark.rate * share, ColorSequence.new(WHITE, glow))
end

-- Adds the look to a fresh model (before it's welded): the aura's emitters on its glowing parts (a made model's
-- MeshParts, the Blade at full rate; a stand-in's Glow parts), the ribbons, the cheap sparkles and the light on the
-- blade. Nothing shows until setPlace.
function WeaponLook.apply(model: Model, weaponId: string, grade: string, level: number)
	local look = lookOf(weaponId)
	if not look or not WeaponLook.layers(weaponId, grade, level, "hand") then
		return
	end
	local glow = rgb(look.glow)
	local blade: BasePart? = nil
	for _, item in model:GetDescendants() do
		if not item:IsA("BasePart") or not (item:IsA("MeshPart") or item:GetAttribute("Glow") == true) then
			continue
		end
		local isBlade = item.Name == "Blade" or item.Name == "Head" -- a spear's head carries its aura
		auraEmitters(item, if isBlade then 1 else WeaponLooks.AURA.otherParts, weaponId, look, grade, isBlade)
		if isBlade or not blade then
			blade = item
		end
	end
	if not blade then
		return
	end
	local ribbonSpec = WeaponLooks.AURA.ribbon
	local ribbon = auraEmitter(blade, "ribbon", ribbonSpec.rate, ColorSequence.new(glow:Lerp(WHITE, 0.3), rgb(look.deep)))
	ribbon.Name = "Ribbons"
	local sparkleSpec = WeaponLooks.SPARKLE_LOOK
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Texture = texture(sparkleSpec.texture)
	sparkles.Shape = Enum.ParticleEmitterShape.Box
	sparkles.Color = ColorSequence.new(WHITE, glow)
	sparkles.LightEmission = 1
	sparkles.LightInfluence = 0
	sparkles.Brightness = sparkleSpec.brightness
	sparkles.Lifetime = NumberRange.new(sparkleSpec.lifetime[1], sparkleSpec.lifetime[2])
	sparkles.Speed = NumberRange.new(sparkleSpec.speed[1], sparkleSpec.speed[2])
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, sparkleSpec.size),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Rate = 0
	sparkles.LockedToPart = true
	sparkles.Parent = blade
	local light = Instance.new("PointLight")
	light.Name = "WeaponLight"
	light.Color = glow
	light.Range = WeaponLooks.LIGHT_LOOK.range
	light.Enabled = false
	light.Parent = blade
	model:SetAttribute("FullAura", true) -- the reveals' stage models stay full; SwordController's budget changes it
end

-- `sequence` with every size times `factor`
local function scaledSize(sequence: NumberSequence, factor: number): NumberSequence
	local points = {}
	for _, point in sequence.Keypoints do
		table.insert(points, NumberSequenceKeypoint.new(point.Time, point.Value * factor, point.Envelope * factor))
	end
	return NumberSequence.new(points)
end

-- Shows what the model's layers and detail call for (setPlace stores the layers on the model)
local function refresh(model: Model)
	local full = model:GetAttribute("FullAura") == true
	local density = ((model:GetAttribute("AuraDensity") :: number?) or 0) * ((model:GetAttribute("AuraShare") :: number?) or 1)
	local size = (model:GetAttribute("AuraSize") :: number?) or 1
	local ribbons = model:GetAttribute("Ribbons") == true
	local sparkles = (model:GetAttribute("SparkleRate") :: number?) or 0
	for _, item in model:GetDescendants() do
		if not item:IsA("ParticleEmitter") then
			continue
		end
		if item.Name == "Aura" then
			item.Rate = ((item:GetAttribute("FullRate") :: number?) or 0) * density
			item.Enabled = full and density > 0
			-- smaller on the back (its full size kept the first time, then scaled from it)
			local base = item:GetAttribute("BaseSize")
			if typeof(base) ~= "NumberSequence" then
				base = item.Size
				item:SetAttribute("BaseSize", base)
			end
			item.Size = scaledSize(base :: NumberSequence, size)
		elseif item.Name == "Ribbons" then
			item.Rate = WeaponLooks.AURA.ribbon.rate
			item.Enabled = full and ribbons
		elseif item.Name == "Sparkles" then
			-- The cheap glow's sparkles, unless the full aura (with its own sparks) is on
			item.Rate = sparkles
			item.Enabled = not (full and density > 0)
		end
	end
end

-- In hand or on the back: the inner glow, the aura's density (less on the back), the ribbons, sparkles and light
function WeaponLook.setPlace(model: Model, weaponId: string, grade: string, level: number, place: "hand" | "back")
	local look = lookOf(weaponId)
	local layers = WeaponLook.layers(weaponId, grade, level, place)
	if not look or not layers then
		return
	end
	local glow = rgb(look.glow)
	model:SetAttribute("AuraDensity", layers.aura)
	model:SetAttribute("AuraSize", layers.auraSize)
	model:SetAttribute("Ribbons", layers.ribbons)
	model:SetAttribute("SparkleRate", layers.sparkles)
	for _, item in model:GetDescendants() do
		if item:IsA("SurfaceAppearance") and item.Name == "Glow" then
			item.EmissiveStrength = WeaponLooks.INNER.strength * layers.edge
			item.EmissiveTint = glow
		elseif item:IsA("PointLight") and item.Name == "WeaponLight" then
			item.Enabled = layers.light
			item.Brightness = WeaponLooks.LIGHT_LOOK.brightness * math.max(layers.edge, 0.5)
		end
	end
	refresh(model)
end

-- A model's parts wearing pack aura layers, with those layers (found once per model) and whether the body hid them
type PackPart = { part: BasePart, emitters: { ParticleEmitter }, hidden: boolean }
local packParts: { [Model]: { PackPart } } = setmetatable({}, { __mode = "k" }) :: any

local function packPartsOf(model: Model): { PackPart }
	local found = packParts[model]
	if found then
		return found
	end
	local list: { PackPart } = {}
	local byPart: { [Instance]: PackPart } = {}
	for _, item in model:GetDescendants() do
		local part = item.Parent
		if not item:IsA("ParticleEmitter") or item:GetAttribute("BaseZ") == nil or not part or not part:IsA("BasePart") then
			continue
		end
		local entry = byPart[part]
		if not entry then
			entry = { part = part, emitters = {}, hidden = false }
			byPart[part] = entry
			table.insert(list, entry)
		end
		table.insert(entry.emitters, item)
	end
	packParts[model] = list
	return list
end

-- The pack aura layers draw past the wearer's body while it stands between the camera at `eye` and their part (owner
-- 2026-11-08: "the glow is blocked by the body", a sword on the back seen from the front; WeaponLookRules.packZOffset).
-- `body` hits only the wearer's body and accessories.
function WeaponLook.drawPastBody(model: Model, eye: Vector3, body: RaycastParams)
	for _, entry in packPartsOf(model) do
		local hidden = workspace:Raycast(eye, entry.part.Position - eye, body) ~= nil
		if hidden == entry.hidden then
			continue
		end
		entry.hidden = hidden
		for _, emitter in entry.emitters do
			emitter.ZOffset = WeaponLookRules.packZOffset(WeaponLooks, (emitter:GetAttribute("BaseZ") :: number?) or 0, hidden)
		end
	end
end

-- The full aura on or off (SwordController's budget: your own sword and the nearest few get it, the rest stay cheap),
-- `share` of its particles (WeaponLookRules.auraShare: another player's in your boss fight, low graphics)
function WeaponLook.setDetail(model: Model, full: boolean, share: number)
	if model:GetAttribute("FullAura") == full and model:GetAttribute("AuraShare") == share then
		return
	end
	model:SetAttribute("FullAura", full)
	model:SetAttribute("AuraShare", share)
	refresh(model)
end

return WeaponLook
