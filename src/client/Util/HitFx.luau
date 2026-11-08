--!strict
-- Hit feel for the player's fight (spec 2026-11-02-you-in-the-fight-design; the sword-moves round's effects, spec
-- 2026-11-04-sword-moves-design): sparks where a sword hit lands, a quick glow over what was hit, the candy sparkle arc
-- on every swing, a star burst on a hit, a ring snapping out on a big one, the dash slash's cut lines and the
-- finisher's dust puff (Config/SwordFx; colours from Config/Swords slash). Effects live under the camera (yours only)
-- and clean themselves up. Hit-stop, shake and the damage numbers are the callers' (SwordAnims, BattleController).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("Config"):WaitForChild("AttackFx"))
local SwordFx = require(Shared:WaitForChild("Config"):WaitForChild("SwordFx"))
local SwordArcRules = require(Shared:WaitForChild("Util"):WaitForChild("SwordArcRules"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))
local PackHit = require((script.Parent :: Instance):WaitForChild("PackHit"))

local HitFx = {}

-- A swing's arc (Config/SwordFx ARCS)
export type ArcLook = {
	tilt: number,
	yaw: number,
	radius: number,
	start: number,
	sweep: number,
	up: number,
	ahead: number,
	from: number,
	wipe: number,
	fade: number,
	width: number,
}
export type SlashLook = { color: { number }, scale: number }

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local WHITE = Color3.new(1, 1, 1)

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function keypoint(time: number, value: number): NumberSequenceKeypoint
	return NumberSequenceKeypoint.new(time, value)
end

-- The camera's folder of sword effects (local to your screen)
local function fxFolder(): Instance
	local camera = workspace.CurrentCamera
	local folder = camera:FindFirstChild("SwordFx")
	if folder then
		return folder
	end
	local made = Instance.new("Folder")
	made.Name = "SwordFx"
	made.Parent = camera
	return made
end

-- An invisible anchored part at `cframe` holding an effect's attachments and emitters, gone after `life` seconds
local function holder(cframe: CFrame, life: number): BasePart
	local part = Instance.new("Part")
	part.Name = "SwordFxHolder"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = cframe
	part.Parent = fxFolder()
	Debris:AddItem(part, life)
	return part
end

