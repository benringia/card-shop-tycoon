--!strict
-- The defeat screen's words (owner 2026-11-04, design A; Config/Defeat, Util/DefeatScreen draws them): the card's rows
-- from the fight's numbers, the line under the title and the tip. Pure, Lune-tested.
local DefeatRules = {}

export type Stats = {
	sword: number?, -- your sword's damage (nil: no sword in this fight)
	creatures: { { cardId: string, damage: number } },
	hpShare: number, -- the boss's HP left, 0-1
	rings: number, -- big attacks aimed at you
	dodged: number, -- of those, dodged or stepped out of
}
export type Row = { kind: string, label: string, value: string, cardId: string?, share: number? }

-- A whole number with thousands commas ("12,346")
function DefeatRules.number(n: number): string
	local text = tostring(math.round(math.max(0, n)))
	local out = text
	repeat
		local changed
		out, changed = string.gsub(out, "^(%d+)(%d%d%d)", "%1,%2")
	until changed == 0
	return out
end

-- Your sword, your creatures by damage (the top `cfg.MAX_CREATURES`, cards you no longer know left out), the boss's HP
-- left, rings dodged (when any came your way)
function DefeatRules.rows(stats: Stats, cardsById: { [string]: any }, cfg: any): { Row }
	local rows: { Row } = {}
	if stats.sword then
		table.insert(rows, { kind = "sword", label = "Your sword", value = DefeatRules.number(stats.sword) })
	end
	local creatures = table.clone(stats.creatures)
	table.sort(creatures, function(a, b)
		return a.damage > b.damage
	end)
	local shown = 0
	for _, entry in creatures do
		local card = cardsById[entry.cardId]
		if card and shown < cfg.MAX_CREATURES then
			shown += 1
			table.insert(rows, { kind = "creature", label = card.name, value = DefeatRules.number(entry.damage), cardId = entry.cardId })
		end
	end
	local share = math.clamp(stats.hpShare, 0, 1)
	table.insert(rows, { kind = "hp", label = "Boss HP left", value = `{math.round(share * 100)}%`, share = share })
	if stats.rings > 0 then
		table.insert(rows, { kind = "rings", label = "Rings dodged", value = `{stats.dodged} / {stats.rings}` })
	end
	return rows
end

-- "Cave Brood Queen won · 1:42"
function DefeatRules.subtitle(foe: string?, seconds: number?): string
	if not foe or foe == "" then
		return "Your party fainted"
	end
	if not seconds or seconds <= 0 then
		return `{foe} won`
	end
	local whole = math.floor(seconds)
	return `{foe} won · {whole // 60}:{string.format("%02d", whole % 60)}`
end

-- A tip for this boss (its own, else a general one); `roll` 0-1 picks which
function DefeatRules.tip(bossId: string?, roll: number, cfg: any): string
	local list = (if bossId then cfg.TIPS[bossId] else nil) or cfg.TIPS.general
	return list[math.clamp(math.floor(roll * #list) + 1, 1, #list)]
end

return DefeatRules
