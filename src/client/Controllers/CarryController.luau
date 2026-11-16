--!strict
-- Drop button (and G key) shown while carrying a box. The server puts the box back on the delivery pad.
-- To Bag (and Y) while the box in your hands holds packs or deck boxes: they go in your Bag, to open anywhere (owner
-- 2026-11-17: "they will never have to go back to the delivery to pickup packs to rip"; server StockService). Its icon
-- is a gold pack and a down arrow by the backpack (Config/IconStacks ToBag, owner's pick B), and the first few boxes of
-- packs bring a bubble with Pish's face over it (Util/TileTip; the server's "ToBagTip", Config/Tips TO_BAG).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Items = require(Shared:WaitForChild("Config"):WaitForChild("Items"))
local Tips = require(Shared:WaitForChild("Config"):WaitForChild("Tips"))
local ItemRules = require(Shared:WaitForChild("Util"):WaitForChild("ItemRules"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local Hud = require(ClientUtil:WaitForChild("Hud"))
local TileTip = require(ClientUtil:WaitForChild("TileTip"))

local DROP_KEY = Enum.KeyCode.G
local BAG_KEY = Enum.KeyCode.Y

local player = Players.LocalPlayer

local CarryController = {}

local dropButton: TextButton
local bagButton: TextButton

local function isCarrying(): boolean
	local count = player:GetAttribute("CarryCount")
	return typeof(count) == "number" and count > 0
end

-- The box in your hands holds packs or deck boxes (a Bag item: Config/Items `stock`)
local function carriesPacks(): boolean
	return isCarrying() and ItemRules.stockItem(Items, player:GetAttribute("CarryProductId")) ~= nil
end

local function drop()
	if isCarrying() then
		Remotes.DropBox:FireServer()
	end
end

local function toBag()
	if carriesPacks() then
		Remotes.BagBox:FireServer()
	end
end

local function refresh()
	dropButton.Visible = isCarrying()
	bagButton.Visible = carriesPacks()
	if bagButton.Visible and player:GetAttribute("ToBagTip") == true then
		TileTip.show(bagButton, Tips.TO_BAG.text)
	else
		TileTip.hide()
	end
end

function CarryController.Start()
	-- Tiles in the bottom row while carrying a box
	dropButton = Hud.tile({ id = "Drop", icon = "Box", label = "Drop", key = "G", group = "Context", order = 20, onClick = drop })
	bagButton = Hud.tile({ id = "ToBag", icon = "ToBag", label = "To Bag", key = "Y", group = "Context", order = 22, onClick = toBag })

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == DROP_KEY then
			drop()
		elseif input.KeyCode == BAG_KEY then
			toBag()
		end
	end)

	player:GetAttributeChangedSignal("CarryCount"):Connect(refresh)
	player:GetAttributeChangedSignal("CarryProductId"):Connect(refresh)
	player:GetAttributeChangedSignal("ToBagTip"):Connect(refresh)
	refresh()
end

return CarryController
