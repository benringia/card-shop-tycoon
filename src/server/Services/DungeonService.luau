--!strict
-- The Dungeon run (spec 2026-10-29-dungeon-final-boss-design.md), in the Dungeon place only: one run per (reserved)
-- server. Players arrive from the Frontier portal (DungeonGateService); the run waits for the group (its teleport's
-- runSize) up to Dungeon.ARRIVAL_WAIT, then its three rooms open one after another: a room's gate seals it, its pack
-- of elites appears and the fight runs on BattleService with each creature's HP carried from the room before
-- (DungeonRules; fainted ones stay out). A won room opens its door; after the third, the chamber door opens onto the
-- Prism Hydra (BossService). A player whose party is all down, or who runs or leaves, is out: back to the Frontier.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Dungeon = require(Config:WaitForChild("Dungeon"))
local Party = require(Config:WaitForChild("Party"))
local DungeonRules = require(Shared:WaitForChild("Util"):WaitForChild("DungeonRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local BattleService = require(Services:WaitForChild("BattleService"))
local BossService = require(Services:WaitForChild("BossService"))
local FrontierService = require(Services:WaitForChild("FrontierService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local WildService = require(Services:WaitForChild("WildService"))
local DungeonBuilder = require(Util:WaitForChild("DungeonBuilder"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

export type Run = {
	members: { Player }, -- everyone in the run (out players stay listed, flagged in `out`)
	out: { [Player]: boolean },
	hpLeft: { [Player]: { [string]: number } }, -- each creature's HP after its last fight this run
	expected: number, -- players the teleport brought (DungeonRules.expectedSize)
	started: boolean, -- the rooms are open
	fought: boolean, -- a fight has started: latecomers can't join any more
	cleared: number, -- rooms won
	room: number?, -- the room being fought
	monster: WildService.Monster?, -- its pack's first monster (BattleService's fight)
	bossFight: boolean, -- the Prism Hydra is being fought
	won: boolean, -- the Hydra fell: the way back is open
}

local DungeonService = {}

local run: Run = { members = {}, out = {}, hpLeft = {}, expected = 1, started = false, fought = false, cleared = 0, room = nil, monster = nil, bossFight = false, won = false }
local layout: DungeonBuilder.DungeonLayout
local allowGate = RateLimiter.new(Bosses.START_COOLDOWN)
local allowLeave = RateLimiter.new(1)
local rng = Random.new()

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

-- Where the run is, for one player's run line (DungeonController)
local function send(player: Player, message: string?)
	local stage = if run.out[player] then "out"
		elseif run.won then "won"
		elseif not run.started then "waiting"
		elseif run.cleared >= #Dungeon.ROOMS then "boss"
		else "room"
	Remotes.DungeonRun:FireClient(player, { room = math.min(run.cleared + 1, #Dungeon.ROOMS), rooms = #Dungeon.ROOMS, stage = stage, message = message })
end

local function sendAll(message: string?)
	for _, player in run.members do
		if player.Parent then
			send(player, message)
		end
	end
end

-- The players still in the run (here, not out)
local function active(): { Player }
	local list = {}
	for _, player in run.members do
		if player.Parent and not run.out[player] then
			table.insert(list, player)
		end
	end
	return list
end

local function partyIds(player: Player): { string }
	local party = PartyService.GetParty(player)
	local ids = {}
	for slot = 1, Party.PARTY_SIZE do
		local beastId = if party then party.slots[slot] else nil
		if beastId then
			table.insert(ids, beastId)
		end
	end
	return ids
end

local function setBarrier(barrier: { BasePart }, up: boolean)
	for _, wall in barrier do
		wall.CanCollide = up
		wall.Transparency = if up then Bosses.BARRIER_TRANSPARENCY else 1
	end
end

local function openDoor(door: BasePart)
	door.CanCollide = false
	door.Transparency = 1
end

-- Out of the run: the party is down, they ran or they left. Back to the Frontier after a moment.
local function markOut(player: Player, why: string)
	if run.out[player] then
		return
	end
	run.out[player] = true
	if player.Parent then
		send(player, why)
		task.delay(Dungeon.OUT_DELAY, function()
			if player.Parent then
				FrontierService.ReturnToFrontier(player)
			end
		end)
	end
end

-- Summons a party card that can still fight this run when the summoned one can't (fainted earlier, or resting).
-- False when none can: the player is out.
local function ensureFighter(player: Player): boolean
	local party = PartyService.GetParty(player)
	if not party then
		return false
	end
	local left = run.hpLeft[player] or {}
	local function ready(beastId: string?): boolean
		return beastId ~= nil and DungeonRules.canFight(left, beastId) and not BattleService.IsResting(player, beastId)
	end
	if party.summoned and ready(party.slots[party.summoned]) then
		return true
	end
	for slot = 1, Party.PARTY_SIZE do
		if ready(party.slots[slot]) then
			return PartyService.SummonSlot(player, slot)
		end
	end
	return false
end

local function start()
	if run.started then
		return
	end
	run.started = true
	sendAll(`The Dungeon is open: {#Dungeon.ROOMS} rooms, then the Prism Hydra.`)
end

-- Arrivals: the group starts together (or after ARRIVAL_WAIT); someone arriving after the first fight goes back
local function onArrive(player: Player)
	if run.fought then
		table.insert(run.members, player)
		markOut(player, "This run has already started.")
		return
	end
	table.insert(run.members, player)
	if #run.members == 1 then
		local ok, data = pcall(function()
			return player:GetJoinData().TeleportData
		end)
		run.expected = DungeonRules.expectedSize(if ok then data else nil, Bosses.GROUP_MAX)
		task.delay(Dungeon.ARRIVAL_WAIT, start)
	end
	send(player, if run.started then nil else "Waiting for your group...")
	if #run.members >= run.expected then
		start()
	end
end

-- A room's gate: everyone still in the run goes in, the ring seals, the pack appears and the fight starts
local function onRoomGate(player: Player, index: number)
	if not allowGate(player) or not table.find(run.members, player) or run.out[player] then
		return
	end
	if not run.started then
		notify(player, "Waiting for your group...", true)
		return
	elseif run.room then
		return -- a room is being fought
	elseif index <= run.cleared then
		notify(player, "This room is cleared. On to the next!", false)
		return
	elseif index > run.cleared + 1 then
		notify(player, "Clear the room before this one first.", true)
		return
	end
	local fighters = {}
	for _, member in active() do
		if ensureFighter(member) then
			table.insert(fighters, member)
		else
			markOut(member, "None of your creatures can fight any more.")
		end
	end
	if #fighters == 0 then
		return
	end
	local room = layout.rooms[index]
	local config = Dungeon.ROOMS[index]
	run.room = index
	run.fought = true
	for slot, member in fighters do
		local character = member.Character
		if character then
			character:PivotTo(room.inside * CFrame.new((slot - (#fighters + 1) / 2) * Bosses.INSIDE_STEP, 0, 0))
		end
	end
	setBarrier(room.barrier, true)
	sendAll(`Room {index}!`)
	task.delay(Dungeon.ROOM_INTRO_SECONDS, function()
		local monsters = {}
		for slot, species in DungeonRules.pack(config, rng:NextInteger(0, 1000)) do
			local sideways = (if slot % 2 == 1 then 1 else -1) * Bosses.ADD_SPACING * (slot // 2)
			local monster = WildService.SpawnAt((room.packSpot * CFrame.new(sideways, 0, 0)).Position, species, config.level, true)
			if monster then
				table.insert(monsters, monster)
			end
		end
		local present = {}
		for _, member in fighters do
			if member.Parent and not run.out[member] then
				table.insert(present, member)
			end
		end
		local first = table.remove(monsters, 1)
		local ok, why = false, "The room couldn't start. Try again."
		if first and #present > 0 then
			ok, why = BattleService.StartGroupFight(present, first, { pack = monsters, hpLeft = run.hpLeft, run = true })
		end
		if ok then
			run.monster = first
			return
		end
		if first then
			WildService.Defeat(first)
		end
		for _, monster in monsters do
			WildService.Defeat(monster)
		end
		setBarrier(room.barrier, false)
		run.room = nil
		for _, member in present do
			notify(member, why or "The room couldn't start. Try again.", true)
		end
	end)
end

-- The chamber's gate: everyone still in the run fights the Prism Hydra with the HP they have left
local function onChamberGate(player: Player, bossId: string)
	if not allowGate(player) or not table.find(run.members, player) or run.out[player] or run.bossFight or run.won then
		return
	end
	if run.cleared < #Dungeon.ROOMS then
		notify(player, "Clear the three rooms first.", true)
		return
	end
	local fighters = {}
	for _, member in active() do
		if ensureFighter(member) then
			table.insert(fighters, member)
		else
			markOut(member, "None of your creatures can fight any more.")
		end
	end
	local ok, why = BossService.StartRun(bossId, fighters, run.hpLeft)
	if ok then
		run.bossFight = true
		run.fought = true
	else
		notify(player, why or "The boss couldn't start. Try again.", true)
	end
end

-- The Hydra fell: a portal back to the Frontier opens in the chamber (players pick up their loot first)
local function openWayBack()
	WildService.BuildPortal(layout.spawn.Parent :: Instance, "Return to the Frontier", layout.returnSpot.Position, layout.returnSpot.LookVector, "Return", function(player)
		FrontierService.ReturnToFrontier(player)
	end)
end

-- HP carries over: each fighter's creatures as the fight left them
local function carryHp(hpLeft: { [Player]: { [string]: number } })
	for player, left in hpLeft do
		run.hpLeft[player] = DungeonRules.merge(run.hpLeft[player] or {}, left)
	end
end

-- The Hydra's fight ended: a win opens the way back, anyone whose party is down is out (the others may try again)
local function onBossEnded(result: string, hpLeft: { [Player]: { [string]: number } })
	run.bossFight = false
	carryHp(hpLeft)
	if result == "win" then
		run.won = true
		openWayBack()
		sendAll("The Prism Hydra has fallen! Pick up your loot, then take the portal home.")
		return
	end
	for player in hpLeft do
		if result ~= "lose" then
			markOut(player, "You left the fight, so you're out of the run.")
		elseif DungeonRules.isOut(run.hpLeft[player], partyIds(player)) then
			markOut(player, "Your whole party is down. Back to the Frontier...")
		end
	end
end

-- A room's fight ended: HP carries over, a win opens the way on, anyone whose party is down is out
local function onFightEnded(monster: WildService.Monster, result: string, hpLeft: { [Player]: { [string]: number } })
	if monster.boss == Dungeon.BOSS then
		onBossEnded(result, hpLeft)
		return
	end
	if monster ~= run.monster then
		return -- nothing of ours
	end
	local index = run.room :: number
	local room = layout.rooms[index]
	run.monster = nil
	run.room = nil
	setBarrier(room.barrier, false)
	carryHp(hpLeft)
	if result == "win" then
		run.cleared = math.max(run.cleared, index)
		openDoor(room.door)
	end
	for player in hpLeft do
		if result ~= "win" and result ~= "lose" then
			markOut(player, "You left the fight, so you're out of the run.")
		elseif DungeonRules.isOut(run.hpLeft[player], partyIds(player)) then
			markOut(player, "Your whole party is down. Back to the Frontier...")
		end
	end
	if result == "win" then
		sendAll(if run.cleared >= #Dungeon.ROOMS then "The chamber is open: the Prism Hydra awaits!" else `Room {index} cleared!`)
	end
end

-- The run as it is now (BossService's chamber start reads its HP; dev commands)
function DungeonService.GetRun(): Run
	return run
end

-- Studio only (/room): rooms before `room` count as cleared and their doors open
function DungeonService.SkipTo(room: number)
	if not RunService:IsStudio() or not layout then
		return
	end
	run.started = true
	for index = 1, math.clamp(room, 1, #Dungeon.ROOMS + 1) - 1 do
		openDoor(layout.rooms[index].door)
		run.cleared = math.max(run.cleared, index)
	end
	sendAll(nil)
end

function DungeonService.Start()
	layout = WildService.GetDungeonLayout() :: DungeonBuilder.DungeonLayout
	for index, room in layout.rooms do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Fight"
		prompt.ObjectText = `Room {index} of {#Dungeon.ROOMS}`
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Bosses.GATE_PROMPT_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt.Parent = room.gate
		prompt.Triggered:Connect(function(player)
			onRoomGate(player, index)
		end)
	end
	BattleService.OnFightEnded(onFightEnded)
	BossService.SetRunGate(onChamberGate)
	-- A group member who ran, died or left mid-room (or mid-Hydra) is out (the others fight on)
	BattleService.OnMemberLeft(function(player, monster)
		if monster == run.monster or monster.boss == Dungeon.BOSS then
			markOut(player, "You left the fight, so you're out of the run.")
		end
	end)
	Remotes.DungeonLeave.OnServerEvent:Connect(function(player)
		if not allowLeave(player) then
			return
		end
		markOut(player, "You left the Dungeon.")
		FrontierService.ReturnToFrontier(player)
	end)
	Players.PlayerAdded:Connect(onArrive)
	for _, player in Players:GetPlayers() do
		onArrive(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		run.out[player] = true
		run.hpLeft[player] = nil
	end)
end

return DungeonService
