--!strict
-- What the victory screen shows (Util/VictoryScreen, design B "banner and loot strip"): one tile per reward from the
-- fight's summary, in order (cash, XP, Star Shards, a dropped card, the boss's chest and loot, the daily bonus), the
-- rare ones glowing gold, and the short notes under them; and for normal monsters (no big screen, owner 2026-11-03)
-- the toast's words (Util/FightToast). Pure: callers pass Config/Items and the cards by id, so tests/ run it in Lune.
-- Icons are Config/UIIcons names (or emoji).
local VictoryRules = {}

export type Tile = { icon: string, amount: string, label: string, rare: boolean }
-- kind: "win" | "rare" (a card or shards dropped) | "lose" | "run"; line: a second, smaller line
export type Toast = { kind: string, title: string, line: string?, pills: { { icon: string, text: string } } }

local function clock(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

function VictoryRules.tiles(summary: any, items: any, cardsById: { [string]: any }): { Tile }
	local tiles: { Tile } = {}
	table.insert(tiles, { icon = "Cash", amount = string.format("$%.2f", tonumber(summary.cash) or 0), label = "cash", rare = false })
	table.insert(tiles, { icon = "Xp", amount = `+{tonumber(summary.xpEach) or 0}`, label = "XP each", rare = false })
	local shards = tonumber(summary.shards) or 0
	if shards > 0 then
		table.insert(tiles, { icon = "Shard", amount = `x{shards}`, label = "Star Shards", rare = false })
	end
	local card = if typeof(summary.card) == "table" then cardsById[summary.card.cardId] else nil
	if card then
		local grade = summary.card.grade
		table.insert(tiles, { icon = "Cards", amount = if typeof(grade) == "string" then `Grade {grade}` else "New!", label = card.name, rare = true })
	end
	local boss = summary.boss
	if typeof(boss) == "table" then
		local function add(list: any, rare: boolean)
			for _, entry in (if typeof(list) == "table" then list else {}) do
				local item = items.ITEMS[entry.item]
				if item then
					table.insert(tiles, { icon = item.icon, amount = `x{entry.count}`, label = item.name, rare = rare })
				end
			end
		end
		add(boss.chest, boss.firstClear == true)
		add(boss.items, false)
		if boss.bonus then
			table.insert(tiles, { icon = "Gift", amount = "Bonus!", label = "Daily bonus", rare = true })
		end
	end
	return tiles
end

-- The lines under the tiles: where the boss's loot is and why it was smaller
function VictoryRules.notes(boss: any): { string }
	local notes = {}
	if typeof(boss) ~= "table" then
		return notes
	end
	if typeof(boss.items) == "table" and #boss.items > 0 then
		table.insert(notes, "Your loot is on the ground: walk over it to pick it up")
	end
	if boss.carried then
		table.insert(notes, "Carried: smaller loot (deal 10% of the damage or take 15% of the hits for full loot)")
	end
	if boss.flagged then
		table.insert(notes, "Too fast for drops this time")
	elseif boss.reduced then
		table.insert(notes, "Reduced drops (many wins today or a much stronger party)")
	end
	if typeof(boss.lootIn) == "number" and boss.lootIn > 0 then
		table.insert(notes, `Full loot again in {clock(boss.lootIn)}`)
	end
	return notes
end

-- A normal monster fight's end as a toast: who fell with the cash and XP, a gold line for a card or shards; a loss
-- (`restLine`: when the party is back) or a run
function VictoryRules.toast(summary: any, cardsById: { [string]: any }, restLine: string?): Toast
	if summary.result == "lose" then
		return { kind = "lose", title = "Your party fainted", line = restLine, pills = {} }
	elseif summary.result ~= "win" then
		return { kind = "run", title = "Got away safely", line = nil, pills = {} }
	end
	local extras = {}
	local card = if typeof(summary.card) == "table" then cardsById[summary.card.cardId] else nil
	if card then
		local grade = summary.card.grade
		table.insert(extras, if typeof(grade) == "string" then `New card! {card.name} · Grade {grade}` else `New card! {card.name}`)
	end
	local shards = tonumber(summary.shards) or 0
	if shards > 0 then
		table.insert(extras, `+{shards} Star Shard{if shards == 1 then "" else "s"}`)
	end
	local foe = if typeof(summary.foe) == "string" and summary.foe ~= "" then summary.foe else "Monster"
	return {
		kind = if #extras > 0 then "rare" else "win",
		title = `{foe} defeated`,
		line = if #extras > 0 then table.concat(extras, " · ") else nil,
		pills = {
			{ icon = "Cash", text = string.format("+$%.2f", tonumber(summary.cash) or 0) },
			{ icon = "Xp", text = `+{tonumber(summary.xpEach) or 0} XP` },
		},
	}
end

-- "Meadow Warden defeated · 1:24"
function VictoryRules.subtitle(foe: string?, seconds: number?): string
	local name = if foe and foe ~= "" then `{foe} defeated` else "Fight won"
	return if seconds and seconds > 0 then `{name} · {clock(seconds)}` else name
end

return VictoryRules
