--!strict
-- Storage racks (spec docs/superpowers/specs/2026-11-24-storage-racks-design.md; owner 2026-11-24: "storage system where
-- box can be put to storage racks. also pets can also carry boxes to the storage racks"): where a stored box goes, which
-- box comes out, the rack's attribute, a saved rack cleaned, the stock clipboard's lines and words, the prompt's words and
-- a restocker's picks
local StorageRules = require("../src/shared/Util/StorageRules")
local Storage = require("../src/shared/Config/Storage")
local Products = require("../src/shared/Config/Products")
local expect = require("./lib/expect")

local function box(productId: string, units: number?): StorageRules.Box
	return { productId = productId, units = units or 1 }
end

local function shelf(uid: string, units: number, capacity: number, productId: string?, accepts: { string }?): StorageRules.ShelfView
	return { uid = uid, units = units, capacity = capacity, productId = productId, accepts = accepts }
end

return {
	["a stored box goes next to its own kind, else the first free spot"] = function()
		expect.equal(StorageRules.slotFor({}, 9, "A"), 1, "an empty rack")
		expect.equal(StorageRules.slotFor({ [1] = box("A"), [2] = box("A"), [3] = box("D") }, 9, "A"), 4, "after its kind")
		expect.equal(StorageRules.slotFor({ [1] = box("A"), [2] = box("D") }, 9, "D"), 3)
		expect.equal(StorageRules.slotFor({ [1] = box("A"), [3] = box("D") }, 9, "S"), 2, "a new kind: the first free spot")
		local full: StorageRules.Stored = {}
		for slot = 1, 9 do
			full[slot] = box("X")
		end
		expect.isNil(StorageRules.slotFor(full, 9, "A"), "a full rack")
		local wrap: StorageRules.Stored = { [2] = box("A") }
		for slot = 3, 9 do
			wrap[slot] = box("X")
		end
		expect.equal(StorageRules.slotFor(wrap, 9, "A"), 1, "no room after its kind: the first free spot")
	end,

	["TAKE takes the half-used box of a kind first, then the lowest spot"] = function()
		expect.equal(StorageRules.takeSlot({ [1] = box("A", 24), [2] = box("A", 14), [4] = box("A", 24) }, "A"), 2)
		expect.equal(StorageRules.takeSlot({ [5] = box("A", 24), [3] = box("A", 24) }, "A"), 3, "a tie: the lowest spot")
		expect.isNil(StorageRules.takeSlot({ [1] = box("A", 24) }, "D"), "none of that kind")
	end,

	["the rack's attribute round-trips its boxes"] = function()
		local stored = { [7] = box("DeckBox", 10), [1] = box("FirstSparkPack", 24), [2] = box("FirstSparkPack", 14) }
		local text = StorageRules.encode(stored)
		expect.equal(text, "1:FirstSparkPack:24;2:FirstSparkPack:14;7:DeckBox:10", "spots in order")
		expect.equal(StorageRules.encode(StorageRules.decode(text, 9)), text)
		local junk = StorageRules.decode("x;3:A:5;12:A:1;2:B:0", 9)
		expect.equal(StorageRules.encode(junk), "3:A:5", "junk, a spot past the rack and an empty box are skipped")
		expect.equal(StorageRules.encode(StorageRules.decode(nil, 9)), "", "no attribute: nothing stored")
		expect.equal(StorageRules.count(stored), 3)
		expect.equal(StorageRules.count({}), 0)
	end,

	["a saved rack is cleaned: unknown kinds dropped, units floored and capped, bad spots moved, extras returned"] = function()
		local stored, extras = StorageRules.clean({
			{ slot = 1, productId = "A", units = 24.7 },
			{ slot = 1, productId = "A", units = 5 }, -- the same spot twice: moves to the next free one by its kind
			{ slot = 99, productId = "A", units = 3 }, -- past the rack
			{ slot = 2, productId = "Gone", units = 4 }, -- a product no longer in the game
			"junk",
		}, 9, { A = 24 })
		expect.equal(StorageRules.encode(stored), "1:A:24;2:A:5;3:A:3")
		expect.equal(#extras, 0)

		local capped = StorageRules.clean({ { slot = 4, productId = "A", units = 99 }, { slot = 5, productId = "A", units = 0.4 } }, 9, { A = 24 })
		expect.equal(StorageRules.encode(capped), "4:A:24", "no more than a box holds; an empty box is nothing")

		local many = {}
		for slot = 1, 11 do
			table.insert(many, { slot = slot, productId = "A", units = 2 })
		end
		local kept, over = StorageRules.clean(many, 9, { A = 24 })
		expect.equal(StorageRules.count(kept), 9)
		expect.equal(#over, 2, "two boxes past the rack come back as extras, never lost")
		expect.equal(over[1].productId, "A")
		expect.equal(over[1].units, 2)

		local none, noExtras = StorageRules.clean("x", 9, { A = 24 })
		expect.isNil(next(none))
		expect.equal(#noExtras, 0)
	end,

	["the clipboard has one line per kind, in shelf order, with tallies and unit words"] = function()
		local stored = {
			[1] = box("FirstSparkPack", 24),
			[2] = box("FirstSparkPack", 24),
			[3] = box("FirstSparkPack", 14),
			[4] = box("DeckBox", 10),
			[5] = box("DeckBox", 10),
			[7] = box("FirstSparkBox", 1),
		}
		local lines = StorageRules.lines(stored, Storage.NAMES, Storage.UNITS)
		expect.equal(#lines, 3)
		expect.equal(lines[1].productId, "FirstSparkPack")
		expect.equal(lines[1].name, "Booster Packs")
		expect.equal(lines[1].boxes, 3)
		expect.equal(lines[1].units, 62)
		expect.equal(lines[1].words, "62 packs")
		expect.equal(lines[1].tally, "III")
		expect.equal(lines[2].words, "20 deck boxes")
		expect.equal(lines[3].words, "1 booster box", "one of a thing")
		expect.equal(lines[3].tally, "I")
		local order = StorageRules.lines({ [2] = box("DeckBox", 10), [5] = box("FirstSparkPack", 3), [1] = box("FirstSparkPack", 3) }, Storage.NAMES, Storage.UNITS)
		expect.equal(order[1].productId, "FirstSparkPack", "the kind whose first box sits lowest comes first")
		expect.equal(#StorageRules.lines({}, Storage.NAMES, Storage.UNITS), 0)
	end,

	["every product has a sheet name and unit words"] = function()
		for _, product in Products.List do
			assert(Storage.NAMES[product.id], `{product.id}: a sheet name`)
			local words = Storage.UNITS[product.id]
			assert(words and words[1] and words[2], `{product.id}: unit words, one and many`)
		end
	end,

	["prompt words: Store with the kind, Rack full when full, Open with the count"] = function()
		local W = Storage.WORDS
		local action, object = StorageRules.prompt(8, 9, "Deck Box", W)
		expect.equal(action, "Store")
		expect.equal(object, "Deck Box")
		action, object = StorageRules.prompt(9, 9, "Deck Box", W)
		expect.equal(action, "Store")
		expect.equal(object, "Rack full · 9 / 9", "said before you press")
		action, object = StorageRules.prompt(8, 9, nil, W)
		expect.equal(action, "Open")
		expect.equal(object, "Storage Rack · 8 boxes")
		_, object = StorageRules.prompt(1, 9, nil, W)
		expect.equal(object, "Storage Rack · 1 box")
		_, object = StorageRules.prompt(0, 9, nil, W)
		expect.equal(object, "Storage Rack · empty")
	end,

	["the sheet's subtitle names the last restocker when there is one"] = function()
		local W = Storage.WORDS
		expect.equal(StorageRules.subtitle(8, 9, "Cindercub", W), "8 of 9 spots · counted by Cindercub")
		expect.equal(StorageRules.subtitle(8, 9, nil, W), "8 of 9 spots")
		expect.equal(StorageRules.subtitle(0, 9, "", W), "0 of 9 spots")
	end,

	["a shelf half full or less is low"] = function()
		expect.equal(StorageRules.isLow(12, 24, Storage.LOW_SHARE), true)
		expect.equal(StorageRules.isLow(13, 24, Storage.LOW_SHARE), false)
		expect.equal(StorageRules.isLow(0, 24, Storage.LOW_SHARE), true)
	end,

	["restockers fill the emptiest low shelf from a rack, then empty shelves"] = function()
		local packs = { { uid = "r1", stored = { [1] = box("FirstSparkPack", 24), [2] = box("FirstSparkPack", 14) } } }
		local pick = StorageRules.restockPick({ shelf("s1", 10, 24, "FirstSparkPack") }, packs, 0.5)
		expect.equal(pick and pick.rack, "r1")
		expect.equal(pick and pick.slot, 2, "the half-used box first")
		expect.equal(pick and pick.shelf, "s1")
		expect.equal(pick and pick.productId, "FirstSparkPack")
		expect.equal((StorageRules.restockPick({ shelf("s1", 12, 24, "FirstSparkPack") }, packs, 0.5) or {} :: any).shelf, "s1", "exactly half: low")
		expect.isNil(StorageRules.restockPick({ shelf("s1", 13, 24, "FirstSparkPack") }, packs, 0.5), "over half full: leave it")

		local decks = { { uid = "r2", stored = { [4] = box("DeckBox", 10) } } }
		local empty = StorageRules.restockPick({ shelf("e1", 0, 24, nil) }, decks, 0.5)
		expect.equal(empty and empty.productId, "DeckBox")
		expect.equal(empty and empty.shelf, "e1")
		expect.equal(empty and empty.slot, 4)
		expect.isNil(StorageRules.restockPick({ shelf("hook", 0, 20, nil, { "CardSleeves", "DeckBox" }) }, packs, 0.5), "a hook takes no packs")

		local lowest = StorageRules.restockPick({ shelf("a", 10, 24, "FirstSparkPack"), shelf("b", 2, 24, "FirstSparkPack") }, packs, 0.5)
		expect.equal(lowest and lowest.shelf, "b", "the emptiest first")
		local holdingFirst = StorageRules.restockPick({ shelf("e", 0, 24, nil), shelf("h", 10, 24, "FirstSparkPack") }, packs, 0.5)
		expect.equal(holdingFirst and holdingFirst.shelf, "h", "a shelf selling it before an empty one")
		expect.isNil(StorageRules.restockPick({ shelf("s", 0, 24, nil) }, {}, 0.5), "nothing racked")
		expect.isNil(StorageRules.restockPick({ shelf("s", 3, 24, "DeckBox") }, packs, 0.5), "its kind isn't racked")
	end,

	["a restocker takes the nearest rack with room"] = function()
		expect.equal(StorageRules.pickRack({
			{ uid = "a", free = 0, distance = 1 },
			{ uid = "b", free = 2, distance = 9 },
			{ uid = "c", free = 1, distance = 4 },
		}), "c")
		expect.isNil(StorageRules.pickRack({ { uid = "a", free = 0, distance = 1 } }), "every rack full")
		expect.isNil(StorageRules.pickRack({}), "no racks")
	end,

	["each spot sits on its deck, the first on your left as you face the rack"] = function()
		local x1, y1 = StorageRules.spot(1, Storage.SPOTS, 7)
		expect.near(x1, 3, 1e-9, "part space +X is your left: the rack faces its part's -Z")
		expect.near(y1, -3.5 + 0.45 + 0.75, 1e-9)
		local x5, y5 = StorageRules.spot(5, Storage.SPOTS, 7)
		expect.near(x5, 0, 1e-9)
		expect.near(y5, -3.5 + 2.7 + 0.75, 1e-9)
		local x9, y9 = StorageRules.spot(9, Storage.SPOTS, 7)
		expect.near(x9, -3, 1e-9)
		expect.near(y9, -3.5 + 4.95 + 0.75, 1e-9)
		expect.equal(#Storage.SPOTS.x * #Storage.SPOTS.decks, 9, "nine spots: Config/Shelves StorageRack capacity")
	end,
}
