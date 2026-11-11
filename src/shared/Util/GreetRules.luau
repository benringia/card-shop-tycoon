--!strict
-- Town Chikin greeting players who come near (the owner 2026-11-11: "Make chicken greet you or other player when your
-- at a certain distance from them"; Config/Chikin TOWN.greet, ChikinTalk.GREETS): who he greets next and which line he
-- says. Pure, Lune-tested (tests/GreetRules); TownChikinService picks, TownChikinController shows his bubble.
local GreetRules = {}

export type Near = { key: string, distance: number }

-- The nearest player within `cfg.range` studs he hasn't greeted in `cfg.cooldown` seconds (`lastAt`: when he last
-- greeted each, by key), or nil
function GreetRules.pick(near: { Near }, lastAt: { [string]: number }, now: number, cfg: { range: number, cooldown: number }): string?
	local best: Near? = nil
	for _, candidate in near do
		local last = lastAt[candidate.key]
		local rested = last == nil or now - last >= cfg.cooldown
		if candidate.distance <= cfg.range and rested and (best == nil or candidate.distance < best.distance) then
			best = candidate
		end
	end
	return if best then best.key else nil
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
