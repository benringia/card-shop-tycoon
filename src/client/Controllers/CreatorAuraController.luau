--!strict
-- The Creator aura (owner 2026-11-27: "Dev exclusive title and aura", pick C; spec
-- docs/superpowers/specs/2026-11-27-live-admin-creator-design.md; Config/CreatorAura): every player whose CreatorAura
-- attribute is on (TitleService: the game's owner wearing the Creator title) gets three card backs circling them, each
-- over a gold glow, drawn on this screen as BillboardGuis on Attachments in their HumanoidRootPart and moved every frame
-- (Shared/Util/CreatorAuraRules). In 3D they shrink with distance and hide behind the character by themselves. Your own
-- hides while you man your register (its first-person view would have cards flying through it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CardDesign = require(Config:WaitForChild("CardDesign"))
local GradeLook = require(Config:WaitForChild("GradeLook"))
local CreatorAura = require(Config:WaitForChild("CreatorAura"))
local CreatorAuraRules = require(Shared:WaitForChild("Util"):WaitForChild("CreatorAuraRules"))

local CreatorAuraController = {}

local auras: { [Player]: { Attachment } } = {}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function billboard(name: string, w: number, h: number, parent: Instance): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromScale(w, h)
	gui.LightInfluence = 0
	gui.MaxDistance = CreatorAura.MAX_DISTANCE
	gui.Parent = parent
	return gui
end

-- One card on its own Attachment (owner: "make the cards around me glow"): a gold halo on its own layer, lit past
-- white so it glows in daylight and breathing, a hair behind the card; the card back with a gold rim; a small gold
-- light; a trail of glowing sparkles as it circles
local function makeCard(root: BasePart, index: number): Attachment
	local glow = CreatorAura.GLOW
	local size = CreatorAura.CARD
	local attachment = Instance.new("Attachment")
	attachment.Name = `CreatorAuraCard{index}`

	local margin = 2 * glow.reach * size.w -- the glow picture is a card with `reach` round it, stretched over this
	local haloGui = billboard("Glow", size.w + margin, size.h + margin, attachment)
	haloGui.Brightness = glow.brightness
	haloGui.StudsOffset = Vector3.new(0, 0, -0.05) -- behind the card from wherever it's seen
	local halo = Instance.new("ImageLabel")
	halo.Name = "Halo"
	halo.BackgroundTransparency = 1
	halo.Size = UDim2.fromScale(1, 1)
	halo.Image = GradeLook.IMAGES.glow
	halo.ImageColor3 = rgb(glow.color)
	halo.ImageTransparency = glow.transparency
	halo.Parent = haloGui
	TweenService:Create(
		halo,
		TweenInfo.new(glow.breathe.seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, (index - 1) * 0.4),
		{ ImageTransparency = glow.breathe.high }
	):Play()

	local cardGui = billboard("Card", size.w, size.h, attachment)
	local card = Instance.new("ImageLabel")
	card.Name = "Back"
	card.BackgroundTransparency = 1
	card.Size = UDim2.fromScale(1, 1)
	card.Image = CardDesign.BACK.IMAGE
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(CreatorAura.CORNER, 0)
	corner.Parent = card
	local rim = Instance.new("UIStroke")
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Color = rgb(CreatorAura.RIM.color)
	rim.Thickness = CreatorAura.RIM.thickness
	rim.Parent = card
	card.Parent = cardGui

	local light = Instance.new("PointLight")
	light.Color = rgb(CreatorAura.LIGHT.color)
	light.Brightness = CreatorAura.LIGHT.brightness
	light.Range = CreatorAura.LIGHT.range
	light.Shadows = false
	light.Parent = attachment

	local spark = CreatorAura.SPARKLES
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = spark.texture
	sparkles.Color = ColorSequence.new(rgb(spark.color))
	sparkles.LightEmission = spark.lightEmission
	sparkles.Rate = spark.rate
	sparkles.Lifetime = NumberRange.new(spark.lifetime * 0.7, spark.lifetime)
	sparkles.Speed = NumberRange.new(spark.speed)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, spark.size),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Transparency = NumberSequence.new(0.1, 1)
	sparkles.Parent = attachment

	attachment.Parent = root
	return attachment
end

local function clear(player: Player)
	local cards = auras[player]
	if cards then
		for _, attachment in cards do
			attachment:Destroy()
		end
		auras[player] = nil
	end
end

-- Draws or takes away the aura to match the player's attribute and character now
local function refresh(player: Player)
	clear(player)
	if player:GetAttribute("CreatorAura") ~= true then
		return
	end
	if player == Players.LocalPlayer and player:GetAttribute("ManningRegister") == true then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	local cards = {}
	for index = 1, CreatorAura.COUNT do
		table.insert(cards, makeCard(root, index))
	end
	auras[player] = cards
end

-- Once the character's HumanoidRootPart is there (it can stream in a moment after the character)
local function refreshWhenReady(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	if player.Character == character then
		refresh(player)
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("CreatorAura"):Connect(function()
		refresh(player)
	end)
	if player == Players.LocalPlayer then
		player:GetAttributeChangedSignal("ManningRegister"):Connect(function()
			refresh(player)
		end)
	end
	player.CharacterAdded:Connect(function(character)
		refreshWhenReady(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		clear(player)
	end)
	local character = player.Character
	if character then
		task.spawn(refreshWhenReady, player, character)
	end
end

function CreatorAuraController.Start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	RunService.RenderStepped:Connect(function()
		if next(auras) == nil then
			return
		end
		local t = os.clock()
		for _, cards in auras do
			for index, attachment in cards do
				local x, y, z = CreatorAuraRules.place(CreatorAura, t, index)
				attachment.Position = Vector3.new(x, y, z)
			end
		end
	end)
end

return CreatorAuraController
