--!strict
-- Titles over players' names (every place): a player's Title attribute (BossService: "Dungeon Conqueror" for clearing
-- the Prism Hydra, from their saved first clear) shown in gold above their character's head.
local Players = game:GetService("Players")

local TitleController = {}

local TITLE_COLOR = Color3.fromRGB(255, 205, 80)
local OFFSET = Vector3.new(0, 3.2, 0) -- above Roblox's own name tag
local SIZE = UDim2.fromOffset(220, 26)
local MAX_DISTANCE = 80

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
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return TitleController
