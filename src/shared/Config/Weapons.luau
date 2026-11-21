--!strict
-- Weapons (spec 2026-11-06-weapons-round1-design): every weapon in the Armory's order, what makes it (the Forge, a
-- boss, a Masterwork recipe) and the numbers behind Power, grades, upgrades, the element bond, perks, costs and drops
-- (Util/WeaponRules). Three families with their own moves: swords now (round 1), spears and scythes later
-- (`ready = false`: listed as "Coming soon"). Plain data so Lune tests can load it.

-- the elements' plain names for the Forge weapons' names (owner 2026-11-12: "Fire Forge Sword"); by path in Lune
local ElementNames = if game ~= nil
	then require((script.Parent :: Instance):WaitForChild("ElementNames")) :: any
	else require("./ElementNames") :: any

export type Cost = { cash: number, items: { [string]: number }, unlockLevel: number? }
export type Source = { kind: string, boss: string?, cost: Cost? } -- kind: "starter" | "forge" | "boss" | "masterwork"
-- kind: "heal" | "burn" | "prism" | "erupt" | "chill" (BattleSim swordPerk)
export type Perk = { kind: string, every: number?, share: number?, seconds: number? }
export type Weapon = {
	id: string,
	name: string,
	family: string, -- "sword" | "spear" | "scythe"
	rarity: string,
	element: string?, -- a card element (Ember, Tide, Bloom, Volt, Shade); nil: none (the Steel Sword)
	prism: boolean?, -- every element at once (the Prism Blade)
	ready: boolean, -- built: forgeable and drawn; false: "Coming soon" in the Armory
	moveset: string?, -- its moves: a Config/Swords entry
	power: number?, -- its own base Power, replacing its rarity's (the Prism Blade: its perks are its edge)
	model: string?, -- ReplicatedStorage.WeaponModels child
	source: Source,
	perk: Perk?,
}

local MATERIALS = {
	meadowWarden = "material_meadowWarden",
	caveBroodQueen = "material_caveBroodQueen",
	emberColossus = "material_emberColossus",
	frostTyrant = "material_frostTyrant",
	stormSovereign = "material_stormSovereign",
	riftDevourer = "material_riftDevourer",
	prismHydra = "material_prismHydra",
}
local WILD_ORE = "wildOre"

