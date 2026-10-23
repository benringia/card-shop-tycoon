--!strict
-- Drop button (and G key) shown while carrying a box. The server puts the box back on the delivery pad.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local Hud = require(ClientUtil:WaitForChild("Hud"))

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
	-- An orange tile in the bottom row while carrying a box
	dropButton = Hud.tile({ id = "Drop", icon = "Box", label = "Drop", key = "G", group = "Context", order = 20, onClick = drop })

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == DROP_KEY then
			drop()
		end
	end)

	player:GetAttributeChangedSignal("CarryCount"):Connect(refresh)
	refresh()
end

return CarryController
