--!strict
-- A weapon in words (the Forge window, the Armory, the drop and forge reveals): its stats and what something costs
-- with what the player has. Pure: `cfg` is Config/Weapons, `items` Config/Items, `combat` Config/Combat. Power and
-- perks come from Util/WeaponRules (required by path in Lune, like BattleSim's requires), so the words always match
-- the numbers the server uses.
local WeaponRules = if game ~= nil
	then require((script.Parent :: Instance):WaitForChild("WeaponRules")) :: any
	else require("./WeaponRules") :: any
-- the elements' plain names (Config/ElementNames, owner 2026-11-12)
local Names = if game ~= nil
	then require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Config"):WaitForChild("ElementNames")) :: any
	else require("../Config/ElementNames") :: any
local function elementName(key: string): string
	local name = Names[key]
	return if typeof(name) == "string" then name else key
end

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
		local which = if perk.every == 1 then "Every hit" else `Every {ordinal(perk.every)} hit`
		return `{which} heals your creature {percent(perk.share)}`
	elseif perk.kind == "erupt" and perk.every and perk.share then
		return `Every {ordinal(perk.every)} hit erupts for {percent(perk.share)} more`
	elseif perk.kind == "chill" and perk.share and perk.seconds then
		return `Hits slow the foe's attacks {percent(perk.share)} for {perk.seconds} s`
	elseif perk.kind == "burn" and perk.seconds and perk.look == "venom" then
		return `Poisons the foe for {perk.seconds} s`
	elseif perk.kind == "burn" and perk.seconds then
		return `Sets the foe burning for {perk.seconds} s`
	elseif perk.kind == "chain" and perk.every and perk.share and perk.spread then
		return `Every {ordinal(perk.every)} hit strikes for {percent(perk.share)} more and arcs to other foes for {percent(perk.spread)}`
	elseif perk.kind == "execute" and perk.share and perk.below then
		return `Hits deal {percent(perk.share)} more to foes under {percent(perk.below)} HP`
	elseif perk.kind == "prism" then
		return "Always strong against the foe's element"
	end
	return nil
end

-- Power, element and bond, the perk; grade and level when owned. Empty for an unknown weapon.
function WeaponText.stats(cfg: any, weaponId: string, owned: { grade: string, level: number }?, combat: any): { Row }
	local weapon = cfg.ById[weaponId]
	if not weapon then
		return {}
	end
	local grade = if owned then owned.grade else "C"
	local level = if owned then owned.level else 0
	local rows: { Row } = {
		{ label = "Power", value = string.format("x%.2f", WeaponRules.shownPower(cfg, combat, weaponId, grade, level)) },
	}
	local element = if weapon.prism then "Every element · bonds with every creature"
		elseif weapon.element then `{elementName(weapon.element)} · bonds with {elementName(weapon.element)} creatures`
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

-- Where a weapon comes from (`bosses` is Config/Bosses): "Drops from the Meadow Warden", "Forge: Wild Ore",
-- "Masterwork: 3 bosses' materials + Star Shards"
function WeaponText.source(cfg: any, bosses: any, weaponId: string): string
	local weapon = cfg.ById[weaponId]
	local source = if weapon then weapon.source else nil
	if not source or source.kind == "starter" then
		return "Everyone's first sword"
	elseif source.kind == "forge" then
		return "Forge: Wild Ore"
	elseif source.kind == "boss" then
		local boss = bosses.BOSSES[source.boss]
		return `Drops from the {if boss then boss.name else source.boss}`
	end
	local materials, shards = 0, false
	for id in (if source.cost then source.cost.items else {}) do
		if id == "starShard" then
			shards = true
		else
			for _, material in cfg.MATERIALS do
				if material == id then
					materials += 1
				end
			end
		end
	end
	if materials == 0 then
		return "Masterwork" -- its recipe isn't set yet (a later round)
	end
	return `Masterwork: {materials} bosses' materials{if shards then " + Star Shards" else ""}`
end

-- A material picked up, with its progress toward what it's for (WeaponRules.materialGoal): "Warden Heartwood +2 (9/15)"
function WeaponText.pickup(name: string, gained: number, have: number, need: number?): string
	return if need then `{name} +{gained} ({have}/{need})` else `{name} +{gained}`
end

-- The weapon switch's line under the name (owner 2026-11-14 pick C): the upgrade level (none at +0) and the element in
-- plain words ("+4 · Nature", "Fire", "+10 · Every element"); empty for the Steel Sword or an unknown weapon
function WeaponText.switchLine(cfg: any, weaponId: string, owned: { grade: string, level: number }?): string
	local weapon = cfg.ById[weaponId]
	if not weapon then
		return ""
	end
	local parts = {}
	if owned and owned.level > 0 then
		table.insert(parts, `+{owned.level}`)
	end
	if weapon.prism then
		table.insert(parts, "Every element")
	elseif weapon.element then
		table.insert(parts, elementName(weapon.element))
	end
	return table.concat(parts, " · ")
end

-- The Forge's one button (owner's pick B): what it does when everything's there ("Forge · $2,000", "Upgrade to +4 ·
-- $1,200", "Reforge · $1,000"), else what's missing first: the shop level, an item ("Need 6 more Warden Heartwood"),
-- then cash ("Need $500 more"). `cost` nil: an upgrade past +10. Returns the text and whether it can be pressed.
function WeaponText.button(
	action: "forge" | "upgrade" | "reforge",
	cost: { cash: number, items: { [string]: number } }?,
	have: { [string]: number },
	cashNow: number,
	items: any,
	opts: { level: number?, unlockLevel: number?, shopLevel: number? }
): (string, boolean)
	if not cost then
		return if action == "upgrade" then "Maxed at +10" else "Not available", false
	end
	if opts.unlockLevel and (opts.shopLevel or 0) < opts.unlockLevel then
		return `Opens at shop level {opts.unlockLevel}`, false
	end
	local ids = {}
	for id in cost.items do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local short = cost.items[id] - (have[id] or 0)
		if short > 0 then
			local item = items.ITEMS[id]
			return `Need {short} more {if item then item.name else id}`, false
		end
	end
	if cashNow < cost.cash then
		return `Need {cash(math.ceil(cost.cash - cashNow))} more`, false
	end
	local price = cash(cost.cash)
	if action == "upgrade" then
		return `Upgrade to +{opts.level or 1} · {price}`, true
	elseif action == "reforge" then
		return `Reforge · {price}`, true
	end
	return `Forge · {price}`, true
