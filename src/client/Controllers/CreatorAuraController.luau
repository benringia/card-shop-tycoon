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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AttackFx = require(Config:WaitForChild("AttackFx"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local CreatorAura = require(Config:WaitForChild("CreatorAura"))
local CreatorAuraRules = require(Shared:WaitForChild("Util"):WaitForChild("CreatorAuraRules"))

local CreatorAuraController = {}

local auras: { [Player]: { Attachment } } = {}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- One card on its own Attachment: the gold glow behind, the card back over it
local function makeCard(root: BasePart, index: number): Attachment
	local glow = CreatorAura.GLOW
	local attachment = Instance.new("Attachment")
	attachment.Name = `CreatorAuraCard{index}`
	local gui = Instance.new("BillboardGui")
	gui.Name = "Card"
	gui.Size = UDim2.fromScale(CreatorAura.CARD.w * glow.size, CreatorAura.CARD.h * glow.size)
	gui.LightInfluence = 0
	gui.MaxDistance = CreatorAura.MAX_DISTANCE
	gui.Parent = attachment
	local halo = Instance.new("ImageLabel")
	halo.Name = "Glow"
	halo.BackgroundTransparency = 1
	halo.Size = UDim2.fromScale(1, 1)
	halo.Image = AttackFx.TEXTURES.glow
	halo.ImageColor3 = rgb(glow.color)
	halo.ImageTransparency = glow.transparency
	halo.Parent = gui
	local card = Instance.new("ImageLabel")
	card.Name = "Back"
	card.BackgroundTransparency = 1
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(1 / glow.size, 1 / glow.size)
	card.Image = CardDesign.BACK.IMAGE
	card.ZIndex = 2
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(CreatorAura.CORNER, 0)
	corner.Parent = card
	card.Parent = gui
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
