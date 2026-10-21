--!strict
-- One wild fight, simulated on the server: up to 2 party fighters (leader + one call-in) vs 1 monster.
-- Pure (only CombatMath; no Roblox APIs) so tests/ run it in Lune. Seeded, so the same seed and inputs replay
-- the same fight. BattleService steps it at Combat.TICK_RATE and forwards the events to the player.
local CombatMath = if game ~= nil
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("CombatMath")) :: any
	else require("../../shared/Util/CombatMath") :: any

local BattleSim = {}

export type FighterInput = { id: string, element: string, hp: number, atk: number, spd: number, signature: string? }
export type MonsterInput = { element: string, hp: number, atk: number, spd: number, elite: boolean }
export type Event = {
	type: string, -- "attack" | "ability" | "faint" | "callin" | "run" | "end"
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
	id: string,
	element: string,
	maxHp: number,
	hp: number,
	atk: number,
	spd: number,
	signature: string?,
	nextAttack: number,
	abilityReady: number,
	signatureReady: number,
	overcharge: number, -- fast attacks left
	dodgeUntil: number,
	fainted: boolean,
}

export type State = {
	combat: any,
	time: number,
	seed: number,
	fighters: { Fighter }, -- on the field
	reserves: { Fighter }, -- may be called in
	monster: Fighter & { elite: boolean, stunUntil: number, slowUntil: number, slow: number, curseUntil: number, curse: number, burnUntil: number, burnPerSecond: number, burnTick: number },
	shield: number, -- damage your side still absorbs (Tidal Shield)
	calledIn: boolean,
	runReadyAt: number,
	result: string?, -- "win" | "lose" | "run"
}

-- Small deterministic generator (LCG) so fights replay identically in Lune and Roblox
local function random(state: State): number
	state.seed = (state.seed * 1103515245 + 12345) % 2147483648
	return state.seed / 2147483648
end

local function makeFighter(combat: any, input: FighterInput, time: number): Fighter
	return {
		id = input.id,
		element = input.element,
		maxHp = input.hp,
		hp = input.hp,
		atk = input.atk,
		spd = input.spd,
		signature = input.signature,
		nextAttack = time + CombatMath.getAttackInterval(combat, input.spd),
		abilityReady = time,
		signatureReady = time,
		overcharge = 0,
		dodgeUntil = 0,
		fainted = false,
	}
end

function BattleSim.new(combat: any, leader: FighterInput, reserves: { FighterInput }, monster: MonsterInput, seed: number): State
	local state: any = {
		combat = combat,
		time = 0,
		seed = math.floor(math.abs(seed)) % 2147483648,
		fighters = { makeFighter(combat, leader, 0) },
		reserves = {},
		shield = 0,
		calledIn = false,
		runReadyAt = 0,
		result = nil,
	}
	for _, input in reserves do
		table.insert(state.reserves, makeFighter(combat, input, 0))
	end
	local m: any = makeFighter(combat, { id = "monster", element = monster.element, hp = monster.hp, atk = monster.atk, spd = monster.spd }, 0)
	m.elite = monster.elite
	m.stunUntil, m.slowUntil, m.slow, m.curseUntil, m.curse = 0, 0, 0, 0, 0
	m.burnUntil, m.burnPerSecond, m.burnTick = 0, 0, 0
	state.monster = m
	return state
end

local function find(list: { Fighter }, id: string): Fighter?
	for _, fighter in list do
		if fighter.id == id then
			return fighter
		end
	end
	return nil
end

local function standing(state: State): { Fighter }
	local list = {}
	for _, fighter in state.fighters do
		if not fighter.fainted then
			table.insert(list, fighter)
		end
	end
	return list
end

local function finish(state: State, result: string, events: { Event })
	state.result = result
	table.insert(events, { type = "end", result = result })
end

local function hitMonster(state: State, from: Fighter, multiplier: number, events: { Event }, kind: string?): number
	local monster = state.monster
	local elementMult, strength = CombatMath.getElementMultiplier(state.combat, from.element, monster.element)
	local damage = CombatMath.getDamage(state.combat, from.atk * multiplier, elementMult, random(state))
	monster.hp = math.max(0, monster.hp - damage)
	table.insert(events, { type = if kind then "ability" else "attack", kind = kind, from = from.id, to = "monster", damage = damage, strength = strength })
	if monster.hp <= 0 and not state.result then
		finish(state, "win", events)
	end
	return damage
