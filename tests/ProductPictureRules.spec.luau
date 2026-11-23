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

	-- Owner 2026-11-20: "delivery boxes should use the actualy first spark model as box icons ... also change the
	-- Icons and the box icons of the other products": every product the shop orders has a picture of its real model,
	-- on its row in the menus and on its delivery box's sticker
	["every product's picture: by its own id, else its look's"] = function()
		local sleeves = ProductPictureRules.forProduct(ProductPictures, "CardSleeves", nil, nil)
		assert(isAsset(sleeves), "the sleeve packets' picture")
		local box = ProductPictureRules.forProduct(ProductPictures, "FirstSparkBox", nil, nil)
		assert(isAsset(box), "the sealed booster box's picture")
		assert(sleeves ~= box)
		expect.equal(ProductPictureRules.forProduct(ProductPictures, "FirstSparkPack", "FirstSpark", "Pack"), ProductPictures.LOOKS.FirstSpark.Pack, "a pack: its look's")
		expect.equal(ProductPictureRules.forProduct(ProductPictures, "DeckBox", "FirstSpark", "Deck"), ProductPictures.LOOKS.FirstSpark.Deck)
		expect.isNil(ProductPictureRules.forProduct(ProductPictures, "Mystery", nil, nil), "none yet: the drawn icon")
		expect.isNil(ProductPictureRules.forProduct(ProductPictures, "Mystery", "Nowhere", "Pack"), "a look with no pictures")
		-- everything Order Stock sells has one
		local Products = require("../src/shared/Config/Products")
		for _, product in Products.List do
			if not product.bulk then
				local look = if product.id == "FirstSparkPack" or product.id == "DeckBox" then "FirstSpark" elseif product.id == "FrontierPack" then "Frontier" else nil
				local kind = if product.id == "DeckBox" then "Deck" elseif look then "Pack" else nil
				assert(isAsset(ProductPictureRules.forProduct(ProductPictures, product.id, look, kind)), `{product.name} has a picture`)
			end
		end
	end,

	["a look with no picture yet shows the drawn icon"] = function()
		local pack, packIcon = ProductPictureRules.pick(ProductPictures, "Nowhere", "Pack")
		expect.isNil(pack)
		expect.equal(packIcon, "BoosterPack")
		local deck, deckIcon = ProductPictureRules.pick(ProductPictures, "Frontier", "Deck")
		expect.isNil(deck, "the Frontier set has no deck box")
		expect.equal(deckIcon, "DeckBox")
	end,

	-- Owner 2026-11-23, pick B: the Frontier Pack's own picture, its 3D pack in the Frontier look
	["the Frontier Pack has its own picture"] = function()
		local pack = ProductPictureRules.pick(ProductPictures, "Frontier", "Pack")
		assert(isAsset(pack), "the Frontier pack's picture uploaded")
		assert(pack ~= ProductPictures.LOOKS.FirstSpark.Pack, "not the First Spark one")
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
