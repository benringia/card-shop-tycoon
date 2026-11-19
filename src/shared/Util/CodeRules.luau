--!strict
-- Codes (Config/Codes): what a typed code is, whether this player may redeem it, and the words for what it gave. Pure
-- (callers pass the configs and the time), Lune-tested. The server decides (CodeService); the client only tidies what
-- is typed with the same rule.
local CodeRules = {}

type Reward = { cash: number?, items: { { item: string, count: number } }?, luck: { strength: string, seconds: number }? }
type Code = { reward: Reward, ends: number? }
type Config = { CODES: { [string]: Code }, MAX_LENGTH: number }
export type Result = "ok" | "empty" | "unknown" | "used" | "expired"

-- What was typed as a code: capitals and digits only (spaces, dashes and symbols dropped); nil when it isn't text,
-- nothing is left or it's longer than a code can be
function CodeRules.normalize(text: unknown, maxLength: number): string?
	if typeof(text) ~= "string" then
		return nil
	end
	local code = string.gsub(string.upper(text), "[^A-Z0-9]", "")
	if code == "" or #code > maxLength then
		return nil
	end
	return code
end

-- Whether a player who has used `redeemed` may redeem `code` (already normalized; nil: nothing typed) at `now` (Unix),
-- and its entry when they may
function CodeRules.check(cfg: Config, redeemed: { string }, code: string?, now: number): (Result, Code?)
	if not code then
		return "empty", nil
	end
	if table.find(redeemed, code) then
		return "used", nil
	end
	local entry = cfg.CODES[code]
	if not entry then
		return "unknown", nil
	end
	if entry.ends and now >= entry.ends then
		return "expired", nil
	end
	return "ok", entry
end

-- A saved list of used codes made safe: well-formed codes only, each once. A code we no longer list is kept, so
-- listing it again can't pay twice
function CodeRules.clean(saved: unknown, maxLength: number): { string }
	local list: { string } = {}
	if typeof(saved) ~= "table" then
		return list
	end
	for _, value in saved :: { unknown } do
		if typeof(value) == "string" and CodeRules.normalize(value, maxLength) == value and not table.find(list, value) then
			table.insert(list, value)
		end
	end
	return list
end

local function money(amount: number): string
	local text = tostring(math.floor(amount))
	local grouped = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if grouped:sub(1, 1) == "," then
		grouped = grouped:sub(2)
	end
	return "$" .. grouped
end

-- "You got: $250, First Spark Pack x2, 15 min 2x Luck" (items: Config/Items, luck: Config/Luck)
function CodeRules.gotLine(reward: Reward, items: any, luck: any): string
	local parts: { string } = {}
	if reward.cash and reward.cash > 0 then
		table.insert(parts, money(reward.cash))
	end
	for _, grant in reward.items or {} do
		local info = items.ITEMS[grant.item]
		local name = if info then info.name else grant.item
		table.insert(parts, if grant.count > 1 then `{name} x{grant.count}` else name)
	end
	if reward.luck then
		local strength = luck.STRENGTHS[reward.luck.strength]
		local name = if strength then strength.name else reward.luck.strength
		table.insert(parts, `{math.floor(reward.luck.seconds / 60)} min {name}`)
	end
	return "You got: " .. table.concat(parts, ", ")
end

return CodeRules
