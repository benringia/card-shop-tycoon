--!strict
-- Drop button (and G key) shown while carrying a box. The server puts the box back on the delivery pad.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local UIKit = require((Controllers.Parent :: Instance):WaitForChild("Util"):WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local DROP_KEY = Enum.KeyCode.G

local player = Players.LocalPlayer

local CarryController = {}

local dropButton: TextButton

local function isCarrying(): boolean
	local count = player:GetAttribute("CarryCount")
	return typeof(count) == "number" and count > 0
end

local function drop()
	if isCarrying() then
		Remotes.DropBox:FireServer()
	end
end

local function refresh()
	dropButton.Visible = isCarrying()
end

function CarryController.Start()
	dropButton = UIKit.button(UIController.GetScreenGui(), "Drop (G)", UIKit.Colors.Danger)
	dropButton.Name = "DropButton"
	-- Under the Build and Prices buttons on the middle-left
	dropButton.AnchorPoint = Vector2.new(0, 0.5)
	dropButton.Position = UDim2.new(0, 12, 0.5, 140)
	dropButton.Size = UDim2.fromOffset(96, 50)
	dropButton.TextSize = 18
	dropButton.Activated:Connect(drop)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == DROP_KEY then
			drop()
		end
	end)

	player:GetAttributeChangedSignal("CarryCount"):Connect(refresh)
	refresh()
end

return CarryController
