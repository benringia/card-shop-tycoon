--!strict
-- The glass cases' cards (UI project 3 spec section 3): every upright card the server places in a Glass Showcase or
-- Collector Case (a DisplayedCard part with the Upright attribute) slowly spins round its vertical axis and bobs, on
-- this client only, over a glowing pad in a metal ring with a light beam in its rarity colour; its back shows the card
-- back. The museum vitrine (owner 2026-11-14, concept B "with the glows and everything"): the beam reaches the case's
-- lid with a bright core, a light spirals up it trailing its colour (Util/CaseSwirl) and star sparkles rise round
-- the card. Cases further than Showcase.SPIN.RANGE from the camera stand still, their swirl and sparkles off.
-- CardEffectsController draws the face, the halo (it follows the card's CFrame) and the card's own sparkles.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CardEffects = require(Config:WaitForChild("CardEffects"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Showcase = require(Config:WaitForChild("Showcase"))
local CaseLayout = require(Config:WaitForChild("CaseLayout"))
local ShopDetail = require(Config:WaitForChild("ShopDetail"))

local CaseSwirl = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("CaseSwirl"))

local ClientUtil = ((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))

type Spinner = {
	case: BasePart, -- the case's hitbox part (the card's parent)
	offset: CFrame, -- the card's resting place in the case's space
	phase: number, -- so neighbouring cards don't turn in step
	still: boolean,
	pad: BasePart,
	ring: BasePart,
	swirl: BasePart, -- the spiralling light (its Trail draws the spiral)
	trail: Trail,
	sparkles: ParticleEmitter,
	reach: number, -- studs from the pad to the lid: the beam and the swirl stop there
	swirlCfg: CaseSwirl.Config, -- Showcase SPIN.SWIRL with its top under the lid
	lap: number,
}

local SPIN = Showcase.SPIN
local FLOAT = CaseLayout.UPRIGHT.float -- a card floats this far over its pad
local PHASE_STEP = 0.17 -- of a turn, between slots

local CaseSpinController = {}

local spinners: { [BasePart]: Spinner } = {}
local lights: Folder

local function rarityColor(card: typeof(Cards.List[1])): Color3
	if card.set == "Frontier" then
		return CardEffects.FRONTIER.AURORA[1]
	end
	local tier = Rarities.Tiers[card.rarity]
	return if tier then tier.color else Color3.new(1, 1, 1)
end

-- The card back on the part's back face, glowing like the front; from afar the card's own blue shows instead
-- (CardEffectsController)
local function drawBack(part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "CardBack"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = CardEffects.FACE_PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Brightness = CardEffects.FACE_BRIGHTNESS
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.MaxDistance = ShopDetail.FULL_CARD_DISTANCE
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	CardFace.renderBack(frame, stroke)
end

-- Where the pad sits: FLOAT under the card's feet at its resting place (a cylinder's axis is its X: stand it up), its
-- metal ring just under it
local function placePad(spinner: Spinner, card: BasePart)
	local rest = spinner.case.CFrame * spinner.offset
	spinner.pad.CFrame = rest * CFrame.new(0, -card.Size.Y / 2 - FLOAT + SPIN.PAD.X / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	spinner.ring.CFrame = spinner.pad.CFrame * CFrame.new(-SPIN.RING.X / 2, 0, 0)
end

local function lightPart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material
	part.Color = color
	part.Size = size
	return part
end

local function beam(pad: BasePart, foot: Attachment, top: Attachment, color: Color3, width: number, transparency: number)
	local ray = Instance.new("Beam")
	ray.Attachment0 = foot
	ray.Attachment1 = top
	ray.Color = ColorSequence.new(color)
	ray.Transparency = NumberSequence.new(transparency, 1)
	ray.Width0 = width
	ray.Width1 = width
	ray.FaceCamera = true
	ray.LightEmission = 1
	ray.Brightness = SPIN.BEAM_BRIGHTNESS
	ray.Segments = 1
	ray.Parent = pad
end

-- A glowing pad in a metal ring under the card, a beam of light rising from it to the lid (`reach` studs) with a
-- bright core, star sparkles rising and a light spiralling up, in the card's rarity colour
local function addLight(color: Color3, reach: number): (BasePart, BasePart, BasePart, Trail, ParticleEmitter)
	local ring = lightPart("CaseCardRing", SPIN.RING, SPIN.RING_COLOR, Enum.Material.Metal)
	ring.Shape = Enum.PartType.Cylinder
	local pad = Instance.new("Part")
	pad.Name = "CaseCardPad"
	pad.Shape = Enum.PartType.Cylinder
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanQuery = false
	pad.CanTouch = false
	pad.CastShadow = false
	pad.Material = Enum.Material.Neon
	pad.Color = color
	pad.Transparency = SPIN.PAD_TRANSPARENCY
	pad.Size = SPIN.PAD
	local foot = Instance.new("Attachment")
	foot.Parent = pad
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(reach, 0, 0) -- the pad's X is up
	top.Parent = pad
	beam(pad, foot, top, color, SPIN.BEAM_WIDTH, SPIN.BEAM_TRANSPARENCY)
	beam(pad, foot, top, color:Lerp(Color3.new(1, 1, 1), 0.5), SPIN.CORE_WIDTH, SPIN.CORE_TRANSPARENCY)
	-- star sparkles rising round the card (the attachment's X is the pad's: up)
	local spark = SPIN.SPARKLES
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = spark.image
	sparkles.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35))
	sparkles.LightEmission = 1
	sparkles.Brightness = spark.brightness
	sparkles.EmissionDirection = Enum.NormalId.Right
	sparkles.Rate = spark.rate
	sparkles.Lifetime = NumberRange.new(spark.lifetime[1], spark.lifetime[2])
	sparkles.Speed = NumberRange.new(spark.speed[1], spark.speed[2])
	sparkles.SpreadAngle = Vector2.new(spark.spread, spark.spread)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, spark.size),
		NumberSequenceKeypoint.new(0.6, spark.size * 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Rotation = NumberRange.new(0, 90)
	sparkles.Enabled = false
	sparkles.Parent = foot
	-- the spiralling light: a small glowing bead trailing its colour
	local bead = SPIN.SWIRL.bead
	local swirl = lightPart("CaseCardSwirl", Vector3.new(bead, bead, bead), color:Lerp(Color3.new(1, 1, 1), 0.4), Enum.Material.Neon)
	swirl.Shape = Enum.PartType.Ball
	local tail0, tail1 = Instance.new("Attachment"), Instance.new("Attachment")
	tail0.Position = Vector3.new(0, SPIN.SWIRL.width / 2, 0)
	tail1.Position = Vector3.new(0, -SPIN.SWIRL.width / 2, 0)
	tail0.Parent = swirl
	tail1.Parent = swirl
	local trail = Instance.new("Trail")
	trail.Attachment0 = tail0
	trail.Attachment1 = tail1
	trail.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Lifetime = SPIN.SWIRL.lifetime
	trail.LightEmission = 1
	trail.Brightness = SPIN.SWIRL.brightness
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = swirl
	pad.Parent = lights
	ring.Parent = lights
	swirl.Parent = lights
	return pad, ring, swirl, trail, sparkles
end

local function detach(part: BasePart)
	local spinner = spinners[part]
	if spinner then
		spinners[part] = nil
		spinner.pad:Destroy()
		spinner.ring:Destroy()
		spinner.swirl:Destroy()
	end
end

local function attach(instance: Instance)
	if not instance:IsA("BasePart") or instance:GetAttribute("Upright") ~= true or spinners[instance] then
		return
	end
	local case = instance.Parent
	local cardId = instance:GetAttribute("CardId")
	local card = if typeof(cardId) == "string" then Cards.ById[cardId] else nil
	if not card or not case or not case:IsA("BasePart") then
		return
	end
	local slot = instance:GetAttribute("Slot")
	-- the beam and the swirl stop just under the case's lid (the back row stands higher)
	local feet = case.CFrame:ToObjectSpace(instance.CFrame * CFrame.new(0, -instance.Size.Y / 2 - FLOAT, 0)).Y
	local reach = math.max(0.5, math.min(SPIN.BEAM_HEIGHT, case.Size.Y / 2 - feet - 0.1))
	local pad, ring, swirl, trail, sparkles = addLight(rarityColor(card), reach)
	local spinner: Spinner = {
		case = case,
		offset = case.CFrame:ToObjectSpace(instance.CFrame),
		phase = (if typeof(slot) == "number" then slot else 0) * PHASE_STEP,
		still = true,
		pad = pad,
		ring = ring,
		swirl = swirl,
		trail = trail,
		sparkles = sparkles,
		reach = reach,
		swirlCfg = {
			seconds = SPIN.SWIRL.seconds,
			turns = SPIN.SWIRL.turns,
			radius = SPIN.SWIRL.radius,
			bottom = SPIN.SWIRL.bottom,
			top = math.min(SPIN.SWIRL.top, reach),
		},
		lap = -1,
	}
	spinners[instance] = spinner
	placePad(spinner, instance)
	swirl.CFrame = pad.CFrame
	drawBack(instance)
	instance.Destroying:Connect(function()
		detach(instance)
	end)
	instance.AncestryChanged:Connect(function()
		if not instance:IsDescendantOf(workspace) then
			detach(instance)
		end
	end)
end

local function step()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local t = os.clock()
	local eye = camera.CFrame.Position
	for part, spinner in spinners do
		local rest = spinner.case.CFrame * spinner.offset
		if (rest.Position - eye).Magnitude <= SPIN.RANGE then
			local turn = (t / SPIN.SECONDS + spinner.phase) * math.pi * 2
			local bob = math.sin((t / SPIN.BOB_SECONDS + spinner.phase) * math.pi * 2) * SPIN.BOB
			part.CFrame = rest * CFrame.new(0, bob, 0) * CFrame.Angles(0, turn, 0)
			placePad(spinner, part)
			-- the light spirals up from the pad to the lid; a new lap jumps back down, so its trail starts afresh
			local at = CaseSwirl.point(t, spinner.phase, spinner.swirlCfg)
			spinner.swirl.CFrame = rest * CFrame.new(at.x, -part.Size.Y / 2 - FLOAT + at.y, at.z)
			if at.lap ~= spinner.lap then
				spinner.lap = at.lap
				spinner.trail:Clear()
			end
			if spinner.still then
				spinner.still = false
				spinner.trail.Enabled = true
				spinner.sparkles.Enabled = true
			end
		elseif not spinner.still then
			part.CFrame = rest
			spinner.still = true
			spinner.trail.Enabled = false
			spinner.sparkles.Enabled = false
		end
	end
end

function CaseSpinController.Start()
	lights = Instance.new("Folder")
	lights.Name = "CaseCardLights"
	lights.Parent = workspace
	local plots = workspace:WaitForChild("Plots")
	for _, descendant in plots:GetDescendants() do
		attach(descendant)
	end
	plots.DescendantAdded:Connect(attach)
	RunService.RenderStepped:Connect(step)
end

return CaseSpinController
