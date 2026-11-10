--!strict
-- A boss's debuff shown on a player's character (spec 2026-11-02-attack-animations-design, the owner's approved look;
-- kinds in Config/Bosses DEBUFFS, colours in Config/CombatHud DEBUFFS): Tangled vines wrapped round the legs, Poisoned
-- green bubbles rising off them, Burning small flames, Chilled frost crystals at the feet and a blue tint, Shocked
-- yellow sparks crackling, Weak a purple haze, Electrocuted (the Storm Sovereign's thunderclap) faint blue sparks and
-- in each jolt arcs flickering round them (Util/StormFx). Everyone in the fight sees it (BattleController shows it for every player
-- fighter's debuff event). Poison and Burn ticks flash the character in their colour. Client-only parts and emitters on
-- the character, gone when it runs out, when the player goes down or when the fight ends.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bosses = require(Shared:WaitForChild("Config"):WaitForChild("Bosses"))
local CombatHud = require(Shared:WaitForChild("Config"):WaitForChild("CombatHud"))
local DebuffRules = require(Shared:WaitForChild("Util"):WaitForChild("DebuffRules"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))
local Extras = require((script.Parent :: Instance):WaitForChild("Extras"))
local IceFx = require((script.Parent :: Instance):WaitForChild("IceFx"))
local StormFx = require((script.Parent :: Instance):WaitForChild("StormFx"))

local DebuffFx = {}

type Shown = { kind: string, token: number, pieces: { Instance } }
local shown: { [Model]: Shown } = {}
local tokens = 0

local FADE = TweenInfo.new(0.35)
local VINE = Color3.fromRGB(58, 120, 44)
local FROST = Color3.fromRGB(196, 236, 255)

local function colorOf(kind: string): Color3
	local look = CombatHud.DEBUFFS[kind]
	local rgb = if look then look.color else { 255, 255, 255 }
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- A small client-only part welded to `to` at `cframe` (massless: the character moves as before)
local function piece(to: BasePart, size: Vector3, color: Color3, cframe: CFrame, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Material = material
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = to, p
	weld.Parent = p
	p.Parent = to
	return p
end

-- Particles streaming out of the whole torso (the root part's box), fewer with the low-graphics switch off
local function stream(character: Model, texture: string, color: Color3, o: any, rate: number): { Instance }
	local root = rootOf(character)
	if not root then
		return {}
	end
	local emitter = ElementFx.emitter(root, texture, color, o)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Rate = if Extras.enabled() then rate else rate * 0.5
	return { emitter }
end

-- Tangled: two bands of vine round each lower leg, and a few green glints
local function vines(character: Model, color: Color3): { Instance }
	local out: { Instance } = {}
	for _, name in { "LeftLowerLeg", "RightLowerLeg" } do
		local leg = character:FindFirstChild(name)
		if leg and leg:IsA("BasePart") then
			local radius = math.max(leg.Size.X, leg.Size.Z) * 0.62
			for band = 1, 2 do
				local y = (band - 1.5) * leg.Size.Y * 0.55
				local tilt = CFrame.Angles(math.rad(if band == 1 then 12 else -12), 0, 0)
				for index = 1, 7 do
					local angle = index / 7 * math.pi * 2
					-- Each segment lies along the circle (its long side on the tangent)
					local at = leg.CFrame * tilt * CFrame.new(math.cos(angle) * radius, y, math.sin(angle) * radius) * CFrame.Angles(0, -angle, 0)
					table.insert(out, piece(leg, Vector3.new(0.22, 0.22, radius * 0.95), VINE, at, Enum.Material.Grass))
				end
			end
		end
	end
	for _, item in stream(character, "spark", color, { size = { 0.35, 0.1 }, life = 0.6, speed = 1, spread = 180 }, 8) do
		table.insert(out, item)
	end
	return out
end

local function bubbles(character: Model, color: Color3): { Instance }
	return stream(character, "glow", color, { size = { 0.25, 0.55 }, life = 1.2, speed = 2.5, accel = Vector3.new(0, 2, 0), light = 0.6, brightness = 1.2 }, 16)
end

local function flames(character: Model, color: Color3): { Instance }
	return stream(character, "flame", color, { size = { 0.9, 0.2 }, life = 0.6, speed = 3, accel = Vector3.new(0, 3, 0), spread = 15 }, 22)
end

-- Chilled: ice crystals round the feet and a cold blue tint on the whole character
local function frost(character: Model, color: Color3): { Instance }
	local root = rootOf(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root then
		return {}
	end
	local out: { Instance } = {}
	local feet = -(root.Size.Y / 2 + (if humanoid then humanoid.HipHeight else 2))
	for index = 1, 7 do
		local angle = index / 7 * math.pi * 2 + math.random() * 0.4
		local height = 0.8 + math.random() * 0.7
		local at = root.CFrame * CFrame.new(math.cos(angle) * 1.1, feet + height * 0.35, math.sin(angle) * 1.1)
			* CFrame.Angles(math.rad(math.random(-25, 25)), angle, math.rad(math.random(-25, 25)))
		local crystal = piece(root, Vector3.new(0.35, height, 0.35), FROST, at, if index % 2 == 0 then Enum.Material.Neon else Enum.Material.Ice)
		crystal.Transparency = 0.15
		table.insert(out, crystal)
	end
	local tint = Instance.new("Highlight")
	tint.FillColor = color
	tint.FillTransparency = 0.78
	tint.OutlineColor = FROST
	tint.OutlineTransparency = 0.5
	tint.DepthMode = Enum.HighlightDepthMode.Occluded
	tint.Parent = character
	table.insert(out, tint)
	return out
end

local function sparks(character: Model, color: Color3): { Instance }
	return stream(character, "spark", color, { size = { 0.9, 0.3 }, life = 0.18, speed = 5, spread = 180, brightness = 2.2 }, 40)
end

-- Electrocuted between its jolts: faint sparks (each jolt is StormFx.jolt's, scheduled by show)
local function charged(character: Model, color: Color3): { Instance }
	return stream(character, "spark", color, { size = { 0.6, 0.2 }, life = 0.15, speed = 4, spread = 180, brightness = 2 }, 10)
end

local function haze(character: Model, color: Color3): { Instance }
	return stream(character, "smoke", color, { size = { 2, 3.5 }, life = 1.4, speed = 0.6, start = 0.45, light = 0.3, spin = { -20, 20 } }, 8)
end

-- Frozen solid (the Frost Tyrant's spikes, 2026-11-10): locked in a block of ice that cracks off as it thaws
local CHARACTER_HEIGHT = 5.2
local function frozen(character: Model, _color: Color3): { Instance }
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return {}
	end
	return { IceFx.encase(root, CHARACTER_HEIGHT, nil) }
end

local BUILD: { [string]: (Model, Color3) -> { Instance } } = {
	Frozen = frozen,
	Entangled = vines,
	Poison = bubbles,
	Burn = flames,
	Chilled = frost,
	Shocked = sparks,
	Electrocuted = charged,
	Weakened = haze,
}

-- Takes the debuff off `character`: emitters stop (their particles fade out), parts and tints fade
function DebuffFx.clear(character: Model)
	local current = shown[character]
	if not current then
		return
	end
	shown[character] = nil
	for _, item in current.pieces do
		if item:IsA("ParticleEmitter") then
			item.Enabled = false
			Debris:AddItem(item, 1.5)
		elseif item:IsA("BasePart") then
			TweenService:Create(item, FADE, { Transparency = 1 }):Play()
			Debris:AddItem(item, FADE.Time)
		elseif item:IsA("Highlight") then
			TweenService:Create(item, FADE, { FillTransparency = 1, OutlineTransparency = 1 }):Play()
			Debris:AddItem(item, FADE.Time)
		elseif item:IsA("Model") and item.Name == "IceBlock" then
			IceFx.thaw(item)
		else
			item:Destroy()
		end
	end
end

-- `kind` on `character` for `seconds`: the same kind again only lasts longer, another replaces it. A debuff with jolts
-- (Electrocuted) jolts them at its times from now (DebuffRules.joltTimes; a refresh starts them over), calling
-- `onJolt(seconds)` with each (your own: the sword stops)
function DebuffFx.show(character: Model, kind: string, seconds: number, onJolt: ((number) -> ())?)
	local current = shown[character]
	if current and current.kind ~= kind then
		DebuffFx.clear(character)
		current = nil
	end
	tokens += 1
	local token = tokens
	if current then
		current.token = token
	else
		local build = BUILD[kind]
		if not build then
			return
		end
		shown[character] = { kind = kind, token = token, pieces = build(character, colorOf(kind)) }
	end
	local spec = Bosses.DEBUFFS[kind]
	local jolt = if spec then spec.jolt else nil
	if spec and jolt then
		for _, at in DebuffRules.joltTimes(spec) do
			task.delay(at, function()
				local now = shown[character]
				if not now or now.token ~= token then
					return -- cleared, refreshed or replaced
				end
				StormFx.jolt(character, jolt.seconds)
				if onJolt then
					onJolt(jolt.seconds)
				end
			end)
		end
	end
	task.delay(seconds, function()
		local now = shown[character]
		if now and now.token == token then
			DebuffFx.clear(character)
		end
	end)
end

-- A Poison or Burn tick: the character flashes in its colour for a moment
function DebuffFx.flash(character: Model, kind: string)
	local flash = Instance.new("Highlight")
	flash.FillColor = colorOf(kind)
	flash.FillTransparency = 0.45
	flash.OutlineTransparency = 1
	flash.DepthMode = Enum.HighlightDepthMode.Occluded
	flash.Parent = character
	TweenService:Create(flash, TweenInfo.new(0.35), { FillTransparency = 1 }):Play()
	Debris:AddItem(flash, 0.4)
end

-- Every debuff off every character (a fight ended)
function DebuffFx.clearAll()
	for character in shown do
		DebuffFx.clear(character)
	end
end

return DebuffFx