end

-- What reaching this upgrade level adds to the weapon's glow (Config/WeaponLooks LADDER; the aura starts earlier for
-- the rarest), for the forge reveal
function WeaponText.ladderStep(looks: any, level: number, rarity: string): string
	local ladder = looks.LADDER
	local auraFrom = ladder.auraFrom[rarity] or ladder.auraFrom.default
	if level >= ladder.awakenedAt then
		return "AWAKENED! Flames stream off it"
	elseif level == ladder.trailFrom then
		return "The full blaze, a bigger trail and a burst on every hit!"
	elseif level > ladder.trailFrom then
		return "A bigger trail"
	elseif level == auraFrom then
		return "Its aura appears!"
	elseif level > auraFrom then
		return "A stronger aura"
	end
	return "It glows brighter"
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

-- The Forge window's line under its tabs: what the tab does (owner's pick A, 2026-11-08)
local TAB_LINES = {
	Forge = "Make a weapon you don't have yet. You pay its materials and cash; it comes out at a random grade, C to S (like a card).",
	Upgrade = "Level a weapon you own up, +0 to +10: more Power and a brighter glow each level. Never fails. +5 and +10 also need Star Shards.",
	Reforge = "Roll a new grade for half the making cost. You keep the better grade, so it never gets worse. Grade S can't be reforged.",
}
function WeaponText.tabLine(tab: string): string
	return TAB_LINES[tab] or ""
end

-- The Forge window's cost chips: cash first ("$250"), then each item by id ("2 Wild Ore (you have 11)"), each with its
-- picture (a Config/UIIcons name, or an emoji; "" for an unknown item) and whether you have enough
export type Chip = { icon: string, text: string, enough: boolean }
function WeaponText.costChips(cost: { cash: number, items: { [string]: number } }, have: { [string]: number }, cashNow: number, items: any): { Chip }
	local chips: { Chip } = {}
	if cost.cash > 0 then
		table.insert(chips, { icon = "Cash", text = cash(cost.cash), enough = cashNow >= cost.cash })
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
		table.insert(chips, {
			icon = if item then item.icon or "" else "",
			text = `{need} {if item then item.name else id} (you have {count})`,
			enough = count >= need,
		})
	end
	return chips
end

