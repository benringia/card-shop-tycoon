--!strict
-- Town Pish on this client (spec 2026-11-09-tutorial-pish-design 4): draws him on the server's marker
-- (workspace.PishNpc.TownPish, Server/Services/PishService) with Util/PishVisual, plays the clip the server names each
-- time its ClipId changes, and floats hearts when someone pets him (Remotes.PishPetted). While this player is in the
-- tutorial their own Pish leads them, so Town Pish is hidden here (SetHidden). His pet prompt and "pet me for luck!"
-- show only to the owner of the shop he's visiting, after their first visit. The marker can
-- stream out (far in the Wild valley) and back in as a new part: he's drawn again on the new one. Main game only; no
-- model (NpcModels.Pish), no Town Pish (the server doesn't make him either).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PishTalk = require(Shared:WaitForChild("Config"):WaitForChild("PishTalk"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local PishVisual = require(ClientUtil:WaitForChild("PishVisual"))

local TownPishController = {}

local FIND_SECONDS = 15 -- how long to wait for the model and the server's marker on join

local visual: PishVisual.Visual? = nil
local marker: BasePart? = nil
local markerConnections: { RBXScriptConnection } = {}
local hidden = false
local player = Players.LocalPlayer

-- Petting him is for the owner of the shop he's visiting, after their first visit (owner 2026-11-10; the server
-- checks the same: PishService)
local function pettable(): boolean
	local current = marker
	return current ~= nil
		and not hidden
		and current:GetAttribute("VisitingOwner") == player.UserId
		and player:GetAttribute("TutorialDone") == true
end

local function applyHidden()
	local canPet = pettable()
	if visual then
		PishVisual.setShown(visual, not hidden)
		PishVisual.nameTag(visual, if canPet then PishTalk.LABELS.petMe else nil)
	end
	local prompt = if marker then marker:FindFirstChild("PetPrompt") else nil
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = canPet -- a local change: only this player's prompt
	end
end

-- Hidden while this player's own (tutorial) Pish is out
function TownPishController.SetHidden(value: boolean)
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
	visual = PishVisual.new(found)
	if not visual then
		return
	end
	applyHidden()
	table.insert(markerConnections, found:GetAttributeChangedSignal("ClipId"):Connect(playNamed))
	table.insert(markerConnections, found:GetAttributeChangedSignal("VisitingOwner"):Connect(applyHidden))
	-- The prompt can arrive a moment after the part: hide it too while this player's own Pish is out
	table.insert(markerConnections, found.ChildAdded:Connect(applyHidden))
	playNamed()
end

function TownPishController.Start()
	if workspace:GetAttribute("PlaceKind") ~= "Main" then
		return
	end
	task.spawn(function()
		local models = ReplicatedStorage:WaitForChild("NpcModels", FIND_SECONDS)
		if not models or not models:WaitForChild("Pish", FIND_SECONDS) then
			return
		end
		local folder = workspace:WaitForChild("PishNpc", FIND_SECONDS)
		if not folder then
			return
		end
		folder.ChildAdded:Connect(function(child)
			if child.Name == "TownPish" and child:IsA("BasePart") then
				attach(child)
			end
		end)
		folder.ChildRemoved:Connect(function(child)
			if child == marker then
				detach()
			end
		end)
		local found = folder:FindFirstChild("TownPish")
		if found and found:IsA("BasePart") then
			attach(found)
		end
		player:GetAttributeChangedSignal("TutorialDone"):Connect(applyHidden)
		Remotes.PishPetted.OnClientEvent:Connect(function()
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

return TownPishController
