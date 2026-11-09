--!strict
-- Town Pish on this client (spec 2026-11-09-tutorial-pish-design 4): draws him on the server's marker
-- (workspace.PishNpc.TownPish, Server/Services/PishService) with Util/PishVisual, plays the clip the server names each
-- time its ClipId changes, and floats hearts when someone pets him (Remotes.PishPetted). While this player is in the
-- tutorial their own Pish leads them, so Town Pish and his pet prompt are hidden here (SetHidden). Main game only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local PishVisual = require(ClientUtil:WaitForChild("PishVisual"))

local TownPishController = {}

local visual: PishVisual.Visual? = nil
local marker: BasePart? = nil
local hidden = false

local function applyHidden()
	if visual then
		PishVisual.setShown(visual, not hidden)
	end
	local prompt = if marker then marker:FindFirstChild("PetPrompt") else nil
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = not hidden -- a local change: only this player loses the prompt
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

local function attach(found: BasePart)
	marker = found
	-- The model ships in ReplicatedStorage.NpcModels; wait for it rather than give up on a slow join
	local models = ReplicatedStorage:WaitForChild("NpcModels")
	models:WaitForChild("Pish")
	visual = PishVisual.new(found)
	if not visual then
		return
	end
	applyHidden()
	found:GetAttributeChangedSignal("ClipId"):Connect(playNamed)
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
end

function TownPishController.Start()
	if workspace:GetAttribute("PlaceKind") ~= "Main" then
		return
	end
	task.spawn(function()
		local folder = workspace:WaitForChild("PishNpc")
		attach(folder:WaitForChild("TownPish") :: BasePart)
	end)
end

return TownPishController