-- A glowing particle emitter that only bursts when told (Emit)
local function burster(parent: Instance, texture: string, tint: ColorSequence, lifetime: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = tint
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Lifetime = NumberRange.new(lifetime)
	emitter.Speed = NumberRange.new(0)
	emitter.Rate = 0
	emitter.ZOffset = 1 -- toward the camera: a big boss doesn't swallow it
	emitter.Parent = parent
	return emitter
end

-- A burst of sparks at a point
function HitFx.sparks(position: Vector3)
	local part = holder(CFrame.new(position), 1)
	local emitter = burster(part, SPARK_TEXTURE, ColorSequence.new(color(SwordFx.SPARK_COLOR)), 0)
	emitter.Size = NumberSequence.new({ keypoint(0, 0.6), keypoint(1, 0) })
	emitter.Lifetime = NumberRange.new(0.15, 0.35)
	emitter.Speed = NumberRange.new(12, 22)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 6
	emitter.ZOffset = 0
	emitter:Emit(SwordFx.SPARKS)
end

-- A swing's candy sparkle arc, from where you stand (`origin`, your root's CFrame) as it starts: a Beam bent into a
-- circular arc in the swing's plane (SwordArcRules.curveSize), in the sword's slash colour with a white core, wiped
-- along the way the swing goes, shedding stars from its head, then fading
function HitFx.swingArc(origin: CFrame, arc: ArcLook, slash: SlashLook)
	local radius = arc.radius * slash.scale
	local stars = SwordFx.ARC_STARS
	local plane = origin * CFrame.new(0, arc.up, -arc.ahead) * CFrame.Angles(0, math.rad(arc.yaw), 0) * CFrame.Angles(0, 0, math.rad(arc.tilt))
	local part = holder(plane, arc.wipe + arc.fade + stars.life[2])
	-- In the plane's space the circle lies in X (right) and -Z (ahead); each end's X axis runs along the arc
	local function frameAt(t: number): CFrame
		local x, y = SwordArcRules.point(radius, arc.start, arc.sweep, t)
		local tx, ty = SwordArcRules.tangent(arc.start, arc.sweep, t)
		return CFrame.fromMatrix(Vector3.new(x, 0, -y), Vector3.new(tx, 0, -ty), Vector3.yAxis)
	end
	local first, last, head = Instance.new("Attachment"), Instance.new("Attachment"), Instance.new("Attachment")
	first.CFrame, last.CFrame, head.CFrame = frameAt(0), frameAt(1), frameAt(0)
	first.Parent, last.Parent, head.Parent = part, part, part
	local curve = SwordArcRules.curveSize(radius, arc.sweep)
	local tint = color(slash.color)
	local function beam(width: number, beamColor: Color3, glow: number, zOffset: number): Beam
		local made = Instance.new("Beam")
		made.Attachment0, made.Attachment1 = first, last
		made.CurveSize0, made.CurveSize1 = curve, curve
		made.Texture = SwordFx.TEXTURES.crescent
		made.TextureMode = Enum.TextureMode.Stretch
		made.TextureLength = 1
		made.Width0, made.Width1 = width, width
		made.Color = ColorSequence.new(beamColor)
		made.LightEmission = glow
		made.LightInfluence = 0
		made.FaceCamera = true
		made.Segments = 24
		made.ZOffset = zOffset
		made.Transparency = NumberSequence.new(1)
		made.Parent = part
		return made
	end
	local width = arc.width * slash.scale
	local body = beam(width, tint, SwordFx.ARC_GLOW, 0)
	local core = beam(width * SwordFx.ARC_CORE, WHITE, 1, 0.05)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SwordFx.TEXTURES.star
	emitter.Color = ColorSequence.new(WHITE, tint)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ keypoint(0, 0), keypoint(0.25, stars.size * slash.scale), keypoint(1, 0) })
	emitter.Lifetime = NumberRange.new(stars.life[1], stars.life[2])
	emitter.Speed = NumberRange.new(stars.speed[1], stars.speed[2])
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -stars.fall, 0)
	emitter.Drag = 2
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-120, 120)
	emitter.Rate = stars.rate
	emitter.Parent = head
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		local t = math.min(1, elapsed / arc.wipe)
		local progress = 1 - (1 - t) * (1 - t) -- a snapped swing: fast, then easing in
		local fade = math.clamp((elapsed - arc.wipe) / arc.fade, 0, 1)
		local keypoints = {}
		for index, point in SwordArcRules.wipe(progress, SwordFx.ARC_TRAIL, SwordFx.ARC_SOFT, fade) do
			keypoints[index] = keypoint(point[1], point[2])
		end
		local sequence = NumberSequence.new(keypoints)
		body.Transparency, core.Transparency = sequence, sequence
		head.CFrame = frameAt(progress)
		emitter.Enabled = t < 1
		if (fade >= 1 or not part.Parent) and connection then
			connection:Disconnect()
		end
	end)
end

-- A hit's spiky star burst popping out at `at` (the burst flipbook), `size` studs, a white core over the tint
function HitFx.burst(at: Vector3, size: number, tint: Color3)
	local seconds = SwordFx.BURST.seconds
	local part = holder(CFrame.new(at), seconds + 0.2)
	for _, layer in { { tint, size }, { WHITE, size * 0.55 } } do
		local emitter = burster(part, SwordFx.TEXTURES.burst, ColorSequence.new(layer[1] :: Color3), seconds)
		emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		emitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		emitter.Size = NumberSequence.new(layer[2] :: number)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter:Emit(1)
	end
end

-- How big a hit's effects are on `model` (Util/PackHit.scaleFor: from its size; 1 with no model)
function HitFx.scaleFor(model: Model?): number
	return PackHit.scaleFor(model)
end

-- A landed cut's impact at `at` (Util/PackHit: the packs' slash streaks in `tint`, the weapon's colour, and
-- `element`'s own particles, ELEMENT_HIT), under your camera, sizes and speeds `scale` times the packs'
function HitFx.impact(at: Vector3, scale: number, tint: Color3, element: string?)
	PackHit.play(fxFolder(), at, scale, tint, element, true, 1)
end

