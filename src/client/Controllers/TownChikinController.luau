--!strict
-- Town Chikin on this client (the owner 2026-11-11; Server/Services/TownChikinService): draws him on the server's marker
-- (workspace.ChikinNpc.TownChikin) with Util/PishVisual, plays the clip the server names each time its ClipId changes,
-- and floats hearts when someone pets him (Remotes.ChikinPetted). While this player's own Chikin leads their combat
-- tour he's hidden here (SetHidden, ChikinController). His pet prompt and "pet me for courage!" show only once this
-- player's combat tour is done (attribute CombatDone; the server checks the same). The marker can stream out and back in
-- as a new part: he's drawn again on the new one. Main game only; no model (NpcModels.Chikin), no Town Chikin.
-- When he greets someone who came near (the marker's GreetId changes; Server/Services/TownChikinService) he barks and a
-- speech bubble over him says hello to them by name (ChikinTalk.GREETS), for everyone who can see him.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChikinTalk = require(Shared:WaitForChild("Config"):WaitForChild("ChikinTalk"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local PishVisual = require(ClientUtil:WaitForChild("PishVisual"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))

local TownChikinController = {}

local FIND_SECONDS = 15 -- how long to wait for the model and the server's marker on join
local NAME = "Chikin"
local BUBBLE_SECONDS = 3
local BUBBLE_UP = 4.6 -- studs over his marker: above his name tag

local visual: PishVisual.Visual? = nil
local marker: BasePart? = nil
local markerConnections: { RBXScriptConnection } = {}
local hidden = false
local player = Players.LocalPlayer

local function pettable(): boolean
	return marker ~= nil and not hidden and player:GetAttribute("CombatDone") == true
end

local function applyHidden()
	local canPet = pettable()
	if visual then
		PishVisual.setShown(visual, not hidden)
		PishVisual.nameTag(visual, if canPet then ChikinTalk.LABELS.petMe else nil)
	end
	local prompt = if marker then marker:FindFirstChild("PetPrompt") else nil
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = canPet -- a local change: only this player's prompt
	end
end

-- Hidden while this player's own (tutorial) Chikin is out
function TownChikinController.SetHidden(value: boolean)
	hidden = value
	applyHidden()
end

local function playNamed()
	local current = marker
	local clip = if current then current:GetAttribute("Clip") else nil
	if visual and typeof(clip) == "string" and clip ~= "" then
		PishVisual.play(visual, clip)
	end
end

-- His hello in a speech bubble over him: white, rounded, popping in and fading after BUBBLE_SECONDS
local function greetBubble()
	local current = marker
	if not current or hidden or not visual then
		return
	end
	local userId = current:GetAttribute("GreetUserId")
	local line = ChikinTalk.GREETS[tonumber(current:GetAttribute("GreetLine")) or 1]
	local greeted = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	if not greeted or not line then
		return
	end
	PishVisual.sound(visual, "bark")
	local old = current:FindFirstChild("GreetBubble")
	if old then
		old:Destroy()
	end
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "GreetBubble"
	bubble.Size = UDim2.fromOffset(260, 44)
	bubble.StudsOffsetWorldSpace = Vector3.new(0, BUBBLE_UP, 0)
	bubble.MaxDistance = 80
	bubble.LightInfluence = 0
	bubble.Adornee = current
	bubble.Parent = current
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Parent = bubble
	UIKit.corner(frame, 20)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 150, 110)
	stroke.Thickness = 2.5
	stroke.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = frame
	local text = UIKit.label(frame, string.format(line, greeted.DisplayName), Enum.Font.FredokaOne, 20, Color3.fromRGB(80, 60, 90))
	text.Size = UDim2.new(1, -16, 1, 0)
	text.Position = UDim2.fromOffset(8, 0)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextScaled = true
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(BUBBLE_SECONDS, function()
		local fade = TweenInfo.new(0.35)
		TweenService:Create(frame, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		TweenService:Create(text, fade, { TextTransparency = 1 }):Play()
	end)
	Debris:AddItem(bubble, BUBBLE_SECONDS + 0.5)
end

local function detach()
	for _, connection in markerConnections do
		connection:Disconnect()
	end
	markerConnections = {}
	if visual then
		PishVisual.destroy(visual)
		visual = nil
	end
	marker = nil
end

local function attach(found: BasePart)
	detach()
	marker = found
	visual = PishVisual.new(found, NAME)
	if not visual then
		return
	end
	applyHidden()
	table.insert(markerConnections, found:GetAttributeChangedSignal("ClipId"):Connect(playNamed))
	table.insert(markerConnections, found:GetAttributeChangedSignal("GreetId"):Connect(greetBubble))
	-- The prompt can arrive a moment after the part
	table.insert(markerConnections, found.ChildAdded:Connect(applyHidden))
	playNamed()
end

function TownChikinController.Start()
	if workspace:GetAttribute("PlaceKind") ~= "Main" then
		return
	end
	task.spawn(function()
		local models = ReplicatedStorage:WaitForChild("NpcModels", FIND_SECONDS)
		if not models or not models:WaitForChild(NAME, FIND_SECONDS) then
			return
		end
		local folder = workspace:WaitForChild("ChikinNpc", FIND_SECONDS)
		if not folder then
			return
		end
		folder.ChildAdded:Connect(function(child)
			if child.Name == "TownChikin" and child:IsA("BasePart") then
				attach(child)
			end
		end)
		folder.ChildRemoved:Connect(function(child)
			if child == marker then
				detach()
			end
		end)
		local found = folder:FindFirstChild("TownChikin")
		if found and found:IsA("BasePart") then
			attach(found)
		end
		player:GetAttributeChangedSignal("CombatDone"):Connect(applyHidden)
		Remotes.ChikinPetted.OnClientEvent:Connect(function()
			if visual and not hidden then
				PishVisual.hearts(visual)
			end
		end)
		RunService.RenderStepped:Connect(function(dt)
			if visual then
				PishVisual.step(visual, dt)
			end
		end)
	end)
end

return TownChikinController
