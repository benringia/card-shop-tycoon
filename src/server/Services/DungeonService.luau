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
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Dungeon = require(Config:WaitForChild("Dungeon"))
local Party = require(Config:WaitForChild("Party"))
local DungeonRules = require(Shared:WaitForChild("Util"):WaitForChild("DungeonRules"))
local AbyssLayout = require(Shared:WaitForChild("Util"):WaitForChild("AbyssLayout"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Blocked = require((script.Parent :: Instance).Parent:WaitForChild("Util"):WaitForChild("Blocked"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local BattleService = require(Services:WaitForChild("BattleService"))
local BossService = require(Services:WaitForChild("BossService"))
local DataService = require(Services:WaitForChild("DataService"))
local FrontierService = require(Services:WaitForChild("FrontierService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local WildService = require(Services:WaitForChild("WildService"))
local DungeonPuzzleService = require(Services:WaitForChild("DungeonPuzzleService"))
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
	done: number, -- steps of Dungeon.STEPS done (fights won, puzzles solved; DungeonRules)
	room: number?, -- the room being fought
	monster: WildService.Monster?, -- its pack's first monster (BattleService's fight)
	bossFight: boolean, -- the Prism Hydra is being fought
	won: boolean, -- the Hydra fell: the way back is open
	gathering: string?, -- the next puzzle, waiting until every player still in the run stands on its island
}

local DungeonService = {}

local run: Run = { members = {}, out = {}, hpLeft = {}, expected = 1, started = false, fought = false, cleared = 0, done = 0, room = nil, monster = nil, bossFight = false, won = false, gathering = nil }
local layout: DungeonBuilder.DungeonLayout
local allowGate = RateLimiter.new(Bosses.START_COOLDOWN)
local allowLeave = RateLimiter.new(1)
local allowAck = RateLimiter.new(1)
local allowLair = RateLimiter.new(1)
-- Each member's welcome until their client says it started it ("introSeen"): sent with every run message, so a
-- client that wasn't listening yet (or was still behind its loading screen) still gets it
local pendingIntro: { [Player]: string } = {}
local rng = Random.new()
local lastCount = "" -- the gather count last sent ("here/total")
local gatherSince = 0 -- when the run began waiting for the group (os.clock)

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

-- The players still in the run (here, not out) and how many of them stand on the next puzzle's island
local function gathered(): (number, number)
	local island = layout.stepIslands[run.done + 1]
	local here, total = 0, 0
	for _, member in run.members do
		if member.Parent and not run.out[member] then
			total += 1
			local character = member.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if island and root and root:IsA("BasePart") and AbyssLayout.onIsland(island, { x = root.Position.X, z = root.Position.Z }) then
				here += 1
			end
		end
	end
	return here, total
end

-- Where the run is, for one player's run line (DungeonController)
local function send(player: Player, message: string?)
	local kind = DungeonRules.stepKind(Dungeon.STEPS, run.done)
	local stage = if run.out[player] then "out"
		elseif run.won then "won"
		elseif not run.started then "waiting"
		elseif run.gathering then "gather"
		elseif kind == "fight" then "room"
		else kind -- "beams", "plates", "lock" or "boss"
	local here, total = nil, nil
	if stage == "gather" then
		here, total = gathered()
	end
	Remotes.DungeonRun:FireClient(player, { room = math.min(run.cleared + 1, #Dungeon.ROOMS), rooms = #Dungeon.ROOMS, stage = stage, next = run.gathering, here = here, total = total, message = message, intro = pendingIntro[player] })
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

-- Room 3's pylons whole and its shield up (`up`, their beams feeding it) for its fight, or both back at rest after it
local function setPylons(room: DungeonBuilder.Room, up: boolean)
	for _, pylon in room.pylons do
		pylon:SetAttribute("Broken", false)
		DungeonBuilder.tint(pylon, nil, 0.1)
		local beam = pylon:FindFirstChild("ShieldBeam")
		if beam and beam:IsA("Beam") then
			beam.Enabled = up
		end
	end
	if room.shield then
		room.shield:SetAttribute("Up", up)
		room.shield.Size = Vector3.one * Dungeon.PUZZLE.SHIELD_RADIUS * 2
		room.shield.Transparency = if up then Dungeon.PUZZLE.SHIELD_UP else 1
	end
end

-- Room 3's fight told us: a pylon broke (it fades, its beam goes out, the shield flickers) or the last one did (the
-- shield bursts outward and fades)
local function onPylon(room: DungeonBuilder.Room, kind: string, pylon: BasePart?)
	local shield = room.shield
	if kind == "pylonBroken" and pylon then
		pylon:SetAttribute("Broken", true)
		DungeonBuilder.tint(pylon, nil, Dungeon.PUZZLE.PYLON_BROKEN)
		local beam = pylon:FindFirstChild("ShieldBeam")
		if beam and beam:IsA("Beam") then
			beam.Enabled = false
		end
		if shield and shield:GetAttribute("Up") then
			shield.Transparency = 0.9
			task.delay(Dungeon.PUZZLE.SHIELD_FLICKER, function()
				if shield:GetAttribute("Up") then
					shield.Transparency = Dungeon.PUZZLE.SHIELD_UP
				end
			end)
		end
	elseif kind == "shieldDown" and shield then
		shield:SetAttribute("Up", false)
		TweenService:Create(shield, TweenInfo.new(Dungeon.PUZZLE.SHIELD_SHATTER, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = shield.Size * 1.5,
			Transparency = 1,
		}):Play()
	end
end

local function openDoor(door: BasePart)
	DungeonBuilder.hide(door) -- the barrier and what it wears (the Hydra's door, its eyes)
end

-- Step `index` done: the gate after it opens, and a fight room's own seal on its way in (with the sigil it wears)
local function openStep(index: number)
	openDoor(layout.doors[index])
	local step = Dungeon.STEPS[index]
	local room = if step and step.kind == "fight" then layout.rooms[step.room :: number] else nil
	if room then
		DungeonBuilder.hide(room.seal)
		DungeonBuilder.hide(room.gate)
		local fight = room.gate:FindFirstChildOfClass("ProximityPrompt")
		if fight then
			fight.Enabled = false -- won: no "Fight" on its open gate
		end
	end
	if index == #Dungeon.STEPS then
		-- the Hydra's door is open: its gate's dragon heads glare (lit one by one in the cinematic before this), and the
		-- castle's gate takes you into its lair (its prompt, or walking into the swirl)
		for eyeIndex, eye in layout.hydraEyes do
			DungeonBuilder.setEye(eye, eyeIndex, true)
		end
		layout.lairPortal:SetAttribute("Open", true)
		layout.lairPortal.CanCollide = false
		local prompt = layout.lairPortal:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = true
		end
	end
end

-- Into the Hydra's lair through the castle's gate (round 3 part 2): a run member still in it, near the gate, once the
-- lock is solved; set down outside the arena's gate (its prompts start the fight), streamed in first
local function enterLair(player: Player)
	if not allowLair(player) or not table.find(run.members, player) or run.out[player] or layout.lairPortal:GetAttribute("Open") ~= true then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	if (root.Position - layout.lairPortal.Position).Magnitude > Dungeon.LAIR_PROMPT_DISTANCE + 6 then
		return
	end
	local gate = BossService.GetGate(table.find(Bosses.LADDER, Dungeon.BOSS) :: number)
	if gate then
		local spot = gate + Vector3.new(0, 3, 0)
		WildService.Prestream(player, spot.Position)
		if player.Character == character and not run.out[player] then -- still them after the wait
			character:PivotTo(spot)
		end
	end
end

-- Out of the run: the party is down, they ran or they left. Back to the Frontier after a moment.
local function markOut(player: Player, why: string)
	if run.out[player] then
		return
	end
	run.out[player] = true
	DungeonPuzzleService.Release(player)
	if player.Parent then
		send(player, why)
		task.delay(Dungeon.OUT_DELAY, function()
			if player.Parent then
				FrontierService.ReturnToFrontier(player)
			end
		end)
	end
end

-- Falling into the chasm is death (spec 2026-11-12-dungeon-world): out of the run and back to the Frontier, set down
-- on the ledge meanwhile (never left falling in the dark, even if the teleport fails). Someone already out who falls
-- again is only set back down.
local rescuing: { [Player]: boolean } = {}
local function sweepFalls()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if character and root and root:IsA("BasePart") and not rescuing[player] and AbyssLayout.fallen(root.Position.Y, Dungeon.ABYSS.KILL_Y) then
			BattleService.Withdraw(player) -- or the fight's leash pulls them back to the ring
			markOut(player, Dungeon.ABYSS.FALL_MESSAGE)
			rescuing[player] = true
			root.Anchored = true -- held in the dark while the ledge streams in (2000 studs off at the far end)
			task.spawn(function()
				WildService.Prestream(player, layout.entrance.Position)
				if root.Parent then
					root.AssemblyLinearVelocity = Vector3.zero
					character:PivotTo(layout.entrance)
					root.Anchored = false
				end
				rescuing[player] = nil
			end)
		end
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

-- Who goes into the next fight: everyone still in the run who can fight; a member whose save is still loading sits
-- it out (not out of the run), one with no creature left that can fight is out
local function readyMembers(): { Player }
	local fighters = {}
	for _, member in active() do
		local check = DungeonRules.gateCheck(PartyService.GetParty(member) ~= nil, ensureFighter(member))
		if check == "fight" then
			table.insert(fighters, member)
		elseif check == "out" then
			markOut(member, "None of your creatures can fight any more.")
		else
			notify(member, "Your save is still loading: you'll join the next fight.", true)
		end
	end
	return fighters
end

-- The rooms open once everyone the teleport brought has loaded (or the wait for a no-show is over)
local function tryStart(waited: number)
	if run.started then
		return
	end
	if not DungeonRules.readyToStart(#run.members, run.expected, waited, Dungeon.ARRIVAL_WAIT) then
		local missing = run.expected - #run.members
		sendAll(`Waiting for {missing} more player{if missing == 1 then "" else "s"} to load...`)
		return
	end
	run.started = true
	-- Each member's own welcome: the Hydra's full one the first time ever, a short one after (BossService saves it)
	for _, player in run.members do
		if player.Parent and not run.out[player] then
			pendingIntro[player] = BossService.IntroKind(player)
			send(player, `The Dungeon is open: {#Dungeon.ROOMS} fights and their puzzles, then the Prism Hydra.`)
		end
	end
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
		task.delay(Dungeon.ARRIVAL_WAIT, tryStart, Dungeon.ARRIVAL_WAIT)
	end
	send(player, nil)
	tryStart(0)
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
	elseif not DungeonRules.canStartRoom(Dungeon.STEPS, run.done, index) then
		-- its fight step is behind the run (won) or ahead of it (a door or puzzle before it): never fought early
		if DungeonRules.doneBefore(Dungeon.STEPS, index) < run.done then
			notify(player, "This room is cleared. On to the next!", false)
		else
			notify(player, "Get past what's before this room first.", true)
		end
		return
	end
	local fighters = readyMembers()
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
			local spot = room.inside * CFrame.new((slot - (#fighters + 1) / 2) * Bosses.INSIDE_STEP, 0, 0)
			if (character:GetPivot().Position - spot.Position).Magnitude > Bosses.FAR_MOVE then
				task.spawn(function()
					WildService.Prestream(member, spot.Position)
					if member.Character == character then
						character:PivotTo(spot)
					end
				end)
			else
				character:PivotTo(spot)
			end
		end
	end
	setBarrier(room.barrier, true)
	sendAll(if config.pylons then `Room {index}! {Dungeon.HINTS.pylons}` else `Room {index}!`)
	task.delay(Dungeon.ROOM_INTRO_SECONDS, function()
		local monsters = {}
		local names = DungeonRules.pack(config, rng:NextInteger(0, 1000))
		-- spread round the arena's far side, each rising out of the ground (owner 2026-11-12); room 3's stay in their
		-- shield, closer together
		local look = Dungeon.PACK_SPAWN
		local spots = DungeonRules.packSpots(#names, if config.pylons then look.shieldRadius else look.radius, rng:NextInteger(1, 100000))
		local middle = if config.pylons then room.packSpot.Position else room.center
		for slot, species in names do
			local spot = middle + Vector3.new(spots[slot].x, 0, spots[slot].z)
			local monster = WildService.SpawnAt(spot, species, config.level, true, nil, nil, { emerge = look.emerge })
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
			-- The players fight in every room with their swords (owner 2026-11-12); room 3's pylons first (spec 2026-11-11-dungeon-puzzles)
			local pylons = {}
			for _, part in room.pylons do
				table.insert(pylons, { part = part, hp = (config.pylons :: any).hp })
			end
			setPylons(room, #pylons > 0)
			ok, why = BattleService.StartGroupFight(present, first, {
				pack = monsters,
				hpLeft = run.hpLeft,
				run = true,
				swords = true,
				pylons = if #pylons > 0 then pylons else nil,
				onPylon = function(kind, pylon)
					onPylon(room, kind, pylon)
				end,
				packAtk = config.atk,
				leashCenter = room.center, -- the leash from the ring's middle keeps its put-back point on the island
			})
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
		setPylons(room, false)
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
	if not DungeonRules.chamberOpen(Dungeon.STEPS, run.done) then
		notify(player, "Open the element lock first.", true)
		return
	end
	local fighters = readyMembers()
	if #fighters == 0 then
		return
	end
	local ok, why = BossService.StartRun(bossId, fighters, run.hpLeft)
	if ok then
		run.bossFight = true
		run.fought = true
	else
		Blocked.tell(player, why or "The boss couldn't start. Try again.") -- the Hydra's level, its fragments...
	end
end

-- The Hydra fell: a portal back to the Frontier opens in the chamber (players pick up their loot first)
local function openWayBack()
	WildService.BuildPortal(layout.spawn.Parent :: Instance, "Return to the Frontier", layout.returnSpot.Position, layout.returnSpot.LookVector, "Return", function(player)
		FrontierService.ReturnToFrontier(player)
	end)
end

-- The run's current step is done (a won fight, a solved puzzle): its door opens and everyone hears what's next.
-- Nothing when `kind` isn't the current step's (a late or repeated report).
local function completeStep(kind: string)
	local step = Dungeon.STEPS[run.done + 1]
	if not step or step.kind ~= kind then
		return
	end
	run.done += 1
	run.gathering = nil -- a step done (a dev skip included) ends any wait for the one before
	if step.kind == "fight" then
		openStep(run.done)
	else
		-- a puzzle's gate opens in a cinematic (the lock's: the way to the Hydra); the gate goes at its moment
		local door = layout.doors[run.done]
		local hydra = DungeonRules.stepKind(Dungeon.STEPS, run.done) == "boss"
		local look = if hydra then Dungeon.CINEMATIC.hydra else Dungeon.CINEMATIC.door
		local eyes = {}
		if hydra then
			-- the castle gate's dragon heads' eyes (the cinematic lights them one by one)
			for _, eye in layout.hydraEyes do
				table.insert(eyes, eye.Position)
			end
		end
		for _, member in run.members do
			if member.Parent and not run.out[member] then
				Remotes.DungeonCinematic:FireClient(member, { kind = if hydra then "hydra" else "door", door = door.Position, through = door.CFrame.XVector, eyes = eyes })
			end
		end
		local index = run.done
		task.delay(look.openAt, openStep, index)
	end
	local nextKind = DungeonRules.stepKind(Dungeon.STEPS, run.done)
	local cleared = if step.kind == "fight" then `Room {step.room} cleared! ` else `{Dungeon.STAGES[step.kind]} solved! `
	if nextKind == "boss" then
		sendAll(Dungeon.LAIR_MESSAGE)
	elseif nextKind == "fight" then
		sendAll(`{cleared}On to room {(Dungeon.STEPS[run.done + 1] :: any).room}.`)
	else
		-- the puzzle waits for the whole group on its island (checkGathering opens it)
		run.gathering = nextKind
		gatherSince = os.clock()
		sendAll(cleared .. Dungeon.GATHER_MESSAGE)
	end
end

-- The next puzzle opens once every player still in the run stands on its island; its count goes out as it changes
local function checkGathering()
	local kind = run.gathering
	if not kind or run.won then
		return
	end
	local here, total = gathered()
	-- everyone there, or most of them a while (one idle player never holds the rest: GATHER_TIMEOUT)
	local waited = os.clock() - gatherSince
	if (total > 0 and here >= total) or (here > 0 and waited >= Dungeon.GATHER_TIMEOUT) then
		run.gathering = nil
		lastCount = ""
		DungeonPuzzleService.Open(kind)
		sendAll(Dungeon.HINTS[kind])
	elseif `{here}/{total}` ~= lastCount then
		lastCount = `{here}/{total}`
		sendAll(nil)
	end
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
		if DungeonRules.leftRun(result) then
			markOut(player, "You left the fight, so you're out of the run.")
		elseif DungeonRules.isOut(run.hpLeft[player], partyIds(player)) then
			markOut(player, "Your whole party is down. Back to the Frontier...")
		end
	end
	if result == "timeout" then
		sendAll("Out of time! Try the Prism Hydra again with the creatures you have left.")
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
	setPylons(room, false) -- a lost room's next try starts with every pylon whole
	carryHp(hpLeft)
	if result == "win" then
		run.cleared = math.max(run.cleared, index)
		completeStep("fight")
	end
	for player in hpLeft do
		if DungeonRules.leftRun(result) then
			markOut(player, "You left the fight, so you're out of the run.")
		elseif DungeonRules.isOut(run.hpLeft[player], partyIds(player)) then
			markOut(player, "Your whole party is down. Back to the Frontier...")
		end
	end
	if result == "timeout" then
		sendAll(`Out of time! Room {index} is still to clear.`)
	end
end

-- The run as it is now (BossService's chamber start reads its HP; dev commands)
function DungeonService.GetRun(): Run
	return run
end

-- A puzzle reports its step solved (DungeonPuzzleService): `kind` "beams", "plates" or "lock"
function DungeonService.CompleteStep(kind: string)
	completeStep(kind)
end

-- Studio only (/winroom): the fight room the run is at counts as won (no fight needed), as a real win goes on: its
-- seal opens and the next puzzle waits for the group
function DungeonService.WinRoom()
	local step = Dungeon.STEPS[run.done + 1]
	if not RunService:IsStudio() or not layout or not step or step.kind ~= "fight" then
		return
	end
	run.started = true
	run.cleared = math.max(run.cleared, step.room :: number)
	completeStep("fight")
end

-- Studio only (/puzzle solve): the puzzle the run is at counts as solved
function DungeonService.SolvePuzzle(player: Player)
	if not RunService:IsStudio() or not layout then
		return
	end
	local kind = DungeonRules.stepKind(Dungeon.STEPS, run.done)
	if kind == "fight" or kind == "boss" then
		notify(player, "The run isn't at a puzzle (try /room).", true)
		return
	end
	run.started = true
	DungeonPuzzleService.Solve(kind) -- its chest, then DungeonService.CompleteStep through the hooks
end

-- Studio only (/tap RoomGate<n>): what pressing room n's "Fight" gate does, every check included
function DungeonService.TapGate(player: Player, index: number)
	if RunService:IsStudio() and layout and layout.rooms[index] then
		onRoomGate(player, index)
	end
end

-- Studio only (/puzzle <beams|plates|lock>): every step before that puzzle counts as done, their doors open, the
-- puzzle opens and `player` stands at its room's entrance
function DungeonService.SkipToPuzzle(kind: string, player: Player)
	local index = DungeonRules.stepIndex(Dungeon.STEPS, kind)
	if not RunService:IsStudio() or not layout or not index or kind == "fight" then
		return
	end
	run.started = true
	run.done = math.max(run.done, index - 1)
	for step = 1, run.done do
		openStep(step)
		local before = Dungeon.STEPS[step]
		if before.kind == "fight" then
			run.cleared = math.max(run.cleared, before.room :: number)
		end
	end
	if DungeonRules.stepKind(Dungeon.STEPS, run.done) == kind then
		run.gathering = nil -- Studio's skip opens it at once
		DungeonPuzzleService.Open(kind)
	end
	sendAll(Dungeon.HINTS[kind])
	local character = player.Character
	local spot = layout.afterDoor[index - 1]
	if character and spot then
		WildService.Prestream(player, spot.Position)
		character:PivotTo(spot) -- on the bridge past the door (an angled bridge: never over the chasm)
	end
end

-- Studio only (/room): rooms before `room` count as cleared, their doors open, and `player` goes to that room's gate
-- (rooms + 1: the Prism Hydra's chamber gate)
function DungeonService.SkipTo(room: number, player: Player?)
	if not RunService:IsStudio() or not layout then
		return
	end
	local target = DungeonRules.skipRoom(room, #Dungeon.ROOMS)
	run.started = true
	run.done = math.max(run.done, DungeonRules.doneBefore(Dungeon.STEPS, target))
	run.gathering = nil
	for index = 1, run.done do
		openStep(index)
	end
	run.cleared = math.max(run.cleared, target - 1)
	sendAll(nil)
	local character = if player then player.Character else nil
	if not character then
		return
	end
	if target <= #Dungeon.ROOMS then
		local spot = layout.rooms[target].approach
		WildService.Prestream(player, spot.Position)
		character:PivotTo(spot) -- on the bridge in, facing the ring
	else
		local gate = BossService.GetGate(table.find(Bosses.LADDER, Dungeon.BOSS) :: number)
		if gate then
			WildService.Prestream(player, gate.Position)
			character:PivotTo(gate + Vector3.new(0, 3, 0)) -- in the lair, before the arena's gate
		end
	end
end

function DungeonService.Start()
	layout = WildService.GetDungeonLayout() :: DungeonBuilder.DungeonLayout
	task.spawn(function()
		while true do
			task.wait(Dungeon.ABYSS.FALL_CHECK)
			local ok, problem = pcall(sweepFalls) -- one bad sweep never ends the loop
			if not ok then
				warn("[DungeonService] fall sweep:", problem)
			end
			local gatheredOk, why = pcall(checkGathering)
			if not gatheredOk then
				warn("[DungeonService] gathering:", why)
			end
		end
	end)
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
	-- the castle's gate into the lair: off until the Hydra's door opens (openStep)
	local lairPrompt = Instance.new("ProximityPrompt")
	lairPrompt.ActionText = "Enter"
	lairPrompt.ObjectText = "The Hydra's lair"
	lairPrompt.HoldDuration = 0
	lairPrompt.MaxActivationDistance = Dungeon.LAIR_PROMPT_DISTANCE
	lairPrompt.RequiresLineOfSight = false
	lairPrompt.Enabled = run.done >= #Dungeon.STEPS
	lairPrompt.Parent = layout.lairPortal
	lairPrompt.Triggered:Connect(enterLair)
	layout.lairPortal.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player then
			enterLair(player) -- walking into the swirl (enterLair checks it's open)
		end
	end)
	BattleService.OnFightEnded(onFightEnded)
	BossService.SetRunGate(onChamberGate)
	DungeonPuzzleService.Start(layout, {
		canAct = function(player)
			return DungeonRules.canAct(table.find(run.members, player) ~= nil, run.out[player] == true)
		end,
		active = active,
		runSize = function()
			return run.expected
		end,
		solved = completeStep,
	})
	-- A group member who ran, died or left mid-room (or mid-Hydra) is out (the others fight on)
	BattleService.OnMemberLeft(function(player, monster)
		if monster == run.monster or monster.boss == Dungeon.BOSS then
			markOut(player, "You left the fight, so you're out of the run.")
		end
	end)
	-- A client asks where the run is (its first message may have come before it listened)
	Remotes.DungeonRun.OnServerEvent:Connect(function(player, what)
		if what == "introSeen" then
			-- the client started its welcome: the full one is seen now, and no message carries it again
			if allowAck(player) and pendingIntro[player] then
				pendingIntro[player] = nil
				BossService.MarkIntroSeen(player)
			end
			return
		end
		if allowLeave(player) and table.find(run.members, player) then
			send(player, nil)
		end
	end)
	Remotes.DungeonLeave.OnServerEvent:Connect(function(player)
		if not allowLeave(player) then
			return
		end
		markOut(player, "You left the Dungeon.")
		FrontierService.ReturnToFrontier(player)
	end)
	-- A player arrives once their save has loaded (their party and creatures exist), never before
	DataService.Register({
		name = "DungeonService",
		load = function(player)
			onArrive(player)
		end,
		save = function() end, -- the run is never saved
		unload = function() end,
	})
	PartyService.SetChangeBlocker(function(player)
		if table.find(run.members, player) and not DungeonRules.canChangeParty(run.fought) then
			return "Your party is set for this run."
		end
		return nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		DungeonPuzzleService.Release(player)
		run.out[player] = true
		run.hpLeft[player] = nil
		pendingIntro[player] = nil
	end)
end

return DungeonService