end

-- The monster hits the standing fighter with the lowest share of its HP (ties: the leader, first in the list)
local function monsterAttack(state: State, events: { Event })
	local targets = standing(state)
	local target = targets[1]
	for _, fighter in targets do
		if fighter.hp / fighter.maxHp < target.hp / target.maxHp then
			target = fighter
		end
	end
	if not target then
		return
	end
	local monster = state.monster
	if state.time < target.dodgeUntil then
		table.insert(events, { type = "attack", from = "monster", to = target.id, damage = 0, dodged = true })
		return
	end
	local atk = monster.atk * (if state.time < monster.curseUntil then 1 - monster.curse else 1)
	local elementMult, strength = CombatMath.getElementMultiplier(state.combat, monster.element, target.element)
	local damage = CombatMath.getDamage(state.combat, atk, elementMult, random(state))
	local absorbed = math.min(state.shield, damage)
	state.shield -= absorbed
	local taken = damage - absorbed
	target.hp = math.max(0, target.hp - taken)
	table.insert(events, { type = "attack", from = "monster", to = target.id, damage = taken, strength = strength })
	if target.hp <= 0 then
		target.fainted = true
		table.insert(events, { type = "faint", to = target.id })
		if #standing(state) == 0 then
			finish(state, "lose", events)
		end
	end
end

local function monsterInterval(state: State): number
	local monster = state.monster
	local interval = CombatMath.getAttackInterval(state.combat, monster.spd)
	if state.time < monster.slowUntil then
		interval /= 1 - monster.slow
	end
	return interval
end

function BattleSim.step(state: State, dt: number): { Event }
	local events: { Event } = {}
	if state.result then
		return events
	end
	state.time += dt
	local combat = state.combat
	local monster = state.monster

	-- One burn per second of Inferno; a long frame catches up on every tick it covered
	while monster.burnUntil > 0 and monster.burnTick <= math.min(state.time, monster.burnUntil) + 1e-9 do
		monster.burnTick += 1
		local damage = math.max(1, math.round(monster.burnPerSecond))
		monster.hp = math.max(0, monster.hp - damage)
		table.insert(events, { type = "ability", kind = "Burn", to = "monster", damage = damage })
		if monster.hp <= 0 then
			finish(state, "win", events)
			return events
		end
	end

	for _, fighter in standing(state) do
		if state.result then
			break
		end
		if state.time >= fighter.nextAttack then
			hitMonster(state, fighter, 1, events, nil)
			local interval = CombatMath.getAttackInterval(combat, fighter.spd)
			if fighter.overcharge > 0 then
				fighter.overcharge -= 1
				interval /= combat.ABILITIES.Volt.speed
			end
			fighter.nextAttack = state.time + interval
		end
	end

	if not state.result and state.time >= monster.nextAttack then
		if state.time >= monster.stunUntil then
			monsterAttack(state, events)
		end
		monster.nextAttack = state.time + monsterInterval(state)
	end

	if not state.result and state.time >= combat.MAX_FIGHT_SECONDS then
		finish(state, "run", events)
	end
	return events
end

function BattleSim.callIn(state: State, id: string): (boolean, string?)
	if state.result then
		return false, "ended"
	elseif state.calledIn or state.time > state.combat.CALL_IN_SECONDS then
		return false, "closed"
	end
	local fighter = find(state.reserves, id)
	if not fighter then
		return false, "missing"
	end
	state.calledIn = true
	fighter.nextAttack = state.time + CombatMath.getAttackInterval(state.combat, fighter.spd)
	table.insert(state.fighters, fighter)
	state.reserves = {}
	return true, nil
end

