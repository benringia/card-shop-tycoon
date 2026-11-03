--!strict
-- A creature appearing, leaving and fainting (owner 2026-11-04, the picked looks; timings in Party.SUMMON_FX, curves in
-- Util/SummonMotion). Summon: a ring in its element colour and a pillar of light, then it pops up out of it with a bounce
-- and sparkles. Unsummon: it shrinks into a flash and a light flies back into its owner. Faint: a white flash, it tips
-- over (CreatureVisuals), dizzy stars circle its head, then it fades in a puff; it comes back (revive) when it's no
-- longer fainted. CreatureController calls these on the marker's SummonedAt stamp and its Unsummon / Fainted flags.
-- A summon dings softly and an unsummon whooshes where the creature is (Party.SUMMON_SOUNDS).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Party = require(Shared:WaitForChild("Config"):WaitForChild("Party"))
local SummonMotion = require(Shared:WaitForChild("Util"):WaitForChild("SummonMotion"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))

local SummonFx = {}

type Body = { model: Model, root: BasePart, cframe: CFrame, grow: number?, faintedAt: number? }

local CFG = Party.SUMMON_FX
local SOUNDS = Party.SUMMON_SOUNDS
local WHITE = Color3.new(1, 1, 1)
local DUST = Color3.fromRGB(200, 196, 190)
local STARS = { "⭐", "💫", "⭐" }

-- The latest faint or revive on each model: an older one's leftover animation stops (a revive mid-fade)
local tokens: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function bump(model: Model): number
	tokens[model] = (tokens[model] or 0) + 1
	return tokens[model]
end

-- Runs `each(t)` every frame for `seconds` (t from 0), then `done`
local function animate(seconds: number, each: (number) -> (), done: (() -> ())?)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		each(math.min(t, seconds))
		if t >= seconds then
			connection:Disconnect()
			if done then
				done()
			end
		end
	end)
end

-- Every part of the model drawn at this transparency share (client-side only)
local function fade(model: Model, share: number)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = share
		end
	end
end

local function flash(model: Model, color: Color3, strength: number, seconds: number)
	local glow = Instance.new("Highlight")
	glow.FillColor = color
	glow.FillTransparency = 1 - strength
	glow.OutlineTransparency = 1
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = model
	TweenService:Create(glow, TweenInfo.new(seconds), { FillTransparency = 1 }):Play()
	Debris:AddItem(glow, seconds + 0.05)
end

-- A summon or unsummon sound where the creature is: quiet and always at its set pitch (no random wobble, which made the
-- first chime sound busy)
local function play(spec: { id: string, volume: number, pitch: number }, at: Vector3)
	local anchor = Instance.new("Attachment")
	anchor.Position = at -- Terrain sits at the origin, so this is the world position
	anchor.Parent = workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = spec.id
	sound.Volume = spec.volume
	sound.PlaybackSpeed = spec.pitch
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMaxDistance = SOUNDS.range
	sound.Parent = anchor
	sound:Play()
	Debris:AddItem(anchor, 4)
end

local function ground(body: Body): Vector3
	return body.cframe.Position
end

-- Summoned: the ring and pillar, then it pops up out of them
function SummonFx.summon(body: Body, color: Color3)
	local at = ground(body)
	play(SOUNDS.summon, at)
	ElementFx.ring(at + Vector3.new(0, 0.2, 0), color, 2.6, CFG.pop + 0.2)
	ElementFx.pillar(at, color:Lerp(WHITE, 0.35), CFG.pillar, CFG.pop + 0.25, "glow")
	body.grow = SummonMotion.popScale(0, CFG.pop)
	task.delay(CFG.pop * 0.5, function()
		ElementFx.burst(at + Vector3.new(0, 1.5, 0), color, 0.9)
	end)
	animate(CFG.pop, function(t)
		body.grow = SummonMotion.popScale(t, CFG.pop)
	end, function()
		body.grow = nil
	end)
end

-- Unsummoned: it shrinks into a flash and a light flies back into `owner` (its owner's character, if there)
function SummonFx.unsummon(body: Body, color: Color3, owner: Model?)
	local from = body.root.Position
	play(SOUNDS.unsummon, from)
	flash(body.model, WHITE, 0.6, CFG.unsummon)
	animate(CFG.unsummon, function(t)
		body.grow = SummonMotion.shrinkScale(t, CFG.unsummon)
	end)
	local target = if owner then owner:FindFirstChild("HumanoidRootPart") else nil
	if target and target:IsA("BasePart") then
		ElementFx.projectile(from, function()
			return target.Position
		end, color, CFG.unsummon, 2, function(arrived)
			ElementFx.burst(arrived, color, 0.5)
		end, { scale = 0.7 })
	end
end

-- Fainted: a flash, dizzy stars round its head while it tips over, then a puff as it fades out. `quiet`: it was already
-- fainted when it came into view (no stars, just gone)
function SummonFx.faint(body: Body, quiet: boolean?)
	local token = bump(body.model)
	if quiet then
		fade(body.model, 1)
		return
	end
	flash(body.model, WHITE, 0.8, 0.3)
	local _, size = body.model:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "DizzyStars"
	gui.Size = UDim2.fromOffset(90, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.6, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = body.root
	gui.Parent = body.root
	local labels: { TextLabel } = {}
	for _, star in STARS do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromOffset(24, 24)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Text = star
		label.TextSize = 20
		label.Parent = gui
		table.insert(labels, label)
	end
	animate(CFG.stars, function(t)
		if tokens[body.model] ~= token then
			return
		end
		for index, label in labels do
			local angle = t * 6 + index * math.pi * 2 / #labels
			label.Position = UDim2.new(0.5, math.cos(angle) * 30, 0.5, math.sin(angle) * 9)
		end
	end, function()
		gui:Destroy()
		if tokens[body.model] ~= token then
			return -- revived meanwhile
		end
		local puff = ElementFx.emitter(body.root, "smoke", DUST, { size = { 2, 4 }, life = 0.7, speed = { 2, 4 }, spread = 180, start = 0.2, light = 0 })
		puff:Emit(14)
		Debris:AddItem(puff, 1)
		animate(CFG.fade, function(t)
			if tokens[body.model] == token then
				fade(body.model, t / CFG.fade)
			end
		end)
	end)
end

-- No longer fainted (the fight is over): back in view with a little pop
function SummonFx.revive(body: Body)
	bump(body.model)
	fade(body.model, 0)
	local stars = body.root:FindFirstChild("DizzyStars")
	if stars then
		stars:Destroy()
	end
	animate(CFG.pop, function(t)
		body.grow = SummonMotion.popScale(t, CFG.pop)
	end, function()
		body.grow = nil
	end)
end

return SummonFx
