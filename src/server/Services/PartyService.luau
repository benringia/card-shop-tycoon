--!strict
-- Party and summoning: 3 party cards; one is summoned and walks with its owner, giving its element's perk.
-- The server only moves an invisible marker part on the ground behind the owner (workspace.Creatures);
-- every client draws the creature itself on that marker (CreatureController), with motion and glow.
-- Creature models live in ReplicatedStorage.CreatureModels (Rojo: assets/creatures); every script inside
-- them is destroyed here before anyone joins. Perks are read live by CustomerService and StockService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Party = require(Config:WaitForChild("Party"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local PartyRules = require(Shared:WaitForChild("Util"):WaitForChild("PartyRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local CardService = require(Services:WaitForChild("CardService"))
local DataService = require(Services:WaitForChild("DataService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData

type PartyState = {
	slots: { [number]: string }, -- slot -> beastId
	summoned: number?,
	marker: Part?,
	hustle: number, -- walk speed bonus currently applied
}

local PartyService = {}

local states: { [Player]: PartyState } = {}
local allowAction = RateLimiter.new(Party.ACTION_COOLDOWN)
local creaturesFolder: Folder
local defaultWalkSpeed = StarterPlayer.CharacterWalkSpeed

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

local function getSummonedBeast(player: Player)
	local state = states[player]
	local beastId = if state and state.summoned then state.slots[state.summoned] else nil
	return if beastId then CardService.GetBeast(player, beastId) else nil
end

-- The summoned card's perk right now (it grows as the card gains stars), or nil
local function getCurrentPerk(player: Player): PartyRules.Perk?
	local beast = getSummonedBeast(player)
	if not beast then
		return nil
	end
	local card = Cards.ById[beast.cardId]
	return PartyRules.getPerk(Party, card.element, card.rarity, beast.stars)
end

-- Perk strength of this kind for the player (0 if their summoned creature has another perk or none)
function PartyService.GetPerk(player: Player, kind: string): number
	local perk = getCurrentPerk(player)
	return if perk and perk.kind == kind then perk.value else 0
end

local function sendParty(player: Player)
	local state = states[player]
	if not state then
		return
	end
	-- A list, not a slot-keyed table: remotes mangle tables with gaps in their number keys
	local slots = {}
	for slot, beastId in state.slots do
		table.insert(slots, { slot = slot, beastId = beastId })
	end
	local perk = getCurrentPerk(player)
	Remotes.PartyChanged:FireClient(player, {
		slots = slots,
		summoned = state.summoned,
		perk = if perk then { kind = perk.kind, value = perk.value, text = PartyRules.describe(perk) } else nil,
	})
end

-- Hustle: walk speed while a Volt creature is summoned
local function applyHustle(player: Player)
	local state = states[player]
	local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
	if not state or not humanoid then
		return
	end
	local bonus = PartyService.GetPerk(player, "Hustle")
	humanoid.WalkSpeed = defaultWalkSpeed * (1 + bonus)
	state.hustle = bonus
end

-- The marker ---------------------------------------------------------------------------------------------

local function refreshMarker(player: Player)
	local state = states[player]
	local marker = if state then state.marker else nil
	local beast = getSummonedBeast(player)
	if not marker or not beast then
		return
	end
	local card = Cards.ById[beast.cardId]
	marker:SetAttribute("OwnerUserId", player.UserId)
	marker:SetAttribute("CardId", card.id)
	marker:SetAttribute("CardName", card.name)
	marker:SetAttribute("Element", card.element)
	marker:SetAttribute("Rarity", card.rarity)
	marker:SetAttribute("Foil", beast.foil)
	marker:SetAttribute("Grade", beast.grade)
	marker:SetAttribute("Level", beast.level)
	marker:SetAttribute("Stars", beast.stars)
end

local function despawn(player: Player)
	local state = states[player]
	if state and state.marker then
		state.marker:Destroy()
		state.marker = nil
	end
end

local function spawnMarker(player: Player)
	local state = states[player]
	if not state or not getSummonedBeast(player) then
		return
	end
	despawn(player)
	local marker = Instance.new("Part")
	marker.Name = `Creature_{player.UserId}`
	marker.Size = Vector3.new(1, 1, 1)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	marker.CFrame = if root then root.CFrame else CFrame.new(0, -500, 0)
	state.marker = marker
	refreshMarker(player)
	marker.Parent = creaturesFolder
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Where the creature stands: behind and to the side of its owner, on the ground
local function getFollowCFrame(root: BasePart, current: CFrame): CFrame
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 0 then look.Unit else Vector3.new(0, 0, -1)
	local right = Vector3.new(-look.Z, 0, look.X)
	local target = root.Position - look * Party.FOLLOW_OFFSET.back + right * Party.FOLLOW_OFFSET.side
	local hit = workspace:Raycast(target + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0), rayParams)
	local ground = if hit then hit.Position else target - Vector3.new(0, 3, 0)
	-- Face the way it's heading (toward the follow point), or the owner's way when standing still
	local heading = Vector3.new(ground.X - current.X, 0, ground.Z - current.Z)
	local facing = if heading.Magnitude > 0.2 then heading.Unit else look
	return CFrame.lookAt(ground, ground + facing)
end

local function moveMarkers()
	local excluded: { Instance } = { creaturesFolder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end
	local workers = workspace:FindFirstChild("Workers")
	if workers then
		table.insert(excluded, workers)
	end
	rayParams.FilterDescendantsInstances = excluded

	for player, state in states do
		local marker = state.marker
		local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if marker and root then
			local target = getFollowCFrame(root, marker.CFrame)
			if (target.Position - marker.Position).Magnitude > Party.TELEPORT_DISTANCE then
				marker.CFrame = target -- teleported, fell or respawned: appear right next to the owner
			else
				-- The client smooths this; the server just steps it toward the follow point
				marker.CFrame = marker.CFrame:Lerp(target, 0.35)
			end
		end
	end
end

-- Remotes -------------------------------------------------------------------------------------------------

local function isSlot(value: unknown): boolean
	return typeof(value) == "number" and value == math.floor(value) and value >= 1 and value <= Party.PARTY_SIZE
end

local function unsummon(player: Player)
	local state = states[player]
	if not state then
		return
	end
	state.summoned = nil
	despawn(player)
	applyHustle(player)
end

local function onSetSlot(player: Player, slot: unknown, target: unknown)
	local state = states[player]
	if not allowAction(player) or not state or not isSlot(slot) then
		return
	end
	local slotNumber = slot :: number
	local old = state.slots[slotNumber]

	local beastId: string? = nil
	if target == nil then
		beastId = nil
	elseif typeof(target) == "string" then
		local beast = CardService.GetBeast(player, target)
		if not beast or CardService.IsWorking(player, target) then
			notify(player, "You can't add that card to your party.", true)
			return
		end
		for otherSlot, id in state.slots do
			if id == target and otherSlot ~= slotNumber then
				notify(player, "That card is already in your party.", true)
				return
			end
		end
		beastId = target
	elseif typeof(target) == "table" then
		local entry = target :: { [string]: unknown }
		local cardId, foil, grade = entry.cardId, entry.foil, entry.grade
		if typeof(cardId) ~= "string" or typeof(foil) ~= "boolean" or not BeastRules.isGrade(grade) then
			return
		end
		local beast = CardService.MakeIndividual(player, cardId, foil, grade :: string)
		if not beast then
			notify(player, "You don't have that card.", true)
			return
		end
		beastId = beast.id
	else
		return
	end

	if old and old ~= beastId then
		CardService.SetPartied(player, old, false)
	end
	state.slots[slotNumber] = beastId
	if beastId then
		CardService.SetPartied(player, beastId, true)
	end
	if state.summoned == slotNumber then
		if beastId then
			spawnMarker(player) -- swapped the summoned card: show the new one
			applyHustle(player)
		else
			unsummon(player)
		end
	end
	sendParty(player)
end

local function onSummon(player: Player, slot: unknown)
	local state = states[player]
	if not allowAction(player) or not state then
		return
	end
	if slot == nil then
		unsummon(player)
	elseif isSlot(slot) and state.slots[slot :: number] then
		state.summoned = slot :: number
		spawnMarker(player)
		applyHustle(player)
	else
		return
	end
	sendParty(player)
end

-- Data ----------------------------------------------------------------------------------------------------

local function load(player: Player, data: PlayerData)
	local state: PartyState = { slots = {}, summoned = nil, marker = nil, hustle = 0 }
	local saved: any = if typeof(data.party) == "table" then data.party else {}
	local savedSlots = if typeof(saved.slots) == "table" then saved.slots else {}
	local seen: { [string]: boolean } = {}
	for slot = 1, Party.PARTY_SIZE do
		local beastId = savedSlots[tostring(slot)]
		local valid = typeof(beastId) == "string" and not seen[beastId] and CardService.GetBeast(player, beastId) ~= nil
			and not CardService.IsWorking(player, beastId)
		if valid then
			seen[beastId] = true
			state.slots[slot] = beastId
			CardService.SetPartied(player, beastId, true)
		end
	end
	if isSlot(saved.summoned) and state.slots[saved.summoned] then
		state.summoned = saved.summoned
	end
	states[player] = state
	task.defer(function()
		if states[player] ~= state then
			return
		end
		if state.summoned then
			spawnMarker(player)
			applyHustle(player)
		end
		sendParty(player)
	end)
end

local function save(player: Player, data: PlayerData)
	local state = states[player]
	if not state then
		return
	end
	local slots: { [string]: string } = {}
	for slot, beastId in state.slots do
		slots[tostring(slot)] = beastId
	end
	data.party = { slots = slots, summoned = state.summoned }
end

local function unload(player: Player)
	despawn(player)
	states[player] = nil
end

function PartyService.Start()
	-- Free models can carry scripts: none may ever run. Clients also strip their own copies.
	local models = ReplicatedStorage:FindFirstChild("CreatureModels")
	if models then
		for _, descendant in models:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
	end

	creaturesFolder = Instance.new("Folder")
	creaturesFolder.Name = "Creatures"
	creaturesFolder.Parent = workspace

	DataService.Register({ name = "PartyService", load = load, save = save, unload = unload })
	Remotes.SetPartySlot.OnServerEvent:Connect(onSetSlot)
	Remotes.Summon.OnServerEvent:Connect(onSummon)
	Remotes.RequestParty.OnServerEvent:Connect(function(player)
		if allowAction(player) then
			sendParty(player)
		end
	end)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(applyHustle, player) -- the new character starts at default speed
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	local elapsed, sinceRefresh = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		sinceRefresh += dt
		if elapsed >= 1 / Party.MARKER_RATE then
			elapsed = 0
			moveMarkers()
		end
		-- Level, stars and perks change as the card grows: refresh the marker and perks once a second
		if sinceRefresh >= 1 then
			sinceRefresh = 0
			for player, state in states do
				if state.summoned then
					if getSummonedBeast(player) then
						refreshMarker(player)
						if PartyService.GetPerk(player, "Hustle") ~= state.hustle then
							applyHustle(player)
						end
					else
						unsummon(player) -- the card is gone
						sendParty(player)
					end
				end
			end
		end
	end)
end

return PartyService
