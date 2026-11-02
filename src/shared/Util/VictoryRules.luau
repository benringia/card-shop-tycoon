--!strict
-- What the victory screen shows (Util/VictoryScreen, design B "banner and loot strip"): one tile per reward from the
-- fight's summary, in order (cash, XP, Star Shards, a dropped card, the boss's chest and loot, the daily bonus), the
-- rare ones glowing gold, and the short notes under them. Pure: callers pass Config/Items and the cards by id, so
-- tests/ run it in Lune. Icons are Config/UIIcons names (or emoji).
local VictoryRules = {}

export type Tile = { icon: string, amount: string, label: string, rare: boolean }

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

-- "Meadow Warden defeated · 1:24"
function VictoryRules.subtitle(foe: string?, seconds: number?): string
	local name = if foe and foe ~= "" then `{foe} defeated` else "Fight won"
	return if seconds and seconds > 0 then `{name} · {clock(seconds)}` else name
end

return VictoryRules
