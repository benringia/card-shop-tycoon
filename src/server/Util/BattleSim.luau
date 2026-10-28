--!strict
-- One fight between two sides of fighters, simulated on the server. Wild fights: side A is the party
-- (leader + call-in reserves), side B one monster with no abilities. PvP: both sides are full parties. Boss groups:
-- side A holds several players' fighters, each tagged with its owner (one call-in per owner, abilities only on your own
-- fighters, a player leaving withdraws only theirs, damage dealt and taken tallied for the loot rules). Boss fights
-- allow swaps (swapSeconds): a reserve comes in for one of its owner's creatures, which goes back to the reserves with
-- its HP (a fainted one stays benched); when all of an owner's creatures faint, their healthiest reserve comes in.
-- Pure (only CombatMath; no Roblox APIs) so tests/ run it in Lune. Seeded, so the same seed and inputs replay
-- the same fight. Fighter ids are prefixed by side ("a:<id>", "b:<id>") in events and snapshots.
local CombatMath = if game ~= nil
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("CombatMath")) :: any
	else require("../../shared/Util/CombatMath") :: any

local BattleSim = {}

-- mechanics: a boss's (Config/Bosses): heal below an HP fraction every cooldown, enrage once below one, a shield every
-- few seconds (its side's shield; breaking it stuns the boss), a thunderclap that stuns every enemy (longer on slow
-- ones), adds at HP fractions (auto-attacks hit them first; the boss takes x guard damage while any stands; the fight is
-- won when the boss falls, adds or not). boss: stuns on it last at most BOSS_MAX_STUN seconds (not a shield break's)
export type Mechanics = {
	heal: { below: number, fraction: number, cooldown: number }?,
	enrage: { below: number, atkMultiplier: number }?,
	shield: { every: number, fraction: number, breakStun: number }?,
	thunderclap: { every: number, seconds: number, minFactor: number, maxFactor: number }?,
	adds: { at: { number }, count: number, hpShare: number, atkShare: number, guard: number, species: string }?,
}
export type FighterInput = { id: string, element: string, hp: number, atk: number, spd: number, signature: string?, elite: boolean?, mechanics: Mechanics?, boss: boolean?, owner: string?, swings: number? }
export type SideInput = { fighters: { FighterInput }, reserves: { FighterInput }?, abilities: boolean, canRun: boolean, swapSeconds: number? }
export type Event = {
	-- "attack" | "ability" | "faint" | "callin" | "swap" (from: in, to: out or nil) | "run" | "end" | "heal" | "enrage" |
	-- "leave" | "shield" (heal: its size) | "shieldBreak" | "thunderclap" | "stun" (damage: its seconds) | "spawn" (to: the add)
	type: string,
	from: string?,
	to: string?,
	damage: number?,
	heal: number?,
	strength: string?,
	dodged: boolean?,
	kind: string?,
	ok: boolean?,
	result: string?,
}

type Fighter = {
	id: string, -- prefixed: "a:<id>"
	rawId: string,
	side: string,
	element: string,
	maxHp: number,
	hp: number,
	atk: number,
	spd: number,
	signature: string?,
	elite: boolean,
	nextAttack: number,
	abilityReady: number,
	signatureReady: number,
	overcharge: number, -- fast attacks left
	dodgeUntil: number,
	stunUntil: number,
	slowUntil: number,
	slow: number,
	curseUntil: number,
	curse: number,
	burnUntil: number,
	burnPerSecond: number,
	burnTick: number,
	fainted: boolean,
	mechanics: Mechanics?,
	boss: boolean,
	healReady: number,
	enraged: boolean,
	shieldReady: number, -- boss: when its next shield goes up
	clapReady: number, -- boss: when its next thunderclap comes
	addsDone: { [number]: boolean }, -- boss: which `adds.at` thresholds have summoned
	addsMade: number, -- boss: adds summoned so far (their ids: "add1", "add2", ...)
	swings: number, -- targets hit per attack (a boss against a group hits several)
	owner: string?, -- the player it belongs to (groups); nil when the side has one owner
	left: boolean, -- its player left the fight: out, never targeted, not fainted
	benched: boolean, -- fainted and swapped out: off the field, but it still rests after the fight
	dealt: number, -- damage it did
	taken: number, -- damage it took
	burnBy: Fighter?, -- who set its burn (credited with the burn damage)
}

type Side = {
	name: string,
	fighters: { Fighter }, -- on the field
	reserves: { Fighter }, -- may be called in (wild)
	abilities: boolean,
	canRun: boolean,
	shield: number, -- damage this side still absorbs (Tidal Shield)
	calledBy: { [string]: boolean }, -- owners ("" = the only one) who used their call-in
	runReadyAt: number,
	swapSeconds: number?, -- boss fights: seconds between one owner's swaps (nil: no swaps)
	swapReadyAt: { [string]: number }, -- by owner
}

export type State = {
	combat: any,
	time: number,
	seed: number,
	sides: { a: Side, b: Side },
	result: string?, -- "a" | "b" | "draw" | "run"
	maxSeconds: number?, -- this fight's time limit (bosses get longer); combat.MAX_FIGHT_SECONDS when nil
}

-- Small deterministic generator (LCG) so fights replay identically in Lune and Roblox
local function random(state: State): number
	state.seed = (state.seed * 1103515245 + 12345) % 2147483648
	return state.seed / 2147483648
end

local function makeFighter(combat: any, input: FighterInput, side: string, time: number): Fighter
	return {
		id = `{side}:{input.id}`,
		rawId = input.id,
		side = side,
		element = input.element,
		maxHp = input.hp,
		hp = input.hp,
		atk = input.atk,
		spd = input.spd,
		signature = input.signature,
		elite = input.elite == true,
		nextAttack = time + CombatMath.getAttackInterval(combat, input.spd),
		abilityReady = time,
		signatureReady = time,
		overcharge = 0,
		dodgeUntil = 0,
		stunUntil = 0,
		slowUntil = 0,
		slow = 0,
		curseUntil = 0,
		curse = 0,
		burnUntil = 0,
		burnPerSecond = 0,
		burnTick = 0,
		fainted = false,
		mechanics = input.mechanics,
		boss = input.boss == true,
		healReady = time,
		enraged = false,
		shieldReady = if input.mechanics and input.mechanics.shield then time + input.mechanics.shield.every else math.huge,
		clapReady = if input.mechanics and input.mechanics.thunderclap then time + input.mechanics.thunderclap.every else math.huge,
		addsDone = {},
		addsMade = 0,
		swings = math.max(1, input.swings or 1),
		owner = input.owner,
		left = false,
		benched = false,
		dealt = 0,
		taken = 0,
		burnBy = nil,
	}
end

local function makeSide(combat: any, input: SideInput, name: string): Side
	local fighters, reserves = {}, {}
	for _, fighter in input.fighters do
		table.insert(fighters, makeFighter(combat, fighter, name, 0))
	end
	for _, fighter in input.reserves or {} do
		table.insert(reserves, makeFighter(combat, fighter, name, 0))
	end
	return {
		name = name,
		fighters = fighters,
		reserves = reserves,
		abilities = input.abilities,
		canRun = input.canRun,
		shield = 0,
		calledBy = {},
		runReadyAt = 0,
		swapSeconds = input.swapSeconds,
		swapReadyAt = {},
	}
end

function BattleSim.new(combat: any, sideA: SideInput, sideB: SideInput, seed: number): State
	return {
		combat = combat,
		time = 0,
		seed = math.floor(math.abs(seed)) % 2147483648,
		sides = { a = makeSide(combat, sideA, "a"), b = makeSide(combat, sideB, "b") },
		result = nil,
	}
end

local function other(state: State, side: Side): Side
	return if side.name == "a" then state.sides.b else state.sides.a
end

local function find(state: State, id: string): (Fighter?, Side?)
	for _, side in { state.sides.a, state.sides.b } do
		for _, fighter in side.fighters do
			if fighter.id == id then
				return fighter, side
			end
		end
	end
	return nil, nil
end

local function standing(side: Side): { Fighter }
	local list = {}
	for _, fighter in side.fighters do
		if not fighter.fainted and not fighter.left then
			table.insert(list, fighter)
		end
	end
	return list
end

-- Everyone attacks the standing enemy with the lowest share of its HP left (ties: list order). Auto-attacks go to a
-- boss's adds first while any stand (abilities may still pick the boss).
local function targetOf(state: State, fighter: Fighter, autoAttack: boolean?): Fighter?
	local enemies = standing(other(state, (state.sides :: any)[fighter.side]))
	if autoAttack then
		local adds = {}
		for _, enemy in enemies do
			if not enemy.boss then
				table.insert(adds, enemy)
			end
		end
		if #adds > 0 and #adds < #enemies then
			enemies = adds
		end
	end
	local target = enemies[1]
	for _, enemy in enemies do
		if enemy.hp / enemy.maxHp < target.hp / target.maxHp then
			target = enemy
		end
	end
	return target
end

local function finish(state: State, result: string, events: { Event })
	state.result = result
	table.insert(events, { type = "end", result = result })
end

local function ownerKey(fighter: Fighter): string
	return fighter.owner or ""
end

-- One owner's creatures on the field (fainted ones too, until benched)
local function onField(side: Side, key: string): { Fighter }
	local list = {}
	for _, fighter in side.fighters do
		if ownerKey(fighter) == key and not fighter.left and not fighter.benched then
			table.insert(list, fighter)
		end
	end
	return list
end

-- A reserve comes in. It takes the place of its owner's first fainted creature, or, when the owner already has as
-- many standing as they may (one, two after a call-in), of the one with the smallest share of its HP left.
local function bringIn(state: State, side: Side, incoming: Fighter, events: { Event })
	local key = ownerKey(incoming)
	local field = onField(side, key)
	local slots = if side.calledBy[key] then 2 else 1
	local out: Fighter? = nil
	local standingCount = 0
	for _, fighter in field do
		if fighter.fainted then
			out = out or fighter
		else
			standingCount += 1
		end
	end
	if not out and standingCount >= slots then
		for _, fighter in field do
			if not out or fighter.hp / fighter.maxHp < (out :: Fighter).hp / (out :: Fighter).maxHp then
				out = fighter
			end
		end
	end
	table.remove(side.reserves, table.find(side.reserves, incoming) :: number)
	incoming.nextAttack = state.time + CombatMath.getAttackInterval(state.combat, incoming.spd)
	table.insert(side.fighters, incoming)
	if out then
		if out.fainted then
			out.benched = true
		else
			table.remove(side.fighters, table.find(side.fighters, out) :: number)
			table.insert(side.reserves, out)
		end
	end
	table.insert(events, { type = "swap", from = incoming.id, to = if out then out.id else nil })
end

-- Swap fights: when an owner has nobody standing, their healthiest reserve comes in (true if one did)
local function autoSwap(state: State, side: Side, key: string, events: { Event }): boolean
	if not side.swapSeconds then
		return false
	end
	for _, fighter in onField(side, key) do
		if not fighter.fainted then
			return false
		end
	end
	local best: Fighter? = nil
	for _, reserve in side.reserves do
		if ownerKey(reserve) == key and (not best or reserve.hp > best.hp) then
			best = reserve
		end
	end
	if not best then
		return false
	end
	bringIn(state, side, best, events)
	return true
end

local function takeDamage(state: State, target: Fighter, amount: number, events: { Event })
	target.taken += math.min(amount, target.hp)
	target.hp = math.max(0, target.hp - amount)
	if target.hp <= 0 and not target.fainted then
		target.fainted = true
		table.insert(events, { type = "faint", to = target.id })
		local side = (state.sides :: any)[target.side] :: Side
		if target.boss and not state.result then
			finish(state, other(state, side).name, events) -- the boss is down: its adds don't matter
			return
		end
		autoSwap(state, side, ownerKey(target), events)
		if #standing(side) == 0 and not state.result then
			finish(state, other(state, side).name, events)
		end
	end
end

-- A boss with adds standing takes only part of the damage (adds.guard)
local function guarded(side: Side, target: Fighter): number
	local adds = if target.boss and target.mechanics then target.mechanics.adds else nil
	if not adds then
		return 1
	end
	for _, fighter in standing(side) do
		if not fighter.boss then
			return adds.guard
		end
	end
	return 1
end

-- A boss's shield just broke: the boss is stunned for its breakStun (longer than the usual cap on boss stuns)
local function shieldBroke(state: State, side: Side, events: { Event })
	for _, fighter in side.fighters do
		local shield = if fighter.boss and fighter.mechanics then fighter.mechanics.shield else nil
		if shield and not fighter.fainted then
			fighter.stunUntil = math.max(fighter.stunUntil, state.time + shield.breakStun)
			table.insert(events, { type = "shieldBreak", to = fighter.id })
		end
	end
end

-- One hit from `from` on `target`: element, curse, dodge and the target side's shield all apply
local function hit(state: State, from: Fighter, target: Fighter, multiplier: number, events: { Event }, kind: string?): number
	if state.time < target.dodgeUntil then
		table.insert(events, { type = if kind then "ability" else "attack", kind = kind, from = from.id, to = target.id, damage = 0, dodged = true })
		return 0
	end
	local atk = from.atk * multiplier * (if state.time < from.curseUntil then 1 - from.curse else 1)
	local elementMult, strength = CombatMath.getElementMultiplier(state.combat, from.element, target.element)
	local side = (state.sides :: any)[target.side] :: Side
	local damage = math.round(CombatMath.getDamage(state.combat, atk, elementMult, random(state)) * guarded(side, target))
	local hadShield = side.shield > 0
	local absorbed = math.min(side.shield, damage)
	side.shield -= absorbed
	if hadShield and side.shield <= 0 then
		shieldBroke(state, side, events)
	end
	local taken = damage - absorbed
	table.insert(events, { type = if kind then "ability" else "attack", kind = kind, from = from.id, to = target.id, damage = taken, strength = strength })
	from.dealt += math.min(taken, target.hp)
	takeDamage(state, target, taken, events)
	return taken
end

local function interval(state: State, fighter: Fighter): number
	local value = CombatMath.getAttackInterval(state.combat, fighter.spd)
	if state.time < fighter.slowUntil then
		value /= 1 - fighter.slow
	end
	return value
end

-- One attack: the usual target, then (a boss against a group) the next most hurt standing enemies, each once
local function attack(state: State, fighter: Fighter, events: { Event })
	local target = targetOf(state, fighter, true)
	if not target then
		return
	end
	hit(state, fighter, target, 1, events, nil)
	if fighter.swings <= 1 then
		return
	end
	local others = {}
	for _, enemy in standing(other(state, (state.sides :: any)[fighter.side])) do
		if enemy ~= target then
			table.insert(others, enemy)
		end
	end
	table.sort(others, function(a, b)
		return a.hp / a.maxHp < b.hp / b.maxHp
	end)
	for index = 1, math.min(fighter.swings - 1, #others) do
		if state.result then
			return
		end
		hit(state, fighter, others[index], 1, events, nil)
	end
end

-- One burn per second of Inferno; a long frame catches up on every tick it covered
local function burn(state: State, fighter: Fighter, events: { Event })
	while not fighter.fainted and fighter.burnUntil > 0 and fighter.burnTick <= math.min(state.time, fighter.burnUntil) + 1e-9 do
		fighter.burnTick += 1
		local damage = math.max(1, math.round(fighter.burnPerSecond))
		table.insert(events, { type = "ability", kind = "Burn", to = fighter.id, damage = damage })
		local source = fighter.burnBy
		if source then
			source.dealt += math.min(damage, fighter.hp)
		end
		takeDamage(state, fighter, damage, events)
	end
end

-- A boss's mechanics, checked every step: heal under its HP fraction (then wait the cooldown), enrage once
local function bossMechanics(state: State, fighter: Fighter, events: { Event })
	local mechanics = fighter.mechanics
	if not mechanics or fighter.fainted then
		return
	end
	local share = fighter.hp / fighter.maxHp
	local heal = mechanics.heal
	if heal and share < heal.below and state.time >= fighter.healReady then
		local amount = math.round(fighter.maxHp * heal.fraction)
		fighter.hp = math.min(fighter.maxHp, fighter.hp + amount)
		fighter.healReady = state.time + heal.cooldown
		table.insert(events, { type = "heal", to = fighter.id, heal = amount })
	end
	local enrage = mechanics.enrage
	if enrage and not fighter.enraged and share < enrage.below then
		fighter.enraged = true
		fighter.atk *= enrage.atkMultiplier
		table.insert(events, { type = "enrage", from = fighter.id })
	end
	local side = (state.sides :: any)[fighter.side] :: Side
	local shield = mechanics.shield
	if shield and state.time >= fighter.shieldReady then
		fighter.shieldReady = state.time + shield.every
		local amount = math.round(fighter.maxHp * shield.fraction)
		side.shield = amount
		table.insert(events, { type = "shield", to = fighter.id, heal = amount })
	end
	local clap = mechanics.thunderclap
	if clap and state.time >= fighter.clapReady then
		fighter.clapReady = state.time + clap.every
		table.insert(events, { type = "thunderclap", from = fighter.id })
		for _, enemy in standing(other(state, side)) do
			local seconds = clap.seconds * math.clamp(fighter.spd / enemy.spd, clap.minFactor, clap.maxFactor)
			enemy.stunUntil = math.max(enemy.stunUntil, state.time + seconds)
			table.insert(events, { type = "stun", to = enemy.id, damage = seconds })
		end
	end
	local adds = mechanics.adds
	if adds then
		for index, at in adds.at do
			if not fighter.addsDone[index] and share < at then
				fighter.addsDone[index] = true
				for _ = 1, adds.count do
					fighter.addsMade += 1
					local add = makeFighter(state.combat, {
						id = `add{fighter.addsMade}`,
						element = fighter.element,
						hp = math.round(fighter.maxHp * adds.hpShare),
						atk = fighter.atk * adds.atkShare,
						spd = fighter.spd,
					}, side.name, state.time)
					table.insert(side.fighters, add)
					table.insert(events, { type = "spawn", from = fighter.id, to = add.id })
				end
			end
		end
	end
end

function BattleSim.step(state: State, dt: number): { Event }
	local events: { Event } = {}
	if state.result then
		return events
	end
	state.time += dt
	local combat = state.combat

	for _, side in { state.sides.a, state.sides.b } do
		for _, fighter in side.fighters do
			burn(state, fighter, events)
			bossMechanics(state, fighter, events)
		end
	end

	for _, side in { state.sides.a, state.sides.b } do
		for _, fighter in standing(side) do
			if state.result then
				return events
			end
			if state.time >= fighter.nextAttack then
				if state.time >= fighter.stunUntil then
					attack(state, fighter, events)
				end
				local next = interval(state, fighter)
				if fighter.overcharge > 0 then
					fighter.overcharge -= 1
					next /= combat.ABILITIES.Volt.speed
				end
				fighter.nextAttack = state.time + next
			end
		end
	end

	if not state.result and state.time >= (state.maxSeconds or combat.MAX_FIGHT_SECONDS) then
		finish(state, if state.sides.a.canRun then "run" else "draw", events)
	end
	return events
end

-- One reserve joins the field. Each owner (nil: the side's only one) calls in once, only their own reserves, early on.
function BattleSim.callIn(state: State, id: string, owner: string?): (boolean, string?)
	if state.result then
		return false, "ended"
	end
	for _, side in { state.sides.a, state.sides.b } do
		for _, fighter in side.reserves do
			if fighter.id == id and (owner == nil or fighter.owner == owner) then
				local key = fighter.owner or ""
				if side.calledBy[key] or state.time > state.combat.CALL_IN_SECONDS then
					return false, "closed"
				end
				side.calledBy[key] = true
				fighter.nextAttack = state.time + CombatMath.getAttackInterval(state.combat, fighter.spd)
				table.insert(side.fighters, fighter)
				-- Without swaps the call-in is the owner's last chance: their other reserves go
				local rest = {}
				for _, reserve in side.reserves do
					if reserve ~= fighter and (side.swapSeconds or (reserve.owner or "") ~= key) then
						table.insert(rest, reserve)
					end
				end
				side.reserves = rest
				return true, nil
			end
		end
	end
	return false, "missing"
end

-- Boss fights: bring one of your reserves in (during the call-in window, while unused, it joins as your call-in instead).
-- Swaps wait swapSeconds between them, except when none of yours is standing.
function BattleSim.swap(state: State, id: string, owner: string?): ({ Event }?, string?)
	if state.result then
		return nil, "ended"
	end
	local side = state.sides.a
	local incoming: Fighter? = nil
	for _, reserve in side.reserves do
		if reserve.id == id then
			incoming = reserve
		end
	end
	if not side.swapSeconds then
		return nil, "none"
	elseif not incoming or (owner ~= nil and incoming.owner ~= owner) then
		return nil, "missing"
	end
	local key = ownerKey(incoming)
	if not side.calledBy[key] and state.time <= state.combat.CALL_IN_SECONDS then
		BattleSim.callIn(state, id, owner)
		return { { type = "callin", from = id } }, nil
	end
	local anyStanding = false
	for _, fighter in onField(side, key) do
		anyStanding = anyStanding or not fighter.fainted
	end
	if anyStanding and state.time < (side.swapReadyAt[key] or 0) then
		return nil, "cooldown"
	end
	side.swapReadyAt[key] = state.time + side.swapSeconds
	local events: { Event } = {}
	bringIn(state, side, incoming, events)
	return events, nil
end

-- A player left a group fight: their fighters step out (not fainted, never targeted) and their reserves go. The fight
-- ends as a run when nobody is left standing on that side.
function BattleSim.withdraw(state: State, owner: string): { Event }
	local events: { Event } = {}
	for _, side in { state.sides.a, state.sides.b } do
		local had = false
		for _, fighter in side.fighters do
			if fighter.owner == owner and not fighter.left then
				fighter.left = true
				had = true
				table.insert(events, { type = "leave", from = fighter.id })
			end
		end
		local rest = {}
		for _, reserve in side.reserves do
			if reserve.owner ~= owner then
				table.insert(rest, reserve)
			end
		end
		side.reserves = rest
		if had and #standing(side) == 0 and not state.result then
			-- Someone who fainted is still in it: their side lost. Everyone left: it's a run.
			local stayed = false
			for _, fighter in side.fighters do
				stayed = stayed or not fighter.left
			end
			finish(state, if stayed then other(state, side).name else "run", events)
		end
	end
	return events
end

-- One owner's share of side A's fight so far (the boss loot's contribution rule). Players who left don't count: the
-- shares are of what the ones still in it did.
function BattleSim.contribution(state: State, owner: string): { dealt: number, taken: number, totalDealt: number, totalTaken: number }
	local result = { dealt = 0, taken = 0, totalDealt = 0, totalTaken = 0 }
	for _, fighter in state.sides.a.fighters do
		if fighter.left then
			continue
		end
		result.totalDealt += fighter.dealt
		result.totalTaken += fighter.taken
		if fighter.owner == owner then
			result.dealt += fighter.dealt
			result.taken += fighter.taken
		end
	end
	return result
end

local function applyAbility(state: State, fighter: Fighter, side: Side, ability: any, events: { Event })
	local kind = ability.kind
	local target = targetOf(state, fighter)
	if kind == "Fireball" or kind == "Supernova" then
		if target then
			hit(state, fighter, target, ability.power, events, kind)
		end
	elseif kind == "Wave" then
		-- Heals the user's own creatures (in a group, not the other players': stacked Waves would out-heal any boss)
		local healed = 0
		for _, ally in standing(side) do
			if ally.owner ~= fighter.owner then
				continue
			end
			local amount = math.round(ally.maxHp * ability.heal)
			ally.hp = math.min(ally.maxHp, ally.hp + amount)
			healed += amount
		end
		table.insert(events, { type = "ability", kind = kind, from = fighter.id, heal = healed })
	elseif kind == "Snare" then
		if target then
			target.slowUntil, target.slow = state.time + ability.seconds, ability.slow
			table.insert(events, { type = "ability", kind = kind, from = fighter.id, to = target.id })
		end
	elseif kind == "Overcharge" then
		-- Pulling the next attack in is the first fast one; the rest shorten the gaps after it
		fighter.overcharge = ability.attacks - 1
		fighter.nextAttack = math.min(fighter.nextAttack, state.time + CombatMath.getAttackInterval(state.combat, fighter.spd) / ability.speed)
		table.insert(events, { type = "ability", kind = kind, from = fighter.id })
	elseif kind == "Curse" then
		if target then
			target.curseUntil, target.curse = state.time + ability.seconds, ability.weaken
			table.insert(events, { type = "ability", kind = kind, from = fighter.id, to = target.id })
		end
	elseif kind == "Inferno" then
		if target then
			target.burnUntil = state.time + ability.seconds
			target.burnPerSecond = fighter.atk * ability.perSecond
			target.burnTick = state.time + 1
			target.burnBy = fighter
			table.insert(events, { type = "ability", kind = kind, from = fighter.id, to = target.id })
		end
	elseif kind == "TidalShield" then
		side.shield = math.round(fighter.maxHp * ability.shield)
		table.insert(events, { type = "ability", kind = kind, from = fighter.id })
	elseif kind == "Stampede" then
		if target then
			hit(state, fighter, target, ability.power, events, kind)
			target.stunUntil = state.time + (if target.boss then math.min(ability.stun, state.combat.BOSS_MAX_STUN) else ability.stun)
			target.nextAttack = math.max(target.nextAttack, target.stunUntil)
		end
	elseif kind == "Eclipse" then
		fighter.dodgeUntil = state.time + ability.seconds
		table.insert(events, { type = "ability", kind = kind, from = fighter.id })
	elseif kind == "Devour" then
		if target then
			local damage = hit(state, fighter, target, ability.power, events, kind)
			fighter.hp = math.min(fighter.maxHp, fighter.hp + math.round(damage * ability.lifesteal))
		end
	end
end

function BattleSim.useAbility(state: State, id: string, which: string, owner: string?): ({ Event }?, string?)
	if state.result then
		return nil, "ended"
	end
	local fighter, side = find(state, id)
	if not fighter or not side or fighter.fainted or fighter.left or (owner ~= nil and fighter.owner ~= owner) then
		return nil, "missing"
	end
	local combat = state.combat
	local ability
	if not side.abilities then
		return nil, "none"
	elseif which == "element" then
		ability = combat.ABILITIES[fighter.element]
		if not ability then
			return nil, "none"
		elseif state.time < fighter.abilityReady then
			return nil, "cooldown"
		end
		fighter.abilityReady = state.time + combat.ABILITY_COOLDOWN
	elseif which == "signature" then
		ability = if fighter.signature then combat.SIGNATURES[fighter.signature] else nil
		if not ability then
			return nil, "none"
		elseif state.time < fighter.signatureReady then
			return nil, "cooldown"
		end
		fighter.signatureReady = state.time + combat.SIGNATURE_COOLDOWN
	else
		return nil, "none"
	end
	local events: { Event } = {}
	applyAbility(state, fighter, side, ability, events)
	return events, nil
end

function BattleSim.getRunChance(state: State, sideName: string): number
	local side = (state.sides :: any)[sideName] :: Side
	local leader, enemy = side.fighters[1], other(state, side).fighters[1]
	if not leader or not enemy then
		return 0
	end
	return CombatMath.getRunChance(state.combat, leader.spd, enemy.spd, enemy.elite)
end

function BattleSim.tryRun(state: State, sideName: string): { Event }
	local events: { Event } = {}
	local side = (state.sides :: any)[sideName] :: Side?
	if state.result or not side then
		return events
	elseif not side.canRun then
		table.insert(events, { type = "run", ok = false, kind = "none" })
		return events
	elseif state.time < side.runReadyAt then
		table.insert(events, { type = "run", ok = false, kind = "wait" })
		return events
	end
	if random(state) < BattleSim.getRunChance(state, sideName) then
		table.insert(events, { type = "run", ok = true })
		finish(state, "run", events)
	else
		side.runReadyAt = state.time + state.combat.RUN_RETRY_SECONDS
		table.insert(events, { type = "run", ok = false, kind = "failed" })
		-- The price of a failed run: the enemy's first standing fighter gets a free hit
		local enemy = standing(other(state, side))[1]
		if enemy then
			attack(state, enemy, events)
		end
	end
	return events
end

-- A player left or gave up: the other side wins at once
function BattleSim.forfeit(state: State, sideName: string): { Event }
	local events: { Event } = {}
	local side = (state.sides :: any)[sideName] :: Side?
	if not state.result and side then
		finish(state, other(state, side).name, events)
	end
	return events
end

function BattleSim.getFighter(state: State, id: string): { hp: number, maxHp: number, fainted: boolean }?
	local fighter = find(state, id)
	return if fighter then { hp = fighter.hp, maxHp = fighter.maxHp, fainted = fighter.fainted } else nil
end

-- Unprefixed ids of a side's fighters that fainted (wild: they rest)
function BattleSim.getFainted(state: State, sideName: string): { string }
	local list = {}
	local side = (state.sides :: any)[sideName] :: Side?
	for _, fighter in if side then side.fighters else {} do
		if fighter.fainted then
			table.insert(list, fighter.rawId)
		end
	end
	return list
end

local function swapWaits(state: State, side: Side): { [string]: number }
	local waits = {}
	for key, readyAt in side.swapReadyAt do
		waits[key] = math.max(0, readyAt - state.time)
	end
	return waits
end

-- Plain view for the clients' fight bars
function BattleSim.snapshot(state: State): any
	local function sideView(side: Side): any
		local fighters = {}
		for _, fighter in side.fighters do
			table.insert(fighters, {
				id = fighter.id,
				hp = fighter.hp,
				maxHp = fighter.maxHp,
				element = fighter.element,
				elite = fighter.elite,
				abilityIn = math.max(0, fighter.abilityReady - state.time),
				signature = fighter.signature,
				signatureIn = math.max(0, fighter.signatureReady - state.time),
				fainted = fighter.fainted,
				owner = fighter.owner,
				left = fighter.left,
				benched = fighter.benched,
			})
		end
		local reserves = {}
		for _, fighter in side.reserves do
			table.insert(reserves, fighter.id)
		end
		return {
			fighters = fighters,
			reserves = reserves,
			callInFor = if #side.reserves == 0 then 0 else math.max(0, state.combat.CALL_IN_SECONDS - state.time),
			runIn = math.max(0, side.runReadyAt - state.time),
			runChance = if side.canRun then BattleSim.getRunChance(state, side.name) else 0,
			canRun = side.canRun,
			shield = side.shield,
			swaps = side.swapSeconds ~= nil,
			swapIn = swapWaits(state, side), -- seconds until each owner may swap again
		}
	end
	return { time = state.time, result = state.result, sides = { a = sideView(state.sides.a), b = sideView(state.sides.b) } }
end

return BattleSim
