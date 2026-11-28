--!strict
-- Players' name tags (every place): a player's Title attribute (TitleService: "Hydra Slayer" for clearing the Prism
-- Hydra, a supporter's "Legend"...) small in its gradient (Config/Titles) with their name under it, in place of
-- Roblox's own name tag. Your own hides on your
-- screen while a tour leads (the owner 2026-11-11: "hide the title and creature tag only on tutorial"), at your register
-- and in your own fight (owner 2026-11-20, the combat HUD tidy; TitleRules.ownTag).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Chikin = require(Shared:WaitForChild("Config"):WaitForChild("Chikin"))
local Titles = require(Shared:WaitForChild("Config"):WaitForChild("Titles"))
local Vip = require(Shared:WaitForChild("Config"):WaitForChild("Vip"))
local TitleRules = require(Shared:WaitForChild("Util"):WaitForChild("TitleRules"))
local TutorialRules = require(Shared:WaitForChild("Util"):WaitForChild("TutorialRules"))
local TitleGradient = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("TitleGradient"))

local TitleController = {}

-- Small and in studs (owner 2026-11-12: "lets do gradient, and shorter", pick B): it shrinks with distance like the
-- player does; the gradient left to right, supporter titles' turning slowly. The player's name sits right under it in
-- the same font (owner 2026-11-13: "should we add player name below title?"), in place of Roblox's own name tag, so
-- title and name are one tag; a player with no title gets the name alone, where Roblox's was (`nameUp` over the head)
local TAG = {
	width = 6,
	titleHeight = 0.62,
	nameHeight = 0.5,
	nameUp = 1.75,
	maxTitle = 20,
	maxName = 17,
	maxDistance = 80,
	shimmerSeconds = 4,
	stroke = 0.25,
}
local FALLBACK = { { 255, 225, 110 }, { 255, 160, 50 } } -- a title missing from Config/Titles: gold
local STROKE = Color3.fromRGB(55, 30, 20)
local NAME_STROKE = Color3.fromRGB(30, 25, 45)

-- Whether `player`'s tag shows on this screen: everyone's, and your own unless a tour leads, you man your register
-- (in first person it hung across the top of the view, QA 2026-11-17) or you're in a fight (BattleController's FightHud)
local function shownHere(player: Player): boolean
	if player ~= Players.LocalPlayer then
		return true
	end
	local pish, combat = player:GetAttribute("TutorialStep"), player:GetAttribute("CombatStep")
	return TitleRules.ownTag({
		fight = player:GetAttribute("FightHud") == true,
		register = player:GetAttribute("ManningRegister") == true,
		tour = TutorialRules.tourLeading(if typeof(pish) == "string" then pish else "", if typeof(combat) == "string" then combat else "", Chikin.WAIT_STEP),
	})
end

local function text(parent: Instance, value: string, most: number): TextLabel
	local made = Instance.new("TextLabel")
	made.BackgroundTransparency = 1
	made.Font = Enum.Font.FredokaOne
	made.TextScaled = true
	made.Text = value
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = most
	cap.Parent = made
	made.Parent = parent
	return made
end

-- The title's line: its icon in its own colours (a gradient would tint it) just left of the name in its gradient
local function titleLine(parent: Frame, title: string, look: any)
	local label = text(parent, title, TAG.maxTitle)
	label.Size = UDim2.fromScale(1, 1)
	label.TextColor3 = Color3.new(1, 1, 1) -- the gradient colours it
	label.TextStrokeColor3 = STROKE
	label.TextStrokeTransparency = TAG.stroke
	local colors = if look then look.gradient else FALLBACK
	local gradient = Instance.new("UIGradient")
	gradient.Color = TitleGradient.sequence(colors)
	gradient.Parent = label
	if look and look.shimmer then
		TweenService:Create(gradient, TweenInfo.new(TAG.shimmerSeconds, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 }):Play()
	end
	local icon = text(parent, if look then look.icon else "🏆", TAG.maxTitle)
	icon.AnchorPoint = Vector2.new(1, 0)
	local function place()
		local height = label.AbsoluteSize.Y
		local half = label.TextBounds.X / 2
		icon.Size = UDim2.new(0, height, 1, 0)
		label.Position = UDim2.fromOffset(height / 2, 0) -- the pair stays centred
		icon.Position = UDim2.new(0.5, height / 2 - half - height * 0.15, 0, 0)
	end
	label:GetPropertyChangedSignal("TextBounds"):Connect(place)
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()
end

