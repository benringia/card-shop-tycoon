--!strict
-- Titles over players' names (every place): a player's Title attribute (BossService: "Dungeon Conqueror" for clearing
-- the Prism Hydra, from their saved first clear) shown in gold above their character's head. Your own hides on your
-- screen while a tour leads (the owner 2026-11-11: "hide the title and creature tag only on tutorial").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Chikin = require(Shared:WaitForChild("Config"):WaitForChild("Chikin"))
local TutorialRules = require(Shared:WaitForChild("Util"):WaitForChild("TutorialRules"))

local TitleController = {}

local TITLE_COLOR = Color3.fromRGB(255, 205, 80)
local OFFSET = Vector3.new(0, 3.2, 0) -- above Roblox's own name tag
local SIZE = UDim2.fromOffset(220, 26)
local MAX_DISTANCE = 80

-- Whether `player`'s title shows on this screen: everyone's but your own while a tour leads
local function shownHere(player: Player): boolean
	if player ~= Players.LocalPlayer then
		return true
	end
	local pish, combat = player:GetAttribute("TutorialStep"), player:GetAttribute("CombatStep")
	return not TutorialRules.tourLeading(if typeof(pish) == "string" then pish else "", if typeof(combat) == "string" then combat else "", Chikin.WAIT_STEP)
end

local function show(player: Player)
	local character = player.Character
	local head = if character then character:FindFirstChild("Head") else nil
	if not head then
		return
	end
	local old = head:FindFirstChild("TitleTag")
	if old then
		old:Destroy()
	end
	local title = player:GetAttribute("Title")
	if typeof(title) ~= "string" or title == "" then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "TitleTag"
	gui.Enabled = shownHere(player)
	gui.Size = SIZE
	gui.StudsOffset = OFFSET
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = TITLE_COLOR
	label.TextStrokeTransparency = 0.4
	label.Text = `🏆 {title}`
	label.Parent = gui
	gui.Parent = head
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("Title"):Connect(function()
		show(player)
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 5)
		show(player)
	end)
	show(player)
end

function TitleController.Start()
	-- A tour starting or ending: your own title hides or comes back
	for _, name in { "TutorialStep", "CombatStep" } do
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
