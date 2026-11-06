--!strict
-- The round 1 swords' own effects (sword skills round, spec 2026-11-06-sword-skills-design 4): each sword's slash on
-- cuts 1-3, its finisher where cut 3 slams down and its skill, by the looks in Config/SwordSkillFx, coloured by the
-- weapon (Config/WeaponLooks) and grown by SwordSkillFxRules.scale. Effects stay low and short (never over the boss's
-- rings), live under the camera and clean themselves up. The Sunforged Blade's looks are its own (storyboard
-- 2026-11-07); the other swords draw their look's basic shape until their round (Tasks 6-8).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local SwordSkillFxConfig = require(Config:WaitForChild("SwordSkillFx"))
local WeaponLooks = require(Config:WaitForChild("WeaponLooks"))
local AttackFx = require(Config:WaitForChild("AttackFx"))
local MoveFx = require(Config:WaitForChild("MoveFx"))
local SuperFx = require(Config:WaitForChild("SuperFx"))
local SwordFx = require(Config:WaitForChild("SwordFx"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))
local Extras = require((script.Parent :: Instance):WaitForChild("Extras"))

export type Colors = { deep: Color3, glow: Color3 }
-- A character's sword blade: its handle part and the blade's base and tip in the handle's space
export type Blade = { part: BasePart, base: CFrame, tip: CFrame }
-- A skill's moments for its caster (your own: the screen shakes): the cleave, and where the effect bursts
export type Hooks = { blade: Blade?, released: (() -> ())?, burst: ((at: Vector3) -> ())? }

local SwordSkillFx = {}

