--!strict
-- Card comparisons a kid reads at a glance: stat bars against the strongest card's stats, paired bars where the
-- longer one wins, and the STRONGER / WEAKER verdict when swapping a party card. Pure (no requires, no Roblox
-- APIs), so tests/ can run it in Lune.
local CompareRules = {}

export type Stats = { hp: number, atk: number, spd: number }
export type Winner = "in" | "out" | "tie"
export type Verdict = "stronger" | "weaker" | "same"

CompareRules.MIN_SHARE = 0.04 -- a bar never draws empty

-- How full a stat's bar is against the reference (the strongest card's stat)
function CompareRules.share(value: number, reference: number): number
	if reference <= 0 then
		return 1
	end
	return math.clamp(value / reference, CompareRules.MIN_SHARE, 1)
end

-- Two cards' stat side by side: the bigger fills its bar and wins
function CompareRules.pair(incoming: number, outgoing: number): (number, number, Winner)
	local top = math.max(incoming, outgoing)
	if top <= 0 then
		return CompareRules.MIN_SHARE, CompareRules.MIN_SHARE, "tie"
	end
	local winner: Winner = if incoming > outgoing then "in" elseif outgoing > incoming then "out" else "tie"
	return CompareRules.share(incoming, top), CompareRules.share(outgoing, top), winner
end

-- Swapping a card in: better or worse by Power (rounded); an empty slot compares with nothing
function CompareRules.verdict(inPower: number, outPower: number?): (Verdict, number)
	local delta = math.round(inPower - (outPower or 0))
	return if delta > 0 then "stronger" elseif delta < 0 then "weaker" else "same", delta
end

-- The badge word
function CompareRules.verdictText(inPower: number, outPower: number?): string
	local kind = CompareRules.verdict(inPower, outPower)
	return if kind == "stronger" then "STRONGER" elseif kind == "weaker" then "WEAKER" else "SAME POWER"
end

-- "Cindercub has 192 less Power" (than Ashbeak, when given)
function CompareRules.powerLine(inName: string, inPower: number, outPower: number, outName: string?): string
	local kind, delta = CompareRules.verdict(inPower, outPower)
	if kind == "same" then
		return if outName then `{inName} and {outName} have the same Power` else `{inName} has the same Power`
	end
	local than = if outName then ` than {outName}` else ""
	return `{inName} has {math.abs(delta)} {if kind == "stronger" then "more" else "less"} Power{than}`
end

-- The line on each party slot in the chooser (outPower nil: the slot is empty)
function CompareRules.swapText(inName: string, inPower: number, outPower: number?): string
	if outPower == nil then
		return `Free spot: {inName} goes here`
	end
	return CompareRules.powerLine(inName, inPower, outPower)
end

-- The highest HP, ATK and SPD across these cards (what full bars mean)
function CompareRules.reference(statsList: { Stats }): Stats
	local best = { hp = 0, atk = 0, spd = 0 }
	for _, stats in statsList do
		best.hp = math.max(best.hp, stats.hp)
		best.atk = math.max(best.atk, stats.atk)
		best.spd = math.max(best.spd, stats.spd)
	end
	return best
end

return CompareRules
