--!strict
-- One fight between two sides of fighters, simulated on the server. Wild fights: side A is the party
-- (leader + call-in reserves), side B one monster with no abilities. PvP: both sides are full parties.
-- Pure (only CombatMath; no Roblox APIs) so tests/ run it in Lune. Seeded, so the same seed and inputs replay
-- the same fight. Fighter ids are prefixed by side ("a:<id>", "b:<id>") in events and snapshots.
local CombatMath = if game ~= nil
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("CombatMath")) :: any
	else require("../../shared/Util/CombatMath") :: any

local BattleSim = {}

-- mechanics: a boss's (Config/Bosses): heal below an HP fraction every cooldown, enrage once below one. boss: stuns on
-- it last at most BOSS_MAX_STUN seconds
export type Mechanics = { heal: { below: number, fraction: number, cooldown: number }?, enrage: { below: number, atkMultiplier: number }? }
export type FighterInput = { id: string, element: string, hp: number, atk: number, spd: number, signature: string?, elite: boolean?, mechanics: Mechanics?, boss: boolean? }
export type SideInput = { fighters: { FighterInput }, reserves: { FighterInput }?, abilities: boolean, canRun: boolean }
export type Event = {
	type: string, -- "attack" | "ability" | "faint" | "callin" | "run" | "end" | "heal" | "enrage"
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
}

type Side = {
	name: string,
	fighters: { Fighter }, -- on the field
	reserves: { Fighter }, -- may be called in (wild)
	abilities: boolean,
	canRun: boolean,
	shield: number, -- damage this side still absorbs (Tidal Shield)
	calledIn: boolean,
	runReadyAt: number,
}

export type State = {
	combat: any,
	time: number,
	seed: number,
	sides: { a: Side, b: Side },
	result: string?, -- "a" | "b" | "draw" | "run"
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
		calledIn = false,
		runReadyAt = 0,
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
		if not fighter.fainted then
			table.insert(list, fighter)
		end
	end
	return list
end

-- Everyone attacks the standing enemy with the lowest share of its HP left (ties: list order)
local function targetOf(state: State, fighter: Fighter): Fighter?
	local enemies = standing(other(state, (state.sides :: any)[fighter.side]))
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

local function takeDamage(state: State, target: Fighter, amount: number, events: { Event })
	target.hp = math.max(0, target.hp - amount)
	if target.hp <= 0 and not target.fainted then
		target.fainted = true
		table.insert(events, { type = "faint", to = target.id })
		local side = (state.sides :: any)[target.side] :: Side
		if #standing(side) == 0 and not state.result then
			finish(state, other(state, side).name, events)
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
	local damage = CombatMath.getDamage(state.combat, atk, elementMult, random(state))
	local side = (state.sides :: any)[target.side] :: Side
	local absorbed = math.min(side.shield, damage)
	side.shield -= absorbed
	local taken = damage - absorbed
	table.insert(events, { type = if kind then "ability" else "attack", kind = kind, from = from.id, to = target.id, damage = taken, strength = strength })
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

local function attack(state: State, fighter: Fighter, events: { Event })
	local target = targetOf(state, fighter)
	if target then
		hit(state, fighter, target, 1, events, nil)
	end
end

-- One burn per second of Inferno; a long frame catches up on every tick it covered
local function burn(state: State, fighter: Fighter, events: { Event })
	while not fighter.fainted and fighter.burnUntil > 0 and fighter.burnTick <= math.min(state.time, fighter.burnUntil) + 1e-9 do
		fighter.burnTick += 1
		local damage = math.max(1, math.round(fighter.burnPerSecond))
		table.insert(events, { type = "ability", kind = "Burn", to = fighter.id, damage = damage })
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

	if not state.result and state.time >= combat.MAX_FIGHT_SECONDS then
		finish(state, if state.sides.a.canRun then "run" else "draw", events)
	end
	return events
end

function BattleSim.callIn(state: State, id: string): (boolean, string?)
	if state.result then
		return false, "ended"
	end
	for _, side in { state.sides.a, state.sides.b } do
		for _, fighter in side.reserves do
			if fighter.id == id then
				if side.calledIn or state.time > state.combat.CALL_IN_SECONDS then
					return false, "closed"
				end
				side.calledIn = true
				fighter.nextAttack = state.time + CombatMath.getAttackInterval(state.combat, fighter.spd)
				table.insert(side.fighters, fighter)
				side.reserves = {}
				return true, nil
			end
		end
	end
	return false, "missing"
end

local function applyAbility(state: State, fighter: Fighter, side: Side, ability: any, events: { Event })
	local kind = ability.kind
	local target = targetOf(state, fighter)
	if kind == "Fireball" or kind == "Supernova" then
		if target then
			hit(state, fighter, target, ability.power, events, kind)
		end
	elseif kind == "Wave" then
		local healed = 0
		for _, ally in standing(side) do
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

function BattleSim.useAbility(state: State, id: string, which: string): ({ Event }?, string?)
	if state.result then
		return nil, "ended"
	end
	local fighter, side = find(state, id)
	if not fighter or not side or fighter.fainted then
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
			})
		end
		local reserves = {}
		for _, fighter in side.reserves do
			table.insert(reserves, fighter.id)
		end
		return {
			fighters = fighters,
			reserves = reserves,
			callInFor = if side.calledIn or #side.reserves == 0 then 0 else math.max(0, state.combat.CALL_IN_SECONDS - state.time),
			runIn = math.max(0, side.runReadyAt - state.time),
			runChance = if side.canRun then BattleSim.getRunChance(state, side.name) else 0,
			canRun = side.canRun,
			shield = side.shield,
		}
	end
	return { time = state.time, result = state.result, sides = { a = sideView(state.sides.a), b = sideView(state.sides.b) } }
end

return BattleSim
