--!strict
-- The creature comes alive on the opening stage (owner 2026-11-17, "do all"; Pokemon TCG Pocket's immersive cards;
-- Config/CardReveal CREATURE, RevealRules.comesAlive): an Epic, a Legendary, a Frontier card or a card the player never
-- had bursts out of its flipped card as its 3D creature, rises toward the camera, roars (a size pulse, its voice, a
-- burst), turns a little either way, then dives back into the card. Never in the way: OpeningCards clears it the moment
-- the player moves on.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local CardReveal = require(Config:WaitForChild("CardReveal"))
local Party = require(Config:WaitForChild("Party"))
local PetVoice = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("PetVoice"))

local ClientUtil = script.Parent :: Instance
local CreatureVisuals = require(ClientUtil:WaitForChild("CreatureVisuals"))
local OpeningStage = require(ClientUtil:WaitForChild("OpeningStage"))
local OpeningFx = require(ClientUtil:WaitForChild("OpeningFx"))

local OpeningCreature = {}

local ALIVE = CardReveal.CREATURE
local MIN_SCALE = 0.08

local current: Model? = nil
local stepper: RBXScriptConnection? = nil

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function backOut(x: number): number
	x = math.clamp(x, 0, 1)
	local c = 1.7
	return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2
end

function OpeningCreature.clear()
	if stepper then
		stepper:Disconnect()
		stepper = nil
	end
	if current then
		current:Destroy()
		current = nil
	end
end

-- Its creature out of the card that just landed at `card` (facing the camera), in `color`'s light
function OpeningCreature.play(cardName: string, rarity: string, card: CFrame, color: Color3)
	OpeningCreature.clear()
	local template = CreatureVisuals.cardTemplate(cardName)
	if not template then
		return
	end
	local model = template:Clone()
	CreatureVisuals.strip(model)
	CreatureVisuals.dress(model, cardName)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
	model:PivotTo(CFrame.new())
	local _, size = model:GetBoundingBox()
	local full = model:GetScale() * ALIVE.height / math.max(size.Y, 0.1)
	model:ScaleTo(full)
	-- where its middle sits from its pivot, at full size (scaling below keeps it in proportion)
	local centre = model:GetBoundingBox()
	local offset = model:GetPivot():ToObjectSpace(centre)
	model:ScaleTo(full * MIN_SCALE)
	model.Parent = OpeningStage.folder()
	current = model

	local toCamera = OpeningStage.home().Position - card.Position
	local toward = if toCamera.Magnitude > 0.1 then toCamera.Unit else Vector3.new(0, 0, -1)
	local start = card.Position
	local out = start + Vector3.new(0, ALIVE.rise, 0) + toward * ALIVE.toward
	local facing = card - card.Position -- the card's turn: its front toward the camera, as the creature's
	local popAt = os.clock()
	local holdEnd = ALIVE.popSeconds + ALIVE.holdSeconds
	local total = holdEnd + ALIVE.backSeconds
	local roared = false

	local function place(at: Vector3, scale: number, yaw: number)
		model:ScaleTo(full * math.max(scale, MIN_SCALE))
		local middle = CFrame.new(at) * facing * CFrame.Angles(0, math.rad(ALIVE.facing + yaw), 0)
		local scaledOffset = CFrame.new(offset.Position * math.max(scale, MIN_SCALE)) * offset.Rotation
		model:PivotTo(middle * scaledOffset:Inverse())
	end

	OpeningFx.burst(start, color, 1.2)
	OpeningStage.play("shimmer")
	stepper = RunService.RenderStepped:Connect(function()
		local t = os.clock() - popAt
		if t >= total then
			OpeningCreature.clear()
			return
		end
		if t < ALIVE.popSeconds then
			local p = backOut(t / ALIVE.popSeconds)
			place(start:Lerp(out, smooth(t / ALIVE.popSeconds)), p, 0)
		elseif t < holdEnd then
			local h = t - ALIVE.popSeconds
			if not roared then
				roared = true
				OpeningFx.burst(out, color, 1.6)
				OpeningStage.shake(0.06, 0.3)
				local voice = PetVoice.voice(rarity, #cardName, Party.VOICE)
				OpeningStage.playId("creature", voice, PetVoice.volume(rarity, Party.VOICE) * 1.6)
			end
			-- the roar's swell, then a slow look either way and a gentle bob
			local roar = if h < 0.3 then 1 + (ALIVE.roar - 1) * math.sin(h / 0.3 * math.pi) else 1
			local yaw = math.sin(h * 1.6) * ALIVE.turn
			local bob = Vector3.new(0, math.sin(h * 3) * 0.05, 0)
			place(out + bob, roar, yaw)
		else
			local b = smooth((t - holdEnd) / ALIVE.backSeconds)
			place(out:Lerp(start, b), 1 - b * (1 - MIN_SCALE), 0)
		end
	end)
end

return OpeningCreature