-- A Forge weapon in every element: $1,500 and 20 Wild Ore, from shop level 6
local FORGE_COST: Cost = { cash = 1500, items = { [WILD_ORE] = 20 }, unlockLevel = 6 }
local ELEMENTS = { "Ember", "Tide", "Bloom", "Volt", "Shade" }
-- Your first Forge weapon (owner 2026-11-19, "do all"): supers need a weapon of the creature's element, and at the
-- full price a first one was about an hour and a half in ($1,500 at a new shop's $1,550 an hour, 20 Wild Ore at 15% a
-- monster). At this price it's about half an hour: 8 ore is some 50 monsters. One time: every Forge weapon after it,
-- and every reforge, costs the full price (WeaponRules.makeCost with what's owned, firstForge).
local FIRST_FORGE_COST: Cost = { cash = 500, items = { [WILD_ORE] = 8 }, unlockLevel = 6 }

local WEAPONS: { Weapon } = {
	{
		id = "starterSword",
		name = "Steel Sword",
		family = "sword",
		rarity = "Common",
		ready = true,
		moveset = "starterSword",
		model = "StarterSword",
		source = { kind = "starter" },
	},
}
for _, element in ELEMENTS do
	table.insert(WEAPONS, {
		id = `forgeSword_{element}`,
		name = `{ElementNames[element]} Forge Sword`,
		family = "sword",
		rarity = "Common",
		element = element,
		ready = true,
		moveset = "forgeSword",
		model = `ForgeSword_{element}`,
		source = { kind = "forge", cost = FORGE_COST },
	})
end
local REST: { Weapon } = {
	{
		id = "verdantBlade",
		name = "Verdant Blade",
		family = "sword",
		rarity = "Rare",
		element = "Bloom",
		ready = true,
		moveset = "verdantBlade",
		model = "VerdantBlade",
		source = { kind = "boss", boss = "meadowWarden" },
		perk = { kind = "heal", every = 4, share = 0.02 }, -- every 4th hit heals your creature 2% of its max HP
	},
	{
		id = "sunforgedBlade",
		name = "Sunforged Blade",
		family = "sword",
		rarity = "Epic",
		element = "Ember",
		ready = true,
		moveset = "sunforgedBlade",
		model = "SunforgedBlade",
		source = {
			kind = "masterwork",
			cost = {
				cash = 15000, -- $25,000 until 2026-11-20 (the Forge's top costs down 40%, below at BOSS_COST)
				items = { [MATERIALS.emberColossus] = 20, [MATERIALS.meadowWarden] = 10, [MATERIALS.caveBroodQueen] = 10, starShard = 5 },
			},
		},
		perk = { kind = "burn", share = 0.03, seconds = 3 }, -- 3% of your creature's ATK a second for 3 s, refreshed
	},
	{
		id = "prismBlade",
		name = "Prism Blade",
		family = "sword",
		rarity = "Legendary",
		prism = true,
		ready = true,
		moveset = "prismBlade",
		model = "PrismBlade",
		source = { kind = "boss", boss = "prismHydra" },
		-- Always strong (x1.5) and bonded with any creature (x1.15) makes it about 1.7 against every foe at +0; its own
		-- base keeps +10 Grade S inside the Hydra's balance limit (spec 4.6; DESIGN.md weapons balance rows)
		power = 0.87, -- 1 until 2026-11-21 (the Power moved into the upgrades: RARITY_POWER below)
		perk = { kind = "prism" }, -- always strong against the foe's element
	},
}
for _, weapon in REST do
	table.insert(WEAPONS, weapon)
end
-- Round 2: spears (spec 2026-11-07-weapons-round2-design 4), all swinging the spear moveset (Config/Swords), built
-- with their models (2026-11-07). The Forge Spear in every element, like the Forge Sword.
for _, element in ELEMENTS do
	table.insert(WEAPONS, {
		id = `forgeSpear_{element}`,
		name = `{ElementNames[element]} Forge Spear`,
		family = "spear",
		rarity = "Common",
		element = element,
		ready = true,
		moveset = "spear",
		model = `ForgeSpear_{element}`,
		source = { kind = "forge", cost = FORGE_COST },
	})
end
REST = {
	{
		id = "magmaHalberd",
		name = "Magma Halberd",
		family = "spear",
		rarity = "Very Rare",
		element = "Ember",
		ready = true,
		moveset = "magmaHalberd", -- the spear's cuts, its own skill: Magma Cleave
		model = "MagmaHalberd",
		source = { kind = "boss", boss = "emberColossus" },
		perk = { kind = "erupt", every = 5, share = 0.6 }, -- every 5th hit bursts for 60% of that hit more
	},
	{
		id = "tidalTrident",
		name = "Tidal Trident",
		family = "spear",
		rarity = "Epic",
		element = "Tide",
		ready = true,
		moveset = "tidalTrident", -- the spear's cuts, its own skill: Torrent Strike
		model = "TidalTrident",
		source = { kind = "boss", boss = "frostTyrant" },
		perk = { kind = "chill", share = 0.1, seconds = 3 }, -- the foe's attacks 10% slower for 3 s, refreshed
	},
	{
		id = "titansLance",
		name = "Titan's Lance",
		family = "spear",
		rarity = "Legendary",
		element = "Bloom",
		ready = true,
		moveset = "titansLance", -- the spear's cuts, its own skill: Titan's Wrath
		model = "TitansLance",
		-- my call (spec 4): about the Prism Blade's two weeks, from three bosses' materials, Star Shards and cash
		source = {
			kind = "masterwork",
			cost = {
				cash = 36000, -- $60,000 until 2026-11-20 (owner: "60k in our current economy takes too long to achieve")
				items = { [MATERIALS.meadowWarden] = 30, [MATERIALS.frostTyrant] = 20, [MATERIALS.stormSovereign] = 20, starShard = 10 },
			},
		},
		-- its own base Power and a heal every 4th hit (tools/balance/bosses on the Prism Hydra: at the Legendary 1.8 with a
		-- heal on every hit a 0.8x party won 100% even at +0; this: +0 C 72%, +10 S 83%, a 1x fight 75% of the Steel
		-- Sword's; DESIGN.md weapons balance rows)
		power = 1.04, -- 1.2 until 2026-11-21 (the Power moved into the upgrades; +10 as before)
		perk = { kind = "heal", every = 4, share = 0.01 }, -- every 4th hit heals your creature 1% of its max HP
	},
}
for _, weapon in REST do
	table.insert(WEAPONS, weapon)
end
-- Round 3: scythes (spec 2026-11-09-weapons-round3-scythes-design 4), all swinging the scythe moveset (Config/Swords),
-- ready since their models are in (plan Task 5). The Forge Scythe in every element, like the Forge Sword and Spear.
for _, element in ELEMENTS do
	table.insert(WEAPONS, {
		id = `forgeScythe_{element}`,
		name = `{ElementNames[element]} Forge Scythe`,
		family = "scythe",
		rarity = "Common",
		element = element,
		ready = true,
		moveset = "scythe",
		model = `ForgeScythe_{element}`,
		source = { kind = "forge", cost = FORGE_COST },
	})
end
REST = {
	{
		id = "widowsReaper",
		name = "Widow's Reaper",
		family = "scythe",
		rarity = "Very Rare",
		element = "Shade",
		ready = true,
		moveset = "scythe",
		model = "WidowsReaper",
		source = { kind = "boss", boss = "caveBroodQueen" },
		-- Venom: the Sunforged Blade's burn as poison, 2.5% of your creature's ATK a second for 3 s, refreshed
		perk = { kind = "burn", share = 0.025, seconds = 3, look = "venom" },
	},
	{
		id = "stormReaper",
		name = "Storm Reaper",
		family = "scythe",
		rarity = "Epic",
		element = "Volt",
		ready = true,
		moveset = "scythe",
		model = "StormReaper",
		source = { kind = "boss", boss = "stormSovereign" },
		-- Chain Lightning: every 4th hit a bolt on the target for 40% more, arcing to every other foe for 30%
		perk = { kind = "chain", every = 4, share = 0.4, spread = 0.3 },
	},
	{
		id = "riftReaper",
		name = "Rift Reaper",
		family = "scythe",
		rarity = "Legendary",
		element = "Shade",
		ready = true,
		moveset = "riftReaper", -- its own skill, Thousand Cuts (Config/Swords)
		model = "RiftReaper",
		source = { kind = "boss", boss = "riftDevourer" },
		-- its own base Power, as the Prism Blade's and the Titan's Lance's (tools/balance/bosses on the Prism Hydra, 200
		-- fights: at the Legendary 1.8 a 0.8x party won 92% at +10 Grade S; at 1.4 +0 C 68%, +10 S 84%, a 1x fight 70%
		-- of the Steel Sword's; DESIGN.md weapons balance rows)
		power = 1.21, -- 1.4 until 2026-11-21 (the Power moved into the upgrades; +10 as before)
		-- Reap: 30% more damage to a foe under 30% of its HP
		perk = { kind = "execute", below = 0.3, share = 0.3 },
	},
}
for _, weapon in REST do
	table.insert(WEAPONS, weapon)
end

local ById: { [string]: Weapon } = {}
for _, weapon in WEAPONS do
	ById[weapon.id] = weapon
end

return {
	WEAPONS = WEAPONS,
	ById = ById,
	STARTER = "starterSword",
	STARTER_POWER = 1, -- the Steel Sword's Power: today's sword hits
	-- Power = rarity's base (or the weapon's own) x grade x (1 + UPGRADE_STEP x level). Tuned with tools/balance/bosses
	-- WEAPON (spec 4.6: no weapon lets a party at 0.8x the recommended Power win more than 85% fighting well on its
	-- tier boss, and +10 Grade S never more than halves a fight at 1x); the spec's starting numbers (1.15 / 1.35 / 1.55
	-- / 1.8 / 2.1, +5% a level) broke both (DESIGN.md weapons balance rows)
	-- Easier to get, the Power in the upgrades (owner 2026-11-21: "up the weapons drop rate ... but increase the grind
	-- to upgrade it", option B: "players dont want to hold on for the same weapon for too long"): a weapon drops weaker
	-- (1.15 / 1.25 / 1.4 / 1.6 / 1.8 before) and gains 5% a level (3% before), so at +10 it is what it was (the old
	-- base x 1.3; a Common 5% over, never under the Steel Sword at +0). tools/balance/bosses: a +10 Grade S Forge Sword
	-- on the Meadow Warden 62 s, 64 s before; every other weapon is at or under its old Power at every level
	RARITY_POWER = { Common = 1.05, Rare = 1.1, ["Very Rare"] = 1.22, Epic = 1.39, Legendary = 1.56 },
	GRADE_POWER = { C = 1, B = 1.05, A = 1.1, S = 1.15 },
	UPGRADE_STEP = 0.05,
	MAX_LEVEL = 10,
	-- Your summoned creature shares the weapon's element (the Prism Blade: any): weapon hits x damage, the super meter's
	-- fill from sword hits x meter
	BOND = { damage = 1.15, meter = 1.5 },
	-- Supers need a weapon (owner 2026-11-19: "only epics and legendary super skills locked until you have same element
	-- weapon", "weapon strength: OK"; WeaponRules.superUnlocked / superScale): a weapon of the creature's element (the
	-- Prism Blade: any) unlocks its super, and the super fires `share` of the way from the Steel Sword's Power to the
	-- weapon's (Config/Combat SUPER_SCALES: which of its numbers grow). Tuned with tools/balance/bosses.
	SUPER = { share = 0.5, lockedTitle = "Super locked" },
	PERK_S = 1.2, -- a Grade S weapon's perk number x this
	-- A boss weapon: its boss's material and cash by rarity. The top costs came down 40% on 2026-11-20 (owner: "lower
	-- the forging cost a bit. 60k in our current economy takes too long to achieve", his pick of three options): Epic
	-- $12,000 -> $8,000, Legendary $30,000 -> $18,000, the masterworks $25,000 -> $15,000 and $60,000 -> $36,000 (a
	-- shop earns about $700-1,550 an hour from packs). Materials as before; a reforge is still half of making
	BOSS_COST = {
		Rare = { material = 15, cash = 2000 },
		["Very Rare"] = { material = 25, cash = 5000 },
		Epic = { material = 40, cash = 8000 },
		Legendary = { material = 60, cash = 18000 },
	},
	REFORGE_SHARE = 0.5, -- a reforge (a new grade roll, the better kept) costs this share of making it, rounded up
	DUPLICATE_MATERIAL = 10, -- a boss dropping a weapon you own gives this many of its material instead
	-- A boss's own weapon dropping outright on a full-loot kill: `base`, plus `step` for every full-loot kill since without
	-- one (pity). By rarity (owner 2026-11-06), median loot wins: Rare 15, Very Rare 25, Epic 50, Legendary 79 (set for 6
	-- a day; since 2026-11-19 there's no daily limit, one every LOOT_COOLDOWN: about 2 / 3 / 6 / 9 hours on its boss)
	-- Rare and Very Rare much sooner since 2026-11-21 (owner: "make it easier for the players to get their hands on
	-- one", "epic/legendary weapons should still be hard to get"): median 6 and 10 loot wins (15 and 25 before; 1% +
	-- 0.5% and 0.5% + 0.2%), a Wild boss's 5 and 8; Epic and Legendary as they were
	-- Then all four again that evening (owner 2026-11-21: "increase epic weapon drop rate to 12% then legendaries to 6.
	-- if thats fair"; his pick of three: those two as asked, and Rare and Very Rare raised so rarer is still slower and
	-- the boss board's "Drop chance now" goes down with rarity): median 3 / 4 / 6 / 11 loot wins, about 20, 30, 40 and
	-- 80 minutes on that boss (6 / 10 / 22 / 37 before: 6% + 2.5%, 3% + 1%, 1% + 0.2%, 0.5% + 0.08%). A weapon is quick
	-- to get; the grind is its upgrade (UPGRADE.material). A duplicate's 10 materials come more often too: about 2.6,
	-- 1.9, 1.3 and 0.7 a loot win on top of the loot's own 1.2
	DROP = {
		Rare = { base = 0.2, step = 0.025 },
		["Very Rare"] = { base = 0.15, step = 0.01 },
		Epic = { base = 0.12, step = 0.002 },
		Legendary = { base = 0.06, step = 0.0008 },
	},
	-- The Wild's three bosses drop their weapons a little more often (owner 2026-11-20: "slightly increase weapon
	-- droprate on wild bosses only"): their chance times DROP_WILD (median loot wins about 12 / 19 / 39 instead of
	-- 15 / 25 / 50). The Frontier's and the Dungeon's are as above (tests/WeaponRules checks the list against
	-- Config/Bosses' places)
	DROP_WILD = 1.3,
	WILD_BOSSES = { meadowWarden = true, caveBroodQueen = true, emberColossus = true } :: { [string]: boolean },
	ANNOUNCE = { Epic = true, Legendary = true }, -- a dropped weapon of these rarities is announced to the server
	-- Upgrades +1..+10: cash x the rarity's share and the weapon's material (Forge weapons: Wild Ore), Star Shards at +5
	-- and +10. They never fail.
	UPGRADE = {
		cash = { 500, 1000, 1500, 2500, 4000, 6000, 8500, 12000, 16000, 22000 },
		material = { 4, 4, 6, 6, 8, 10, 12, 14, 16, 20 }, -- 100 in all: twice what it was until 2026-11-21 (the grind is the upgrade)
		starShards = { [5] = 1, [10] = 3 },
		rarityCash = { Common = 0.5, Rare = 0.8, ["Very Rare"] = 1, Epic = 1.3, Legendary = 1.6 },
	},
	FIRST_FORGE = { cash = FIRST_FORGE_COST.cash, items = FIRST_FORGE_COST.items, unlockLevel = FIRST_FORGE_COST.unlockLevel, line = "Your first Forge weapon: special price!" },
	MATERIALS = MATERIALS, -- each boss's weapon material (Config/Items)
	WILD_ORE = WILD_ORE,
	FORGE_UNLOCK_LEVEL = 6,
	EQUIP_COOLDOWN = 0.5, -- seconds between Equip requests (WeaponService)
	EQUIP_SEND_SLACK = 0.1, -- the switch chip sends no sooner than the cooldown plus this, so a send isn't dropped
	FORGE_COOLDOWN = 1, -- seconds between Forge, Upgrade and Reforge requests (ForgeService)
	FORGE_DISTANCE = 12, -- studs from your own Forge machine
	REQUEST_COOLDOWN = 1, -- seconds between a client's asks for its weapons
	-- The boss each round-1 weapon is balanced against (tools/balance/bosses WEAPON)
	TIER_BOSS = {
		forgeSword = "meadowWarden",
		verdantBlade = "caveBroodQueen",
		sunforgedBlade = "frostTyrant",
		prismBlade = "prismHydra",
		-- the spears (spec 2026-11-07-weapons-round2-design 4): the swords' tiers by rarity
		forgeSpear = "meadowWarden",
		magmaHalberd = "emberColossus",
		tidalTrident = "frostTyrant",
		titansLance = "prismHydra",
		-- the scythes (spec 2026-11-09-weapons-round3-scythes-design 4): the same tiers by rarity
		forgeScythe = "meadowWarden",
		widowsReaper = "emberColossus",
		stormReaper = "frostTyrant",
		riftReaper = "prismHydra",
	},
	-- A weapon switched in a fight (the quick switch, spec 2026-11-07-weapons-round2-design 6): this long with no cut or
	-- skill (the dodge still works)
	SWAP_SECONDS = 1,
	-- The quick switch's key for the weapon before (Q is the next; owner 2026-11-09: "Add a previous button to weapon
	-- quick switch"), an Enum.KeyCode name, shown on its < button
	PREVIOUS_KEY = "Z",
}