local function applyAbility(state: State, fighter: Fighter, ability: any, events: { Event })
	local monster = state.monster
	local kind = ability.kind
	if kind == "Fireball" or kind == "Supernova" then
		hitMonster(state, fighter, ability.power, events, kind)
	elseif kind == "Wave" then
		local healed = 0
		for _, ally in standing(state) do
			local amount = math.round(ally.maxHp * ability.heal)
			ally.hp = math.min(ally.maxHp, ally.hp + amount)
			healed += amount
		end
		table.insert(events, { type = "ability", kind = kind, from = fighter.id, heal = healed })
	elseif kind == "Snare" then
		monster.slowUntil, monster.slow = state.time + ability.seconds, ability.slow
		table.insert(events, { type = "ability", kind = kind, from = fighter.id, to = "monster" })
	elseif kind == "Overcharge" then
		-- Pulling the next attack in is the first fast one; the rest shorten the gaps after it
		fighter.overcharge = ability.attacks - 1
		fighter.nextAttack = math.min(fighter.nextAttack, state.time + CombatMath.getAttackInterval(state.combat, fighter.spd) / ability.speed)
		table.insert(events, { type = "ability", kind = kind, from = fighter.id })
	elseif kind == "Curse" then
		monster.curseUntil, monster.curse = state.time + ability.seconds, ability.weaken
		table.insert(events, { type = "ability", kind = kind, from = fighter.id, to = "monster" })
	elseif kind == "Inferno" then
		monster.burnUntil = state.time + ability.seconds
		monster.burnPerSecond = fighter.atk * ability.perSecond
		monster.burnTick = state.time + 1
		table.insert(events, { type = "ability", kind = kind, from = fighter.id, to = "monster" })
	elseif kind == "TidalShield" then
		state.shield = math.round(fighter.maxHp * ability.shield)
		table.insert(events, { type = "ability", kind = kind, from = fighter.id })
	elseif kind == "Stampede" then
		hitMonster(state, fighter, ability.power, events, kind)
		monster.stunUntil = state.time + ability.stun
		monster.nextAttack = math.max(monster.nextAttack, monster.stunUntil)
	elseif kind == "Eclipse" then
		fighter.dodgeUntil = state.time + ability.seconds
		table.insert(events, { type = "ability", kind = kind, from = fighter.id })
	elseif kind == "Devour" then
		local damage = hitMonster(state, fighter, ability.power, events, kind)
		fighter.hp = math.min(fighter.maxHp, fighter.hp + math.round(damage * ability.lifesteal))
	end
end

function BattleSim.useAbility(state: State, id: string, which: string): ({ Event }?, string?)
	if state.result then
		return nil, "ended"
	end
	local fighter = find(state.fighters, id)
	if not fighter or fighter.fainted then
		return nil, "missing"
	end
	local combat = state.combat
	local ability
	if which == "element" then
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
	applyAbility(state, fighter, ability, events)
	return events, nil
end

function BattleSim.getRunChance(state: State): number
	local leader = state.fighters[1]
	return CombatMath.getRunChance(state.combat, leader.spd, state.monster.spd, state.monster.elite)
end

function BattleSim.tryRun(state: State): { Event }
	local events: { Event } = {}
	if state.result then
		return events
	elseif state.time < state.runReadyAt then
		table.insert(events, { type = "run", ok = false, kind = "wait" })
		return events
	end
	if random(state) < BattleSim.getRunChance(state) then
		table.insert(events, { type = "run", ok = true })
		finish(state, "run", events)
	else
		state.runReadyAt = state.time + state.combat.RUN_RETRY_SECONDS
		table.insert(events, { type = "run", ok = false, kind = "failed" })
		monsterAttack(state, events) -- the price of a failed run
	end
	return events
end

-- Plain view for the client's fight bar
function BattleSim.snapshot(state: State): any
	local fighters = {}
	for _, fighter in state.fighters do
		table.insert(fighters, {
			id = fighter.id,
			hp = fighter.hp,
			maxHp = fighter.maxHp,
			element = fighter.element,
			abilityIn = math.max(0, fighter.abilityReady - state.time),
			signature = fighter.signature,
			signatureIn = math.max(0, fighter.signatureReady - state.time),
			fainted = fighter.fainted,
		})
	end
	local reserves = {}
	for _, fighter in state.reserves do
		table.insert(reserves, fighter.id)
	end
	return {
		time = state.time,
		result = state.result,
		monster = { hp = state.monster.hp, maxHp = state.monster.maxHp, element = state.monster.element, elite = state.monster.elite },
		fighters = fighters,
		reserves = reserves,
		callInFor = if state.calledIn then 0 else math.max(0, state.combat.CALL_IN_SECONDS - state.time),
		runIn = math.max(0, state.runReadyAt - state.time),
		runChance = BattleSim.getRunChance(state),
		shield = state.shield,
	}
end

return BattleSim
