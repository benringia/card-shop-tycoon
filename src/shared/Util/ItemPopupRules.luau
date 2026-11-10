--!strict
-- The item cards a pickup pops at the top right (the owner 2026-11-10: "picking up an item should show a notification";
-- Util/ItemPopup draws them, Config/Victory PICKUP): the same item again while its card shows adds to it and keeps it up
-- (`bumped`: how many it just grew by), different items stack newest at the bottom, the oldest dropped past `max`, and
-- each goes `seconds` after its last pickup. Pure, Lune-tested.
local ItemPopupRules = {}

export type Card = { item: string, count: number, untilTime: number, bumped: number }
export type Config = { seconds: number, max: number, height: number, gap: number, top: number }

-- The cards after picking up `count` of `item` at `now`
function ItemPopupRules.add(list: { Card }, item: string, count: number, now: number, cfg: Config): { Card }
	local cards = table.clone(list)
	for _, card in cards do
		if card.item == item and now < card.untilTime then
			card.count += count
			card.bumped = count
			card.untilTime = now + cfg.seconds
			return cards
		end
	end
	table.insert(cards, { item = item, count = count, untilTime = now + cfg.seconds, bumped = 0 })
	while #cards > cfg.max do
		table.remove(cards, 1)
	end
	return cards
end

-- The cards still up at `now`
function ItemPopupRules.expire(list: { Card }, now: number): { Card }
	local kept = {}
	for _, card in list do
		if now < card.untilTime then
			table.insert(kept, card)
		end
	end
	return kept
end

-- Where the `index`th card's top sits, in pixels from the screen's top
function ItemPopupRules.slotY(index: number, cfg: Config): number
	return cfg.top + (index - 1) * (cfg.height + cfg.gap)
end

return ItemPopupRules