local TEXTURE_TABLES = { AttackFx.TEXTURES, MoveFx.TEXTURES, SuperFx.TEXTURES, SwordFx.TEXTURES } :: { any }
local WHITE = Color3.new(1, 1, 1)
local UP = Vector3.yAxis
local COOLED = Color3.fromRGB(110, 22, 0) -- a lava crack's colour once it has cooled
local GROUND_LIFT = 0.3 -- studs above the ground a finisher or skill draws (low: under the boss's rings)
local ROOT_TO_GROUND = 3 -- studs from a character's root down to its feet
local SLAM_AHEAD = 2.5 -- studs in front of you cut 3's blade meets the ground
local AIR_TIP = 8.5 -- studs above the root the blade's tip is at the top of a jump, when the blade isn't known
local GROUND_REACH = 6 -- studs up or down from a character's feet the ground under an effect is looked for
local VINE_PIECES = 3 -- stem pieces in a Verdant vine or root, bottom to top
local VINE_SNAP = 0.1 -- seconds a vine takes to snap shut
local VERDANT = SwordSkillFxConfig.VERDANT

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

-- An invisible anchored part under the camera, gone after `life` seconds
local function holder(cframe: CFrame, size: Vector3, life: number): Part
	local part = Instance.new("Part")
	part.Name = "SwordSkillFx"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size
	part.CFrame = cframe
	part.Parent = workspace.CurrentCamera
	Debris:AddItem(part, life)
	return part
end

-- One emitter of a look's texture (any of the four TEXTURES tables) with ElementFx's options
local function emitter(parent: Instance, key: string, color: Color3, o: any): ParticleEmitter
	local e = ElementFx.emitter(parent, "glow", color, o)
	e.Texture = texture(key) or e.Texture
	return e
end

local function tween(item: Instance, seconds: number, goal: { [string]: any })
	TweenService:Create(item, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

-- The terrain under `at` within `GROUND_REACH` studs of it (never a boss's or creature's model), else `at` itself
local function groundAt(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(at + UP * GROUND_REACH, -UP * GROUND_REACH * 2, params)
	return if hit then hit.Position else at
end

-- One burst of a look's particles from a flat box `width` x `depth` studs at `cframe`, then gone (the looks still
-- waiting for their sword's round)
local function sketch(cframe: CFrame, width: number, depth: number, spec: SwordSkillFxConfig.Look, colors: Colors, scale: number)
	local part = holder(cframe, Vector3.new(math.max(width, 0.2), 0.2, math.max(depth, 0.2)), spec.seconds + 0.2)
	local share = math.max(1, math.round(spec.count * scale / #spec.textures))
	for index, key in spec.textures do
		local e = emitter(part, key, if index == 1 then colors.glow else WHITE, {
			size = { 0.9 * scale, 0 },
			life = { spec.seconds * 0.5, spec.seconds },
			speed = { 2, 6 },
			spread = 40,
			spin = { -90, 90 },
		})
		e.Shape = Enum.ParticleEmitterShape.Box
		e:Emit(share)
	end
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

-- The blade's tip in the world now (the animated hand's), else above the character
local function tipOf(blade: Blade?, root: BasePart): Vector3
	if blade and blade.part.Parent then
		return (blade.part.CFrame * blade.tip).Position
	end
	return root.Position + UP * AIR_TIP
end

-- Sunforged: flames streaming off the blade for the swing, left behind in the air as it moves (a fire trail)
local function fireTrail(spec: SwordSkillFxConfig.Look, colors: Colors, scale: number, blade: Blade)
	local points: { Attachment } = {}
	for _, share in { 0.25, 0.6, 0.95 } do
		local point = Instance.new("Attachment")
		point.CFrame = blade.base:Lerp(blade.tip, share)
		point.Parent = blade.part
		table.insert(points, point)
		local flame = emitter(point, "flame", colors.deep, {
			size = { spec.size * scale, 0.2 },
			life = { 0.25, 0.4 },
			speed = { 0.5, 1.5 },
			spread = 180,
			spin = { -60, 60 },
			accel = UP * 6,
			fade = 0.3,
		})
		flame.Rate = spec.count * scale / 3
		local core = emitter(point, "flame", colors.glow:Lerp(WHITE, 0.4), {
			size = { spec.size * 0.5 * scale, 0.1 },
			life = { 0.15, 0.25 },
			spread = 180,
			brightness = 2.2,
		})
		core.Rate = spec.count * scale / 4
		local embers = emitter(point, "spark", colors.glow, { size = { 0.25, 0.05 }, life = { 0.4, 0.7 }, speed = { 2, 5 }, spread = 180, accel = UP * 4 })
		embers.Rate = spec.count * scale / 8
	end
	task.delay(spec.seconds, function()
		for _, point in points do
			for _, item in point:GetChildren() do
				if item:IsA("ParticleEmitter") then
					item.Rate = 0
				end
			end
		end
	end)
	for _, point in points do
		Debris:AddItem(point, spec.seconds + 0.8)
	end
end

-- Sunforged: the ground cracks open with glowing lava `size` studs across at `ground`, cooling to dark red as it fades
local function lavaCrack(ground: Vector3, size: number, spec: SwordSkillFxConfig.Look, colors: Colors, scale: number)
	local seconds = spec.seconds
	local plate = holder(CFrame.new(ground + UP * 0.06), Vector3.new(size, 0.05, size), seconds + 0.6)
	local decal = Instance.new("Decal")
	decal.Texture = texture("crack") or ""
	decal.Face = Enum.NormalId.Top
	decal.Color3 = colors.glow
	decal.Parent = plate
	tween(decal, seconds * 0.6, { Color3 = colors.deep })
	task.delay(seconds * 0.6, function()
		tween(decal, seconds * 0.4, { Color3 = COOLED, Transparency = 1 })
	end)
	local light = Instance.new("PointLight")
	light.Color = colors.deep
	light.Range = size * 1.4
	light.Brightness = 3
	light.Parent = plate
	tween(light, seconds, { Brightness = 0 })
	local disc = holder(CFrame.new(ground + UP * 0.4) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.2, size * 0.8, size * 0.8), seconds + 0.6)
	local function fromDisc(e: ParticleEmitter)
		e.Shape = Enum.ParticleEmitterShape.Disc
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.EmissionDirection = Enum.NormalId.Right
	end
	local licks = emitter(disc, "flame", colors.deep, { size = { 1.6 * scale, 0.3 }, life = { 0.35, 0.6 }, speed = { 3, 6 }, spread = 20, accel = UP * 4 })
	fromDisc(licks)
	licks:Emit(math.round(spec.count * 0.5 * scale))
	local embers = emitter(disc, "spark", colors.glow, { size = { 0.35, 0.05 }, life = { 0.6, 1.1 }, speed = { 5, 10 }, spread = 35, accel = -UP * 6 })
	fromDisc(embers)
	embers:Emit(math.round(spec.count * scale))
	local smoke = emitter(disc, "smoke", Color3.fromRGB(70, 50, 40), { size = { 2.5 * scale, 5 * scale }, life = { 0.8, 1.2 }, speed = { 1, 3 }, spread = 30, light = 0, brightness = 1, start = 0.4 })
	fromDisc(smoke)
	smoke:Emit(math.round(spec.count * 0.25 * scale))
end

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

-- Fewer particles with the low-graphics switch off (as ElementFx's)
local function detail(count: number): number
	return math.max(1, math.round(if Extras.enabled() then count else count * 0.45))
end

-- Three trails of `key` particles swirling round `center()` (`radius` studs, a little bob) for `seconds`: a charge's
-- spiral of flames or leaves
local function swirl(center: () -> Vector3, radius: number, color: Color3, key: string, seconds: number, size: number)
	local anchor = holder(CFrame.new(center()), Vector3.one, seconds + 1)
	local points: { { point: Attachment, emitter: ParticleEmitter, phase: number } } = {}
	for index = 1, 3 do
		local point = Instance.new("Attachment")
		point.Parent = anchor
		local trail = emitter(point, key, color, { size = { size, size * 0.2 }, life = { 0.35, 0.55 }, spread = 10, spin = { -90, 90 }, fade = 0.5 })
		trail.Rate = detail(45)
		table.insert(points, { point = point, emitter = trail, phase = index / 3 * math.pi * 2 })
	end
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t > seconds or not anchor.Parent then
			connection:Disconnect()
			for _, entry in points do
				entry.emitter.Rate = 0
			end
			return
		end
		anchor.CFrame = CFrame.new(center())
		local spin = t * math.pi * 2 * 1.6
		for _, entry in points do
			local angle = spin + entry.phase
			entry.point.Position = Vector3.new(math.cos(angle) * radius, math.sin(t * 6 + entry.phase) * 0.6, math.sin(angle) * radius)
		end
	end)
end

-- A glowing fissure tearing along the ground from `from` to `to` over `grow` seconds (a tiled crack over a bright seam,
-- `spark` particles spitting up out of it, a light), held `linger` seconds, then fading over `fade`
local function fissure(from: Vector3, to: Vector3, width: number, glow: Color3, deep: Color3, grow: number, linger: number, fade: number, spark: string)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	if length < 0.5 then
		return
	end
	local direction = flat.Unit
	local y = from.Y + 0.07
	local life = grow + linger + fade + 0.3
	local plate = holder(CFrame.new(from), Vector3.new(width, 0.05, 0.05), life)
	local crack = Instance.new("Texture")
	crack.Texture = texture("crack") or ""
	crack.Face = Enum.NormalId.Top
	crack.StudsPerTileU = width
	crack.StudsPerTileV = width
	crack.Color3 = glow
	crack.Parent = plate
	local seam = holder(CFrame.new(from), Vector3.new(width * 0.18, 0.06, 0.05), life)
	seam.Material = Enum.Material.Neon
	seam.Color = glow
	seam.Transparency = 0.15
	local spit = emitter(seam, spark, glow, { size = { 0.55, 0.1 }, life = { 0.5, 0.9 }, speed = { 3, 8 }, spread = 25, accel = UP * 2, brightness = 2.2 })
	spit.Shape = Enum.ParticleEmitterShape.Box
	spit.Rate = detail(80)
	local light = Instance.new("PointLight")
	light.Color = deep
	light.Range = math.max(width * 4, length * 0.6)
	light.Brightness = 2.5
	light.Parent = seam
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local a = if grow <= 0 then 1 else math.clamp((os.clock() - started) / grow, 0, 1)
		local shown = math.max(length * smooth(a), 0.05)
		local middle = from + direction * shown / 2
		local frame = CFrame.lookAt(Vector3.new(middle.X, y, middle.Z), Vector3.new(middle.X, y, middle.Z) + direction)
		plate.Size = Vector3.new(width, 0.05, shown)
		plate.CFrame = frame
		seam.Size = Vector3.new(width * 0.18, 0.06, shown)
		seam.CFrame = frame
		if a >= 1 or not plate.Parent then
			connection:Disconnect()
		end
	end)
	task.delay(grow + linger, function()
		spit.Rate = 0
		tween(crack, fade, { Transparency = 1 })
		tween(seam, fade, { Transparency = 1 })
		tween(light, fade, { Brightness = 0 })
	end)
end

-- Verdant: leaves and a few pink petals peeling off the blade for the swing, tumbling down behind it
local function leafShed(spec: SwordSkillFxConfig.Look, colors: Colors, scale: number, blade: Blade)
	local points: { Attachment } = {}
	for _, share in { 0.3, 0.65, 0.95 } do
		local point = Instance.new("Attachment")
		point.CFrame = blade.base:Lerp(blade.tip, share)
		point.Parent = blade.part
		table.insert(points, point)
		local leaves = emitter(point, "shard", colors.glow, {
			size = { spec.size * scale, spec.size * 0.6 * scale },
			life = { 0.6, 1 },
			speed = { 1, 3 },
			spread = 180,
			spin = { -200, 200 },
			accel = -UP * 5,
			drag = 1.2,
			light = 0.3,
			fade = 0.6,
		})
		leaves.Rate = spec.count * scale / 3
		local petals = emitter(point, "glow", rgb(VERDANT.petal), { size = { 0.35 * scale, 0.2 }, life = { 0.6, 1 }, speed = { 1, 2 }, spread = 180, accel = -UP * 3, drag = 1 })
		petals.Rate = spec.count * scale / 10
	end
	task.delay(spec.seconds, function()
		for _, point in points do
			for _, item in point:GetChildren() do
				if item:IsA("ParticleEmitter") then
					item.Rate = 0
				end
			end
		end
	end)
	for _, point in points do
		Debris:AddItem(point, spec.seconds + 1.2)
	end
end

-- Verdant: a burst of leaves (and `petals` pink petals) and dirt at `at` on the ground
local function leafBurst(at: Vector3, colors: Colors, count: number, scale: number, petals: number?)
	local anchor = holder(CFrame.new(at + UP * 0.5), Vector3.one, 2.5)
	local leaves = emitter(anchor, "shard", colors.glow, { size = { 0.9 * scale, 0.5 * scale }, life = { 0.9, 1.5 }, speed = { 6, 14 }, spread = 70, spin = { -220, 220 }, accel = -UP * 9, drag = 1.4, light = 0.3 })
	leaves:Emit(detail(count))
	local dirt = emitter(anchor, "smoke", rgb(VERDANT.bark), { size = { 2 * scale, 4 * scale }, life = { 0.5, 0.9 }, speed = { 2, 5 }, spread = 50, light = 0, brightness = 1, start = 0.4 })
	dirt:Emit(detail(math.max(1, math.round(count / 3))))
	if petals and petals > 0 then
		local pink = emitter(anchor, "glow", rgb(VERDANT.petal), { size = { 0.5 * scale, 0.2 }, life = { 1, 1.6 }, speed = { 4, 10 }, spread = 80, accel = -UP * 4, drag = 1.2 })
		pink:Emit(detail(petals))
	end
end

-- A Verdant vine or root: solid lit stem pieces with thorns, a leaf and a glowing bulb at its tip (the owner wanted the
-- Vine Snare's vines "more visible", Thornline's "noticeable", then everything exaggerated), growing out of the ground
-- at `base`, leaning and curling toward `inward`
type Vine = {
	base: Vector3,
	inward: Vector3,
	height: number,
	thick: number,
	stems: { Part },
	thorns: { Part },
	leaf: Part,
	bulb: Part?,
	growAt: number, -- seconds into the effect it starts growing
	grow: number, -- seconds it takes
	lean: number, -- radians toward `inward` standing, and its curl per piece; then when snapped shut
	curl: number,
	snapLean: number,
	snapCurl: number,
	last: number, -- its last drawn state (grow and snap), so a still vine isn't redrawn every frame
}

local function piece(color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = "SwordSkillFx"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Color = color
	p.Material = material
	p.Size = Vector3.one * 0.05
	p.Transparency = 1
	p.Parent = workspace.CurrentCamera
	return p
end

-- `bulb`: a glowing bud on its tip in that colour
local function makeVine(base: Vector3, inward: Vector3, height: number, thick: number, color: Color3, leafColor: Color3, material: Enum.Material, bulb: Color3?): Vine
	local stems: { Part } = {}
	local thorns: { Part } = {}
	for _ = 1, VINE_PIECES do
		local stem = piece(color, material)
		stem.Shape = Enum.PartType.Cylinder
		table.insert(stems, stem)
		table.insert(thorns, piece(rgb(VERDANT.thorn), Enum.Material.SmoothPlastic))
	end
	local bud: Part? = nil
	if bulb then
		bud = piece(bulb, Enum.Material.Neon)
		bud.Shape = Enum.PartType.Ball
	end
	return {
		base = base,
		inward = inward,
		height = height,
		thick = thick,
		stems = stems,
		thorns = thorns,
		leaf = piece(leafColor, Enum.Material.SmoothPlastic),
		bulb = bud,
		growAt = 0,
		grow = 0.12,
		lean = -0.22,
		curl = 0.12,
		snapLean = 0.5,
		snapCurl = 0.42,
		last = -1,
	}
end

-- A vine `grow` (0-1) of its height, leaning `lean` and curling `curl` radians a piece toward its `inward`
local function placeVine(v: Vine, grow: number, lean: number, curl: number)
	local shown = grow > 0.02
	local at = v.base
	local length = v.height / VINE_PIECES * grow
	local angle = lean
	local side = v.inward:Cross(UP)
	for index, stem in v.stems do
		angle += curl
		local direction = UP * math.cos(angle) + v.inward * math.sin(angle)
		local to = at + direction * length
		local width = v.thick * (1 - (index - 1) * 0.25)
		stem.Size = Vector3.new(math.max(length + width * 0.3, 0.05), width, width)
		stem.CFrame = CFrame.lookAt((at + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0)
		stem.Transparency = if shown then 0 else 1
		-- a pale thorn sticking out from each joint, alternately left and right
		local thorn = v.thorns[index]
		local out = (side * (if index % 2 == 0 then 1 else -1) - v.inward * 0.4 + UP * 0.3).Unit
		local long = 0.8 * v.thick * grow
		thorn.Size = Vector3.new(0.24 * v.thick, 0.24 * v.thick, math.max(long, 0.05))
		thorn.CFrame = CFrame.lookAt(to, to + out) * CFrame.new(0, 0, -long / 2)
		thorn.Transparency = if shown then 0 else 1
		if index == 2 then
			local leafOut = (-side + UP * 0.4).Unit
			local leafSize = 1.6 * v.thick * grow
			v.leaf.Size = Vector3.new(math.max(leafSize * 0.5, 0.05), 0.08, math.max(leafSize, 0.05))
			v.leaf.CFrame = CFrame.lookAt(at, at + leafOut) * CFrame.new(0, 0, -leafSize / 2)
			v.leaf.Transparency = if shown then 0 else 1
		end
		at = to
	end
	local bud = v.bulb
	if bud then
		bud.Size = Vector3.one * math.max(v.thick * 1.1 * grow, 0.05)
		bud.CFrame = CFrame.new(at)
		bud.Transparency = if shown then 0.1 else 1
	end
end

local function dropVine(v: Vine)
	for _, part in v.stems do
		part:Destroy()
	end
	for _, part in v.thorns do
		part:Destroy()
	end
	v.leaf:Destroy()
	if v.bulb then
		v.bulb:Destroy()
	end
end

-- Drives `vines` from now: each grows from its `growAt` over its `grow`, snaps shut from `snapAt` (nil: never), and
-- all wither back into the ground from `witherAt` over `wither` seconds (`withered(vine)` as each starts), then are gone
local function animateVines(vines: { Vine }, snapAt: number?, witherAt: number, wither: number, withered: ((Vine) -> ())?)
	local started = os.clock()
	local withering = false
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t > witherAt and not withering then
			withering = true
			if withered then
				for _, v in vines do
					withered(v)
				end
			end
		end
		for _, v in vines do
			local grow = smooth(math.clamp((t - v.growAt) / v.grow, 0, 1))
			if withering then
				grow = math.min(grow, 1 - smooth(math.clamp((t - witherAt) / wither, 0, 1)))
			end
			local shut = if snapAt then smooth(math.clamp((t - snapAt) / VINE_SNAP, 0, 1)) else 0
			local state = grow * 2 + shut
			if state ~= v.last then
				v.last = state
				placeVine(v, grow, v.lean + (v.snapLean - v.lean) * shut, v.curl + (v.snapCurl - v.curl) * shut)
			end
		end
		if t > witherAt + wither then
			connection:Disconnect()
			for _, v in vines do
				dropVine(v)
			end
		end
	end)
end

-- Verdant: thorny bark roots spiking up in a ring round `ground` with a burst of earth, a green shockwave, leaves and
-- petals flying, sinking back
local function rootBurst(ground: Vector3, spec: SwordSkillFxConfig.Look, colors: Colors, scale: number)
	local beats = spec.beats :: { [string]: number }
	local roots: { Vine } = {}
	local radius = spec.size * 0.3 * scale
	for index = 1, beats.roots do
		local angle = index / beats.roots * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
		local root = makeVine(groundAt(ground + offset), -offset.Unit, beats.height * scale, beats.thick * scale, rgb(VERDANT.bark), colors.glow, Enum.Material.Wood, colors.glow)
		root.growAt = (index % 3) * 0.03
		root.grow = 0.1
		root.lean = -0.35 -- spiking outward
		root.curl = 0.12
		table.insert(roots, root)
	end
	animateVines(roots, nil, spec.seconds * 0.55, spec.seconds * 0.45)
	ElementFx.eruption(ground, rgb(VERDANT.bark), radius * 1.2, 10)
	ElementFx.ring(ground, colors.glow, spec.size * scale, 0.45)
	leafBurst(ground, colors, spec.count, scale, 12)
end

-- A cut's slash (cut 1-3): along the swing in front of you (cut 3's upright, the others across); with the blade known,
-- the Sunforged's flames or the Verdant's leaves stream off it
function SwordSkillFx.slash(character: Model, look: string, cut: number, colors: Colors, scale: number, blade: Blade?)
	local spec = SwordSkillFxConfig.LOOKS[look]
	local root = rootOf(character)
	if not spec or not root then
		return
	end
	if look == "fireTrail" and blade and blade.part.Parent then
		fireTrail(spec, colors, scale, blade)
		return
	elseif look == "leafShed" and blade and blade.part.Parent then
		leafShed(spec, colors, scale, blade)
		return
	end
	local ahead = root.CFrame * CFrame.new(0, 0.5, -2.5)
	local turn = if cut == 3 then CFrame.Angles(0, 0, math.rad(90)) elseif cut == 2 then CFrame.Angles(0, 0, math.rad(-25)) else CFrame.Angles(0, 0, math.rad(25))
	sketch(ahead * turn, 4 * scale, 0.6, spec, colors, scale)
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
	if look == "lavaCrack" then
		-- the slam bursts the ground open: lava, a spurt of fire, a shockwave
		local ground = groundAt(at)
		lavaCrack(ground, size, spec, colors, scale)
		ElementFx.eruption(ground, colors.deep, size * 0.35, 10)
		ElementFx.pillar(ground, colors.deep, 7 * scale, 0.25, "flame")
		ElementFx.ring(ground, colors.glow, size * 1.1, 0.45)
		return
	elseif look == "rootBurst" and spec.beats then
		rootBurst(groundAt(at), spec, colors, scale)
		return
	end
	sketch(CFrame.new(at + Vector3.new(0, GROUND_LIFT, 0)), size, size, spec, colors, scale)
end

-- Sunfall Cleave's upright fire crescent: from `from` it glides to `to` (on the ground, ahead) in `seconds` (when the
-- server lands its hit), its two tips above and below with fire beams bowing forward between them, flames and embers
-- streaming off; then `arrive()`
local function fireCrescent(from: Vector3, to: Vector3, seconds: number, beats: { [string]: number }, colors: Colors, scale: number, arrive: () -> ())
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local half = beats.height * 0.5 * scale
	local carrier = holder(CFrame.new(from), Vector3.new(0.4, half * 2, 0.4), seconds + 1)
	local function tip(side: number): Attachment
		local a = Instance.new("Attachment")
		-- X along the flight (the beams bow that way), the tips above and below
		a.CFrame = CFrame.fromMatrix(UP * half * side, Vector3.new(0, 0, -1), UP)
		a.Parent = carrier
		return a
	end
	local top, bottom = tip(1), tip(-1)
	local beams: { Beam } = {}
	for _, layer in { { width = beats.width, color = colors.deep, z = 0 }, { width = beats.width * 0.5, color = colors.glow, z = 0.04 }, { width = beats.width * 0.2, color = WHITE, z = 0.08 } } do
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = top, bottom
		b.CurveSize0, b.CurveSize1 = half * 0.7, -half * 0.7
		b.Texture = texture("moon") or ""
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureLength = 1
		b.Width0, b.Width1 = layer.width * scale, layer.width * scale
		b.Color = ColorSequence.new(layer.color)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.FaceCamera = true
		b.Segments = 18
		b.ZOffset = layer.z
		b.Parent = carrier
		table.insert(beams, b)
	end
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = top, bottom
	trail.Color = ColorSequence.new(colors.glow, colors.deep)
	trail.Transparency = NumberSequence.new(0.4, 1)
	trail.Lifetime = 0.35
	trail.LightEmission = 1
	trail.Parent = carrier
	local flames = emitter(carrier, "flame", colors.deep, { size = { beats.flame * scale, 0.2 }, life = { 0.3, 0.5 }, speed = { 0.5, 2 }, spread = 180, accel = UP * 5, spin = { -60, 60 } })
	flames.Shape = Enum.ParticleEmitterShape.Box
	flames.Rate = 10 * beats.height * scale
	local embers = emitter(carrier, "spark", colors.glow, { size = { 0.35, 0.05 }, life = { 0.4, 0.8 }, speed = { 2, 5 }, spread = 180 })
	embers.Shape = Enum.ParticleEmitterShape.Box
	embers.Rate = 6 * beats.height * scale
	local light = Instance.new("PointLight")
	light.Color = colors.deep
	light.Range = 2.2 * beats.height * scale
	light.Brightness = 2.5
	light.Parent = carrier
	local started = os.clock()
	local direction = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = if seconds <= 0 then 1 else math.clamp((os.clock() - started) / seconds, 0, 1)
		local now = from:Lerp(to, t)
		carrier.CFrame = CFrame.lookAt(now, now + direction)
		if t >= 1 or not carrier.Parent then
			connection:Disconnect()
			flames.Rate, embers.Rate = 0, 0
			trail.Enabled = false
			for _, b in beams do
				b.Enabled = false
			end
			light.Enabled = false
			arrive()
		end
	end)
