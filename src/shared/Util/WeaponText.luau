--!strict
-- A weapon in words (the Forge window, the Armory, the drop and forge reveals): its stats and what something costs
-- with what the player has. Pure: `cfg` is Config/Weapons, `items` Config/Items, `combat` Config/Combat. Power and
-- perks come from Util/WeaponRules (required by path in Lune, like BattleSim's requires), so the words always match
-- the numbers the server uses.
local WeaponRules = if game ~= nil
	then require((script.Parent :: Instance):WaitForChild("WeaponRules")) :: any
	else require("./WeaponRules") :: any
-- the perks' icons, the same the Armory has always used
local WeaponLookRules = if game ~= nil
	then require((script.Parent :: Instance):WaitForChild("WeaponLookRules")) :: any
	else require("./WeaponLookRules") :: any
-- a weapon's mutation in words (weapons round 4 part 2)
local MutationRules = if game ~= nil
	then require((script.Parent :: Instance):WaitForChild("MutationRules")) :: any
	else require("./MutationRules") :: any
-- the elements' plain names (Config/ElementNames, owner 2026-11-12)
local Names = if game ~= nil
	then require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Config"):WaitForChild("ElementNames")) :: any
	else require("../Config/ElementNames") :: any
local function elementName(key: string): string
	local name = Names[key]
	return if typeof(name) == "string" then name else key
end

-- `highlight`: the Prism Blade's Super effective, gold on the weapon switch's tip (owner 2026-11-25: "highlight that
-- stat inside prism blade tooltip"; "Always strong" until the owner's keyword pick, 2026-11-26)
export type Row = { label: string, value: string, highlight: boolean? }

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
	end
	return nil -- the Prism Blade's too: its Element line says it
end

-- A weapon's Power as its Attack (weapons round 4, owner 2026-11-25: "better numbers for kids ... rather than x1.30"):
-- the multiplier x 100, rounded, never truncated (1.505 x 100 is 150.4999... in floating point: the epsilon)
function WeaponText.attack(power: number): number
	return math.floor(power * 100 + 0.5 + 1e-9)
end

-- The card face's line: "Attack 151"
function WeaponText.attackLine(power: number): string
	return `Attack {WeaponText.attack(power)}`
end

-- Attack, element and bond, the perk; grade and level when owned. Empty for an unknown weapon.
-- `mutations` (Config/Mutations): given, an owned weapon's mutation gets its line ("Epic · Sharp · sword hits +12%")
function WeaponText.stats(cfg: any, weaponId: string, owned: { grade: string, level: number, mutation: any? }?, combat: any, mutations: any?): { Row }
	local weapon = cfg.ById[weaponId]
	if not weapon then
		return {}
	end
	local grade = if owned then owned.grade else "C"
	local level = if owned then owned.level else 0
	local rows: { Row } = {
		{ label = "Attack", value = tostring(WeaponText.attack(WeaponRules.shownPower(cfg, combat, weaponId, grade, level))) },
	}
	if weapon.prism then
		table.insert(rows, { label = "Element", value = "Super effective against every element", highlight = true })
		table.insert(rows, { label = "Ultimate", value = "Use your creature's element weapon" })
	else
		local element = if weapon.element then `{elementName(weapon.element)} · bonds with {elementName(weapon.element)} creatures` else "None"
		table.insert(rows, { label = "Element", value = element })
	end
	local perk = WeaponRules.perk(cfg, weaponId, grade)
	local words = if perk then perkWords(perk) else nil
	if words then
		table.insert(rows, { label = "Perk", value = words })
	end
	if owned then
		table.insert(rows, { label = "Grade", value = owned.grade })
		table.insert(rows, { label = "Level", value = `+{owned.level}` })
		if mutations and owned.mutation then
			table.insert(rows, { label = "Mutation", value = MutationRules.words(mutations, owned.mutation).short })
		end
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
-- plain words ("+4 · Nature", "Fire"; the Prism Blade's one edge: "+10 · Super effective"); empty for the Steel Sword or
-- an unknown weapon
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
		table.insert(parts, "Super effective")
	elseif weapon.element then
		table.insert(parts, elementName(weapon.element))
	end
	return table.concat(parts, " · ")
end

-- The Forge window's picture recipe (owner 2026-11-20: "redesign it like the condenser to be easily understood ...
-- do the same with forge") ---------------------------------------------------------------------------------------------
type Cost = { cash: number, items: { [string]: number } }
export type RecipeOpts = {
	name: string?, -- the weapon's name
	level: number?, -- an upgrade: the level it becomes
	unlockLevel: number?,
	shopLevel: number?,
	wait: string?, -- how long the job takes, in words ("2 minutes")
	done: boolean?, -- a reforge: it is Grade S already
}

local function sortedIds(cost: Cost): { string }
	local ids = {}
	for id in cost.items do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

local function itemName(items: any, id: string): string
	local item = items.ITEMS[id]
	return if item then item.name else id
end

-- "15 Warden Heartwood", "2 Star Shards": a name that ends in a stuff word takes no s
local STUFF = { "wood", "Silk", "Ore" }
local function counted(items: any, id: string, count: number): string
	local name = itemName(items, id)
	local plural = count ~= 1
	for _, ending in STUFF do
		if string.sub(name, -#ending) == ending then
			plural = false
		end
	end
	return `{count} {name}{if plural then "s" else ""}`
end

-- The first thing that's missing: an item (its id and how many more), else the cash (how much more)
local function missing(cost: Cost, have: { [string]: number }, cashNow: number): (string?, number)
	for _, id in sortedIds(cost) do
		local short = cost.items[id] - (have[id] or 0)
		if short > 0 then
			return id, short
		end
	end
	if cashNow < cost.cash then
		return nil, math.ceil(cost.cash - cashNow)
	end
	return nil, 0
end

-- The recipe's spots: each material by id with what you have of what it takes ("9 / 15", never more than it takes),
-- then the cash ("$2,000"), each with its picture (a Config/UIIcons name or an emoji; "" for an unknown item) and
-- whether you have enough
export type Spot = { icon: string, count: string, enough: boolean }
function WeaponText.spots(cost: Cost, have: { [string]: number }, cashNow: number, items: any): { Spot }
	local spots: { Spot } = {}
	for _, id in sortedIds(cost) do
		local need = cost.items[id]
		local count = have[id] or 0
		local item = items.ITEMS[id]
		table.insert(spots, { icon = if item then item.icon or "" else "", count = `{math.min(count, need)} / {need}`, enough = count >= need })
	end
	if cost.cash > 0 then
		table.insert(spots, { icon = "Cash", count = cash(cost.cash), enough = cashNow >= cost.cash })
	end
	return spots
end

-- How many spots across: one row up to three, then two rows
function WeaponText.spotColumns(count: number): number
	return if count <= 3 then math.max(1, count) else math.ceil(count / 2)
end

-- What the action makes, after "to": "make the Verdant Blade", "make it +4", "roll a new grade"
local function goal(action: string, opts: RecipeOpts): string
	if action == "upgrade" then
		return `make it +{opts.level or 1}`
	elseif action == "reforge" then
		return "roll a new grade"
	end
	return `make the {opts.name or "weapon"}`
end

-- The one sentence over the recipe: what goes in and what comes out ("Use 15 Warden Heartwood and $2,000 to make the
-- Verdant Blade!"; more than two kinds of material are counted, the spots show them), or what to get first ("Get 6
-- more Warden Heartwood to ...", "Save up $500 more to ..."). `cost` nil: an upgrade past the top level
function WeaponText.say(action: "forge" | "upgrade" | "reforge", cost: Cost?, have: { [string]: number }, cashNow: number, items: any, opts: RecipeOpts): string
	if opts.done then
		return "Grade S is the best grade: nothing to reforge!"
	elseif not cost then
		return if action == "upgrade" then "It is +10: fully upgraded!" else "The Forge can't make this yet."
	elseif opts.unlockLevel and (opts.shopLevel or 0) < opts.unlockLevel then
		return `The Forge makes this at shop level {opts.unlockLevel}.`
	end
	local what = goal(action, opts)
	local id, short = missing(cost, have, cashNow)
	if id then
		return `Get {short} more {itemName(items, id)} to {what}.`
	elseif short > 0 then
		return `Save up {cash(short)} more to {what}.`
	end
	local ids = sortedIds(cost)
	local parts: { string } = {}
	if #ids > 2 then
		table.insert(parts, `these {#ids} materials`)
	else
		for _, id2 in ids do
			table.insert(parts, counted(items, id2, cost.items[id2]))
		end
	end
	if cost.cash > 0 then
		table.insert(parts, cash(cost.cash))
	end
	local last = table.remove(parts) or "nothing"
	local list = if #parts > 0 then `{table.concat(parts, ", ")} and {last}` else last
	if action == "upgrade" then
		return `Use {list} to {what}: more Attack!`
	elseif action == "reforge" then
		return `Use {list} to {what}. You keep the better one!`
	end
	return `Use {list} to {what}!`
end

-- The Forge's one button: its words, the small line under them and whether it can be pressed. Ready: what it does
-- ("Forge it!", "Make it +4!", "Roll a new grade!") over how long it takes; else what's missing first (the shop level,
-- an item, then cash) over what you have
function WeaponText.recipeButton(action: "forge" | "upgrade" | "reforge", cost: Cost?, have: { [string]: number }, cashNow: number, items: any, opts: RecipeOpts): (string, string?, boolean)
	if opts.done then
		return "Already Grade S", nil, false
	elseif not cost then
		return if action == "upgrade" then "Fully upgraded" else "Not available", nil, false
	elseif opts.unlockLevel and (opts.shopLevel or 0) < opts.unlockLevel then
		return `Opens at shop level {opts.unlockLevel}`, nil, false
	end
	local id, short = missing(cost, have, cashNow)
	if id then
		return `Need {short} more {itemName(items, id)}`, `you have {have[id] or 0}`, false
	elseif short > 0 then
		return `Need {cash(short)} more`, `you have {cash(cashNow)}`, false
	end
	local sub = if opts.wait then `takes {opts.wait}` else nil
	if action == "upgrade" then
		return `Make it +{opts.level or 1}!`, sub, true
	elseif action == "reforge" then
		return "Roll a new grade!", sub, true
	end
	return "Forge it!", sub, true
end

-- Under the recipe's weapon: a pill (the grade or level it comes out with) and a line. `step`: an upgrade's
-- WeaponText.ladderStep; `max`: it is fully upgraded; `grade`: a reforge's grade now; `done`: Grade S already
function WeaponText.outcome(action: "forge" | "upgrade" | "reforge", view: { level: number?, step: string?, max: boolean?, grade: string?, done: boolean? }): (string, string?)
	if action == "upgrade" then
		return `+{view.level or 0}`, if view.max then "Awakened!" else view.step
	elseif action == "reforge" then
		return `Grade {view.grade or "C"}`, if view.done then nil else "A new roll, C to S. It never gets worse!"
	end
	return "Grade C to S", "It comes out at a random grade, like a card. S is the best!"
end

-- How much Attack an upgrade adds (two Powers), in the whole numbers the cards show
function WeaponText.powerGain(now: number, after: number): string
	return `+{math.max(0, WeaponText.attack(after) - WeaponText.attack(now))} Attack`
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

-- The Forge window's line under its tabs: what the tab does (owner's pick A, 2026-11-08)
local TAB_LINES = {
	Forge = "Make a weapon you don't have yet. You pay its materials and cash; it comes out at a random grade, C to S (like a card).",
	Upgrade = "Level a weapon you own up, +0 to +10: more Attack and a brighter glow each level. Never fails. +5 and +10 also need Star Shards.",
	Reforge = "Roll a new grade for half the making cost. You keep the better grade, so it never gets worse. Grade S can't be reforged.",
}
function WeaponText.tabLine(tab: string): string
	return TAB_LINES[tab] or ""
end

-- The weapon window (Armory UI, owner's pick A 2026-11-09) ----------------------------------------------------------

-- A weapon's Attack as the cards show it (a record nil: Grade C at +0), so differences match what's on screen
local function shownAttack(cfg: any, combat: any, weaponId: string, owned: { grade: string, level: number }?): number
	local grade = if owned then owned.grade else "C"
	local level = if owned then owned.level else 0
	return WeaponText.attack(WeaponRules.shownPower(cfg, combat, weaponId, grade, level))
end

-- This weapon's Attack against the equipped one's: "+79 vs Steel Sword" (sign 1), "-20 vs Rift Reaper" (-1),
-- "Same Attack as ..." or "Equipped now" (0). A record nil: Grade C at +0. nil when either weapon is unknown.
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
	local difference = shownAttack(cfg, combat, weaponId, owned) - shownAttack(cfg, combat, equippedId, equipped)
	if difference == 0 then
		return { text = `Same Attack as {held.name}`, sign = 0 }
	end
	local sign = if difference > 0 then 1 else -1
	return { text = `{if sign > 0 then "+" else "-"}{math.abs(difference)} vs {held.name}`, sign = sign }
end

-- A weapon's Attack from Grade C at +0 to Grade S at the top level ("Attack 140 to 209"; one number when they match)
function WeaponText.powerRange(cfg: any, combat: any, weaponId: string): string
	if not cfg.ById[weaponId] then
		return ""
	end
	local low = shownAttack(cfg, combat, weaponId, nil)
	local high = shownAttack(cfg, combat, weaponId, { grade = "S", level = cfg.MAX_LEVEL })
	return if low == high then `Attack {low}` else `Attack {low} to {high}`
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
-- name in words ("DASH" -> "Dash"), what it does and that in one short line (the weapon window's row)
export type Skill = { icon: string, name: string, text: string, short: string }
function WeaponText.skill(hud: any, cfg: any, weaponId: string): Skill
	local weapon = cfg.ById[weaponId]
	local spec = (if weapon and weapon.moveset then hud.SKILLS[weapon.moveset] else nil) or hud.BUTTONS.skill
	local name: string = spec.name
	if name == string.upper(name) then
		name = string.upper(string.sub(name, 1, 1)) .. string.lower(string.sub(name, 2))
	end
	return { icon = spec.icon, name = name, text = spec.tip, short = spec.short or spec.tip }
end

-- A perk's row in the weapon window: a title and one short line ("Heals your creature", "Every 4th hit heals it 2%.");
-- nil for a perk with no row (the Prism Blade's, its SUPER EFFECTIVE row instead)
local function perkRow(perk: any): (string?, string?)
	if perk.kind == "heal" and perk.every and perk.share then
		local which = if perk.every == 1 then "Every hit" else `Every {ordinal(perk.every)} hit`
		return "Heals your creature", `{which} heals it {percent(perk.share)}.`
	elseif perk.kind == "erupt" and perk.every and perk.share then
		return "Erupts", `Every {ordinal(perk.every)} hit bursts for {percent(perk.share)} more.`
	elseif perk.kind == "chill" and perk.share and perk.seconds then
		return "Chills the foe", `Its attacks slow {percent(perk.share)} for {perk.seconds} s.`
	elseif perk.kind == "burn" and perk.seconds and perk.look == "venom" then
		return "Poisons the foe", `Hits poison it for {perk.seconds} s.`
	elseif perk.kind == "burn" and perk.seconds then
		return "Burns the foe", `Hits set it burning for {perk.seconds} s.`
	elseif perk.kind == "chain" and perk.every and perk.share then
		return "Chain lightning", `Every {ordinal(perk.every)} hit strikes {percent(perk.share)} harder and arcs to other foes.`
	elseif perk.kind == "execute" and perk.share and perk.below then
		return "Finishes foes", `Hits deal {percent(perk.share)} more to foes under {percent(perk.below)} HP.`
	end
	return nil, nil
end

-- The weapon window's rows (weapons round 4, layout A; owner 2026-11-25: "rearrange this UI to be easily understood"):
-- each an icon (a Config/UIIcons name), a bold title and one short line, in window order. A weapon you don't have:
-- its Attack range first. Then its skill, its perk, its bond; the Prism Blade's SUPER EFFECTIVE and Ultimate instead of
-- a bond (distinct icons, owner: "attack, mutation and super has the same icon"; supers are called Ultimate in the
-- game's words, owner 2026-11-26). Last, its mutation (weapons round 4 part 2; `mutations` is Config/Mutations: its
-- group's icon, drawn in its `rarity` colour) and one waiting for the player's choice. `looks` is Config/WeaponLooks
-- (the perks' icons). Empty for an unknown weapon.
export type WindowRow = {
	kind: "range" | "skill" | "perk" | "bond" | "strong" | "ultimate" | "mutation" | "pending",
	icon: string,
	title: string,
	words: string,
	rarity: string?,
}
function WeaponText.rows(cfg: any, hud: any, looks: any, combat: any, weaponId: string, owned: { grade: string, level: number, mutation: any?, pending: any? }?, mutations: any?): { WindowRow }
	local weapon = cfg.ById[weaponId]
	if not weapon then
		return {}
	end
	local rows: { WindowRow } = {}
	if not owned then
		table.insert(rows, { kind = "range", icon = "Power", title = WeaponText.powerRange(cfg, combat, weaponId), words = `Grade C at +0 to Grade S at +{cfg.MAX_LEVEL}` })
	end
	local skill = WeaponText.skill(hud, cfg, weaponId)
	table.insert(rows, { kind = "skill", icon = skill.icon, title = skill.name, words = skill.short })
	local perk = WeaponRules.perk(cfg, weaponId, if owned then owned.grade else "C")
	if perk then
		local title, words = perkRow(perk)
		if title and words then
			table.insert(rows, { kind = "perk", icon = WeaponLookRules.perkIcon(looks, perk), title = title, words = words })
		end
	end
	if weapon.prism then
		table.insert(rows, { kind = "strong", icon = "Elements", title = "SUPER EFFECTIVE", words = `Every hit is super effective ({combat.STRONG}x), whatever the foe's element.` })
		table.insert(rows, { kind = "ultimate", icon = "Lock", title = "Ultimate", words = "Doesn't unlock ultimates: use your creature's element weapon." })
	elseif weapon.element then
		local name = elementName(weapon.element)
		table.insert(rows, {
			kind = "bond",
			icon = weapon.element,
			title = `Best with {name} creatures`,
			words = `Unlocks their ultimates. Hits +{percent(cfg.BOND.damage - 1)}, ultimates charge {percent(cfg.BOND.meter - 1)} faster.`,
		})
	end
	if mutations and owned and owned.mutation then
		local words = MutationRules.words(mutations, owned.mutation)
		table.insert(rows, { kind = "mutation", icon = words.icon, title = words.title, words = words.line, rarity = words.rarity })
	end
	if mutations and owned and owned.pending then
		-- the reveal plays once no window is open (its stage is 3D: WeaponRevealController)
		table.insert(rows, { kind = "pending", icon = "Sparkle", title = "New mutation waiting!", words = "Close your windows to choose: take it or keep yours." })
	end
	return rows
end

-- A boss material toward its weapon (the chest card, the pick-up card), in simple words (owner 2026-11-20; it said
-- "9/15 to make ..." and "Enough to make ...!"): "Get 6 more to make the Verdant Blade", "Get 1 more to upgrade the
-- Verdant Blade", or "You can make the Verdant Blade now!" once there's enough (`owned`: the weapon is yours, so
-- `need` is its next upgrade's cost)
function WeaponText.goalLine(have: number, need: number, weaponName: string, owned: boolean): string
	local verb = if owned then "upgrade" else "make"
	if have >= need then
		return `You can {verb} the {weaponName} now!`
	end
	return `Get {need - have} more to {verb} the {weaponName}`
end

return WeaponText
