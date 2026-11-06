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
	["every weapon is complete and in the Armory order"] = function()
		expect.equal(#Weapons.WEAPONS, 17) -- Steel, 5 Forge Swords, 3 new swords, 4 spears, 4 scythes
		for _, w in Weapons.WEAPONS do
			assert(Weapons.ById[w.id] == w, w.id)
			assert(Weapons.RARITY_POWER[w.rarity] or w.id == "starterSword", w.id)
			if w.ready then
				assert(w.moveset and w.model, `{w.id} needs a moveset and a model`)
			end
			assert(WeaponLooks.WEAPONS[w.id], `{w.id} needs a look`)
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
