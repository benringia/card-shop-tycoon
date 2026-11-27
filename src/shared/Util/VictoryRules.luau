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
	-- the shop's own XP from the win (owner 2026-11-17)
	local shopXp = tonumber(summary.shopXp) or 0
	if shopXp > 0 then
		table.insert(tiles, { icon = "Level", amount = `+{shopXp}`, label = "shop XP", rare = false })
	end
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
	if typeof(boss.lootIn) == "number" and boss.lootIn > 0 then
		if boss.fullPay == false then
			-- a win before the loot timer ended: a share of the cash (BossRules.pay), and when it's all back
			local percent = math.round((tonumber(boss.payShare) or 0) * 100)
			table.insert(notes, `Loot timer running: {percent}% cash. Full loot and cash in {clock(boss.lootIn)}`)
		else
			table.insert(notes, `Full loot and cash again in {clock(boss.lootIn)}`)
		end
	end
	-- a loot win during a weekly event (Boss Rush, Config/Events `note`): why the wait is shorter
	if boss.fullPay == true and typeof(boss.event) == "string" and boss.event ~= "" then
		table.insert(notes, boss.event)
	end
	return notes
end

-- A normal monster fight's end as a toast: who fell with the cash and XP, a gold line for a card or shards (Wild Ore
-- joins the line but is common, so it alone keeps the plain look); a loss (`restLine`: when the party is back) or a run
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
	local rare = #extras > 0
	local ore = tonumber(summary.ore) or 0
	if ore > 0 then
		table.insert(extras, `+{ore} Wild Ore`)
	end
	local foe = if typeof(summary.foe) == "string" and summary.foe ~= "" then summary.foe else "Monster"
	local pills = {
		{ icon = "Cash", text = string.format("+$%.2f", tonumber(summary.cash) or 0) },
		{ icon = "Xp", text = `+{tonumber(summary.xpEach) or 0} XP` },
	}
	-- the shop's own XP from the win (owner 2026-11-17: "a small exp to the shop from killing monsters")
	local shopXp = tonumber(summary.shopXp) or 0
	if shopXp > 0 then
		table.insert(pills, { icon = "Level", text = `+{shopXp} shop XP` })
	end
	-- teammates near you added to it (spec 2026-11-15-teams-design)
	local team = tonumber(summary.team) or 0
	if team > 0 then
		table.insert(pills, { icon = "Party", text = `+{math.floor(team * 100 + 0.5)}% team` })
	end
	return {
		kind = if rare then "rare" else "win",
		title = `{foe} defeated`,
		line = if #extras > 0 then table.concat(extras, " · ") else nil,
		pills = pills,
	}
end

export type Box = { x: number, y: number, w: number, h: number }

-- The toast's top (px): where it slides in (`toast.y`), or `gap` px under what it would lie on among `keepClear` (the
-- tutorial's talk card and Skip hanging off it; seen 2026-11-27: the win toast covered Chikin's line about the shop XP
-- it shows). A toast not laid out yet counts as a point at its middle.
function VictoryRules.toastTop(toast: Box, keepClear: { Box }, gap: number): number
	local w, h = math.max(toast.w, 1), math.max(toast.h, 1)
	local x = toast.x + (toast.w - w) / 2
	local top = toast.y
	local moved = true
	while moved do
		moved = false
		for _, box in keepClear do
			local across = math.min(x + w, box.x + box.w) - math.max(x, box.x)
			local down = math.min(top + h, box.y + box.h) - math.max(top, box.y)
			if across > 0 and down > 0 then
				top = box.y + box.h + gap -- past it for good: each box moves the toast once at most
				moved = true
			end
		end
	end
	return top
end

-- "Meadow Warden defeated · 1:24"
function VictoryRules.subtitle(foe: string?, seconds: number?): string
	local name = if foe and foe ~= "" then `{foe} defeated` else "Fight won"
	return if seconds and seconds > 0 then `{name} · {clock(seconds)}` else name
end

return VictoryRules
