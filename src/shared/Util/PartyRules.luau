--!strict
-- The summoned creature's perk: its element picks the kind, rarity and stars set how strong it is.
-- Pure (no requires, no Roblox APIs): callers pass Config/Party in, so tests/ can run it in Lune.
local PartyRules = {}

export type Perk = { kind: string, value: number }
type Config = {
	PERKS: { [string]: { kind: string, base: number } },
	RARITY_MULTIPLIER: { [string]: number },
	STAR_BONUS: number,
	FIGHT_PERKS: { [string]: number }?,
}

local TEXT = {
	Hype = "customers %d%% more often",
	Calm = "customers wait %d%% longer",
	Express = "deliveries %d%% faster",
	Hustle = "you walk %d%% faster",
	Haggle = "customers %d%% more likely to buy",
}

local PAL_RARITY = { Common = 1, Rare = 2, ["Very Rare"] = 3, Epic = 4, Legendary = 5 }
local PAL_GRADE = { C = 1, B = 2, A = 3, S = 4 }

-- The first pal from Pish's present (owner 2026-11-17, the first 15 minutes): the binder's best plain copy by rarity,
-- then grade, then foil (`stacks`: cardId -> grade -> counts; `rarityOf` a card's rarity). Nil when there's none
function PartyRules.firstPal(stacks: { [string]: { [string]: { normal: number, foil: number } } }, rarityOf: (cardId: string) -> string?): (string?, boolean, string?)
	local best: { cardId: string, foil: boolean, grade: string, score: number }? = nil
	for cardId, grades in stacks do
		local rank = PAL_RARITY[rarityOf(cardId) or ""] or 0
		for grade, counts in grades do
			for _, foil in { true, false } do
				local have = if foil then counts.foil else counts.normal
				local score = rank * 100 + (PAL_GRADE[grade] or 0) * 10 + (if foil then 1 else 0)
				if have > 0 and (not best or score > best.score or (score == best.score and cardId < best.cardId)) then
					best = { cardId = cardId, foil = foil, grade = grade, score = score }
				end
			end
		end
	end
	if not best then
		return nil, false, nil
	end
	return best.cardId, best.foil, best.grade
end

function PartyRules.getPerk(config: Config, element: string, rarity: string, stars: number): Perk?
	local perk = config.PERKS[element]
	if not perk then
		return nil
	end
	local multiplier = config.RARITY_MULTIPLIER[rarity] or 1
	return { kind = perk.kind, value = perk.base * multiplier * (1 + config.STAR_BONUS * math.max(0, stars)) }
end

-- The perk in monster and boss fights: the element's kind with its fight value, grown like the shop one
function PartyRules.getFightPerk(config: Config, element: string, rarity: string, stars: number): Perk?
	local perk = config.PERKS[element]
	local base = if perk and config.FIGHT_PERKS then config.FIGHT_PERKS[perk.kind] else nil
	if not perk or not base then
		return nil
	end
	local multiplier = config.RARITY_MULTIPLIER[rarity] or 1
	return { kind = perk.kind, value = base * multiplier * (1 + config.STAR_BONUS * math.max(0, stars)) }
end

local FIGHT_TEXT = {
	Hype = "hits %d%% harder",
	Calm = "takes %d%% less damage",
	Express = "skills recharge %d%% faster",
	Hustle = "creature attacks %d%% faster",
	Haggle = "%d%% chance to crit",
}

-- "hits 6% harder"
function PartyRules.describeFight(perk: Perk): string
	return string.format(FIGHT_TEXT[perk.kind] or "%d%%", math.round(perk.value * 100))
end

-- "deliveries 15% faster" -> "Deliveries 15% faster"
local function sentence(text: string): string
	return string.upper(string.sub(text, 1, 1)) .. string.sub(text, 2)
end

-- "Deliveries 15% faster": a perk's effect alone (the Party window's perk box, owner 2026-11-23)
function PartyRules.effect(perk: Perk): string
	return sentence(string.format(TEXT[perk.kind] or "%d%%", math.round(perk.value * 100)))
end

-- "Creature attacks 5% faster": a fight perk's effect as a sentence
function PartyRules.fightEffect(perk: Perk): string
	return sentence(PartyRules.describeFight(perk))
end

-- "Hype: customers 5% more often"
function PartyRules.describe(perk: Perk): string
	local text = TEXT[perk.kind] or "%d%%"
	return `{perk.kind}: {string.format(text, math.round(perk.value * 100))}`
end

export type ChangeKind = "joined" | "swapped" | "left"
export type Change = { slot: number, kind: ChangeKind, before: string?, after: string? }

-- What changed between two parties (slot -> beastId), slot by slot: a card joined an empty slot, swapped in
-- for another, or left
function PartyRules.changes(before: { [number]: string }, after: { [number]: string }, size: number): { Change }
	local list: { Change } = {}
	for slot = 1, size do
		local was, now = before[slot], after[slot]
		if was ~= now then
			local kind: ChangeKind = if was == nil then "joined" elseif now == nil then "left" else "swapped"
			table.insert(list, { slot = slot, kind = kind, before = was, after = now })
		end
	end
	return list
end

-- The toast for a change: "Cindercub swapped in for Ashbeak!"
function PartyRules.changeText(kind: ChangeKind, inName: string?, outName: string?): string
	if kind == "joined" then
		return `{inName or "A card"} joined your party!`
	elseif kind == "swapped" then
		return `{inName or "A card"} swapped in for {outName or "a card"}!`
	end
	return `{outName or "A card"} left your party`
end

-- Resting creatures stay in their cards (testers 2026-11-26: "Resting pets should not be summoned"): whether a creature
-- rested until `restUntil` (os.time, nil: never fainted) is still resting at `now`
function PartyRules.isResting(restUntil: number?, now: number): boolean
	return restUntil ~= nil and restUntil > now
end

-- What a refused summon says ("add a notification if someone tries to summon a dead pet"): when it's back (a part of a
-- second counts up) and where `place` ("Main" | "Frontier" | "Dungeon") heals it now
function PartyRules.restingWords(name: string, secondsLeft: number, place: string): string
	local left = math.max(0, math.ceil(secondsLeft))
	local back = string.format("%d:%02d", left // 60, left % 60)
	local heal = if place == "Dungeon" then "." elseif place == "Frontier" then " or visit the spring at the entrance." else " or visit the plaza spring."
	return `{name} is resting: back in {back}. Summon a rested one{heal}`
end

return PartyRules
