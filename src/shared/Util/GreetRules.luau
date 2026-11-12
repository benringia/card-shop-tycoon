--!strict
-- Town Chikin greeting players who come near (the owner 2026-11-11: "Make chicken greet you or other player when your
-- at a certain distance from them"; Config/Chikin TOWN.greet, ChikinTalk.GREETS): who he greets next and which line he
-- says. Pure, Lune-tested (tests/GreetRules); TownChikinService picks, TownChikinController shows his bubble.
local GreetRules = {}

export type Near = { key: string, distance: number }

-- The nearest player within `cfg.range` studs he hasn't greeted in `cfg.cooldown` seconds (`lastAt`: when he last
-- greeted each, by key), or nil. With `inside` (who was in range on his last look) only one who just walked up counts
-- (owner 2026-11-12: a hello is for coming near him, not for standing there or joining beside him)
function GreetRules.pick(near: { Near }, lastAt: { [string]: number }, now: number, cfg: { range: number, cooldown: number }, inside: { [string]: boolean }?): string?
	local best: Near? = nil
	for _, candidate in near do
		local last = lastAt[candidate.key]
		local rested = last == nil or now - last >= cfg.cooldown
		local arrived = inside == nil or not inside[candidate.key]
		if candidate.distance <= cfg.range and rested and arrived and (best == nil or candidate.distance < best.distance) then
			best = candidate
		end
	end
	return if best then best.key else nil
end

-- The line for a hello in one list of `count` hellos then `thanks` thank-yous (a supporter gets a thank-you, owner
-- 2026-11-12 "Support the dev"), never `last` again while there's another of its kind
function GreetRules.pickLine(count: number, thanks: number, supporter: boolean, roll: number, last: number?): number
	if supporter and thanks > 0 then
		return count + GreetRules.line(thanks, roll, if last and last > count then last - count else nil)
	end
	return GreetRules.line(count, roll, if last and last <= count then last else nil)
end

-- Which of `count` greetings he says (by `roll`, 0-1), never `last` again while there's another
function GreetRules.line(count: number, roll: number, last: number?): number
	if count <= 1 then
		return 1
	end
	local options = {}
	for index = 1, count do
		if index ~= last then
			table.insert(options, index)
		end
	end
	return options[math.floor(math.clamp(roll, 0, 0.999999) * #options) + 1]
end

return GreetRules