-- A VIP's name (spec 2026-11-28-robux-round-design, tag B; Config/Vip NAME): the name in a gold gradient, top to bottom,
-- with a crown just left of it, the pair centred like a title's icon and words; the title row above stays theirs
local function vipName(label: TextLabel)
	local gradient = Instance.new("UIGradient")
	gradient.Color = TitleGradient.sequence(Vip.NAME.gradient)
	gradient.Rotation = 90
	gradient.Parent = label
	label.TextStrokeColor3 = Color3.fromRGB(Vip.NAME.stroke[1], Vip.NAME.stroke[2], Vip.NAME.stroke[3])
	local crown = text(label, Vip.NAME.crown, TAG.maxName)
	crown.Name = "Crown"
	crown.AnchorPoint = Vector2.new(1, 0)
	local function place()
		local height = label.AbsoluteSize.Y
		local half = label.TextBounds.X / 2
		crown.Size = UDim2.new(0, height, 1, 0)
		label.Position = UDim2.new(0, height / 2, 1, 0) -- the pair stays centred
		crown.Position = UDim2.new(0.5, -half - height * 0.15, 0, 0) -- just left of the name's first letter
	end
	label:GetPropertyChangedSignal("TextBounds"):Connect(place)
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()
end

local function show(player: Player)
	local character = player.Character
	local head = if character then character:FindFirstChild("Head") else nil
	if not character or not head then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- our tag shows the name
	end
	local old = head:FindFirstChild("TitleTag")
	if old then
		old:Destroy()
	end
	local raw = player:GetAttribute("Title")
	local title = if typeof(raw) == "string" and raw ~= "" then raw else nil
	local height = TAG.nameHeight + (if title then TAG.titleHeight else 0)
	local gui = Instance.new("BillboardGui")
	gui.Name = "TitleTag"
	gui.Enabled = shownHere(player)
	gui.Size = UDim2.new(TAG.width, 0, height, 0) -- studs, not pixels
	gui.StudsOffset = Vector3.new(0, TAG.nameUp - TAG.nameHeight / 2 + height / 2, 0) -- the name where Roblox's was
	gui.MaxDistance = TAG.maxDistance
	gui.LightInfluence = 0
	if title then
		local row = Instance.new("Frame")
		row.Name = "TitleRow"
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, TAG.titleHeight / height)
		row.Parent = gui
		local id = player:GetAttribute("TitleId")
		titleLine(row, title, if typeof(id) == "string" then Titles.ById[id] else nil)
	end
	local name = text(gui, player.DisplayName, TAG.maxName)
	name.Name = "NameRow"
	name.AnchorPoint = Vector2.new(0, 1)
	name.Position = UDim2.fromScale(0, 1)
	name.Size = UDim2.fromScale(1, TAG.nameHeight / height)
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeColor3 = NAME_STROKE
	name.TextStrokeTransparency = 0.3
	if player:GetAttribute("HasVIP") == true then
		vipName(name)
	end
	gui.Parent = head
end

local function watch(player: Player)
	for _, name in { "Title", "TitleId", "HasVIP" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			show(player)
		end)
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 5)
		show(player)
	end)
	show(player)
end

function TitleController.Start()
	-- A tour starting or ending, stepping onto your register or off it, a fight of yours: your own tag hides or comes back
	for _, name in { "TutorialStep", "CombatStep", "ManningRegister", "FightHud" } do
		Players.LocalPlayer:GetAttributeChangedSignal(name):Connect(function()
			show(Players.LocalPlayer)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return TitleController
