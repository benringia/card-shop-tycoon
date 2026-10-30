--!strict
-- Which creature models a client downloads in the background, and in what order (Util/ModelPreload). Only models the
-- game uses (a card's model, a town animal's): the bought packs also hold 45 unused models with 93% of the meshes, and
-- downloading them kept a new player's own cards waiting. The cards asked for (their own, one about to be summoned) go
-- first.
local party = require("../src/shared/Config/Party")
local ambient = require("../src/shared/Config/Ambient")
local ModelPreload = require("../src/shared/Util/ModelPreload")
local expect = require("./lib/expect")

local function keys(order: { ModelPreload.Entry }): { string }
	local list = {}
	for _, entry in order do
		table.insert(list, entry.key)
	end
	return list
end

local function aCard(): string
	for name in party.CREATURE_MODELS do
		return name
	end
	error("no cards")
end

return {
	["only models something uses"] = function()
		local wanted: { [string]: boolean } = {}
		for _, entry in party.CREATURE_MODELS do
			wanted[ModelPreload.key(entry.pack, entry.model)] = true
		end
		for _, critter in ambient.CRITTERS do
			wanted[ModelPreload.key("CutePets", critter.model)] = true
		end
		local count = 0
		for _ in wanted do
			count += 1
		end
		local order = ModelPreload.order({}, party.CREATURE_MODELS, ambient.CRITTERS)
		expect.equal(#order, count, "one entry per used model")
		for _, entry in order do
			assert(wanted[entry.key], `{entry.key} is not used by any card or town animal`)
		end
	end,

	["no model twice"] = function()
		-- two baby dragons share a model; cards could share one too
		local seen: { [string]: boolean } = {}
		for _, key in keys(ModelPreload.order({ aCard(), aCard() }, party.CREATURE_MODELS, ambient.CRITTERS)) do
			assert(not seen[key], `{key} listed twice`)
			seen[key] = true
		end
	end,

	["asked-for cards come first, in the order asked"] = function()
		local names = {}
		for name in party.CREATURE_MODELS do
			table.insert(names, name)
		end
		table.sort(names)
		local first, second = names[#names], names[1]
		local order = ModelPreload.order({ first, "Not A Card", second }, party.CREATURE_MODELS, ambient.CRITTERS)
		local a, b = party.CREATURE_MODELS[first], party.CREATURE_MODELS[second]
		expect.equal(order[1].key, ModelPreload.key(a.pack, a.model), "the first card asked for")
		expect.equal(order[2].key, ModelPreload.key(b.pack, b.model), "the second (unknown names skipped)")
	end,

	["downloads go in batches of the next models still waiting"] = function()
		-- one model per call is slow (each call waits about half a second); a batch keeps the order and the speed
		local order = ModelPreload.order({}, party.CREATURE_MODELS, ambient.CRITTERS)
		local done = { [order[1].key] = true, [order[3].key] = true }
		local batch = ModelPreload.nextBatch(order, done, 3)
		expect.equal(#batch, 3, "batch size")
		expect.equal(batch[1].key, order[2].key, "skips what's done")
		expect.equal(batch[2].key, order[4].key, "keeps the order")
		expect.equal(batch[3].key, order[5].key, "up to the size")
		local all: { [string]: boolean } = {}
		for _, entry in order do
			all[entry.key] = true
		end
		expect.equal(#ModelPreload.nextBatch(order, all, 3), 0, "nothing left")
		assert(party.PRELOAD_BATCH >= 2, "downloads go several at a time")
	end,

	["cards before town animals"] = function()
		local order = ModelPreload.order({}, party.CREATURE_MODELS, ambient.CRITTERS)
		local cardKeys: { [string]: boolean } = {}
		for _, entry in party.CREATURE_MODELS do
			cardKeys[ModelPreload.key(entry.pack, entry.model)] = true
		end
		local seenAnimal = false
		for _, entry in order do
			if cardKeys[entry.key] then
				assert(not seenAnimal, `card model {entry.key} after a town animal`)
			else
				seenAnimal = true
			end
		end
	end,
}
