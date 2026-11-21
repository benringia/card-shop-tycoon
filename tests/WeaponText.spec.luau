--!strict
local WeaponText = require("../src/shared/Util/WeaponText")
local Weapons = require("../src/shared/Config/Weapons")
local Items = require("../src/shared/Config/Items")
local Combat = require("../src/shared/Config/Combat")
local Bosses = require("../src/shared/Config/Bosses")
local CombatHud = require("../src/shared/Config/CombatHud")
local expect = require("./lib/expect")

local function valueOf(rows: { { label: string, value: string } }, label: string): string?
	for _, row in rows do
		if row.label == label then
			return row.value
		end
	end
	return nil
end

return {
	["the spears' perks in words (weapons round 2)"] = function()
		expect.equal(valueOf(WeaponText.stats(Weapons, "magmaHalberd", nil, Combat), "Perk"), "Every 5th hit erupts for 60% more")
		expect.equal(valueOf(WeaponText.stats(Weapons, "tidalTrident", nil, Combat), "Perk"), "Hits slow the foe's attacks 10% for 3 s")
		expect.equal(valueOf(WeaponText.stats(Weapons, "titansLance", nil, Combat), "Perk"), "Every 4th hit heals your creature 1%")
	end,

	["stats: Power to 2 decimals, the element and its bond, the perk in words"] = function()
		local rows = WeaponText.stats(Weapons, "verdantBlade", nil, Combat)
		expect.equal(valueOf(rows, "Power"), "x1.10")
		expect.equal(valueOf(rows, "Element"), "Nature · bonds with Nature creatures") -- plain element names (owner 2026-11-12)
		expect.equal(valueOf(rows, "Perk"), "Every 4th hit heals your creature 2%")
		expect.equal(valueOf(rows, "Grade"), nil, "not owned: no grade or level")
		local owned = WeaponText.stats(Weapons, "verdantBlade", { grade = "S", level = 4 }, Combat)
		expect.equal(valueOf(owned, "Power"), "x1.52") -- 1.1 x 1.15 x 1.2
		expect.equal(valueOf(owned, "Perk"), "Every 4th hit heals your creature 2.4%", "Grade S perks are stronger")
		expect.equal(valueOf(owned, "Grade"), "S")
		expect.equal(valueOf(owned, "Level"), "+4")
	end,

	["stats: the burn, the prism and the plain Steel Sword"] = function()
		expect.equal(valueOf(WeaponText.stats(Weapons, "sunforgedBlade", nil, Combat), "Perk"), "Sets the foe burning for 3 s")
		local prism = WeaponText.stats(Weapons, "prismBlade", nil, Combat)
		expect.equal(valueOf(prism, "Power"), "x1.50", "always strong and bonded (0.87 x 1.5 x 1.15)")
		expect.equal(valueOf(prism, "Perk"), "Always strong against the foe's element")
		expect.equal(valueOf(prism, "Element"), "Every element · bonds with every creature")
		local steel = WeaponText.stats(Weapons, "starterSword", nil, Combat)
		expect.equal(valueOf(steel, "Power"), "x1.00")
		expect.equal(valueOf(steel, "Element"), "None")
		expect.equal(valueOf(steel, "Perk"), nil)
		expect.equal(#WeaponText.stats(Weapons, "nope", nil, Combat), 0)
	end,

	["where a weapon comes from, in words (the Armory's locked cards)"] = function()
		local Bosses = require("../src/shared/Config/Bosses")
		expect.equal(WeaponText.source(Weapons, Bosses, "verdantBlade"), "Drops from the Meadow Warden")
		expect.equal(WeaponText.source(Weapons, Bosses, "prismBlade"), "Drops from the Prism Hydra")
		expect.equal(WeaponText.source(Weapons, Bosses, "forgeSword_Tide"), "Forge: Wild Ore")
		expect.equal(WeaponText.source(Weapons, Bosses, "sunforgedBlade"), "Masterwork: 3 bosses' materials + Star Shards")
		expect.equal(WeaponText.source(Weapons, Bosses, "starterSword"), "Everyone's first sword")
		expect.equal(WeaponText.source(Weapons, Bosses, "tidalTrident"), "Drops from the Frost Tyrant")
		expect.equal(WeaponText.source(Weapons, Bosses, "titansLance"), "Masterwork: 3 bosses' materials + Star Shards")
	end,

	["a material's pickup line shows its progress toward what it's for"] = function()
		expect.equal(WeaponText.pickup("Warden Heartwood", 2, 9, 15), "Warden Heartwood +2 (9/15)")
		expect.equal(WeaponText.pickup("Wild Ore", 1, 3, nil), "Wild Ore +1")
	end,

	-- owner 2026-11-20: "in grading station window. redesign it like the condenser to be easily understood ... do the
	-- same with forge": the Forge's pane is a picture recipe (what goes in as spots, an arrow, the weapon), one
	-- sentence over it and one button with a small line under its words
	["the Forge's recipe: a spot for each material with what you have of what it takes, then the cash"] = function()
		local spots = WeaponText.spots({ cash = 2000, items = { material_meadowWarden = 15, starShard = 1 } }, { material_meadowWarden = 9, starShard = 3 }, 2500, Items)
		expect.equal(#spots, 3)
		expect.equal(spots[1].icon, "WardenHeartwood")
		expect.equal(spots[1].count, "9 / 15")
		expect.equal(spots[1].enough, false)
		expect.equal(spots[2].icon, "Shard")
		expect.equal(spots[2].count, "1 / 1", "never more than it takes")
		expect.equal(spots[2].enough, true)
		expect.equal(spots[3].icon, "Cash")
		expect.equal(spots[3].count, "$2,000")
		expect.equal(spots[3].enough, true)
		local poor = WeaponText.spots({ cash = 25000, items = {} }, {}, 900, Items)
		expect.equal(#poor, 1)
		expect.equal(poor[1].enough, false)
		local free = WeaponText.spots({ cash = 0, items = { mystery = 2 } }, {}, 0, Items)
		expect.equal(#free, 1, "no cash spot for a cost without cash")
		expect.equal(free[1].icon, "", "an unknown item has no picture")
		expect.equal(free[1].count, "0 / 2")
	end,

	["the recipe's spots sit in one row up to three, then in two rows"] = function()
		expect.equal(WeaponText.spotColumns(1), 1)
		expect.equal(WeaponText.spotColumns(2), 2)
		expect.equal(WeaponText.spotColumns(3), 3)
		expect.equal(WeaponText.spotColumns(4), 2)
		expect.equal(WeaponText.spotColumns(5), 3)
		expect.equal(WeaponText.spotColumns(6), 3)
	end,

	["the Forge's one sentence says what goes in and what comes out, or what to get first"] = function()
		local cost = { cash = 2000, items = { material_meadowWarden = 15 } }
		local opts = { name = "Verdant Blade" }
		expect.equal(WeaponText.say("forge", cost, { material_meadowWarden = 15 }, 5000, Items, opts), "Use 15 Warden Heartwood and $2,000 to make the Verdant Blade!")
		expect.equal(WeaponText.say("forge", cost, { material_meadowWarden = 9 }, 5000, Items, opts), "Get 6 more Warden Heartwood to make the Verdant Blade.")
		expect.equal(WeaponText.say("forge", cost, { material_meadowWarden = 15 }, 1500, Items, opts), "Save up $500 more to make the Verdant Blade.")
		expect.equal(WeaponText.say("forge", cost, { material_meadowWarden = 15 }, 5000, Items, { name = "Verdant Blade", unlockLevel = 6, shopLevel = 5 }), "The Forge makes this at shop level 6.")
		-- two kinds of material are both named; more than two are counted (the spots show them)
		local two = { cash = 2000, items = { material_meadowWarden = 15, starShard = 2 } }
		expect.equal(WeaponText.say("forge", two, { material_meadowWarden = 15, starShard = 2 }, 5000, Items, opts), "Use 15 Warden Heartwood, 2 Star Shards and $2,000 to make the Verdant Blade!")
		local many = { cash = 25000, items = { material_meadowWarden = 30, material_caveBroodQueen = 30, material_emberColossus = 30, starShard = 5 } }
		local all = { material_meadowWarden = 30, material_caveBroodQueen = 30, material_emberColossus = 30, starShard = 5 }
		expect.equal(WeaponText.say("forge", many, all, 30000, Items, { name = "Sunforged Blade" }), "Use these 4 materials and $25,000 to make the Sunforged Blade!")
		-- upgrading and reforging
		expect.equal(WeaponText.say("upgrade", { cash = 600, items = { wildOre = 5 } }, { wildOre = 9 }, 9000, Items, { name = "Verdant Blade", level = 4 }), "Use 5 Wild Ore and $600 to make it +4: more Power!")
		expect.equal(WeaponText.say("upgrade", { cash = 1200, items = {} }, {}, 9000, Items, { name = "Verdant Blade", level = 4 }), "Use $1,200 to make it +4: more Power!")
		expect.equal(WeaponText.say("upgrade", { cash = 600, items = { wildOre = 5 } }, { wildOre = 1 }, 9000, Items, { name = "Verdant Blade", level = 4 }), "Get 4 more Wild Ore to make it +4.")
		expect.equal(WeaponText.say("upgrade", nil, {}, 9000, Items, { name = "Verdant Blade" }), "It is +10: fully upgraded!")
		expect.equal(WeaponText.say("reforge", { cash = 750, items = { wildOre = 10 } }, { wildOre = 10 }, 9000, Items, { name = "Fire Forge Sword" }), "Use 10 Wild Ore and $750 to roll a new grade. You keep the better one!")
		expect.equal(WeaponText.say("reforge", { cash = 750, items = {} }, {}, 100, Items, { name = "Fire Forge Sword" }), "Save up $650 more to roll a new grade.")
		expect.equal(WeaponText.say("reforge", { cash = 750, items = {} }, {}, 9000, Items, { name = "Fire Forge Sword", done = true }), "Grade S is the best grade: nothing to reforge!")
	end,

	["the Forge's one button: what it does and how long it takes, or what's missing and what you have"] = function()
		local cost = { cash = 2000, items = { material_meadowWarden = 15 } }
		local text, sub, ready = WeaponText.recipeButton("forge", cost, { material_meadowWarden = 9 }, 5000, Items, {})
		expect.equal(text, "Need 6 more Warden Heartwood")
		expect.equal(sub, "you have 9")
		expect.equal(ready, false)
		text, sub, ready = WeaponText.recipeButton("forge", cost, { material_meadowWarden = 15 }, 1500, Items, { wait = "2 minutes" })
		expect.equal(text, "Need $500 more")
		expect.equal(sub, "you have $1,500", "what's missing says no time")
		expect.equal(ready, false)
		text, sub, ready = WeaponText.recipeButton("forge", cost, { material_meadowWarden = 20 }, 2000, Items, { wait = "2 minutes" })
		expect.equal(text, "Forge it!")
		expect.equal(sub, "takes 2 minutes")
		expect.equal(ready, true)
		text, sub = WeaponText.recipeButton("forge", cost, { material_meadowWarden = 20 }, 2000, Items, {})
		expect.equal(sub, nil, "no wait known: its words alone")
		expect.equal((WeaponText.recipeButton("upgrade", { cash = 1200, items = {} }, {}, 9000, Items, { level = 4 })), "Make it +4!")
		expect.equal((WeaponText.recipeButton("reforge", { cash = 1000, items = {} }, {}, 9000, Items, {})), "Roll a new grade!")
		text, sub, ready = WeaponText.recipeButton("upgrade", nil, {}, 9000, Items, {})
		expect.equal(text, "Fully upgraded")
		expect.equal(ready, false)
		text, sub, ready = WeaponText.recipeButton("reforge", { cash = 1000, items = {} }, {}, 9000, Items, { done = true })
		expect.equal(text, "Already Grade S")
		expect.equal(ready, false)
		text, sub, ready = WeaponText.recipeButton("forge", { cash = 1500, items = {} }, {}, 9000, Items, { unlockLevel = 6, shopLevel = 5 })
		expect.equal(text, "Opens at shop level 6")
		expect.equal(ready, false)
	end,

	["under the Forge's weapon: what comes out, in a pill and a line"] = function()
		local pill, line = WeaponText.outcome("forge", {})
		expect.equal(pill, "Grade C to S")
		expect.equal(line, "It comes out at a random grade, like a card. S is the best!")
		pill, line = WeaponText.outcome("upgrade", { level = 4, step = "Its aura appears!" })
		expect.equal(pill, "+4")
		expect.equal(line, "Its aura appears!")
		pill, line = WeaponText.outcome("upgrade", { level = 10, max = true })
		expect.equal(pill, "+10")
		expect.equal(line, "Awakened!")
		pill, line = WeaponText.outcome("reforge", { grade = "B" })
		expect.equal(pill, "Grade B")
		expect.equal(line, "A new roll, C to S. It never gets worse!")
		pill, line = WeaponText.outcome("reforge", { grade = "S", done = true })
		expect.equal(pill, "Grade S")
		expect.equal(line, nil)
		expect.equal(WeaponText.powerGain(1.4, 1.44), "+0.04 Power")
		expect.equal(WeaponText.powerGain(1.25, 1.25), "+0.00 Power")
	end,

	["what each upgrade adds to the glow (the forge reveal's line), by rarity"] = function()
		local Looks = require("../src/shared/Config/WeaponLooks")
		expect.equal(WeaponText.ladderStep(Looks, 1, "Rare"), "It glows brighter")
		expect.equal(WeaponText.ladderStep(Looks, 3, "Rare"), "It glows brighter")
		expect.equal(WeaponText.ladderStep(Looks, 4, "Rare"), "Its aura appears!")
		expect.equal(WeaponText.ladderStep(Looks, 2, "Epic"), "Its aura appears!", "Epic and Legendary start at +2")
		expect.equal(WeaponText.ladderStep(Looks, 2, "Rare"), "It glows brighter")
		expect.equal(WeaponText.ladderStep(Looks, 6, "Rare"), "A stronger aura")
		expect.equal(WeaponText.ladderStep(Looks, 7, "Rare"), "The full blaze, a bigger trail and a burst on every hit!")
		expect.equal(WeaponText.ladderStep(Looks, 9, "Rare"), "A bigger trail")
		expect.equal(WeaponText.ladderStep(Looks, 10, "Legendary"), "AWAKENED! Flames stream off it")
	end,

	["the Forge window's tab lines say what each tab does (owner's pick A, 2026-11-08)"] = function()
		expect.equal(WeaponText.tabLine("Forge"), "Make a weapon you don't have yet. You pay its materials and cash; it comes out at a random grade, C to S (like a card).")
		expect.equal(WeaponText.tabLine("Upgrade"), "Level a weapon you own up, +0 to +10: more Power and a brighter glow each level. Never fails. +5 and +10 also need Star Shards.")
		expect.equal(WeaponText.tabLine("Reforge"), "Roll a new grade for half the making cost. You keep the better grade, so it never gets worse. Grade S can't be reforged.")
	end,

	-- Weapons round 3 (spec 4): the scythes' perks in words
	["the scythes' perks in words"] = function()
		expect.equal(valueOf(WeaponText.stats(Weapons, "widowsReaper", nil, Combat), "Perk"), "Poisons the foe for 3 s")
		expect.equal(valueOf(WeaponText.stats(Weapons, "stormReaper", nil, Combat), "Perk"), "Every 4th hit strikes for 40% more and arcs to other foes for 30%")
		expect.equal(valueOf(WeaponText.stats(Weapons, "riftReaper", nil, Combat), "Perk"), "Hits deal 30% more to foes under 30% HP")
	end,

	-- The weapon window (Armory UI, owner's pick A 2026-11-09): Power against what you hold, signed
	["versus: this weapon's Power against the equipped one's, signed, to 2 decimals"] = function()
		local maxed = { grade = "S", level = 10 }
		local better = WeaponText.versus(Weapons, Combat, "titansLance", maxed, "starterSword", nil)
		assert(better, "a known pair compares")
		expect.equal(better.text, "+0.79 vs Steel Sword")
		expect.equal(better.sign, 1)
		local worse = WeaponText.versus(Weapons, Combat, "starterSword", nil, "titansLance", maxed)
		assert(worse)
		expect.equal(worse.text, "-0.79 vs Titan's Lance")
		expect.equal(worse.sign, -1)
		local held = WeaponText.versus(Weapons, Combat, "titansLance", maxed, "titansLance", maxed)
		assert(held)
		expect.equal(held.text, "Equipped now")
		expect.equal(held.sign, 0)
		local even = WeaponText.versus(Weapons, Combat, "forgeSword_Ember", nil, "forgeSword_Tide", nil)
		assert(even)
		expect.equal(even.text, "Same Power as Water Forge Sword")
		expect.equal(even.sign, 0)
		expect.equal(WeaponText.versus(Weapons, Combat, "titansLance", maxed, "nope", nil), nil, "an unknown weapon compares to nothing")
	end,

	["powerRange: Grade C at +0 to Grade S at the top level, one number when they match"] = function()
		expect.equal(WeaponText.powerRange(Weapons, Combat, "riftReaper"), "x1.21 to x2.09")
		expect.equal(WeaponText.powerRange(Weapons, Combat, "starterSword"), "x1.00")
		expect.equal(WeaponText.powerRange(Weapons, Combat, "nope"), "")
	end,

	["howToGet: the boss and where it lives, then how the forge makes it"] = function()
		local rift = WeaponText.howToGet(Weapons, Bosses, "riftReaper")
		expect.equal(rift.drop, "Beat the Rift Devourer in the Frontier: it can drop.")
		expect.equal(rift.forge, "Or forge it:")
		expect.equal(WeaponText.howToGet(Weapons, Bosses, "widowsReaper").drop, "Beat the Cave Brood Queen in the Wild: it can drop.")
		local forged = WeaponText.howToGet(Weapons, Bosses, "forgeScythe_Ember")
		expect.equal(forged.drop, nil)
		expect.equal(forged.forge, "Forge it at the Forge in your shop:")
		local masterwork = WeaponText.howToGet(Weapons, Bosses, "titansLance")
		expect.equal(masterwork.drop, nil)
		expect.equal(masterwork.forge, "A masterwork. Forge it at the Forge in your shop:")
		local steel = WeaponText.howToGet(Weapons, Bosses, "starterSword")
		expect.equal(steel.drop, nil, "everyone has the Steel Sword")
		expect.equal(steel.forge, nil)
	end,

	["howToGet: a Dungeon boss is at the end of the Dungeon run"] = function()
		local bosses = { BOSSES = { prismHydra = { name = "Prism Hydra", place = "Dungeon" } } }
		local cfg = { ById = { test = { id = "test", source = { kind = "boss", boss = "prismHydra" } } } }
		expect.equal(WeaponText.howToGet(cfg, bosses, "test").drop, "Beat the Prism Hydra at the end of the Dungeon: it can drop.")
	end,

	["progress: each material's have/need sorted by id, then the cash"] = function()
		local rows = WeaponText.progress({ cash = 30000, items = { material_riftDevourer = 60, starShard = 2 } }, { material_riftDevourer = 12 }, 40000, Items)
		expect.equal(#rows, 3)
		expect.equal(rows[1].icon, "RiftShard")
		expect.equal(rows[1].name, "Rift Shard")
		expect.equal(rows[1].have, 12)
		expect.equal(rows[1].need, 60)
		expect.equal(rows[1].text, "12/60")
		expect.equal(rows[2].name, "Star Shard")
		expect.equal(rows[2].text, "0/2", "none yet")
		expect.equal(rows[3].icon, "Cash")
		expect.equal(rows[3].name, "Cash")
		expect.equal(rows[3].text, "$30,000")
		expect.equal(rows[3].have, 40000)
		expect.equal(rows[3].need, 30000)
		expect.equal(#WeaponText.progress({ cash = 0, items = {} }, {}, 0, Items), 0, "a free cost has no rows")
	end,

	["skill: a weapon's own sword skill by its moveset, else the dash slash (named in words, not capitals)"] = function()
		local lance = WeaponText.skill(CombatHud, Weapons, "titansLance")
		expect.equal(lance.name, "Titan's Wrath")
		expect.equal(lance.icon, "LanceLeaves")
		expect.equal(lance.text, CombatHud.SKILLS.titansLance.tip)
		expect.equal(WeaponText.skill(CombatHud, Weapons, "widowsReaper").name, "Reaping Cyclone")
		expect.equal(WeaponText.skill(CombatHud, Weapons, "riftReaper").name, "Thousand Cuts")
		local steel = WeaponText.skill(CombatHud, Weapons, "starterSword")
		expect.equal(steel.name, "Dash")
		expect.equal(steel.icon, CombatHud.BUTTONS.skill.icon)
		for _, weapon in Weapons.WEAPONS do
			local skill = WeaponText.skill(CombatHud, Weapons, weapon.id)
			assert(skill.name ~= "" and skill.text ~= "", `{weapon.id} has a skill in words`)
		end
	end,

	["bond: what sharing its element with your creature gives, from Config/Weapons BOND"] = function()
		expect.equal(WeaponText.bond(Weapons, "titansLance"), "+15% hits and a 50% faster super with Nature creatures")
		expect.equal(WeaponText.bond(Weapons, "prismBlade"), "+15% hits and a 50% faster super with every creature")
		expect.equal(WeaponText.bond(Weapons, "starterSword"), nil, "no element, no bond")
	end,

	-- the dial's name under its title (owner 2026-11-14 pick C): the upgrade level and the element, in plain words
	["the weapon switch's line: upgrade level and element"] = function()
		expect.equal(WeaponText.switchLine(Weapons, "verdantBlade", { grade = "A", level = 4 }), "+4 · Nature")
		expect.equal(WeaponText.switchLine(Weapons, "forgeSword_Ember", { grade = "C", level = 0 }), "Fire", "+0 is left out")
		expect.equal(WeaponText.switchLine(Weapons, "prismBlade", { grade = "S", level = 10 }), "+10 · Every element")
		expect.equal(WeaponText.switchLine(Weapons, "starterSword", nil), "", "no element, not upgraded: nothing")
		expect.equal(WeaponText.switchLine(Weapons, "nope", nil), "")
	end,
	-- A boss material's line on its chest card and pick-up card (owner 2026-11-16 saw "84/4 for Verdant Blade": the 4
	-- was the next upgrade's cost of a sword already owned)
	-- in simpler words (owner 2026-11-20, of "Enough to make the Sunforged Blade!": "update description in a more simple
	-- terms"): how many more to get, or that you can make it now. No fractions
	["a material's goal line says make or upgrade, how many more to get, and when you can"] = function()
		expect.equal(WeaponText.goalLine(9, 15, "Verdant Blade", false), "Get 6 more to make the Verdant Blade")
		expect.equal(WeaponText.goalLine(3, 4, "Verdant Blade", true), "Get 1 more to upgrade the Verdant Blade")
		expect.equal(WeaponText.goalLine(84, 4, "Verdant Blade", true), "You can upgrade the Verdant Blade now!")
		expect.equal(WeaponText.goalLine(15, 15, "Verdant Blade", false), "You can make the Verdant Blade now!")
		expect.equal(WeaponText.goalLine(1, 1, "Sunforged Blade", false), "You can make the Sunforged Blade now!")
	end,
}

