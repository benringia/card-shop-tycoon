--!strict
-- Owns the main ScreenGui: cash display, shop level / XP bar, and short toast messages.
-- Other controllers add their panels to UIController.GetScreenGui().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local LevelRules = require(Shared:WaitForChild("Util"):WaitForChild("LevelRules"))
local UIKit = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("UIKit"))

local TOAST_SECONDS = 2.5
local LEVEL_UP_TOAST_SECONDS = 5
local XP_FILL_COLOR = Color3.fromRGB(90, 160, 255)

local player = Players.LocalPlayer

local UIController = {}

local screenGui: ScreenGui
local cashLabel: TextLabel
local levelLabel: TextLabel
local xpLabel: TextLabel
local xpFill: Frame
local toastLabel: TextLabel
local toastToken = 0

local function getNumber(name: string, default: number): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function updateCash()
	local cash = player:GetAttribute("Cash")
	cashLabel.Text = if typeof(cash) == "number" then string.format("$%.2f", cash) else "$--"
end

local function updateXp()
	local xp = getNumber("XP", 0)
	levelLabel.Text = `Lv {getNumber("Level", 1)}`
	local into, span = LevelRules.getProgress(xp)
	if span then
		xpLabel.Text = `{into}/{span} XP`
		xpFill.Size = UDim2.fromScale(math.clamp(into / span, 0, 1), 1)
	else
		xpLabel.Text = "MAX"
		xpFill.Size = UDim2.fromScale(1, 1)
	end
end

function UIController.GetScreenGui(): ScreenGui
	return screenGui
end

function UIController.Notify(message: string, isError: boolean?, duration: number?)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	toastLabel.BackgroundColor3 = if isError then UIKit.Colors.Danger else UIKit.Colors.Accent
	toastLabel.Visible = true

	task.delay(duration or TOAST_SECONDS, function()
		-- A newer toast replaced this one, leave it showing
		if toastToken == token then
			toastLabel.Visible = false
		end
	end)
end

-- Several level-ups can arrive at once; show them one after another instead of overwriting
local levelUpQueue: { number } = {}
local showingLevelUps = false

local function showLevelUps()
	showingLevelUps = true
	while #levelUpQueue > 0 do
		local level = table.remove(levelUpQueue, 1) :: number
		local unlocks = LevelRules.getUnlocks(level)
		local message = if #unlocks > 0
			then `Level {level}! Unlocked: {table.concat(unlocks, ", ")}`
			else `Level {level}!`
		UIController.Notify(message, false, LEVEL_UP_TOAST_SECONDS)
		task.wait(LEVEL_UP_TOAST_SECONDS)
	end
	showingLevelUps = false
end

local function queueLevelUp(level: number)
	table.insert(levelUpQueue, level)
	if not showingLevelUps then
		task.spawn(showLevelUps)
	end
end

function UIController.Start()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MainGui"
	screenGui.ResetOnSpawn = false
	-- Children always draw above their parent; ZIndex only orders panels against each other.
	-- (The code default is Global, where a raised panel would cover its own contents.)
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player:WaitForChild("PlayerGui")

	cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "Cash"
	cashLabel.AnchorPoint = Vector2.new(0.5, 0)
	cashLabel.Position = UDim2.new(0.5, 0, 0, 8)
	cashLabel.Size = UDim2.fromOffset(180, 48)
	cashLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	cashLabel.BackgroundTransparency = 0.2
	cashLabel.Font = Enum.Font.FredokaOne
	cashLabel.TextColor3 = Color3.fromRGB(120, 230, 120)
	cashLabel.TextSize = 30
	cashLabel.Parent = screenGui
	UIKit.corner(cashLabel, 12)

	-- Level badge + XP bar under the cash display
	local xpBar = Instance.new("Frame")
	xpBar.Name = "XPBar"
	xpBar.AnchorPoint = Vector2.new(0.5, 0)
	xpBar.Position = UDim2.new(0.5, 0, 0, 62)
	xpBar.Size = UDim2.fromOffset(180, 26)
	xpBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	xpBar.BackgroundTransparency = 0.2
	xpBar.ClipsDescendants = true
	xpBar.Parent = screenGui
	UIKit.corner(xpBar, 8)

	xpFill = Instance.new("Frame")
	xpFill.Name = "Fill"
	xpFill.BackgroundColor3 = XP_FILL_COLOR
	xpFill.BorderSizePixel = 0
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.Parent = xpBar
	UIKit.corner(xpFill, 8)

	levelLabel = UIKit.label(xpBar, "Lv 1", Enum.Font.FredokaOne, 18, UIKit.Colors.Text)
	levelLabel.Position = UDim2.fromOffset(8, 0)
	levelLabel.Size = UDim2.new(0, 50, 1, 0)
	levelLabel.ZIndex = 2

	xpLabel = UIKit.label(xpBar, "", Enum.Font.GothamBold, 14, UIKit.Colors.Text)
	xpLabel.TextXAlignment = Enum.TextXAlignment.Right
	xpLabel.Position = UDim2.fromOffset(56, 0)
	xpLabel.Size = UDim2.new(1, -64, 1, 0)
	xpLabel.ZIndex = 2

	toastLabel = Instance.new("TextLabel")
	toastLabel.Name = "Toast"
	toastLabel.AnchorPoint = Vector2.new(0.5, 1)
	toastLabel.Position = UDim2.new(0.5, 0, 1, -24)
	toastLabel.Size = UDim2.new(0.9, 0, 0, 52)
	toastLabel.Font = Enum.Font.GothamBold
	toastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	toastLabel.TextSize = 20
	toastLabel.TextWrapped = true
	toastLabel.Visible = false
	toastLabel.ZIndex = 10
	toastLabel.Parent = screenGui
	UIKit.corner(toastLabel, 12)

	local toastSize = Instance.new("UISizeConstraint")
	toastSize.MaxSize = Vector2.new(480, math.huge)
	toastSize.Parent = toastLabel

	updateCash()
	updateXp()
	player:GetAttributeChangedSignal("Cash"):Connect(updateCash)
	player:GetAttributeChangedSignal("XP"):Connect(updateXp)
	player:GetAttributeChangedSignal("Level"):Connect(updateXp)
	Remotes.Notify.OnClientEvent:Connect(UIController.Notify)
	Remotes.LevelUp.OnClientEvent:Connect(queueLevelUp)
end

return UIController
