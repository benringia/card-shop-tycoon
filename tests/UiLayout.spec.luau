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
	["detailPanelLeft: the 3D card and the panel centred as a pair on wide screens"] = function()
		-- card 330 + gap 16 + panel 520 = 866 wide, centred on 1920: starts at 527, the panel after the card
		expect.equal(UiLayout.detailPanelLeft(1920, 330, 16, 520, 16), 873, "centred pair")
	end,
	["detailPanelLeft: a narrow screen keeps the panel on screen first"] = function()
		-- the pair doesn't fit: the panel sits at its right margin (the card clamps to its own left margin)
		expect.equal(UiLayout.detailPanelLeft(800, 330, 16, 520, 16), 264, "right margin wins")
		expect.equal(UiLayout.detailPanelLeft(750, 200, 16, 420, 76), 254, "phone: clear of the close button")
	end,
	["combat buttons: big enough, on screen, never overlapping, clear of the thumbstick"] = function()
		for _, view in { { w = 844, h = 390 }, { w = 667, h = 375 }, { w = 1920, h = 1080 }, { w = 1280, h = 720 } } do
			local rects = UiLayout.combatButtons(view)
			local names = { "attack", "dodge", "skill", "pet", "signature", "swap", "run" }
			for _, name in names do
				local r = (rects :: any)[name] :: UiLayout.Rect
				local where = `{name} at {view.w}x{view.h}`
				expect.equal(r.w >= 48 and r.h >= 48, true, `{where}: tap target`)
				expect.equal(r.x >= 0 and r.y >= 0 and r.x + r.w <= view.w and r.y + r.h <= view.h, true, `{where}: on screen`)
				-- Roblox's thumbstick lives in the bottom-left: the left 40% of the lower half
				local inStick = r.x < view.w * 0.4 and r.y + r.h > view.h * 0.5
				expect.equal(inStick, false, `{where}: clear of the thumbstick`)
			end
			for i, a in names do
				for j = i + 1, #names do
					local r1, r2 = (rects :: any)[a], (rects :: any)[names[j]]
					local overlap = r1.x < r2.x + r2.w and r2.x < r1.x + r1.w and r1.y < r2.y + r2.h and r2.y < r1.y + r1.h
					expect.equal(overlap, false, `{a} and {names[j]} at {view.w}x{view.h}`)
				end
			end
			expect.equal(rects.attack.w > rects.dodge.w and rects.attack.w > rects.skill.w, true, "Attack is the biggest")
			expect.equal(rects.attack.x > view.w / 2 and rects.attack.y > view.h / 2, true, "Attack sits bottom-right")
		end
	end,
	["combat buttons with a mouse: no Attack, the Pet button in its corner, Dodge and Skill beside it"] = function()
		for _, view in { { w = 1920, h = 1080 }, { w = 1280, h = 720 }, { w = 844, h = 390 } } do
			local rects = UiLayout.combatButtons(view, true)
			local names = { "dodge", "skill", "pet", "signature", "swap", "run" }
			for i, a in names do
				local r = (rects :: any)[a] :: UiLayout.Rect
				expect.equal(r.x >= 0 and r.y >= 0 and r.x + r.w <= view.w and r.y + r.h <= view.h, true, `{a} at {view.w}x{view.h}: on screen`)
				for j = i + 1, #names do
					local r1, r2 = r, (rects :: any)[names[j]]
					local overlap = r1.x < r2.x + r2.w and r2.x < r1.x + r1.w and r1.y < r2.y + r2.h and r2.y < r1.y + r1.h
					expect.equal(overlap, false, `{a} and {names[j]} at {view.w}x{view.h}`)
				end
			end
			local full = UiLayout.combatButtons(view)
			expect.near(rects.pet.x + rects.pet.w, full.attack.x + full.attack.w, 1e-6, "the Pet button's right edge is Attack's")
			expect.equal(rects.pet.y + rects.pet.h > full.attack.y + full.attack.h - 1, true, "the Pet button sits at the bottom")
			expect.equal(rects.dodge.x + rects.dodge.w < rects.pet.x, true, "Dodge left of the Pet button")
			expect.equal(rects.dodge.x > full.dodge.x, true, "Dodge moves toward the corner")
			expect.near(rects.skill.x, rects.dodge.x + rects.dodge.w - rects.skill.w, 1e-6, "Skill above Dodge, right-aligned")
		end
	end,
	["wild fight buttons: the Pet button big, all on screen, no overlaps, clear of the thumbstick"] = function()
		for _, view in { { w = 844, h = 390 }, { w = 667, h = 375 }, { w = 1920, h = 1080 }, { w = 1280, h = 720 } } do
			local rects = UiLayout.wildButtons(view)
			local names = { "pet", "signature", "swap", "run" }
			for _, name in names do
				local r = (rects :: any)[name] :: UiLayout.Rect
				local where = `{name} at {view.w}x{view.h}`
				expect.equal(r.w >= 48 and r.h >= 48, true, `{where}: tap target`)
				expect.equal(r.x >= 0 and r.y >= 0 and r.x + r.w <= view.w and r.y + r.h <= view.h, true, `{where}: on screen`)
				local inStick = r.x < view.w * 0.4 and r.y + r.h > view.h * 0.5
				expect.equal(inStick, false, `{where}: clear of the thumbstick`)
			end
			for i, a in names do
				for j = i + 1, #names do
					local r1, r2 = (rects :: any)[a], (rects :: any)[names[j]]
					local overlap = r1.x < r2.x + r2.w and r2.x < r1.x + r1.w and r1.y < r2.y + r2.h and r2.y < r1.y + r1.h
					expect.equal(overlap, false, `{a} and {names[j]} at {view.w}x{view.h}`)
				end
			end
			expect.equal(rects.pet.w > rects.run.w and rects.pet.w > rects.swap.w, true, "the Pet button is the biggest")
			expect.equal(rects.pet.x > view.w / 2 and rects.pet.y > view.h / 2, true, "it sits bottom-right")
		end
	end,

	["the binder's Filters window fits its content, and the screen"] = function()
		local look = require("../src/shared/Config/FiltersLayout")
		local baby = require("../src/shared/Config/BabyColors")
		local chrome = look.header + look.inset * 2 + look.footer
		local body = UiLayout.filtersBody(look, baby.SEGMENTED.hit, baby.DOT_TAG.hit)
		-- what Studio measured on 2026-11-04: 354 px of pieces, gaps and edge room
		local rows = baby.DOT_TAG.hit * look.rarityRows + look.gap * (look.rarityRows - 1) -- the tag rows wrap with a gap
		local drawn = look.search + look.headingRow * 3 + baby.SEGMENTED.hit * 2 + rows
		expect.equal(body, drawn + look.gap * 6 + look.edge * 2, "the search box, headings, switches and every rarity row")
		local top, size = UiLayout.filtersFrame(1080, look, body)
		expect.equal(top, look.top, "a tall screen: under the binder's close and magnifier")
		expect.equal(size, body + chrome, "as tall as its content, not stretched down the screen")
		top, size = UiLayout.filtersFrame(625, look, body)
		expect.equal(top, look.shortTop, "a short screen: from the top, over the corner buttons")
		expect.equal(size, body + chrome, "still showing everything without scrolling")
		for _, height in { 330, 340, 370 } do
			top, size = UiLayout.filtersFrame(height, look, body)
			expect.equal(top + size + look.shortBottom <= height, true, `a landscape phone {height} px tall: on screen`)
			expect.equal(size > chrome, true, `a landscape phone {height} px tall: a body to scroll`)
		end
	end,
}
