--!strict
-- Weapon mutations' rules (weapons round 4 part 2; Config/Mutations): a roll, a saved one read back, what one does in a
-- fight (Stats), its words, the Mutation Essence for the one you don't keep and the Forge's Mutate check. Pure: the
-- server rolls and enforces, the client shows. `cfg` is Config/Mutations (passed in so Lune can test it).
export type Mutation = { id: string, rarity: string }
-- One waiting for the player's choice: `forge` when the Forge's Mutate rolled it (no Essence either way)
export type Pending = { id: string, rarity: string, forge: boolean? }
-- What the weapon in hand's mutation does: multipliers 1 and shares 0 when it has none
export type Stats = {
	sword: number, -- sword hits x (Sharp)
	crit: number, -- a sword hit's chance to deal double (Critical)
	strong: number, -- strong sword hits x (Element Edge)
	boss: number, -- sword hits on a boss x (Boss Hunter)
	hp: number, -- the player's HP x (Tough)
	taken: number, -- damage the player takes x (Guard)
	dodge: number, -- the dodge's cooldown x (Quick Step)
	thorns: number, -- share of the damage taken struck back at the hitter (Thorns)
	lifesteal: number, -- share of sword damage healed back (Lifesteal)
	petAtk: number, -- the player's creatures' ATK x (Pet Boost)
	petHp: number, -- and their HP x
	meter: number, -- the ultimate meter's fill x (Ultimate Charge)
	cash: number, -- fight cash x (Treasure)
	xp: number, -- creature XP from fights x (Scholar)
	secondWind: number, -- once a fight, heal this share of HP when low (Tough's Legendary twist)
	rally: number, -- teammates' creatures' ATK + this share (Pet Boost's Legendary twist)
}
export type Words = { name: string, title: string, line: string, short: string, yours: string, icon: string, group: string, rarity: string }

local MutationRules = {}

local function entryOf(cfg: any, id: string): any
	for _, entry in cfg.LIST do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

-- A roll: its rarity from `rarityRoll` in [0, 1) by ODDS (in RARITIES order), its kind from `kindRoll` in [0, 1)
function MutationRules.roll(cfg: any, rarityRoll: number, kindRoll: number): Mutation
	local rarity = cfg.RARITIES[#cfg.RARITIES]
	local reach = 0
	for _, name in cfg.RARITIES do
		reach += cfg.ODDS[name]
		if rarityRoll < reach then
			rarity = name
			break
		end
	end
	local index = math.clamp(math.floor(kindRoll * #cfg.LIST) + 1, 1, #cfg.LIST)
	return { id = cfg.LIST[index].id, rarity = rarity }
end

-- A saved mutation: a known id at a known rarity, else nil
function MutationRules.read(cfg: any, value: unknown): Mutation?
	if typeof(value) ~= "table" then
		return nil
	end
	local raw = value :: any
	if typeof(raw.id) ~= "string" or typeof(raw.rarity) ~= "string" or not entryOf(cfg, raw.id) or not cfg.SIZE[raw.rarity] then
		return nil
	end
	return { id = raw.id, rarity = raw.rarity }
end

-- A mutation's number as a share (its rarity's size; half for Treasure and Scholar; an entry's own `sizes` first)
function MutationRules.size(cfg: any, mutation: Mutation): number
	local entry = entryOf(cfg, mutation.id)
	local sizes = if entry and entry.sizes then entry.sizes elseif entry and entry.half then cfg.HALF_SIZE else cfg.SIZE
	return sizes[mutation.rarity] or 0
end

-- A share as the percent players read: whole when it is ("12"), else one decimal ("0.3", "1.6")
local function percentOf(share: number): string
	local percent = share * 100
	local whole = math.round(percent)
	if math.abs(percent - whole) < 1e-6 then
		return tostring(whole)
	end
	return string.format("%.1f", percent)
end

function MutationRules.stats(cfg: any, mutation: Mutation?): Stats
	local stats: Stats = {
		sword = 1,
		crit = 0,
		strong = 1,
		boss = 1,
		hp = 1,
		taken = 1,
		dodge = 1,
		thorns = 0,
		lifesteal = 0,
		petAtk = 1,
		petHp = 1,
		meter = 1,
		cash = 1,
		xp = 1,
		secondWind = 0,
		rally = 0,
	}
	local entry = if mutation then entryOf(cfg, mutation.id) else nil
	if not mutation or not entry then
		return stats
	end
	local size = MutationRules.size(cfg, mutation)
	local value = if entry.how == "more" then 1 + size elseif entry.how == "less" then 1 - size else size
	local raw = stats :: any
	if entry.stat == "pet" then
		raw.petAtk = value
		raw.petHp = value
	else
		raw[entry.stat] = value
	end
	if entry.twist and mutation.rarity == "Legendary" then
		raw[entry.twist.stat] = entry.twist.value
	end
	return stats
end

-- Essence a mutation turns into when it isn't kept (none for nil)
function MutationRules.essence(cfg: any, mutation: Mutation?): number
	return if mutation then cfg.ESSENCE[mutation.rarity] or 0 else 0
end

-- The choice: which mutation stays (a plain copy) and the Essence for the other (no old one: the new one stays,
-- nothing to turn). A Forge roll's (`new.forge`) gives no Essence either way: only boss drops do (owner 2026-11-26).
function MutationRules.resolve(cfg: any, have: Mutation?, new: Pending, take: boolean): (Mutation?, number)
	local rolled = { id = new.id, rarity = new.rarity }
	local free = new.forge == true
	if not have then
		return rolled, 0
	end
	if take then
		return rolled, if free then 0 else MutationRules.essence(cfg, have)
	end
	return have, if free then 0 else MutationRules.essence(cfg, new)
end

local function lowerFirst(text: string): string
	return string.lower(string.sub(text, 1, 1)) .. string.sub(text, 2)
end

-- Its words: "Sharp · Epic mutation" over "Sword hits +12%." (a Legendary's twist after it), "Epic · Sharp · sword
-- hits +12%" under the reveal's banner, "Epic · Sharp (sword hits +12%)" as the one you have; its group's icon
function MutationRules.words(cfg: any, mutation: Mutation): Words
	local entry = entryOf(cfg, mutation.id)
	if not entry then
		return { name = mutation.id, title = mutation.id, line = "", short = mutation.id, yours = mutation.id, icon = "Sparkle", group = "", rarity = mutation.rarity }
	end
	local percent = percentOf(MutationRules.size(cfg, mutation))
	local said = string.gsub(entry.words, "{n}", percent)
	local line = `{said}.`
	if entry.twist and mutation.rarity == "Legendary" then
		line ..= ` {entry.twist.words}.`
	end
	return {
		name = entry.name,
		title = `{entry.name} · {mutation.rarity} mutation`,
		line = line,
		short = `{mutation.rarity} · {entry.name} · {lowerFirst(said)}`,
		yours = `{mutation.rarity} · {entry.name} ({lowerFirst(said)})`,
		icon = cfg.GROUPS[entry.group].icon,
		group = entry.group,
		rarity = mutation.rarity,
	}
end

-- The chip for the weapon in hand's mutation (owner 2026-11-27, picks B: on your own HP line in a fight, and C: a mark
-- on the weapon dial), from the character's SwordMutationId and SwordMutation attributes (WeaponService.ApplyAttributes):
-- its name, its words when opened ("Sharp: your sword deals +12% damage"), its group's icon and its rarity (the colour);
-- nil without a mutation or for anything it doesn't know
function MutationRules.chip(cfg: any, id: unknown, rarity: unknown): { name: string, open: string, icon: string, rarity: string }?
	local mutation = MutationRules.read(cfg, { id = id, rarity = rarity })
	if not mutation then
		return nil
	end
	local entry = entryOf(cfg, mutation.id)
	local said = string.gsub(entry.words, "{n}", percentOf(MutationRules.size(cfg, mutation)))
	return {
		name = entry.name,
		open = `{entry.name}: {lowerFirst(said)}`,
		icon = cfg.GROUPS[entry.group].icon,
		rarity = mutation.rarity,
	}
end

-- Treasure and Scholar over a fight (the mutation audit 2026-11-26: switching to a Treasure weapon for the last hit
-- paid its whole share): what the weapon in hand pays, weighted by how long each was in hand. `holding` with the time
-- the fight starts (after a boss's intro: its seconds never count), `switched` on every weapon switch, `averaged` at
-- the win (a fight over at once: the weapon in hand's)
export type Held = { since: number, cash: number, xp: number, cashTime: number, xpTime: number, time: number }

function MutationRules.holding(startsAt: number, stats: { cash: number, xp: number }): Held
	return { since = startsAt, cash = stats.cash, xp = stats.xp, cashTime = 0, xpTime = 0, time = 0 }
end

function MutationRules.switched(held: Held, now: number, stats: { cash: number, xp: number }): Held
	local spent = math.max(0, now - held.since)
	return {
		since = math.max(now, held.since),
		cash = stats.cash,
		xp = stats.xp,
		cashTime = held.cashTime + held.cash * spent,
		xpTime = held.xpTime + held.xp * spent,
		time = held.time + spent,
	}
end

function MutationRules.averaged(held: Held, now: number): (number, number)
	local final = MutationRules.switched(held, now, held)
	if final.time <= 0 then
		return held.cash, held.xp
	end
	return final.cashTime / final.time, final.xpTime / final.time
end

-- Whether the Forge may roll a mutation on this weapon: yours (not the Steel Sword), no choice waiting on it, enough
-- Essence. `weapons` is Config/Weapons; `owned` its record (nil: not yours). The reason in plain words otherwise.
function MutationRules.canMutate(cfg: any, weapons: any, weaponId: string, owned: { mutation: Mutation?, pending: Mutation? }?, essence: number): (boolean, string?)
	if weaponId == weapons.STARTER then
		return false, "The Steel Sword can't mutate."
	end
	if not owned or not weapons.ById[weaponId] then
		return false, "You don't have this weapon."
	end
	if owned.pending then
		return false, "Choose your waiting mutation first."
	end
	if essence < cfg.MUTATE.essence then
		return false, `Need {cfg.MUTATE.essence} Mutation Essence.`
	end
	return true, nil
end

return MutationRules
