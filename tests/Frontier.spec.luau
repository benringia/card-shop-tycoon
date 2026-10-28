--!strict
local frontier = require("../src/shared/Config/Frontier")
local wild = require("../src/shared/Config/Wild")
local cardList = require("../src/shared/Config/CardList")
local combat = require("../src/shared/Config/Combat")
local places = require("../src/shared/Config/Places")
local expect = require("./lib/expect")

local ELEMENTS = { "Ember", "Tide", "Bloom", "Volt", "Shade" }

return {
	["the Frontier world has every key the Wild one has (WildService reads either)"] = function()
		local mainOnly = { PLAZA_PORTAL = true } -- read only on the main place's branch
		for key in wild do
			expect.equal(mainOnly[key] == true or (frontier :: any)[key] ~= nil, true, `Frontier.{key}`)
		end
	end,

	["every zone has known species and valid elements"] = function()
		for _, zone in frontier.ZONES do
			for _, species in zone.species do
				local info = frontier.SPECIES[species]
				assert(info, `{zone.name}: unknown species {species}`)
				assert(table.find(ELEMENTS, info.element), `{species}: element {info.element}`)
			end
			for _, element in zone.elements or {} do
				assert(table.find(ELEMENTS, element), `{zone.name}: element {element}`)
			end
		end
	end,

	["zone levels are 15-25, 25-35, 35-50 and The Rift chases"] = function()
		local ranges = { { 15, 25 }, { 25, 35 }, { 35, 50 } }
		for index, range in ranges do
			local zone = frontier.ZONES[index]
			expect.equal(zone.minLevel, range[1], `{zone.name} min`)
			expect.equal(zone.maxLevel, range[2], `{zone.name} max`)
		end
		expect.equal(frontier.ZONES[3].aggro, true, "The Rift chases")
		expect.equal(#frontier.ZONES[3].elements, 5, "The Rift: all five elements")
	end,

	["drop chances and elite rate"] = function()
		expect.equal(frontier.SHARD_CHANCE, 0.03, "shard")
		expect.equal(frontier.ELITE_SHARD_CHANCE, 0.10, "elite shard")
		expect.equal(frontier.CARD_CHANCE, 0.03, "card")
		expect.equal(frontier.ELITE_CARD_CHANCE, 0.10, "elite card")
		expect.near(frontier.ELITE_CHANCE, 1 / 6, 1e-9, "elites 1 in 6")
		for rarity in frontier.CARD_RARITY do
			assert(rarity == "Rare" or rarity == "Epic" or rarity == "Legendary", `card rarity {rarity}`)
		end
	end,

	["six Frontier cards, two per rarity, with signatures"] = function()
		expect.equal(#cardList.FRONTIER, 6, "six cards")
		local byRarity = {}
		for _, row in cardList.FRONTIER do
			local name, rarity = row[1], row[3]
			byRarity[rarity] = (byRarity[rarity] or 0) + 1
			for _, set1 in cardList.SET1 do
				assert(set1[1] ~= name, `{name} is also a Set 1 card`)
			end
			if rarity == "Epic" or rarity == "Legendary" then
				local signature = combat.SIGNATURES[name]
				assert(signature, `{name} has no signature`)
				local known = false
				for _, existing in { "Inferno", "TidalShield", "Stampede", "Eclipse", "Supernova", "Devour" } do
					known = known or signature.kind == existing
				end
				assert(known, `{name}: unknown ability kind {signature.kind}`)
			end
		end
		expect.equal(byRarity.Rare, 2, "rares")
		expect.equal(byRarity.Epic, 2, "epics")
		expect.equal(byRarity.Legendary, 2, "legendaries")
	end,

	["Set 1 unchanged"] = function()
		expect.equal(#cardList.SET1, 35, "35 cards")
		expect.equal(cardList.SET1[1][1], "Cindercub", "FS01 is still Cindercub")
		assert(places.FRONTIER_PLACE_ID ~= places.MAIN_PLACE_ID, "two different places")
	end,
}