end

-- Sunfall Cleave (exaggerated, owner 2026-11-07): a heat ring and glowing cracks open under you with embers rising as
-- you leap, a sun swells at the blade's tip with fire swirling round you while you hang charging, the cleave flashes
-- and sends a shockwave out, the fire crescent glides down toward `aim` (else straight ahead its full run) tearing a
-- burning fissure along the ground, and bursts there: a pillar of fire, an eruption, a double flash, a lava crack
local function sunfallCleave(character: Model, root: BasePart, spec: SwordSkillFxConfig.Look, colors: Colors, scale: number, aim: Vector3?, hooks: Hooks)
	local beats = spec.beats :: { [string]: number }
	local direction = flatLook(root)
	local start = root.Position
	local feet = start - UP * ROOT_TO_GROUND
	local finish = if aim then Vector3.new(aim.X, feet.Y, aim.Z) else feet + direction * spec.size
	local ground = groundAt(finish)
	local base = groundAt(feet)
	-- The leap: a heat ring spinning under you, cracks glowing out from your feet, embers rising
	ElementFx.castRing(base, colors.deep, beats.heat * scale, beats.release)
	for index = 1, 3 do
		local angle = index / 3 * math.pi * 2 + 0.4
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		fissure(base, base + out * beats.heat * 1.3 * scale, beats.fissure * 0.6 * scale, colors.glow, colors.deep, beats.release * 0.7, 0.4, 0.5, "spark")
	end
	local heat = holder(CFrame.new(base + UP * 0.3), Vector3.new(beats.heat * 2 * scale, 0.2, beats.heat * 2 * scale), beats.release + 1.5)
	local embers = emitter(heat, "spark", colors.glow, { size = { 0.45, 0.05 }, life = { 0.8, 1.4 }, speed = { 3, 8 }, spread = 15, accel = UP * 3, brightness = 2.2 })
	embers.Shape = Enum.ParticleEmitterShape.Box
	embers.Rate = detail(70)
	task.delay(beats.release, function()
		embers.Rate = 0
	end)
	task.delay(beats.charge, function()
		if not character.Parent then
			return
		end
		local charge = beats.release - beats.charge
		local sun = holder(CFrame.new(tipOf(hooks.blade, root)), Vector3.one, charge + 1)
		local stopGlow = ElementFx.chargeGlow(sun, colors.glow, charge, beats.glow / 2.6 * scale)
		local stopGather = ElementFx.gather(sun.Position, colors.glow, beats.charged - beats.charge, beats.gather * scale)
		local glare = Instance.new("PointLight")
		glare.Color = colors.glow
		glare.Range = 6 * beats.glow * scale
		glare.Brightness = 0
		glare.Parent = sun
		tween(glare, charge, { Brightness = 4 })
		-- fire swirling round you as you hang
		swirl(function(): Vector3
			return tipOf(hooks.blade, root) - UP * 2.5
		end, beats.swirl * scale, colors.deep, "flame", charge, 1.8 * scale)
		-- the sun rides the blade's tip while you hang
		local follow = RunService.RenderStepped:Connect(function()
			if sun.Parent then
				sun.CFrame = CFrame.new(tipOf(hooks.blade, root))
			end
		end)
		task.delay(charge, function()
			follow:Disconnect()
			stopGlow()
			stopGather()
			sun:Destroy()
		end)
	end)
	task.delay(beats.release, function()
		if hooks.released then
			hooks.released()
		end
		-- the cleave: a flash at the blade, a shockwave rolling out under you
		ElementFx.burst(tipOf(hooks.blade, root), colors.glow, 1.4 * scale)
		ElementFx.ring(base, colors.deep, 10 * scale, 0.5)
		-- From the top of the cleave, in front of you: it glides down from there, reaching the burst when the server's
		-- hit lands (its distance from you at the shape's speed, SwordRules.skillHits)
		local from = root.Position + flatLook(root) * beats.ahead + UP * beats.launch
		local seconds = Vector3.new(ground.X - start.X, 0, ground.Z - start.Z).Magnitude / math.max(beats.speed, 1)
		-- a burning fissure tearing along the ground under it
		fissure(base + direction * beats.ahead, ground, beats.fissure * scale, colors.glow, colors.deep, seconds, 0.7, 0.8, "spark")
		fireCrescent(from, ground + UP * beats.height * 0.5 * scale, seconds, beats, colors, scale, function()
			if hooks.burst then
				hooks.burst(ground)
			end
			local blast = beats.blast * scale
			ElementFx.burst(ground + UP * 2, colors.glow, beats.boom * scale)
			ElementFx.burst(ground + UP * 5, colors.glow:Lerp(WHITE, 0.5), beats.boom * 0.6 * scale)
			ElementFx.eruption(ground, colors.deep, blast * 1.1, 18)
			ElementFx.pillar(ground, colors.deep, beats.pillar * scale, 0.6, "flame")
			ElementFx.ring(ground, colors.glow, blast * 1.8, 0.6)
			lavaCrack(ground, blast * 2.2, spec, colors, scale)
		end)
	end)
end

-- Thornline (exaggerated, owner 2026-11-07): green energy gathers on the blade and leaves swirl round you through the
-- hop; the pierce sends a shockwave and a burst of earth out and a glowing green fissure tears toward the foe while big
-- thorny vines with glowing buds burst up in rows either side of it, racing out to where they reach the first foe
-- (`aim`; else the end of their run); there they all snap shut and a ring of giant vines clamps the foe (an eruption, a
-- storm of leaves and petals), then each withers in a puff of leaves
local function thornline(root: BasePart, spec: SwordSkillFxConfig.Look, colors: Colors, scale: number, aim: Vector3?, hooks: Hooks)
	local beats = spec.beats :: { [string]: number }
	local feet = root.Position - UP * ROOT_TO_GROUND
	local direction = flatLook(root)
	local finish = if aim then Vector3.new(aim.X, feet.Y, aim.Z) else feet + direction * spec.size
	local flat = Vector3.new(finish.X - feet.X, 0, finish.Z - feet.Z)
	if flat.Magnitude > 1e-3 then
		direction = flat.Unit
	end
	local reach = flat.Magnitude
	-- the vines reach the foe when the server lands the hit (its distance from you at the shape's speed)
	local snapAt = beats.release + reach / beats.speed
	local right = direction:Cross(UP)
	local trap = groundAt(finish)
	-- The hop: green energy gathering on the blade, leaves swirling round you
	local orb = holder(CFrame.new(tipOf(hooks.blade, root)), Vector3.one, beats.release + 1)
	local stopGlow = ElementFx.chargeGlow(orb, colors.glow, beats.release, 0.9 * scale)
	ElementFx.gather(root.Position + UP, colors.glow, beats.release, beats.gather * scale)
	local follow = RunService.RenderStepped:Connect(function()
		if orb.Parent then
			orb.CFrame = CFrame.new(tipOf(hooks.blade, root))
		end
	end)
	swirl(function(): Vector3
		return root.Position
	end, beats.swirl * scale, colors.glow, "shard", beats.release + 0.15, 1 * scale)
	-- Each row's vines are made as it bursts (not all at once: a 200-part hitch), joining the ones already growing
	local vines: { Vine } = {}
	local distance = SLAM_AHEAD
	while distance <= reach + 0.01 do
		local along = distance
		local burstAt = beats.release + along / beats.speed
		task.delay(burstAt, function()
			local at = groundAt(feet + direction * along)
			for _, side in { -1, 1 } do
				local vine = makeVine(at + right * side * beats.side * scale, -right * side, beats.height * scale, beats.thick * scale, colors.deep, colors.glow, Enum.Material.SmoothPlastic, colors.glow)
				vine.growAt = burstAt
				table.insert(vines, vine)
			end
			leafBurst(at, colors, 10, scale, 3)
		end)
		distance += beats.spacing
	end
	task.delay(math.max(0, snapAt - 0.1), function()
		for index = 1, beats.trapVines do
			local angle = index / beats.trapVines * math.pi * 2
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * beats.trap * scale
			local vine = makeVine(groundAt(trap + offset), -offset.Unit, beats.height * beats.trapTall * scale, beats.thick * 1.2 * scale, colors.deep, colors.glow, Enum.Material.SmoothPlastic, rgb(VERDANT.petal))
			vine.growAt = snapAt - 0.1
			vine.grow = 0.1
			vine.lean, vine.curl = -0.15, 0.1
			vine.snapLean, vine.snapCurl = 0.55, 0.45
			table.insert(vines, vine)
		end
	end)
	animateVines(vines, snapAt, snapAt + beats.linger, beats.wither, function(vine: Vine)
		-- each vine goes in a puff of leaves (every other one: plenty)
		if (vine.base.X + vine.base.Z) % 2 < 1 then
			leafBurst(vine.base, colors, 4, scale)
		end
	end)
	task.delay(beats.release, function()
		follow:Disconnect()
		stopGlow()
		orb:Destroy()
		-- The pierce: a shockwave, a burst of earth, a green fissure tearing toward the foe ahead of the vines
		local stab = groundAt(feet + direction * SLAM_AHEAD)
		ElementFx.ring(stab, colors.glow, 7 * scale, 0.5)
		ElementFx.castRing(stab, colors.glow, 3 * scale, 0.5)
		ElementFx.eruption(stab, rgb(VERDANT.bark), 2.5 * scale, 8)
		leafBurst(stab, colors, 16, scale, 6)
		fissure(stab, trap, beats.fissure * scale, colors.glow, colors.deep, math.max(0.05, (reach - SLAM_AHEAD) / beats.speed), beats.linger + 0.3, 0.5, "spark")
	end)
	task.delay(snapAt, function()
		if hooks.burst then
			hooks.burst(trap)
		end
		ElementFx.eruption(trap, colors.deep, beats.blast * 1.2 * scale, 16)
		ElementFx.burst(trap + UP * 3, colors.glow, 1.6 * scale)
		ElementFx.ring(trap, colors.glow, 8 * scale, 0.5)
		leafBurst(trap + UP * 2, colors, 60, scale, 24)
	end)
end

-- The skill: Sunfall Cleave its own; the looks still waiting for their round around you, along the ground toward
-- `aim` (else ahead), or on the aimed foe
function SwordSkillFx.skill(character: Model, look: string, colors: Colors, scale: number, aim: Vector3?, hooks: Hooks?)
	local spec = SwordSkillFxConfig.LOOKS[look]
	local root = rootOf(character)
	if not spec or not root then
		return
	end
	if look == "sunfallCleave" and spec.beats then
		sunfallCleave(character, root, spec, colors, scale, aim, hooks or {})
		return
	elseif look == "thornline" and spec.beats then
		thornline(root, spec, colors, scale, aim, hooks or {})
		return
	end
	local feet = root.Position - Vector3.new(0, ROOT_TO_GROUND - GROUND_LIFT, 0)
	local size = spec.size * scale
	if spec.form == "around" then
		sketch(CFrame.new(feet), size, size, spec, colors, scale)
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
		sketch(CFrame.new(Vector3.new(aim.X, feet.Y, aim.Z)), size, size, spec, colors, scale)
		return
	end
	local middle = feet + direction * size / 2
	sketch(CFrame.lookAt(middle, middle + direction), size * 0.25, size, spec, colors, scale)
end

return SwordSkillFx