-- The weapon window (Armory UI, owner's pick A 2026-11-09) ----------------------------------------------------------

-- A Power as the cards show it (2 decimals), read back as a number so differences match what's on screen
local function shown(cfg: any, combat: any, weaponId: string, owned: { grade: string, level: number }?): number
	local grade = if owned then owned.grade else "C"
	local level = if owned then owned.level else 0
	return tonumber(string.format("%.2f", WeaponRules.shownPower(cfg, combat, weaponId, grade, level))) :: number
end

-- This weapon's Power against the equipped one's: "+0.79 vs Steel Sword" (sign 1), "-0.20 vs Rift Reaper" (-1),
-- "Same Power as ..." or "Equipped now" (0). A record nil: Grade C at +0. nil when either weapon is unknown.
export type Versus = { text: string, sign: number }
function WeaponText.versus(
	cfg: any,
	combat: any,
	weaponId: string,
	owned: { grade: string, level: number }?,
	equippedId: string,
	equipped: { grade: string, level: number }?
): Versus?
	local held = cfg.ById[equippedId]
	if not cfg.ById[weaponId] or not held then
		return nil
	end
	if weaponId == equippedId then
		return { text = "Equipped now", sign = 0 }
	end
	local difference = shown(cfg, combat, weaponId, owned) - shown(cfg, combat, equippedId, equipped)
	if math.abs(difference) < 0.005 then
		return { text = `Same Power as {held.name}`, sign = 0 }
	end
	local sign = if difference > 0 then 1 else -1
	return { text = `{if sign > 0 then "+" else "-"}{string.format("%.2f", math.abs(difference))} vs {held.name}`, sign = sign }
end

-- A weapon's Power from Grade C at +0 to Grade S at the top level ("x1.40 to x2.09"; one number when they match)
function WeaponText.powerRange(cfg: any, combat: any, weaponId: string): string
	if not cfg.ById[weaponId] then
		return ""
	end
	local low = string.format("x%.2f", shown(cfg, combat, weaponId, nil))
	local high = string.format("x%.2f", shown(cfg, combat, weaponId, { grade = "S", level = cfg.MAX_LEVEL }))
	return if low == high then low else `{low} to {high}`
end

-- Where a boss lives, after its name (Config/Bosses place)
local PLACE_WORDS = { Wild = "in the Wild", Frontier = "in the Frontier", Dungeon = "at the end of the Dungeon" }

-- How to get a weapon you don't have: the boss that drops it ("Beat the Rift Devourer in the Frontier: it can drop.")
-- and the line over its forge materials (WeaponText.progress), when it can be forged
export type HowToGet = { drop: string?, forge: string? }
function WeaponText.howToGet(cfg: any, bosses: any, weaponId: string): HowToGet
	local weapon = cfg.ById[weaponId]
	local source = if weapon then weapon.source else nil
	if not source then
		return {}
	end
	if source.kind == "boss" then
		local boss = bosses.BOSSES[source.boss]
		local name = if boss then boss.name else source.boss
		local where = if boss then PLACE_WORDS[boss.place] else nil
		return {
			drop = if where then `Beat the {name} {where}: it can drop.` else `Beat the {name}: it can drop.`,
			forge = if WeaponRules.makeCost(cfg, weaponId) then "Or forge it:" else nil,
		}
	elseif source.kind == "forge" then
		return { forge = "Forge it at the Forge in your shop:" }
	elseif source.kind == "masterwork" then
		return { forge = "A masterwork. Forge it at the Forge in your shop:" }
	end
	return {}
end

-- A cost as progress rows: each material (sorted by id) with have/need ("12/60"), then the cash ("$30,000", have being
-- your cash), each with its picture (a Config/UIIcons name, "" for an unknown item)
export type Progress = { icon: string, name: string, have: number, need: number, text: string }
function WeaponText.progress(cost: { cash: number, items: { [string]: number } }, have: { [string]: number }, cashNow: number, items: any): { Progress }
	local rows: { Progress } = {}
	local ids = {}
	for id in cost.items do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local need = cost.items[id]
		local count = have[id] or 0
		local item = items.ITEMS[id]
		table.insert(rows, {
			icon = if item then item.icon or "" else "",
			name = if item then item.name else id,
			have = count,
			need = need,
			text = `{count}/{need}`,
		})
	end
	if cost.cash > 0 then
		table.insert(rows, { icon = "Cash", name = "Cash", have = cashNow, need = cost.cash, text = cash(cost.cash) })
	end
	return rows
end

-- A weapon's sword skill (Config/CombatHud SKILLS by its moveset, else the dash slash's BUTTONS.skill): its icon, its
-- name in words ("DASH" -> "Dash") and what it does
export type Skill = { icon: string, name: string, text: string }
function WeaponText.skill(hud: any, cfg: any, weaponId: string): Skill
	local weapon = cfg.ById[weaponId]
	local spec = (if weapon and weapon.moveset then hud.SKILLS[weapon.moveset] else nil) or hud.BUTTONS.skill
	local name: string = spec.name
	if name == string.upper(name) then
		name = string.upper(string.sub(name, 1, 1)) .. string.lower(string.sub(name, 2))
	end
	return { icon = spec.icon, name = name, text = spec.tip }
end

-- What sharing the weapon's element with your summoned creature gives (Config/Weapons BOND; the Prism Blade: every
-- creature). nil for a weapon with no element.
function WeaponText.bond(cfg: any, weaponId: string): string?
	local weapon = cfg.ById[weaponId]
	if not weapon or (not weapon.prism and not weapon.element) then
		return nil
	end
	local who = if weapon.prism then "every creature" else `{elementName(weapon.element)} creatures`
	return `+{percent(cfg.BOND.damage - 1)} hits and a {percent(cfg.BOND.meter - 1)} faster super with {who}`
end

return WeaponText
