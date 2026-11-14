--!strict
-- Luck bought with Robux (Config/Luck): seconds left per strength. Each purchase adds to its strength, the strongest
-- with time runs (ORDER) and only it runs down, so a 2x bought under a Super Luck waits its turn. Pure; never changes
-- the state passed in. Tested in tests/BoughtLuck.
local BoughtLuck = {}

export type State = { [string]: number } -- strength -> seconds left

local function copy(state: State): State
	return table.clone(state)
end

-- A saved luck made safe: every strength present, whole seconds from 0 to MAX_SECONDS, nothing else
function BoughtLuck.clean(saved: any, cfg: any): State
	local state: State = {}
	for strength in cfg.STRENGTHS do
		local value = if typeof(saved) == "table" then saved[strength] else nil
		state[strength] = if typeof(value) == "number" and value == value then math.clamp(math.floor(value), 0, cfg.MAX_SECONDS) else 0
	end
	return state
end

-- `seconds` more of `strength` (capped); an unknown strength changes nothing
function BoughtLuck.add(state: State, strength: string, seconds: number, cfg: any): State
	local out = copy(state)
	if cfg.STRENGTHS[strength] then
		out[strength] = math.min(cfg.MAX_SECONDS, (out[strength] or 0) + math.max(0, math.floor(seconds)))
	end
	return out
end

-- The strength running now: the strongest with time left, nil when none
function BoughtLuck.active(state: State, cfg: any): string?
	for _, strength in cfg.ORDER do
		if (state[strength] or 0) > 0 then
			return strength
		end
	end
	return nil
end

-- `seconds` of play: the running strength's time goes down (never below 0), the others wait
function BoughtLuck.tick(state: State, seconds: number, cfg: any): State
	local strength = BoughtLuck.active(state, cfg)
	if not strength then
		return state
	end
	local out = copy(state)
	out[strength] = math.max(0, out[strength] - seconds)
	return out
end

local function percent(chance: number): string
	local value = chance * 100
	if math.abs(value - math.round(value)) < 0.05 then
		return `{math.round(value)}%`
	end
	return string.format("%.1f%%", math.floor(value * 10 + 0.5) / 10) -- halves up (1.25% reads 1.3%)
end

-- The Store tile's chip: the Legendary chance on the last card before and with the luck ("Legendary 1% to 2%"; plain
-- words, the fonts draw an arrow as a box)
function BoughtLuck.oddsText(plain: number, lucky: number): string
	return `Legendary {percent(plain)} to {percent(lucky)}`
end

-- A win card's line with the minutes bought in place of {minutes} ("1 minute", never "1 minutes")
function BoughtLuck.winText(text: string, seconds: number): string
	local minutes = math.floor(seconds / 60)
	local out = string.gsub(text, "{minutes}", tostring(minutes))
	if minutes == 1 then
		out = string.gsub(out, "^1 minutes", "1 minute")
	end
	return out
end

-- What a strength adds to the last card's luck (Util/LuckRules.boost amount; Pish's Luck adds to it), 0 for none
function BoughtLuck.boost(strength: string?, cfg: any): number
	local info = if strength then cfg.STRENGTHS[strength] else nil
	return if info then info.boost else 0
end

return BoughtLuck
