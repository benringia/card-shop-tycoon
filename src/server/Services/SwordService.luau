--!strict
-- The player's sword and look (spec 2026-11-02-you-in-the-fight-design). Everyone gets the standard body (torso, arms
-- and legs at standard scale, their own head, face, hair and accessories kept), so the sword animations fit every
-- avatar. From shop level 3 the character carries the starter sword (character attribute Sword; SwordDrawn while
-- attacking, back on the back SHEATH_SECONDS later); clients draw it. The first time, a popup says so: saved as
-- data.seenSword once the client closes it (Remotes.SwordState / SwordSeen). Boss fights hide back accessories
-- (capes, wings, backpacks) that would clash with the sword on the back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Swords = require(Shared:WaitForChild("Config"):WaitForChild("Swords"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData

local SwordService = {}

local REQUEST_COOLDOWN = 1 -- seconds between SwordState / SwordSeen requests
local HIDDEN_ATTRIBUTE = "SwordHidTransparency" -- a hidden back accessory's own transparency, to put back

local seen: { [Player]: boolean } = {} -- loaded players: closed the first-sword popup
local sheathTokens: { [Player]: number } = {}
local allowRequest = RateLimiter.new(REQUEST_COOLDOWN)
local allowSeen = RateLimiter.new(REQUEST_COOLDOWN)

-- The sword this player fights with: the starter from the shop level that opens boss 1 (the Forge adds more later)
function SwordService.GetSword(player: Player): string?
	return if EconomyService.GetLevel(player) >= Swords.UNLOCK_SHOP_LEVEL then Swords.STARTER else nil
end

local function sendState(player: Player)
	local sword = SwordService.GetSword(player)
	Remotes.SwordState:FireClient(player, { sword = sword, popup = sword ~= nil and seen[player] == false })
end

local function setSwordAttribute(player: Player)
	local character = player.Character
	if character then
		character:SetAttribute("Sword", SwordService.GetSword(player))
	end
end

-- An attack: the sword is in the hand now and goes back on the back SHEATH_SECONDS after the last one
function SwordService.Touch(player: Player)
	local character = player.Character
	if not character or not SwordService.GetSword(player) then
		return
	end
	character:SetAttribute("SwordDrawn", true)
	local token = (sheathTokens[player] or 0) + 1
	sheathTokens[player] = token
	task.delay(Swords.SHEATH_SECONDS, function()
		if sheathTokens[player] == token and player.Character == character then
			character:SetAttribute("SwordDrawn", nil)
		end
	end)
end

-- Boss fights: back accessories go invisible (their own transparency is kept to put back)
function SwordService.SetBackHidden(player: Player, hidden: boolean)
	local character = player.Character
	if not character then
		return
	end
	for _, accessory in character:GetChildren() do
		if not accessory:IsA("Accessory") or accessory.AccessoryType ~= Enum.AccessoryType.Back then
			continue
		end
		for _, part in accessory:GetDescendants() do
			if not part:IsA("BasePart") then
				continue
			end
			local was = part:GetAttribute(HIDDEN_ATTRIBUTE)
			if hidden and was == nil then
				part:SetAttribute(HIDDEN_ATTRIBUTE, part.Transparency)
				part.Transparency = 1
			elseif not hidden and typeof(was) == "number" then
				part.Transparency = was
				part:SetAttribute(HIDDEN_ATTRIBUTE, nil)
			end
		end
	end
end

-- Studio's /swordpopup: show the first-sword popup again
function SwordService.ResetPopup(player: Player)
	if seen[player] ~= nil then
		seen[player] = false
		sendState(player)
	end
end

-- The standard body on this character, keeping its head and everything worn (R15 only: the sword animations need it)
local function applyStandardBody(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	local ok, err = pcall(function()
		local description = humanoid:GetAppliedDescription()
		description.Torso, description.LeftArm, description.RightArm, description.LeftLeg, description.RightLeg = 0, 0, 0, 0, 0
		description.BodyTypeScale, description.ProportionScale = 0, 0
		description.HeightScale, description.WidthScale, description.DepthScale = 1, 1, 1
		humanoid:ApplyDescription(description)
	end)
	if not ok then
		warn(`[SwordService] standard body failed: {err}`)
	end
end

local function onPlayer(player: Player)
	player.CharacterAppearanceLoaded:Connect(function(character)
		applyStandardBody(character)
		setSwordAttribute(player)
	end)
	player.CharacterAdded:Connect(function()
		setSwordAttribute(player)
	end)
	if player.Character then
		applyStandardBody(player.Character)
		setSwordAttribute(player)
	end
	-- Reaching the sword's shop level gives it (and its popup) at once
	player:GetAttributeChangedSignal("Level"):Connect(function()
		setSwordAttribute(player)
		if seen[player] == false and SwordService.GetSword(player) then
			sendState(player)
		end
	end)
end

local function load(player: Player, data: PlayerData)
	seen[player] = data.seenSword == true
	setSwordAttribute(player)
	sendState(player)
end

local function save(player: Player, data: PlayerData)
	local value = seen[player]
	if value ~= nil then
		data.seenSword = value
	end
end

local function unload(player: Player)
	seen[player] = nil
	sheathTokens[player] = nil
end

function SwordService.Start()
	DataService.Register({ name = "SwordService", load = load, save = save, unload = unload })
	Remotes.SwordState.OnServerEvent:Connect(function(player)
		if allowRequest(player) and seen[player] ~= nil then
			sendState(player)
		end
	end)
	Remotes.SwordSeen.OnServerEvent:Connect(function(player)
		if allowSeen(player) and seen[player] ~= nil and SwordService.GetSword(player) then
			seen[player] = true
		end
	end)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return SwordService
