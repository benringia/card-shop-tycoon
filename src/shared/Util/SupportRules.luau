--!strict
-- "Support the dev" (owner 2026-11-12; Config/Support): a player's gifts and best tier as saved (data.support), which
-- product is which tier, and when Pish asks. Pure, Lune-tested.
local SupportRules = {}

export type State = { gifts: number, best: number }

local function count(value: unknown, top: number): number
	return if typeof(value) == "number" and value == value then math.clamp(math.floor(value), 0, top) else 0
end

-- A saved record read back (`top`: the highest tier; junk counts as nothing)
function SupportRules.read(saved: unknown, top: number?): State
	local record: any = if typeof(saved) == "table" then saved else {}
	return { gifts = count(record.gifts, math.huge), best = count(record.best, top or math.huge) }
end

-- One more gift of `tier`: counted, and the best tier kept (never past `top`)
function SupportRules.give(state: State, tier: number, top: number): State
	return { gifts = state.gifts + 1, best = math.max(state.best, math.clamp(tier, 0, top)) }
end

-- The tier a Monetization PRODUCTS key buys, or nil
function SupportRules.tierOf(cfg: any, product: string): number?
	for index, tier in cfg.TIERS do
		if tier.product == product then
			return index
		end
	end
	return nil
end

-- Whether Pish asks now (after a good moment): once a session, never someone who gave, never over a tour, never
-- before their first visit is done
function SupportRules.nudge(s: { asked: boolean, best: number, touring: boolean, ready: boolean }): boolean
	return not s.asked and s.best == 0 and not s.touring and s.ready
end

-- The thank-you after a gift: "full" (the dogs run in) unless a fight, a tour or another cinematic or screen holds the
-- player's screen, then "glow" (only the glow rising out of them)
function SupportRules.thanksMode(s: { fighting: boolean, touring: boolean, busy: boolean }): "full" | "glow"
	return if s.fighting or s.touring or s.busy then "glow" else "full"
end

return SupportRules
