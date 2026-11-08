--!strict
-- The weapons catalogue (spec 2026-11-06-weapons-round1-design): every weapon, its look, the boss materials and Wild
-- Ore, and the approved pace
local Weapons = require("../src/shared/Config/Weapons")
local WeaponLooks = require("../src/shared/Config/WeaponLooks")
local Items = require("../src/shared/Config/Items")
local Bosses = require("../src/shared/Config/Bosses")
local Wild = require("../src/shared/Config/Wild")
local Frontier = require("../src/shared/Config/Frontier")
local expect = require("./lib/expect")

return {
	["every weapon material has its picture icon from sheet 7 (Config/UIIcons), not an emoji"] = function()
		local UIIcons = require("../src/shared/Config/UIIcons")
		local ids = { "wildOre" }
		for _, material in Weapons.MATERIALS do
			table.insert(ids, material)
		end
		for _, id in ids do
			local item = Items.ITEMS[id]
			assert(item, `{id} is an item`)
			assert(string.match(UIIcons[item.icon] or "", "^rbxassetid://%d+$"), `{id}'s icon {item.icon} is a UIIcons picture`)
		end
	end,

	["the drop cinematic's own sounds (not the pack pulls'): a rise, an arrival by rarity, the card's turn"] = function()
		local source = require("@lune/fs").readFile("src/shared/Config/PackOpening.luau")
		local drop = WeaponLooks.REVEAL.drop
		local names = { drop.rise, drop.ring }
		for _, rarity in { "Rare", "Very Rare", "Epic", "Legendary" } do
			assert(#drop.arrive[rarity] > 0, `{rarity} has an arrival sound`)
			for _, name in drop.arrive[rarity] do
				table.insert(names, name)
			end
		end
		for _, name in names do
			assert(string.sub(name, 1, 4) == "drop", `{name}: the drop's own sound`)
			assert(string.match(source, name .. ' = "rbxassetid://%d+"'), `{name} is a stage sound`)
			assert(string.match(source, name .. " = [%d%.]+"), `{name} has a volume`)
		end
		assert(#drop.arrive.Legendary > #drop.arrive.Rare, "a Legendary arrives bigger")
		assert(string.match(source, drop.card .. ' = "rbxassetid://%d+"'), "the card's turn is a stage sound")
	end,

	["the forge reveal's sounds are all stage sounds with a volume (Config/PackOpening)"] = function()
		-- Config/PackOpening builds Vector3s, so Lune reads its text: each name's id line and its volume
		local source = require("@lune/fs").readFile("src/shared/Config/PackOpening.luau")
		local PackOpening = { SOUNDS = {} :: { [string]: string }, VOLUMES = {} :: { [string]: number } }
		for name, id in string.gmatch(source, "(forge%w+) = \"(rbxassetid://%d+)\"") do
			PackOpening.SOUNDS[name] = id
		end
		for name, volume in string.gmatch(source, "(forge%w+) = ([%d%.]+)") do
			PackOpening.VOLUMES[name] = tonumber(volume) :: number
		end
		local forge = WeaponLooks.REVEAL.forge
		local names = { forge.sounds.fire, forge.sounds.strike, forge.sounds.ring }
		for _, grade in { "C", "B", "A", "S" } do
			assert(#forge.hit[grade] > 0, `{grade} has a hit`)
			for _, name in forge.hit[grade] do
				table.insert(names, name)
			end
		end
		for _, name in names do
			assert(string.match(PackOpening.SOUNDS[name] or "", "^rbxassetid://%d+$"), `{name} is a stage sound`)
			assert(PackOpening.VOLUMES[name], `{name} has a volume`)
			assert(string.sub(name, 1, 5) == "forge", `{name}: the Forge's own sounds, not the pack pulls'`)
		end
		assert(#forge.strikes >= 2, "hammer strikes through the build-up")
		for _, at in forge.strikes do
			assert(at < forge.buildUp, "every strike lands before the hit")
		end
	end,

	-- Weapons round 2 (spec 2026-11-07-weapons-round2-design 4)
	["the spears: the Forge Spear in five elements, one moveset, their perks, tiers and the swap time"] = function()
		expect.isNil(Weapons.ById.forgeSpear, "the Forge Spear comes in elements")
		for _, element in { "Ember", "Tide", "Bloom", "Volt", "Shade" } do
			local spear = Weapons.ById[`forgeSpear_{element}`]
			assert(spear, element)
			expect.equal(spear.family, "spear")
			expect.equal(spear.element, element)
			expect.equal(spear.moveset, "spear")
			expect.equal(spear.source.kind, "forge")
		end
		for _, id in { "magmaHalberd", "tidalTrident" } do
			expect.equal(Weapons.ById[id].moveset, "spear", id)
		end
		expect.equal(Weapons.ById.titansLance.moveset, "titansLance", "its own skill (round 2.5)")
		local erupt = Weapons.ById.magmaHalberd.perk :: any
		expect.equal(erupt.kind, "erupt")
		expect.equal(erupt.every, 5)
		expect.equal(erupt.share, 0.6)
		local chill = Weapons.ById.tidalTrident.perk :: any
		expect.equal(chill.kind, "chill")
		expect.equal(chill.share, 0.1)
		expect.equal(chill.seconds, 3)
		-- the Lance's own base Power and a heal every 4th hit keep it inside the Hydra's balance limit (tools/balance/bosses:
		-- at 1.8 with a heal on every hit a 0.8x party won 100% even at +0; DESIGN.md weapons balance rows)
		expect.equal(Weapons.ById.titansLance.power, 1.2)
		local bloom = Weapons.ById.titansLance.perk :: any
		expect.equal(bloom.kind, "heal")
		expect.equal(bloom.every, 4)
		expect.equal(bloom.share, 0.01)
		expect.equal(Weapons.TIER_BOSS.forgeSpear, "meadowWarden")
		expect.equal(Weapons.TIER_BOSS.magmaHalberd, "emberColossus")
		expect.equal(Weapons.TIER_BOSS.tidalTrident, "frostTyrant")
		expect.equal(Weapons.TIER_BOSS.titansLance, "prismHydra")
		expect.equal(Weapons.SWAP_SECONDS, 1)
	end,

	-- Weapons round 2: the spears are built (their models in, spec 2026-11-07-weapons-round2-design 7); every built
	-- weapon's model (a Forge copy: its base model's) has its glow map
	["the spears are built, and every built weapon has its glow map"] = function()
		local models = { magmaHalberd = "MagmaHalberd", tidalTrident = "TidalTrident", titansLance = "TitansLance" }
		for _, element in { "Ember", "Tide", "Bloom", "Volt", "Shade" } do
			models[`forgeSpear_{element}`] = `ForgeSpear_{element}`
		end
		for id, model in models do
			expect.equal(Weapons.ById[id].ready, true, `{id} is built`)
			expect.equal(Weapons.ById[id].model, model, id)
		end
		for _, w in Weapons.WEAPONS do
			if w.ready and w.model and w.id ~= Weapons.STARTER then
				local base = string.gsub(w.model, "_%a+$", "")
				assert(WeaponLooks.GLOW_MAPS[base], `{w.id}: no glow map for {base}`)
			end
		end
	end,

	["every weapon is complete and in the Armory order"] = function()
		expect.equal(#Weapons.WEAPONS, 21) -- Steel, 5 Forge Swords, 3 new swords, 5 Forge Spears, 3 spears, 4 scythes
		for _, w in Weapons.WEAPONS do
			assert(Weapons.ById[w.id] == w, w.id)
			assert(Weapons.RARITY_POWER[w.rarity] or w.id == "starterSword", w.id)
			if w.ready then
				assert(w.moveset and w.model, `{w.id} needs a moveset and a model`)
			end
			assert(WeaponLooks.WEAPONS[w.id], `{w.id} needs a look`)
		end
	end,

	["every weapon with a model has its portrait (the card's picture); the rest wait for theirs"] = function()
		for _, w in Weapons.WEAPONS do
			local portrait = WeaponLooks.WEAPONS[w.id].portrait
			if w.model then
				assert(string.match(portrait, "^rbxassetid://%d+$"), `{w.id} needs its portrait`)
			else
				expect.equal(portrait, "", `{w.id}: no model yet, so no portrait`)
			end
		end
	end,

	["each boss drops its own material with full loot, and its daily chest adds 2"] = function()
		local count = 0
		for bossId, item in Weapons.MATERIALS do
			count += 1
			assert(Items.ITEMS[item], item)
			local found = false
			for _, drop in Bosses.BOSSES[bossId].drops do
				if drop.item == item then
					found = true
					expect.equal(drop.chance, 0.8)
					expect.equal(drop.min, 1)
					expect.equal(drop.max, 2)
				end
			end
			assert(found, bossId)
			local chest = 0
			for _, grant in Bosses.BOSSES[bossId].dailyBonus do
				if grant.item == item then
					chest = grant.count
				end
			end
			expect.equal(chest, 2, `{bossId}'s daily chest`)
		end
		expect.equal(count, 7, "all seven bosses")
	end,

	["the pace: a Rare weapon in about 2 days, a Legendary in 6-16 (owner's approved pace)"] = function()
		local perDay = Bosses.SOFT_CAP_AFTER * 0.8 * 1.5 + 2 -- full-chance kills x chance x average count + the daily chest
		local rare = Weapons.BOSS_COST.Rare.material / perDay
		local legendary = Weapons.BOSS_COST.Legendary.material / perDay
		assert(rare >= 1.5 and rare <= 3, `Rare {rare} days`)
		assert(legendary >= 6 and legendary <= 16, `Legendary {legendary} days`)
	end,

	["Wild Ore drops from Wild and Frontier monsters"] = function()
		expect.equal(Wild.ORE_CHANCE, 0.15)
		expect.equal(Wild.ELITE_ORE_CHANCE, 0.6)
		expect.equal(Frontier.ORE_CHANCE, 0.15)
		expect.equal(Frontier.ELITE_ORE_CHANCE, 0.6)
		assert(Items.ITEMS[Weapons.WILD_ORE], "the Wild Ore item")
	end,
}
