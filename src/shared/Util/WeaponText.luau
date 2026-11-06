--!strict
-- A weapon in words (the Forge window, the Armory, the drop and forge reveals): its stats and what something costs
-- with what the player has. Pure: `cfg` is Config/Weapons, `items` Config/Items, `combat` Config/Combat. Power and
-- perks come from Util/WeaponRules (required by path in Lune, like BattleSim's requires), so the words always match
-- the numbers the server uses.
local WeaponRules = if game ~= nil
	then require((script.Parent :: Instance):WaitForChild("WeaponRules")) :: any
	else require("./WeaponRules") :: any

export type Row = { label: string, value: string }
export type Line = { text: string, enough: boolean }

local WeaponText = {}

-- "$25,000"
local function cash(amount: number): string
	local whole = tostring(math.floor(amount))
	local grouped = string.reverse((string.gsub(string.reverse(whole), "(%d%d%d)", "%1,")))
	if string.sub(grouped, 1, 1) == "," then
		grouped = string.sub(grouped, 2)
	end
	return `${grouped}`
end

-- 1st, 2nd, 3rd, 4th...
local function ordinal(n: number): string
	local lastTwo = n % 100
	local suffix = if lastTwo >= 11 and lastTwo <= 13 then "th"
		elseif n % 10 == 1 then "st"
		elseif n % 10 == 2 then "nd"
		elseif n % 10 == 3 then "rd"
		else "th"
	return `{n}{suffix}`
end

-- A share as a percent with no trailing zeros: 0.02 -> "2%", 0.024 -> "2.4%"
local function percent(share: number): string
	local text = string.format("%.1f", share * 100)
	return (string.gsub(text, "%.0$", "")) .. "%"
end

local function perkWords(perk: any): string?
	if perk.kind == "heal" and perk.every and perk.share then
		return `Every {ordinal(perk.every)} hit heals your creature {percent(perk.share)}`
	elseif perk.kind == "burn" and perk.seconds then
		return `Sets the foe burning for {perk.seconds} s`
	elseif perk.kind == "prism" then
		return "Always strong against the foe's element"
	end
	return nil
end

-- Power, element and bond, the perk; grade and level when owned. Empty for an unknown weapon.
function WeaponText.stats(cfg: any, weaponId: string, owned: { grade: string, level: number }?, _combat: any): { Row }
	local weapon = cfg.ById[weaponId]
	if not weapon then
		return {}
	end
	local grade = if owned then owned.grade else "C"
	local level = if owned then owned.level else 0
	local rows: { Row } = {
		{ label = "Power", value = string.format("x%.2f", WeaponRules.power(cfg, weaponId, grade, level)) },
	}
	local element = if weapon.prism then "Every element · bonds with every creature"
		elseif weapon.element then `{weapon.element} · bonds with {weapon.element} creatures`
		else "None"
	table.insert(rows, { label = "Element", value = element })
	local perk = WeaponRules.perk(cfg, weaponId, grade)
	local words = if perk then perkWords(perk) else nil
	if words then
		table.insert(rows, { label = "Perk", value = words })
	end
	if owned then
		table.insert(rows, { label = "Grade", value = owned.grade })
		table.insert(rows, { label = "Level", value = `+{owned.level}` })
	end
	return rows
end

-- A cost's lines: its cash (when there is any), then each item by name with have/need, each marked enough or not
function WeaponText.cost(cost: { cash: number, items: { [string]: number } }, have: { [string]: number }, cashNow: number, items: any): { Line }
	local lines: { Line } = {}
	if cost.cash > 0 then
		table.insert(lines, { text = cash(cost.cash), enough = cashNow >= cost.cash })
	end
	local ids = {}
	for id in cost.items do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local need = cost.items[id]
		local count = have[id] or 0
		local item = items.ITEMS[id]
		table.insert(lines, { text = `{if item then item.name else id} {count}/{need}`, enough = count >= need })
	end
	return lines
end

return WeaponText
