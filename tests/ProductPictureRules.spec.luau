--!strict
-- Round 5 (spec 2026-11-04-round5-design section 6): sharp pictures of the real pack and deck box, the drawn icon until
-- a look has one.
local ProductPictureRules = require("../src/shared/Util/ProductPictureRules")
local ProductPictures = require("../src/shared/Config/ProductPictures")
local Pricing = require("../src/shared/Config/Pricing")
local expect = require("./lib/expect")

local function isAsset(id: any): boolean
	return typeof(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil
end

return {
	["First Spark has a picture for its pack and its deck box"] = function()
		local pack, packIcon = ProductPictureRules.pick(ProductPictures, "FirstSpark", "Pack")
		assert(isAsset(pack), "pack picture uploaded")
		expect.equal(packIcon, "BoosterPack")
		local deck = ProductPictureRules.pick(ProductPictures, "FirstSpark", "Deck")
		assert(isAsset(deck), "deck box picture uploaded")
	end,

	["a look with no picture yet shows the drawn icon"] = function()
		local pack, packIcon = ProductPictureRules.pick(ProductPictures, "Frontier", "Pack")
		expect.isNil(pack)
		expect.equal(packIcon, "BoosterPack")
		local deck, deckIcon = ProductPictureRules.pick(ProductPictures, "Frontier", "Deck")
		expect.isNil(deck)
		expect.equal(deckIcon, "DeckBox")
	end,

	["the drawn icon shows until the picture has loaded (still processing, or rejected)"] = function()
		expect.equal(ProductPictureRules.showIcon(false), true)
		expect.equal(ProductPictureRules.showIcon(true), false)
	end,

	["the picture fits its row with air around it"] = function()
		expect.equal(ProductPictures.MARGIN > 0, true)
		expect.equal(ProductPictures.AREA + 2 * ProductPictures.MARGIN <= Pricing.ROWS.ROW_HEIGHT, true)
		expect.equal(ProductPictures.AREA - 2 * ProductPictures.MARGIN >= 40, true, "still big enough to read")
	end,
}
