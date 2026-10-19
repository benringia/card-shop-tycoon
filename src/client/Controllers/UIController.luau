--!strict
-- Owns the main ScreenGui: the cash display and short toast messages.
-- Other controllers add their panels to UIController.GetScreenGui().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UIKit = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("UIKit"))

local TOAST_SECONDS = 2.5

local player = Players.LocalPlayer

local UIController = {}

local screenGui: ScreenGui
local cashLabel: TextLabel
local toastLabel: TextLabel
local toastToken = 0

local function formatCash(amount: number): string
	return string.format("$%.2f", amount)
end

local function updateCash()
	local cash = player:GetAttribute("Cash")
	cashLabel.Text = if typeof(cash) == "number" then formatCash(cash) else "$--"
end

function UIController.GetScreenGui(): ScreenGui
	return screenGui
end

function UIController.Notify(message: string, isError: boolean?)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	toastLabel.BackgroundColor3 = if isError then UIKit.Colors.Danger else UIKit.Colors.Accent
	toastLabel.Visible = true

	task.delay(TOAST_SECONDS, function()
		-- A newer toast replaced this one, leave it showing
		if toastToken == token then
			toastLabel.Visible = false
		end
	end)
end

function UIController.Start()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MainGui"
	screenGui.ResetOnSpawn = false
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
	player:GetAttributeChangedSignal("Cash"):Connect(updateCash)
	Remotes.Notify.OnClientEvent:Connect(UIController.Notify)
end

return UIController