-- A ring snapping out from `at` to `size` studs across, facing you (a big hit; flat ground rings are the boss's)
function HitFx.ring(at: Vector3, size: number, tint: Color3)
	local seconds = SwordFx.RING.seconds
	local part = holder(CFrame.new(at), seconds + 0.2)
	local emitter = burster(part, AttackFx.TEXTURES.ring, ColorSequence.new(WHITE, tint), seconds)
	emitter.Size = NumberSequence.new({ keypoint(0, size * 0.15), keypoint(0.35, size * 0.8), keypoint(1, size) })
	emitter.Transparency = NumberSequence.new({ keypoint(0, 0), keypoint(0.5, 0.3), keypoint(1, 1) })
	emitter:Emit(1)
end

-- The dash slash's two crossing cut lines on a foe at `at`, `scale` times their size: a beat after the hit they grow
-- out across it (facing your camera), hold and fade
function HitFx.cutLines(at: Vector3, scale: number, tint: Color3)
	local cfg = SwordFx.CUT_LINES
	local view = workspace.CurrentCamera.CFrame
	local half = cfg.length * scale / 2
	local life = cfg.delay + cfg.grow * 2 + cfg.hold + cfg.fade
	local part = holder(CFrame.new(at), life + 0.1)
	local lines = {}
	for index, angle in { cfg.angle, -cfg.angle } do
		local direction = view.RightVector * math.cos(math.rad(angle)) + view.UpVector * math.sin(math.rad(angle))
		local first, last = Instance.new("Attachment"), Instance.new("Attachment")
		first.Parent, last.Parent = part, part
		local line = Instance.new("Beam")
		line.Attachment0, line.Attachment1 = first, last
		line.Texture = SwordFx.TEXTURES.line
		line.TextureMode = Enum.TextureMode.Stretch
		line.TextureLength = 1
		line.Width0, line.Width1 = cfg.width * scale, cfg.width * scale
		line.Color = ColorSequence.new(WHITE, tint)
		line.LightEmission = 1
		line.LightInfluence = 0
		line.FaceCamera = true
		line.Transparency = NumberSequence.new(1)
		line.Parent = part
		-- the second line a beat after the first
		table.insert(lines, { first = first, last = last, beam = line, direction = direction, at = cfg.delay + (index - 1) * cfg.grow })
	end
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		local done = true
		for _, line in lines do
			local since = elapsed - line.at
			local grow = math.clamp(since / cfg.grow, 0, 1)
			local fade = math.clamp((since - cfg.grow - cfg.hold) / cfg.fade, 0, 1)
			line.first.Position = -line.direction * half * grow
			line.last.Position = line.direction * half * grow
			line.beam.Transparency = NumberSequence.new(if since < 0 then 1 else fade)
			done = done and fade >= 1
		end
		if (done or not part.Parent) and connection then
			connection:Disconnect()
		end
	end)
end

-- The finisher landing: a dust ring spreading on the ground at `at` (your feet) and a few puffs
function HitFx.dust(at: Vector3)
	local cfg = SwordFx.DUST
	local tint = color(cfg.color)
	ElementFx.ring(at + Vector3.new(0, 0.2, 0), tint, cfg.radius, cfg.seconds)
	local part = holder(CFrame.new(at + Vector3.new(0, 0.5, 0)), 1)
	local puffs = burster(part, AttackFx.TEXTURES.smoke, ColorSequence.new(tint), 0)
	puffs.Lifetime = NumberRange.new(0.4, 0.6)
	puffs.Speed = NumberRange.new(6, 9)
	puffs.SpreadAngle = Vector2.new(80, 80)
	puffs.Drag = 5
	puffs.Size = NumberSequence.new({ keypoint(0, 1.2), keypoint(1, 3) })
	puffs.Transparency = NumberSequence.new({ keypoint(0, 0.35), keypoint(1, 1) })
	puffs.LightEmission = 0
	puffs.ZOffset = 0
	puffs:Emit(cfg.puffs)
end

-- A glow over a model (or part) fading from `strongest` (fill transparency) to nothing over `seconds`
function HitFx.flash(target: Instance, tint: Color3, seconds: number, strongest: number)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = tint
	highlight.OutlineTransparency = 1
	highlight.FillTransparency = strongest
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = target
	highlight.Parent = target
	TweenService:Create(highlight, TweenInfo.new(seconds), { FillTransparency = 1 }):Play()
	Debris:AddItem(highlight, seconds + 0.05)
end

return HitFx
