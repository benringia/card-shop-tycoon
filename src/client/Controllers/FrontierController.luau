--!strict
-- Travel to and from the Frontier on this client. Main game: the plaza portal opens a menu (Explore, or Join a
-- friend who is in a Frontier server right now). Frontier: a home button (top centre) back to the shops.
-- The server checks everything and does the teleport (FrontierService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Places = require(Shared:WaitForChild("Config"):WaitForChild("Places"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local FrontierController = {}

local panel: Frame
local list: ScrollingFrame

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function addButton(order: number, text: string, color: Color3, onClick: () -> ()): TextButton
	local button = UIKit.button(list, text, color)
	button.LayoutOrder = order
	button.Size = UDim2.new(1, -6, 0, 52)
	button.TextSize = 16
	button.Activated:Connect(onClick)
	return button
end

local function note(order: number, text: string)
	local label = UIKit.label(list, text, Enum.Font.Gotham, 13, UIKit.Colors.Subtext)
	label.LayoutOrder = order
	label.Size = UDim2.new(1, -6, 0, 36)
	label.TextWrapped = true
end

-- Friends whose current place is the Frontier (Roblox's online-friends list, read on this client)
local function frontierFriends(): { { userId: number, name: string } }
	local found = {}
	if Places.FRONTIER_PLACE_ID == 0 then
		return found
	end
	local ok, friends = pcall(function()
		return Players.LocalPlayer:GetFriendsOnline(50)
	end)
	if ok and typeof(friends) == "table" then
		for _, friend in friends do
			if friend.PlaceId == Places.FRONTIER_PLACE_ID and typeof(friend.VisitorId) == "number" then
				table.insert(found, { userId = friend.VisitorId, name = friend.DisplayName or friend.UserName or "Friend" })
			end
		end
	end
	return found
end

local function openMenu()
	clear(list)
	note(1, "High-level monsters, Star Shards and Frontier-only cards. Recommended Lv 15+. Your shop pauses while you're away.")
	addButton(2, "Explore", UIKit.Colors.Accent, function()
		panel.Visible = false
		Remotes.FrontierTravel:FireServer("explore")
	end)
	note(3, "Join a friend")
	panel.Visible = true
	task.spawn(function()
		local friends = frontierFriends()
		if not panel.Visible then
			return
		end
		if #friends == 0 then
			note(4, "No friends in the Frontier right now.")
		end
		for index, friend in friends do
			addButton(3 + index, `Join {friend.name}`, UIKit.Colors.Row, function()
				panel.Visible = false
				Remotes.FrontierTravel:FireServer("friend", friend.userId)
			end)
		end
	end)
end

function FrontierController.Start()
	local screenGui = UIController.GetScreenGui()
	Remotes.FrontierTravel.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.open and not Place.isFrontier() then
			openMenu()
		elseif typeof(payload.message) == "string" then
			UIController.Notify(payload.message, true, 3)
		end
	end)

	if Place.isFrontier() then
		local home = UIKit.button(screenGui, "🏠 Back to the shops", UIKit.Colors.Row)
		home.Name = "FrontierHome"
		home.AnchorPoint = Vector2.new(0.5, 0)
		home.Position = UDim2.new(0.5, 0, 0, 8)
		home.Size = UDim2.fromOffset(200, 48)
		home.TextSize = 16
		home.Activated:Connect(function()
			Remotes.FrontierTravel:FireServer("home")
		end)
		return
	end
	panel, list = UIKit.panel(screenGui, "Frontier", "The Frontier")
end

return FrontierController
