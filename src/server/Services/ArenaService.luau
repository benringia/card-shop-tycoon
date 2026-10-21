--!strict
-- PvP (battles part 2): challenges, the cash bet held in escrow, the single arena pad with its queue, the
-- fights themselves and the saved win/loss record. A fight is two full parties (cards resting from the wild
-- stay out) in a two-sided BattleSim; the winner takes both bets, a draw refunds them, and leaving or resetting
-- mid-fight forfeits. 10 s after the result both players go home. Spectators walk in through the plaza portal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Combat = require(Config:WaitForChild("Combat"))
local Pvp = require(Config:WaitForChild("Pvp"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local PvpRules = require(Shared:WaitForChild("Util"):WaitForChild("PvpRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local BattleSim = require(Util:WaitForChild("BattleSim"))
local BattleService = require(Services:WaitForChild("BattleService"))
local CardService = require(Services:WaitForChild("CardService"))
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local WildService = require(Services:WaitForChild("WildService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData
type Record = PvpRules.Record

type Challenge = { from: Player, to: Player, bet: number, token: number }
type Match = { a: Player, b: Player, bet: number }
type FightSide = {
	player: Player,
	name: string, -- "a" or "b"
	spawn: CFrame,
	beastIds: { string },
	summonedId: string?, -- the summoned card fights on its own follow marker (held in place)
	extraMarkers: { BasePart },
	died: RBXScriptConnection?,
	leashWarnedAt: number,
}
type Fight = {
	match: Match,
	sim: BattleSim.State,
	sides: { a: FightSide, b: FightSide },
	markers: { [string]: BasePart }, -- sim id -> marker
	extras: { BasePart }, -- every marker made for this fight (not the summoned ones), for clean-up
	spots: { [string]: CFrame }, -- sim id -> where it stands
	sinceSnapshot: number,
	started: boolean, -- both players are on the pad: the sim runs
	forfeited: boolean, -- someone left or reset
	ended: boolean,
}

local ArenaService = {}

local LUNGE_SECONDS = 0.15
local SNAPSHOT_SECONDS = 1
local PORTAL_COLOR = Color3.fromRGB(230, 90, 70)

local records: { [Player]: Record } = {}
local pending: { [Player]: Challenge } = {} -- both players of a challenge point at it
local cooldownUntil: { [Player]: number } = {}
local blockedUntil: { [string]: number } = {} -- pair key -> time
local queue: { Match } = {}
local fight: Fight? = nil
local padBusy = false -- the last pair is still on the pad (the 10 s before they go home)
local busyReturning: { [Player]: boolean } = {} -- in the 10 s after a fight
local challengeToken = 0
local allowAction = RateLimiter.new(Pvp.ACTION_COOLDOWN)
local allowAbility = RateLimiter.new(Combat.ACTION_COOLDOWN / 2)
local rng = Random.new()

local function vec(point: { x: number, y: number, z: number }): Vector3
	return Vector3.new(point.x, point.y, point.z)
end

local ARENA = vec(Pvp.ARENA_ORIGIN)

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

local function status(player: Player, state: string, message: string?, position: number?)
	if player.Parent then
		Remotes.ChallengeStatus:FireClient(player, { state = state, message = message, position = position })
	end
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function pairKey(a: Player, b: Player): string
	local low, high = math.min(a.UserId, b.UserId), math.max(a.UserId, b.UserId)
	return `{low}:{high}`
end

local function inGame(player: Player): boolean
	return player.Parent == Players
end

-- Party cards that can fight now: they exist and aren't resting from the wild
local function usableCards(player: Player): { CardService.Beast }
	local party = PartyService.GetParty(player)
	local list = {}
	if party then
		for slot = 1, 3 do
			local beastId = party.slots[slot]
			local beast = if beastId then CardService.GetBeast(player, beastId) else nil
			if beast and not BattleService.IsResting(player, beast.id) then
				table.insert(list, beast)
			end
		end
	end
	return list
end

local function partyPower(player: Player): number
	local total = 0
	for _, beast in usableCards(player) do
		total += BeastRules.getPower(Cards.ById[beast.cardId], beast.foil, beast.level, beast.stars, beast.grade)
	end
	return total
end

local function isQueued(player: Player): boolean
	for _, match in queue do
		if match.a == player or match.b == player then
			return true
		end
	end
	return false
end

local function inFight(player: Player): boolean
	local current = fight
	return current ~= nil and not current.ended and (current.sides.a.player == player or current.sides.b.player == player)
end

function ArenaService.IsBusy(player: Player): boolean
	return pending[player] ~= nil or isQueued(player) or inFight(player) or busyReturning[player] == true
end

-- Arena map -----------------------------------------------------------------------------------------------

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function portal(parent: Instance, name: string, position: Vector3, facing: Vector3, actionText: string, onTriggered: (Player) -> ())
	local center = position + Vector3.new(0, 5, 0)
	local ring = block(parent, name, Vector3.new(1, 10, 10), CFrame.lookAt(center, center + facing) * CFrame.Angles(0, math.rad(90), 0), PORTAL_COLOR, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.CanCollide = false
	ring.Transparency = 0.25
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = ring
	prompt.Triggered:Connect(onTriggered)
end

local function standsSpot(): CFrame
	local spot = ARENA + Vector3.new(Pvp.PAD_SIZE / 2 + 10, 3, 0)
	return CFrame.lookAt(spot, ARENA + Vector3.new(0, 3, 0))
end

local function goHome(player: Player)
	local plot = PlotService.GetPlot(player)
	if plot then
		WildService.MoveTo(player, plot.spawn.CFrame)
	end
end

function ArenaService.TravelToStands(player: Player)
	if inFight(player) then
		return
	end
	WildService.MoveTo(player, standsSpot())
end

local function buildArena()
	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	block(folder, "Ground", Vector3.new(Pvp.PAD_SIZE + 60, 2, Pvp.PAD_SIZE + 40), CFrame.new(ARENA - Vector3.new(0, 1, 0)), Color3.fromRGB(120, 110, 100), Enum.Material.Cobblestone)
	local pad = block(folder, "Pad", Vector3.new(0.4, Pvp.PAD_SIZE, Pvp.PAD_SIZE), CFrame.new(ARENA + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 170, 110), Enum.Material.Sand)
	pad.Shape = Enum.PartType.Cylinder
	-- Low wall around the pad
	local segments = 24
	for index = 1, segments do
		local angle = index / segments * math.pi * 2
		local spot = ARENA + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (Pvp.PAD_SIZE / 2 + 1)
		block(folder, "Wall", Vector3.new(1, 2, Pvp.PAD_SIZE * math.pi / segments + 0.5), CFrame.lookAt(spot + Vector3.new(0, 1, 0), ARENA + Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(150, 60, 50))
	end
	-- Stands on both long sides, three steps each
	for _, sideSign in { -1, 1 } do
		for step = 1, 3 do
			local x = sideSign * (Pvp.PAD_SIZE / 2 + 6 + step * 3)
			block(folder, "Stands", Vector3.new(3, step * 1.5, Pvp.PAD_SIZE), CFrame.new(ARENA + Vector3.new(x, step * 0.75, 0)), Color3.fromRGB(90, 90, 110))
		end
	end
	portal(folder, "Return to shop", ARENA + Vector3.new(Pvp.PAD_SIZE / 2 + 18, 0, Pvp.PAD_SIZE / 2 + 6), Vector3.new(-1, 0, 0), "Return", function(player)
		if not inFight(player) then
			goHome(player)
		end
	end)
	folder.Parent = workspace

	local plaza = workspace:FindFirstChild("Plaza") or Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = workspace
	portal(plaza, "Arena", vec(Pvp.ARENA_PORTAL), Vector3.new(1, 0, 0), "Watch", function(player)
		if not ArenaService.IsBusy(player) and not BattleService.IsFighting(player) then
			ArenaService.TravelToStands(player)
		end
	end)
end

-- Records -------------------------------------------------------------------------------------------------

local function publishRecord(player: Player)
	local record = records[player]
	if record then
		player:SetAttribute("PvpWins", record.wins)
		player:SetAttribute("PvpLosses", record.losses)
		player:SetAttribute("PvpDraws", record.draws)
	end
end

-- Escrow --------------------------------------------------------------------------------------------------

local function refund(player: Player, bet: number)
	if bet > 0 and inGame(player) then
		EconomyService.AddCash(player, bet)
	end
end

-- Challenges ----------------------------------------------------------------------------------------------

local function clearChallenge(challenge: Challenge)
	if pending[challenge.from] == challenge then
		pending[challenge.from] = nil
	end
	if pending[challenge.to] == challenge then
		pending[challenge.to] = nil
	end
end

-- Why `from` can't challenge (or `to` can't accept) right now, or nil. `ignore` is the challenge being answered.
local function whyNot(from: Player, to: Player, bet: number, ignore: Challenge?): string?
	for _, player in { from, to } do
		if not inGame(player) or not records[player] then
			return "That player isn't ready yet."
		elseif (pending[player] and pending[player] ~= ignore) or isQueued(player) or inFight(player) or busyReturning[player] then
			return if player == from then "You already have a PvP match going." else `{to.DisplayName} is busy.`
		elseif BattleService.IsFighting(player) or PartyService.IsLocked(player) then
			return if player == from then "Finish your fight first." else `{to.DisplayName} is in a fight.`
		elseif #usableCards(player) == 0 then
			return if player == from then "You need a rested party card to fight." else `{to.DisplayName} has no rested party cards.`
		end
	end
	local cap = PvpRules.getBetCap(Pvp, EconomyService.GetCash(from), EconomyService.GetCash(to), EconomyService.GetLevel(from), EconomyService.GetLevel(to))
	if not PvpRules.isValidBet(Pvp, bet, cap) then
		return `That bet isn't allowed (max ${cap}).`
	end
	return nil
end

local function onChallenge(player: Player, targetUserId: unknown, bet: unknown)
	if not allowAction(player) or typeof(targetUserId) ~= "number" or typeof(bet) ~= "number" then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return
	end
	local now = os.clock()
	if (cooldownUntil[player] or 0) > now then
		status(player, "refused", "Wait a moment before challenging again.")
		return
	elseif (blockedUntil[pairKey(player, target)] or 0) > now then
		status(player, "refused", `{target.DisplayName} said no. Try again later.`)
		return
	end
	local rootA, rootB = getRoot(player), getRoot(target)
	if not rootA or not rootB or (rootA.Position - rootB.Position).Magnitude > Pvp.CHALLENGE_DISTANCE then
		status(player, "refused", "Get closer to challenge them.")
		return
	end
	local reason = whyNot(player, target, bet :: number, nil)
	if reason then
		status(player, "refused", reason)
		return
	end

	challengeToken += 1
	local challenge: Challenge = { from = player, to = target, bet = bet :: number, token = challengeToken }
	pending[player], pending[target] = challenge, challenge
	cooldownUntil[player] = now + Pvp.CHALLENGE_COOLDOWN
	Remotes.ChallengeIncoming:FireClient(target, {
		fromUserId = player.UserId,
		fromName = player.DisplayName,
		bet = challenge.bet,
		yourPower = partyPower(target),
		theirPower = partyPower(player),
		seconds = Pvp.CHALLENGE_SECONDS,
	})
	status(player, "sent", `Challenge sent to {target.DisplayName}.`)
	task.delay(Pvp.CHALLENGE_SECONDS, function()
		if pending[target] == challenge then
			clearChallenge(challenge)
			blockedUntil[pairKey(player, target)] = os.clock() + Pvp.DECLINE_BLOCK_SECONDS
			status(player, "expired", `{target.DisplayName} didn't answer.`)
			status(target, "expired")
		end
	end)
end

local tryStartNext: () -> ()

local function onRespond(player: Player, accept: unknown)
	local challenge = pending[player]
	if not allowAction(player) or not challenge or challenge.to ~= player or typeof(accept) ~= "boolean" then
		return
	end
	local from = challenge.from
	if not accept then
		clearChallenge(challenge)
		blockedUntil[pairKey(from, player)] = os.clock() + Pvp.DECLINE_BLOCK_SECONDS
		status(from, "declined", `{player.DisplayName} declined.`)
		status(player, "cancelled")
		return
	end
	local reason = whyNot(from, player, challenge.bet, challenge)
	if reason then
		clearChallenge(challenge)
		status(from, "refused", reason)
		status(player, "refused", reason)
		return
	end
	-- Escrow: take both bets now, or neither
	local bet = challenge.bet
	if bet > 0 then
		if not EconomyService.TrySpend(from, bet) then
			clearChallenge(challenge)
			status(from, "refused", "You don't have the cash for that bet any more.")
			status(player, "refused", `{from.DisplayName} can't cover the bet any more.`)
			return
		elseif not EconomyService.TrySpend(player, bet) then
			refund(from, bet)
			clearChallenge(challenge)
			status(from, "refused", `{player.DisplayName} can't cover the bet any more.`)
			status(player, "refused", "You don't have the cash for that bet any more.")
			return
		end
	end
	clearChallenge(challenge)
	table.insert(queue, { a = from, b = player, bet = bet })
	tryStartNext()
	for index, match in queue do
		status(match.a, "queued", nil, index)
		status(match.b, "queued", nil, index)
	end
end

local function removeFromQueue(player: Player): boolean
	for index, match in queue do
		if match.a == player or match.b == player then
			table.remove(queue, index)
			refund(match.a, match.bet)
			refund(match.b, match.bet)
			local other = if match.a == player then match.b else match.a
			status(other, "cancelled", `{player.DisplayName} left the arena queue. Your bet was returned.`)
			status(player, "cancelled", "You left the arena queue. Your bet was returned.")
			return true
		end
	end
	return false
end

local function onCancel(player: Player)
	if not allowAction(player) then
		return
	end
	local challenge = pending[player]
	if challenge and challenge.from == player then
		clearChallenge(challenge)
		status(challenge.to, "cancelled")
		status(player, "cancelled", "Challenge cancelled.")
	elseif not challenge then
		removeFromQueue(player)
	end
end

-- Fights --------------------------------------------------------------------------------------------------

local function sideOf(current: Fight, player: Player): FightSide?
	return if current.sides.a.player == player then current.sides.a elseif current.sides.b.player == player then current.sides.b else nil
end

local function place(current: Fight, id: string, cframe: CFrame)
	local sideName = string.sub(id, 1, 1)
	local side = (current.sides :: any)[sideName] :: FightSide?
	if side and side.summonedId and id == `{sideName}:{side.summonedId}` then
		PartyService.SetHold(side.player, cframe)
	else
		local marker = current.markers[id]
		if marker then
			marker.CFrame = cframe
		end
	end
end

local function lunge(current: Fight, from: string, to: string)
	local home, targetSpot = current.spots[from], current.spots[to]
	if not home or not targetSpot then
		return
	end
	local direction = targetSpot.Position - home.Position
	if direction.Magnitude < 0.1 then
		return
	end
	place(current, from, home + direction.Unit * Combat.LUNGE_STUDS)
	task.delay(LUNGE_SECONDS, function()
		if not current.ended then
			place(current, from, home)
		end
	end)
end

local function updateHp(current: Fight, id: string)
	local marker = current.markers[id]
	local info = BattleSim.getFighter(current.sim, id)
	if marker and info then
		marker:SetAttribute("Hp", info.hp)
		marker:SetAttribute("MaxHp", info.maxHp)
		marker:SetAttribute("Fainted", if info.fainted then true else nil)
	end
end

local function broadcast(current: Fight, events: { BattleSim.Event })
	local snapshot = BattleSim.snapshot(current.sim)
	for _, side in { current.sides.a, current.sides.b } do
		if inGame(side.player) then
			Remotes.BattleEvent:FireClient(side.player, { events = events, snapshot = snapshot })
		end
	end
end

local function handleEvents(current: Fight, events: { BattleSim.Event })
	for _, event in events do
		if event.type == "attack" and event.from and event.to then
			lunge(current, event.from, event.to)
		end
		if event.to then
			updateHp(current, event.to)
		end
		if event.from then
			updateHp(current, event.from)
		end
	end
	if #events > 0 then
		current.sinceSnapshot = 0
		broadcast(current, events)
	end
end

local endFight: (current: Fight) -> ()

local function cleanUp(current: Fight)
	for _, side in { current.sides.a, current.sides.b } do
		local player = side.player
		if side.died then
			side.died:Disconnect()
		end
		PartyService.SetHold(player, nil)
		PartyService.SetLocked(player, false)
		for _, beastId in side.beastIds do
			CardService.SetFighting(player, beastId, false)
		end
		for _, marker in side.extraMarkers do
			marker:Destroy()
		end
		local summoned = PartyService.GetMarker(player)
		if summoned then
			summoned:SetAttribute("Hp", nil)
			summoned:SetAttribute("MaxHp", nil)
			summoned:SetAttribute("Fainted", nil)
		end
	end
end

endFight = function(current: Fight)
	if current.ended then
		return
	end
	current.ended = true
	if fight == current then
		fight = nil
	end
	cleanUp(current)

	local result = current.sim.result or "draw"
	local bet = current.match.bet
	for _, side in { current.sides.a, current.sides.b } do
		local player = side.player
		local outcome = if result == "draw" then "draw" elseif result == side.name then "win" else "lose"
		local other = if side.name == "a" then current.sides.b.player else current.sides.a.player
		if inGame(player) then
			local payout = PvpRules.getPayout(outcome, bet)
			if payout > 0 then
				EconomyService.AddCash(player, payout)
			end
			if records[player] then
				records[player] = PvpRules.addResult(records[player], outcome)
				publishRecord(player)
			end
			busyReturning[player] = true
			Remotes.BattleEnded:FireClient(player, {
				mode = "pvp",
				outcome = outcome,
				cash = if outcome == "win" then bet else if outcome == "lose" then -bet else 0,
				opponentName = other.DisplayName,
				forfeit = current.forfeited and outcome == "win",
				returnIn = Pvp.RETURN_SECONDS,
			})
		end
	end

	padBusy = true
	task.delay(Pvp.RETURN_SECONDS, function()
		for _, side in { current.sides.a, current.sides.b } do
			busyReturning[side.player] = nil
			if inGame(side.player) and not inFight(side.player) then
				goHome(side.player)
			end
		end
		padBusy = false
		tryStartNext()
	end)
end

-- One player's side: their usable cards as fighters, in a line in front of them
local function buildSide(current: Fight, player: Player, name: string, spawn: CFrame, inputs: { BattleSim.FighterInput }): FightSide
	local party = PartyService.GetParty(player)
	local summonedId = if party and party.summoned then party.slots[party.summoned] else nil
	local side: FightSide = {
		player = player,
		name = name,
		spawn = spawn,
		beastIds = {},
		summonedId = nil,
		extraMarkers = {},
		died = nil,
		leashWarnedAt = 0,
	}
	local forward = spawn.LookVector
	local right = spawn.RightVector
	for index, input in inputs do
		local id = `{name}:{input.id}`
		local spotPosition = spawn.Position + forward * 6 + right * (index - (#inputs + 1) / 2) * Pvp.CREATURE_SPACING
		local spot = CFrame.lookAt(spotPosition, spotPosition + forward)
		current.spots[id] = spot
		table.insert(side.beastIds, input.id)
		CardService.SetFighting(player, input.id, true)
		local summonedMarker = PartyService.GetMarker(player)
		if input.id == summonedId and summonedMarker then
			side.summonedId = input.id
			PartyService.SetHold(player, spot)
			current.markers[id] = summonedMarker
		else
			local marker = PartyService.CreateMarker(player, input.id, spot)
			if marker then
				table.insert(side.extraMarkers, marker)
				table.insert(current.extras, marker)
				current.markers[id] = marker
			end
		end
	end
	return side
end

-- Something broke while starting: undo everything for both players and give the bets back
local function abortMatch(current: Fight, match: Match, err: unknown)
	warn(`[ArenaService] a match failed to start: {err}`)
	if current.ended then
		return
	end
	current.ended = true
	if fight == current then
		fight = nil
	end
	for _, player in { match.a, match.b } do
		PartyService.SetHold(player, nil)
		PartyService.SetLocked(player, false)
		for _, beast in usableCards(player) do
			CardService.SetFighting(player, beast.id, false)
		end
		local summoned = PartyService.GetMarker(player)
		if summoned then
			summoned:SetAttribute("Hp", nil)
			summoned:SetAttribute("MaxHp", nil)
			summoned:SetAttribute("Fainted", nil)
		end
		refund(player, match.bet)
		status(player, "refused", "The match couldn't start. Your bet was returned.")
	end
	for _, marker in current.extras do
		marker:Destroy()
	end
	task.defer(tryStartNext)
end

local runMatch: (current: Fight, a: Player, b: Player, spawnA: CFrame, spawnB: CFrame, inputsA: { BattleSim.FighterInput }, inputsB: { BattleSim.FighterInput }) -> ()

local function startMatch(match: Match): boolean
	local a, b = match.a, match.b
	if not inGame(a) or not inGame(b) then
		refund(a, match.bet)
		refund(b, match.bet)
		status(a, "cancelled", "The match was cancelled. Your bet was returned.")
		status(b, "cancelled", "The match was cancelled. Your bet was returned.")
		return false
	end
	local inputsA, inputsB = {}, {}
	for _, beast in usableCards(a) do
		table.insert(inputsA, BattleService.FighterInput(beast))
	end
	for _, beast in usableCards(b) do
		table.insert(inputsB, BattleService.FighterInput(beast))
	end
	if #inputsA == 0 or #inputsB == 0 then
		refund(a, match.bet)
		refund(b, match.bet)
		status(a, "refused", "Someone has no rested party cards. Bets returned.")
		status(b, "refused", "Someone has no rested party cards. Bets returned.")
		return false
	end

	local spawnA = CFrame.lookAt(ARENA + Vector3.new(0, 3, -Pvp.SPAWN_OFFSET), ARENA + Vector3.new(0, 3, 0))
	local spawnB = CFrame.lookAt(ARENA + Vector3.new(0, 3, Pvp.SPAWN_OFFSET), ARENA + Vector3.new(0, 3, 0))
	local current: any = {
		match = match,
		sim = BattleSim.new(Combat, { fighters = inputsA, abilities = true, canRun = false }, { fighters = inputsB, abilities = true, canRun = false }, rng:NextInteger(1, 2 ^ 30)),
		markers = {},
		extras = {},
		spots = {},
		sinceSnapshot = 0,
		started = false,
		forfeited = false,
		ended = false,
	}
	fight = current
	local ok, err = pcall(runMatch, current, a, b, spawnA, spawnB, inputsA, inputsB)
	if not ok then
		abortMatch(current, match, err)
	end
	return true
end

runMatch = function(current: Fight, a: Player, b: Player, spawnA: CFrame, spawnB: CFrame, inputsA: { BattleSim.FighterInput }, inputsB: { BattleSim.FighterInput })
	local match = current.match
	PartyService.SetLocked(a, true)
	PartyService.SetLocked(b, true)
	-- Sides first, so a player leaving while being moved still forfeits through onLeaving
	current.sides = {
		a = buildSide(current, a, "a", spawnA, inputsA),
		b = buildSide(current, b, "b", spawnB, inputsB),
	}
	for id in current.markers do
		updateHp(current, id)
	end
	status(a, "starting")
	status(b, "starting")
	-- Streams the pad in on each device first (can take a few seconds)
	WildService.MoveTo(a, spawnA)
	if current.ended then
		return -- someone left while moving: already settled (don't pull the other one in)
	end
	WildService.MoveTo(b, spawnB)
	if current.ended then
		return
	end
	for _, side in { current.sides.a, current.sides.b } do
		local character = side.player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			side.died = humanoid.Died:Connect(function()
				if not current.ended then
					current.forfeited = true
					BattleSim.forfeit(current.sim, side.name)
					endFight(current)
				end
			end)
		end
	end

	local names: { [string]: string } = {}
	for _, side in { current.sides.a, current.sides.b } do
		for _, beastId in side.beastIds do
			local beast = CardService.GetBeast(side.player, beastId)
			if beast then
				names[`{side.name}:{beastId}`] = Cards.ById[beast.cardId].name
			end
		end
	end
	local snapshot = BattleSim.snapshot(current.sim)
	for _, side in { current.sides.a, current.sides.b } do
		local other = if side.name == "a" then b else a
		Remotes.BattleStarted:FireClient(side.player, {
			mode = "pvp",
			side = side.name,
			names = names,
			opponentName = other.DisplayName,
			bet = match.bet,
			markers = current.markers,
			snapshot = snapshot,
			startsIn = Pvp.COUNTDOWN_SECONDS,
		})
	end
	-- 3, 2, 1, FIGHT! on both screens, then the fight runs (leaving or resetting meanwhile still forfeits)
	task.delay(Pvp.COUNTDOWN_SECONDS, function()
		if not current.ended then
			current.started = true
		end
	end)
end

tryStartNext = function()
	while not fight and not padBusy and #queue > 0 do
		local match = table.remove(queue, 1) :: Match
		if startMatch(match) then
			break
		end
	end
	for index, match in queue do
		status(match.a, "queued", nil, index)
		status(match.b, "queued", nil, index)
	end
end

-- During a fight: stay on your half of the pad; leaving the game or losing your character forfeits
local function keepNear(side: FightSide)
	local root = getRoot(side.player)
	if not root then
		return
	end
	local offset = Vector3.new(root.Position.X - side.spawn.X, 0, root.Position.Z - side.spawn.Z)
	if offset.Magnitude <= Pvp.LEASH_RADIUS then
		return
	end
	local edge = side.spawn.Position + offset.Unit * (Pvp.LEASH_RADIUS - 2)
	root.AssemblyLinearVelocity = Vector3.zero
	;(side.player.Character :: Model):PivotTo(CFrame.lookAt(Vector3.new(edge.X, root.Position.Y, edge.Z), Vector3.new(ARENA.X, root.Position.Y, ARENA.Z)))
	if os.clock() - side.leashWarnedAt > 3 then
		side.leashWarnedAt = os.clock()
		notify(side.player, "Stay on your side of the arena!", true)
	end
end

local function stepFight(dt: number)
	local current = fight
	if not current or current.ended or not current.started then
		return
	end
	for _, side in { current.sides.a, current.sides.b } do
		if not inGame(side.player) or not getRoot(side.player) then
			current.forfeited = true
			BattleSim.forfeit(current.sim, side.name)
			endFight(current)
			return
		end
		keepNear(side)
	end
	handleEvents(current, BattleSim.step(current.sim, dt))
	if current.sim.result then
		endFight(current)
		return
	end
	current.sinceSnapshot += dt
	if current.sinceSnapshot >= SNAPSHOT_SECONDS then
		current.sinceSnapshot = 0
		broadcast(current, {})
	end
end

local function onUseAbility(player: Player, fighterId: unknown, which: unknown)
	local current = fight
	if not current or current.ended or not current.started or not allowAbility(player) then
		return
	end
	local side = sideOf(current, player)
	if not side or typeof(fighterId) ~= "string" or string.sub(fighterId, 1, 2) ~= `{side.name}:` then
		return
	end
	if which ~= "element" and which ~= "signature" then
		return
	end
	local events = BattleSim.useAbility(current.sim, fighterId, which :: string)
	if events then
		handleEvents(current, events)
		if current.sim.result then
			endFight(current)
		end
	end
end

-- Leaving -------------------------------------------------------------------------------------------------

-- Before the leave save: settle anything with cash in it, so payouts and refunds are saved
local function onLeaving(player: Player)
	local challenge = pending[player]
	if challenge then
		clearChallenge(challenge)
		local other = if challenge.from == player then challenge.to else challenge.from
		status(other, "cancelled", `{player.DisplayName} left.`)
	end
	removeFromQueue(player)
	local current = fight
	if current and not current.ended then
		local side = sideOf(current, player)
		if side then
			current.forfeited = true
			BattleSim.forfeit(current.sim, side.name)
			endFight(current)
		end
	end
end

-- Data ----------------------------------------------------------------------------------------------------

local function load(player: Player, data: PlayerData)
	records[player] = PvpRules.sanitizeRecord(data.pvp)
	publishRecord(player)
end

local function save(player: Player, data: PlayerData)
	local record = records[player]
	if record then
		data.pvp = { wins = record.wins, losses = record.losses, draws = record.draws }
	end
end

local function unload(player: Player)
	onLeaving(player)
	records[player] = nil
	pending[player] = nil
	cooldownUntil[player] = nil
	busyReturning[player] = nil
end

function ArenaService.Start()
	buildArena()
	DataService.Register({ name = "ArenaService", load = load, save = save, unload = unload })
	DataService.OnBeforeLeave(onLeaving)
	Remotes.Challenge.OnServerEvent:Connect(onChallenge)
	Remotes.ChallengeRespond.OnServerEvent:Connect(onRespond)
	Remotes.ChallengeCancel.OnServerEvent:Connect(onCancel)
	Remotes.UseAbility.OnServerEvent:Connect(onUseAbility) -- BattleService ignores players it isn't fighting for

	BattleService.AddStartBlocker(function(player)
		return if ArenaService.IsBusy(player) then "You have a PvP match going." else nil
	end)
	WildService.AddTravelBlocker(function(player)
		return if ArenaService.IsBusy(player) then "You can't travel during a PvP match." else nil
	end)

	local elapsed, sincePower = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		sincePower += dt
		local tick = 1 / Combat.TICK_RATE
		if elapsed >= tick then
			local step = elapsed
			elapsed = 0
			stepFight(step)
		end
		if sincePower >= Pvp.POWER_REFRESH_SECONDS then
			sincePower = 0
			for player in records do
				player:SetAttribute("PartyPower", partyPower(player))
			end
		end
	end)
end

return ArenaService
