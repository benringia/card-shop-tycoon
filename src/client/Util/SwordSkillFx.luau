--!strict
-- The round 1 swords' own effects (sword skills round, spec 2026-11-06-sword-skills-design 4): each sword's slash on
-- cuts 1-3, its finisher where cut 3 slams down and its skill, by the looks in Config/SwordSkillFx, coloured by the
-- weapon (Config/WeaponLooks) and grown by SwordSkillFxRules.scale. Effects stay low and short (never over the boss's
-- rings), live under the camera and clean themselves up. Each builder draws its look's basic shape until its sword's
-- round gives it its own (Tasks 5-8).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local SwordSkillFxConfig = require(Config:WaitForChild("SwordSkillFx"))
local WeaponLooks = require(Config:WaitForChild("WeaponLooks"))
local AttackFx = require(Config:WaitForChild("AttackFx"))
local MoveFx = require(Config:WaitForChild("MoveFx"))
local SuperFx = require(Config:WaitForChild("SuperFx"))
local SwordFx = require(Config:WaitForChild("SwordFx"))

export type Colors = { deep: Color3, glow: Color3 }

local SwordSkillFx = {}

local TEXTURE_TABLES = { AttackFx.TEXTURES, MoveFx.TEXTURES, SuperFx.TEXTURES, SwordFx.TEXTURES } :: { any }
local WHITE = Color3.new(1, 1, 1)
local GROUND_LIFT = 0.3 -- studs above the ground a finisher or skill draws (low: under the boss's rings)
local ROOT_TO_GROUND = 3 -- studs from a character's root down to its feet
local SLAM_AHEAD = 2.5 -- studs in front of you cut 3's blade meets the ground

local function texture(key: string): string?
	for _, list in TEXTURE_TABLES do
		local id = list[key]
		if typeof(id) == "string" then
			return id
		end
	end
	return nil
end

local function rgb(list: { number }): Color3
	return Color3.fromRGB(list[1], list[2], list[3])
end

-- A weapon's effect colours (its own look; a Forge Sword's is its element's)
function SwordSkillFx.colorsOf(weaponId: string): Colors
	local look = WeaponLooks.WEAPONS[weaponId] or WeaponLooks.WEAPONS.starterSword
	return { deep = rgb(look.deep), glow = rgb(look.glow) }
end

-- One burst of a look's particles from a flat box `width` x `depth` studs at `cframe`, then gone
local function burst(cframe: CFrame, width: number, depth: number, spec: SwordSkillFxConfig.Look, colors: Colors, scale: number)
	local part = Instance.new("Part")
	part.Name = "SwordSkillFx"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(math.max(width, 0.2), 0.2, math.max(depth, 0.2))
	part.CFrame = cframe
	part.Parent = workspace.CurrentCamera
	local share = math.max(1, math.round(spec.count * scale / #spec.textures))
	for index, key in spec.textures do
		local id = texture(key)
		if id then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = id
			emitter.Color = ColorSequence.new(if index == 1 then colors.glow else WHITE, colors.deep)
			emitter.LightEmission = 1
			emitter.Size = NumberSequence.new(0.9 * scale, 0)
			emitter.Transparency = NumberSequence.new(0.1, 1)
			emitter.Lifetime = NumberRange.new(spec.seconds * 0.5, spec.seconds)
			emitter.Speed = NumberRange.new(2, 6)
			emitter.SpreadAngle = Vector2.new(40, 40)
			emitter.Rotation = NumberRange.new(0, 360)
			emitter.RotSpeed = NumberRange.new(-90, 90)
			emitter.Shape = Enum.ParticleEmitterShape.Box
			emitter.EmissionDirection = Enum.NormalId.Top
			emitter.Rate = 0
			emitter.Parent = part
			emitter:Emit(share)
		end
	end
	Debris:AddItem(part, spec.seconds + 0.2)
end

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function flatLook(root: BasePart): Vector3
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
end

-- A cut's slash (cut 1-3): along the swing in front of you (cut 3's upright, the others across)
function SwordSkillFx.slash(character: Model, look: string, cut: number, colors: Colors, scale: number)
	local spec = SwordSkillFxConfig.LOOKS[look]
	local root = rootOf(character)
	if not spec or not root then
		return
	end
	local ahead = root.CFrame * CFrame.new(0, 0.5, -2.5)
	local turn = if cut == 3 then CFrame.Angles(0, 0, math.rad(90)) elseif cut == 2 then CFrame.Angles(0, 0, math.rad(-25)) else CFrame.Angles(0, 0, math.rad(25))
	burst(ahead * turn, spec.size * scale, 0.6, spec, colors, scale)
end

-- Where cut 3's slam lands: on the ground just ahead of you
function SwordSkillFx.slamPoint(character: Model): Vector3?
	local root = rootOf(character)
	if not root then
		return nil
	end
	return root.Position + flatLook(root) * SLAM_AHEAD - Vector3.new(0, ROOT_TO_GROUND, 0)
end

-- The finisher where cut 3's slam lands (`at`: on the ground)
function SwordSkillFx.finisher(at: Vector3, look: string, colors: Colors, scale: number)
	local spec = SwordSkillFxConfig.LOOKS[look]
	if not spec then
		return
	end
	local size = spec.size * scale
	burst(CFrame.new(at + Vector3.new(0, GROUND_LIFT, 0)), size, size, spec, colors, scale)
end

-- The skill: around you, along the ground toward `aim` (else ahead), or on the aimed foe
function SwordSkillFx.skill(character: Model, look: string, colors: Colors, scale: number, aim: Vector3?)
	local spec = SwordSkillFxConfig.LOOKS[look]
	local root = rootOf(character)
	if not spec or not root then
		return
	end
	local feet = root.Position - Vector3.new(0, ROOT_TO_GROUND - GROUND_LIFT, 0)
	local size = spec.size * scale
	if spec.form == "around" then
		burst(CFrame.new(feet), size, size, spec, colors, scale)
		return
	end
	local direction = flatLook(root)
	if aim then
		local toward = Vector3.new(aim.X - feet.X, 0, aim.Z - feet.Z)
		if toward.Magnitude > 1e-3 then
			direction = toward.Unit
		end
	end
	if spec.form == "on" and aim then
		burst(CFrame.new(Vector3.new(aim.X, feet.Y, aim.Z)), size, size, spec, colors, scale)
		return
	end
	local middle = feet + direction * size / 2
	burst(CFrame.lookAt(middle, middle + direction), size * 0.25, size, spec, colors, scale)
end

return SwordSkillFx
