--!strict
-- The Shop window's tiles on a phone (pre-launch QA 2026-11-19; owner: "do all"): the full tile was taller than the
-- list, so a picture and its price never showed together. Phones get a row tile that shows whole (Config/ShopTiles,
-- Util/ShopTileRules).
local ShopTiles = require("../src/shared/Config/ShopTiles")
local ShopTileRules = require("../src/shared/Util/ShopTileRules")
local expect = require("./lib/expect")

-- Screen heights under Roblox's top bar (the Device Simulator's): the smallest phone, a new iPhone
local GALAXY_A06 = 280
local IPHONE_17_PRO = 323

return {
	["why: the full tile never showed whole on a phone"] = function()
		assert(ShopTileRules.listHeight(ShopTiles, GALAXY_A06, false) < ShopTiles.FULL.height, "the old layout on a Galaxy A06")
		assert(ShopTileRules.listHeight(ShopTiles, IPHONE_17_PRO, false) < ShopTiles.FULL.height, "and on an iPhone 17 Pro")
	end,

	["a phone's row tile shows whole in the list, with room to see the next row coming"] = function()
		local tile = ShopTileRules.tileHeight(ShopTiles, true)
		for name, height in { GalaxyA06 = GALAXY_A06, iPhone17Pro = IPHONE_17_PRO } do
			local list = ShopTileRules.listHeight(ShopTiles, height, true)
			assert(list >= tile + 20, `{name}: list {list}, tile {tile}`)
		end
		expect.equal(ShopTileRules.tileHeight(ShopTiles, false), ShopTiles.FULL.height, "desktops keep the tall tile")
	end,

	["the row tile's pieces fit inside it, its button a finger-sized target"] = function()
		local look = ShopTiles.PHONE
		local row = ShopTileRules.row(ShopTiles)
		assert(row.margin + row.picture + row.margin <= look.height, "the picture")
		assert(row.detailY >= row.nameY + row.nameHeight, "the line under the name")
		local wordsEnd = row.detailY + row.detailHeight
		local buttonTop = look.height - row.margin - row.button
		assert(buttonTop >= wordsEnd, `the button under the words: {buttonTop} vs {wordsEnd}`)
		assert(row.button >= 44, "a finger-sized button")
		assert(row.beside > row.margin + row.picture, "words clear of the picture")
		expect.equal(look.columns, 2)
	end,

	["the window's chrome adds up: header, tabs and margins"] = function()
		local window = ShopTiles.WINDOW
		expect.equal(window.chrome, window.header + 10 + window.tabs + 10 + 10)
		expect.equal(window.phoneChrome, window.header + 6 + window.phoneTabs + 6 + 8)
		assert(window.phoneTabs >= 44, "tabs stay finger-sized")
		assert(window.phoneHeight <= 0.98, "inside the screen")
	end,

	-- Owner 2026-11-19: Pish no longer visits for every unlock; a NEW tag on the tile says what just opened
	["a tile is NEW for the level it unlocks at and the one after, never the starting things"] = function()
		expect.equal(ShopTileRules.isNew(4, 4), true, "just unlocked")
		expect.equal(ShopTileRules.isNew(5, 4), true, "one level later still")
		expect.equal(ShopTileRules.isNew(6, 4), false, "old news")
		expect.equal(ShopTileRules.isNew(3, 4), false, "locked: its lock says so, not NEW")
		expect.equal(ShopTileRules.isNew(1, 1), false, "what a new shop starts with isn't news")
		expect.equal(ShopTileRules.isNew(2, 1), false)
	end,
}
