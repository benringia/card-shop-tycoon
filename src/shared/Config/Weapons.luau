--!strict
-- Weapons (spec 2026-11-06-weapons-round1-design): every weapon in the Armory's order, what makes it (the Forge, a
-- boss, a Masterwork recipe) and the numbers behind Power, grades, upgrades, the element bond, perks, costs and drops
-- (Util/WeaponRules). Three families with their own moves: swords now (round 1), spears and scythes later
-- (`ready = false`: listed as "Coming soon"). Plain data so Lune tests can load it.

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
		name = `{element} Forge Sword`,
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
				cash = 25000,
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
		power = 1,
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
		name = `{element} Forge Spear`,
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
				cash = 60000,
				items = { [MATERIALS.meadowWarden] = 30, [MATERIALS.frostTyrant] = 20, [MATERIALS.stormSovereign] = 20, starShard = 10 },
			},
		},
		-- its own base Power and a heal every 4th hit (tools/balance/bosses on the Prism Hydra: at the Legendary 1.8 with a
		-- heal on every hit a 0.8x party won 100% even at +0; this: +0 C 72%, +10 S 83%, a 1x fight 75% of the Steel
		-- Sword's; DESIGN.md weapons balance rows)
		power = 1.2,
		perk = { kind = "heal", every = 4, share = 0.01 }, -- every 4th hit heals your creature 1% of its max HP
	},
	-- Round 3: scythes
	{ id = "forgeScythe", name = "Forge Scythe", family = "scythe", rarity = "Common", ready = false, source = { kind = "forge", cost = FORGE_COST } },
	{ id = "widowsReaper", name = "Widow's Reaper", family = "scythe", rarity = "Very Rare", element = "Shade", ready = false, source = { kind = "boss", boss = "caveBroodQueen" } },
	{ id = "stormReaper", name = "Storm Reaper", family = "scythe", rarity = "Epic", element = "Volt", ready = false, source = { kind = "boss", boss = "stormSovereign" } },
	{ id = "riftReaper", name = "Rift Reaper", family = "scythe", rarity = "Legendary", element = "Shade", ready = false, source = { kind = "boss", boss = "riftDevourer" } },
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
	RARITY_POWER = { Common = 1.15, Rare = 1.25, ["Very Rare"] = 1.4, Epic = 1.6, Legendary = 1.8 },
	GRADE_POWER = { C = 1, B = 1.05, A = 1.1, S = 1.15 },
	UPGRADE_STEP = 0.03,
	MAX_LEVEL = 10,
	-- Your summoned creature shares the weapon's element (the Prism Blade: any): weapon hits x damage, the super meter's
	-- fill from sword hits x meter
	BOND = { damage = 1.15, meter = 1.5 },
	PERK_S = 1.2, -- a Grade S weapon's perk number x this
	-- A boss weapon: its boss's material and cash by rarity
	BOSS_COST = {
		Rare = { material = 15, cash = 2000 },
		["Very Rare"] = { material = 25, cash = 5000 },
		Epic = { material = 40, cash = 12000 },
		Legendary = { material = 60, cash = 30000 },
	},
	REFORGE_SHARE = 0.5, -- a reforge (a new grade roll, the better kept) costs this share of making it, rounded up
	DUPLICATE_MATERIAL = 10, -- a boss dropping a weapon you own gives this many of its material instead
	-- A boss's own weapon dropping outright on a full-loot kill: `base`, plus `step` for every full-loot kill since without
	-- one (pity). By rarity (owner 2026-11-06), median kills at 6 a day: Rare 15 (2.5 days), Very Rare 25, Epic 50 (about
	-- a week), Legendary 79 (about 2 weeks, like forging it)
	DROP = {
		Rare = { base = 0.01, step = 0.005 },
		["Very Rare"] = { base = 0.005, step = 0.002 },
		Epic = { base = 0.002, step = 0.0005 },
		Legendary = { base = 0.001, step = 0.0002 },
	},
	ANNOUNCE = { Epic = true, Legendary = true }, -- a dropped weapon of these rarities is announced to the server
	-- Upgrades +1..+10: cash x the rarity's share and the weapon's material (Forge weapons: Wild Ore), Star Shards at +5
	-- and +10. They never fail.
	UPGRADE = {
		cash = { 500, 1000, 1500, 2500, 4000, 6000, 8500, 12000, 16000, 22000 },
		material = { 2, 2, 3, 3, 4, 5, 6, 7, 8, 10 },
		starShards = { [5] = 1, [10] = 3 },
		rarityCash = { Common = 0.5, Rare = 0.8, ["Very Rare"] = 1, Epic = 1.3, Legendary = 1.6 },
	},
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
	},
	-- A weapon switched in a fight (the quick switch, spec 2026-11-07-weapons-round2-design 6): this long with no cut or
	-- skill (the dodge still works)
	SWAP_SECONDS = 1,
}
