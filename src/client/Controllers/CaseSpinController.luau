--!strict
-- The glass cases' cards (UI project 3 spec section 3): every upright card the server places in a Glass Showcase or
-- Collector Case (a DisplayedCard part with the Upright attribute) slowly spins round its vertical axis and bobs, on
-- this client only, over a glowing pad with a light beam in its rarity colour; its back shows the card back. Cases
-- further than Showcase.SPIN.RANGE from the camera stand still. CardEffectsController draws the face, the halo (it
-- follows the card's CFrame) and the sparkles.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CardEffects = require(Config:WaitForChild("CardEffects"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Showcase = require(Config:WaitForChild("Showcase"))

local ClientUtil = ((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))

type Spinner = {
	case: BasePart, -- the case's hitbox part (the card's parent)
	offset: CFrame, -- the card's resting place in the case's space
	phase: number, -- so neighbouring cards don't turn in step
	still: boolean,
	pad: BasePart,
}

local SPIN = Showcase.SPIN
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

-- The card back on the part's back face, glowing like the front
local function drawBack(part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "CardBack"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = CardEffects.FACE_PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Brightness = CardEffects.FACE_BRIGHTNESS
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	CardFace.renderBack(frame, stroke)
end

-- Where the pad sits: on the bed under the card's feet at its resting place (a cylinder's axis is its X: stand it up)
local function padCFrame(spinner: Spinner, card: BasePart): CFrame
	local rest = spinner.case.CFrame * spinner.offset
	return rest * CFrame.new(0, -card.Size.Y / 2 + SPIN.PAD.X / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
end

-- A glowing pad under the card and a beam of light rising from it, in the card's rarity colour
local function addLight(color: Color3): BasePart
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
	top.Position = Vector3.new(SPIN.BEAM_HEIGHT, 0, 0) -- the pad's X is up
	top.Parent = pad
	local beam = Instance.new("Beam")
	beam.Attachment0 = foot
	beam.Attachment1 = top
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new(SPIN.BEAM_TRANSPARENCY, 1)
	beam.Width0 = SPIN.BEAM_WIDTH
	beam.Width1 = SPIN.BEAM_WIDTH
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Segments = 1
	beam.Parent = pad
	pad.Parent = lights
	return pad
end

local function detach(part: BasePart)
	local spinner = spinners[part]
	if spinner then
		spinners[part] = nil
		spinner.pad:Destroy()
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
	local spinner: Spinner = {
		case = case,
		offset = case.CFrame:ToObjectSpace(instance.CFrame),
		phase = (if typeof(slot) == "number" then slot else 0) * PHASE_STEP,
		still = true,
		pad = addLight(rarityColor(card)),
	}
	spinners[instance] = spinner
	spinner.pad.CFrame = padCFrame(spinner, instance)
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
			spinner.pad.CFrame = padCFrame(spinner, part)
			spinner.still = false
		elseif not spinner.still then
			part.CFrame = rest
			spinner.still = true
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
