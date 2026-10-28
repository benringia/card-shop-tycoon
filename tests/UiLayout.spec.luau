--!strict
local UiLayout = require("../src/shared/Util/UiLayout")
local expect = require("./lib/expect")

local SCREEN = { w = 1000, h = 600 }
local TIP = { w = 200, h = 150 }

return {
	["beside: right of the anchor when it fits"] = function()
		local spot = UiLayout.beside({ x = 100, y = 50, w = 60, h = 80 }, TIP, SCREEN, 8)
		expect.equal(spot.x, 168, "right of the card")
		expect.equal(spot.y, 50, "level with it")
	end,
	["beside: flips left near the right edge"] = function()
		local spot = UiLayout.beside({ x = 850, y = 50, w = 60, h = 80 }, TIP, SCREEN, 8)
		expect.equal(spot.x, 642, "left of the card")
	end,
	["beside: kept on screen at the bottom"] = function()
		local spot = UiLayout.beside({ x = 100, y = 560, w = 60, h = 80 }, TIP, SCREEN, 8)
		expect.equal(spot.y, 450, "pushed up to fit")
	end,
	["beside: no room either side goes above, never over the card"] = function()
		local spot = UiLayout.beside({ x = 150, y = 300, w = 60, h = 80 }, TIP, { w = 360, h = 600 }, 8)
		expect.equal(spot.y, 142, "above the card")
		expect.equal(spot.x, 80, "centred on it")
	end,
	["above: centred over the anchor, clamped to the screen"] = function()
		local spot = UiLayout.above({ x = 900, y = 500, w = 50, h = 60 }, { w = 230, h = 180 }, SCREEN, 8)
		expect.equal(spot.x, 770, "clamped to the right edge")
		expect.equal(spot.y, 312, "above the slot")
	end,
	["above: no room above goes below the anchor, never over it"] = function()
		-- the HUD party bar on a touch phone sits near the top of the screen
		local spot = UiLayout.above({ x = 600, y = 80, w = 60, h = 80 }, { w = 230, h = 180 }, { w = 750, h = 381 }, 10)
		expect.equal(spot.y, 170, "below the slot")
		expect.equal(spot.x, 515, "centred on it")
	end,
	["beside: no side room falls back around the pocket, not the whole book"] = function()
		local book = { x = 100, y = 40, w = 560, h = 100 }
		local pocket = { x = 500, y = 40, w = 100, h = 100 }
		local spot = UiLayout.beside(book, { w = 260, h = 200 }, { w = 760, h = 500 }, 8, pocket)
		expect.equal(spot.y, 148, "below the top-row pocket")
		expect.equal(spot.x, 420, "centred on the pocket")
	end,
	["inspectorCard: the card's right edge lands on the panel"] = function()
		local offset, rect = UiLayout.inspectorCard({ w = 1000, h = 500 }, 70, 3, { w = 1.8, h = 2.57 }, 0, 480, 8)
		expect.near(offset, -1.068, 0.01, "studs left of centre")
		expect.near(rect.x + rect.w, 480, 1, "right edge on the panel")
		expect.near(rect.h, 305.9, 1, "about 61% of the height")
		expect.near(rect.y, 97, 1, "centred vertically")
	end,
	["inspectorCard: a phone keeps the card on screen"] = function()
		local _, rect = UiLayout.inspectorCard({ w = 844, h = 390 }, 70, 3, { w = 1.8, h = 2.57 }, 0, 100, 8)
		expect.near(rect.x, 8, 1, "never off the left edge")
	end,
}
