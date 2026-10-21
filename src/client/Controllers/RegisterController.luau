--!strict
-- Checkout panel: shows the running total and how many items are left to scan,
-- and the Charge button once everything is scanned. Scanning itself is tapping items on the counter.
-- It only shows while you're at your register: elsewhere (or while a cashier card serves) it stays hidden.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RegisterConfig = require(Shared:WaitForChild("Config"):WaitForChild("Register"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local UIKit = require((Controllers.Parent :: Instance):WaitForChild("Util"):WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local NEAR_CHECK_SECONDS = 0.25

local player = Players.LocalPlayer

local RegisterController = {}

local panel: Frame
local statusLabel: TextLabel
local chargeButton: TextButton
local checkoutOpen = false -- the server says a customer is being checked out

-- Your own plot's register, if you have a plot
local function getRegister(): BasePart?
	local plotId = player:GetAttribute("PlotId")
	local plots = workspace:FindFirstChild("Plots")
	local plot = if typeof(plotId) == "number" and plots then plots:FindFirstChild("Plot" .. plotId) else nil
	local register = if plot then plot:FindFirstChild("Register", true) else nil
	return if register and register:IsA("BasePart") then register else nil
end

local function isAtRegister(): boolean
	local register = getRegister()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return register ~= nil and root ~= nil and (root.Position - register.Position).Magnitude <= RegisterConfig.REACH
end

local function updateVisible()
	panel.Visible = checkoutOpen and isAtRegister()
end

local function onUpdate(total: number?, remaining: number)
	checkoutOpen = total ~= nil
	updateVisible()
	if total == nil then
		return
	end
	if remaining > 0 then
		statusLabel.Text = string.format("Tap items on the counter\n%d left · $%.2f", remaining, total)
		chargeButton.Visible = false
	else
		statusLabel.Text = "All scanned!"
		chargeButton.Text = string.format("Charge $%.2f", total)
		chargeButton.Visible = true
	end
end

local function buildPanel(parent: Instance)
	panel = Instance.new("Frame")
	panel.Name = "Checkout"
	-- Middle-right, clear of the Build/Prices buttons and the mobile jump button
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -12, 0.5, 0)
	panel.Size = UDim2.fromOffset(200, 140)
	panel.BackgroundColor3 = UIKit.Colors.Panel
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.Parent = parent
	UIKit.corner(panel, 12)

	statusLabel = UIKit.label(panel, "", Enum.Font.GothamBold, 16, UIKit.Colors.Text)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center
	statusLabel.Position = UDim2.fromOffset(10, 8)
	statusLabel.Size = UDim2.new(1, -20, 0, 52)

	chargeButton = UIKit.button(panel, "", UIKit.Colors.Accent)
	chargeButton.Name = "Charge"
	chargeButton.AnchorPoint = Vector2.new(0.5, 1)
	chargeButton.Position = UDim2.new(0.5, 0, 1, -10)
	chargeButton.Size = UDim2.new(1, -20, 0, 56)
	chargeButton.Visible = false
	chargeButton.Activated:Connect(function()
		Remotes.Charge:FireServer()
	end)
end

function RegisterController.Start()
	buildPanel(UIController.GetScreenGui())
	Remotes.CheckoutUpdate.OnClientEvent:Connect(onUpdate)
	task.spawn(function()
		while true do
			task.wait(NEAR_CHECK_SECONDS)
			if checkoutOpen then
				updateVisible()
			end
		end
	end)
end

return RegisterController
