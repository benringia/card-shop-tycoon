--!strict
-- Checkout panel: shows the running total and how many items are left to scan,
-- and the Charge button once everything is scanned. Scanning itself is tapping items on the counter.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local UIKit = require((Controllers.Parent :: Instance):WaitForChild("Util"):WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local RegisterController = {}

local panel: Frame
local statusLabel: TextLabel
local chargeButton: TextButton

local function onUpdate(total: number?, remaining: number)
	if total == nil then
		panel.Visible = false
		return
	end
	panel.Visible = true
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
end

return RegisterController
