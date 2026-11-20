--!strict
-- Owner 2026-11-21 (picked layout A from the mockups, "and we can drop the rating"): on a mouse-and-keyboard screen
-- the HUD groups by purpose. What you have (your face and level, the cash) sits in the top row beside Roblox's
-- buttons; everything you press (your creatures, the weapon dial, Cards, Bag) is one bar at the bottom centre; quests
-- stay top right, the Phone and the gift on the left. Phones keep their own layout.
local DesktopHud = require("../src/shared/Util/DesktopHud")
local Config = require("../src/shared/Config/DesktopHud")
local expect = require("./lib/expect")

local function near(a: number, b: number, why: string?)
	assert(math.abs(a - b) < 1e-6, `{why or ""}: expected {b}, got {a}`)
end

return {
	["only on a mouse-and-keyboard screen, and it can be switched off"] = function()
		expect.equal(DesktopHud.active(false, Config), true, "a computer")
		expect.equal(DesktopHud.active(true, Config), false, "a phone or tablet keeps its own layout")
		expect.equal(DesktopHud.active(false, { LAYOUT = "corners" }), false, "switched off: the corners as before")
	end,

	-- Owner 2026-11-21, after seeing A in the game: "can you change it to C? Keep combat UI for now." C: the cash on
	-- top of the right column (over the quests), your creatures and your row back in the bottom-left corner, the weapon
	-- dial bottom right; A's top row and bottom bar stay in the code behind LAYOUT = "bar"
	["the layout in use is C, the right column; A (the bar) is still there to switch to"] = function()
		expect.equal(Config.LAYOUT, "column")
		expect.equal(DesktopHud.layout(false, Config), "column")
		expect.isNil(DesktopHud.layout(true, Config), "a touch screen: its own")
		expect.equal(DesktopHud.layout(false, { LAYOUT = "bar" }), "bar")
		expect.isNil(DesktopHud.layout(false, { LAYOUT = "corners" }))
		expect.isNil(DesktopHud.layout(false, { LAYOUT = "sideways" }), "an unknown name: the corners")
	end,

	["C's cash sits at the top of the right column, in line with the quests' right edge"] = function()
		local top = Config.TOP
		near(DesktopHud.topRight(1809, 1809, Config), 1809 - top.right, "the top bar's room ends at the screen's edge")
		near(DesktopHud.topRight(1700, 1809, Config), 1700 - top.right, "clear of anything Roblox keeps at the right")
		near(DesktopHud.topRight(0, 1366, Config), 1366 - top.right, "the top bar's room not known yet: the screen's edge")
		expect.equal(top.right, 16, "the quest strip's own margin")
	end,

	["the bottom bar: creatures, weapon and tiles side by side, centred as one"] = function()
		local spots = DesktopHud.bar(1366, { { id = "party", w = 240 }, { id = "weapon", w = 130 }, { id = "tiles", w = 160 } }, 14, 100, 100)
		assert(spots, "it fits a laptop")
		local total = 240 + 130 + 160 + 14 * 2
		near(spots.party, 1366 / 2 - total / 2, "the bar's left end")
		near(spots.weapon, spots.party + 240 + 14, "the weapon after the creatures")
		near(spots.tiles, spots.weapon + 130 + 14, "Cards and Bag after the weapon")
		near(spots.tiles + 160, 1366 / 2 + total / 2, "the bar's right end: centred")
	end,

	["a piece that isn't showing (no weapon yet) leaves no hole"] = function()
		local spots = DesktopHud.bar(1366, { { id = "party", w = 240 }, { id = "weapon", w = 0 }, { id = "tiles", w = 160 } }, 14, 100, 100)
		assert(spots and spots.weapon == nil, "no spot for it")
		near(spots.tiles, spots.party + 240 + 14, "the tiles right after the creatures")
		near((spots.party + spots.tiles + 160) / 2, 1366 / 2, "still centred")
		local alone = DesktopHud.bar(1366, { { id = "party", w = 0 }, { id = "weapon", w = 0 }, { id = "tiles", w = 160 } }, 14, 100, 100)
		assert(alone, "the tiles alone (Pish's calm HUD)")
		near(alone.tiles, 1366 / 2 - 80, "where they always were")
	end,

	["it keeps clear of the side column and of Pish; too narrow a window: no bar"] = function()
		-- more to clear on the left than on the right: the bar slides over rather than cover the Phone
		local pieces = { { id = "party", w = 300 }, { id = "weapon", w = 170 }, { id = "tiles", w = 210 } }
		local shifted = DesktopHud.bar(1000, pieces, 14, 220, 60)
		assert(shifted, "it still fits")
		assert(shifted.party >= 220, "clear of the side column")
		assert(shifted.tiles + 210 <= 1000 - 60, "clear of Pish")
		expect.isNil(DesktopHud.bar(800, pieces, 14, 220, 60), "no room: the caller keeps the corners")
		expect.isNil(DesktopHud.bar(0, pieces, 14, 0, 0), "no screen yet")
	end,

	["the top row sits beside Roblox's buttons, or under the top bar when it can't"] = function()
		local top = Config.TOP
		local beside = DesktopHud.topRow(170, 1300, 600, Config)
		expect.equal(beside.inBar, true)
		near(beside.x, 170 + top.left, "just right of Roblox's buttons")
		local squeezed = DesktopHud.topRow(170, 700, 600, Config)
		expect.equal(squeezed.inBar, false, "no room beside them")
		near(squeezed.x, top.side, "at the left edge, under the bar")
		local unknown = DesktopHud.topRow(0, 0, 600, Config)
		expect.equal(unknown.inBar, false, "the top bar's room not known yet")
	end,

	["the numbers: gaps a finger of space wide, never touching"] = function()
		assert(Config.GAP >= 8 and Config.GAP <= 24)
		assert(Config.CLEAR >= 8)
		assert(Config.TOP.gap >= 6 and Config.TOP.left >= 4 and Config.TOP.top >= 0 and Config.TOP.under >= 0)
	end,
	-- Owner 2026-11-21, on C in the game: "Level the coins with the roblox pills to add gap at the coin pill top, move
	-- pish icon at the top of quests."
	["the cash is level with Roblox's pills, its coin never against the screen's top"] = function()
		local top = Config.TOP
		-- a 42 px pill with a 54 px coin (scale 1): centred on the pills' middle
		near(DesktopHud.cashTop(top.level, 42, 54, top.clear), top.level - 21, "centred on Roblox's pills")
		assert(DesktopHud.cashTop(top.level, 42, 54, top.clear) - (54 - 42) / 2 >= top.clear, "the coin clear of the top")
		-- grown 1.35x on a big screen: the coin (73 px) would poke out of the top, so the row sits lower
		local grown = DesktopHud.cashTop(top.level, 42 * 1.35, 54 * 1.35, top.clear)
		near(grown - (54 * 1.35 - 42 * 1.35) / 2, top.clear, "the coin's top at the gap")
		assert(top.level > 24 and top.level < 40, "Roblox's pills sit a little under the top bar's middle")
		assert(top.clear >= 3, "a gap at the coin's top")
	end,
	-- Owner 2026-11-21: "make phone and daily gift move up below roblox". On a computer the side column (the Phone, the
	-- gift) hangs from the top, under Roblox's buttons, not from the screen's middle
	["the Phone and the gift hang under Roblox's buttons on a computer"] = function()
		expect.equal(DesktopHud.sideTop("column", Config), Config.SIDE.top)
		expect.equal(DesktopHud.sideTop("bar", Config), Config.SIDE.top)
		expect.isNil(DesktopHud.sideTop(nil, Config), "the corners, or a phone (it has its own top): as before")
		assert(Config.SIDE.top >= 16 and Config.SIDE.top <= 40, "room for the first tile's icon, which pops out over its top")
	end,
	-- Owner 2026-11-21: "can we just put the quests inside phone ... then propose a few designs for the weapons section
	-- that pish can be placed to". On a computer the quest strip leaves the HUD for a Phone app; Pish, who sat on the
	-- strip, waits in the bottom-right corner by the weapon dial until a design for him there is picked
	["the quests live in the Phone on a computer, and Pish by the weapons"] = function()
		expect.equal(DesktopHud.questsInPhone("column", Config), true)
		expect.equal(DesktopHud.questsInPhone("bar", Config), true)
		expect.equal(DesktopHud.questsInPhone(nil, Config), false, "a phone keeps its quest chip by the cash")
		expect.equal(DesktopHud.questsInPhone("column", { QUESTS = "strip" }), false, "switched back: the strip")
		expect.equal(Config.QUESTS, "phone")
		expect.equal(DesktopHud.pishAt("column", { QUESTS = "phone", PISH = true }), "corner", "no strip to sit on: the corner by the weapon dial")
		expect.equal(DesktopHud.pishAt("column", { QUESTS = "strip", PISH = true }), "quests", "with the strip back he sits on it")
		expect.isNil(DesktopHud.pishAt(nil, { QUESTS = "phone", PISH = true }), "a phone has no Pish on its HUD")
	end,

	-- Owner 2026-11-21, after three designs for him by the weapons: "okay just remove pish. and make the toast
	-- notification appear on the lower right" and "reduce size a bit for coin pill"
	["no Pish on a computer's HUD; the cash pill a little smaller"] = function()
		expect.equal(Config.PISH, false)
		expect.isNil(DesktopHud.pishAt("column", Config), "nowhere: he's off the HUD")
		expect.isNil(DesktopHud.pishAt("bar", Config))
		assert(Config.CASH_SCALE < 1 and Config.CASH_SCALE >= 0.75, "a bit smaller, still easy to read")
		-- the toasts sit in the lower right, over the weapon dial when it's there
		local view = { w = 1366, h = 700 }
		local free = DesktopHud.toastCorner(view, 0, Config)
		expect.equal(free.x, view.w - Config.TOASTS.right)
		expect.equal(free.y, view.h - Config.TOASTS.bottom, "no dial: the corner itself")
		local over = DesktopHud.toastCorner(view, 130, Config)
		expect.equal(over.x, free.x)
		expect.equal(over.y, view.h - Config.TOASTS.bottom - 130 - Config.TOASTS.gap, "over the dial, never on it")
	end,
	-- Owner 2026-11-21: "move character info and level below the coin". In the column layout your row (face, shop
	-- level, XP, buffs) sits right under the cash at the top right; what follows in that column (the team strip, the
	-- Turts and event pills) starts under it
	["your row sits under the cash, and the rest of the column starts under your row"] = function()
		expect.equal(DesktopHud.meUnderCash("column"), true)
		expect.equal(DesktopHud.meUnderCash("bar"), false, "the bar layout keeps it beside the cash, in the top row")
		expect.equal(DesktopHud.meUnderCash(nil), false, "a phone has its own")
		local top = Config.TOP
		expect.equal(DesktopHud.columnStart(nil, 70, top.below), 70, "no top row showing: where it always started")
		expect.equal(DesktopHud.columnStart(30, 70, top.below), 70, "a short top row: still where it always started")
		expect.equal(DesktopHud.columnStart(96, 70, top.below), 96 + top.below, "under your row, never on it")
		assert(top.stack >= 2 and top.stack <= 12, "your row close under the cash")
		assert(top.below >= 8, "room for the line under the XP bar")
	end,
	-- Owner 2026-11-21: "Make the player avatar as small as the coin. then put the avatar beside the coin." The top
	-- right is two lines: your face and the cash, then your level, XP bar and buffs under them
	["your face is the coin's size and sits beside the cash"] = function()
		local coin = 54 -- HudLayout.STATUS_ICON
		local fit = DesktopHud.faceSize(coin, Config.CASH_SCALE, Config.FACE.ring)
		near(fit.hit, coin * Config.CASH_SCALE, "as big as the coin looks")
		near(fit.face + Config.FACE.ring * 2, fit.hit, "its white ring included")
		assert(fit.face >= 32, "still a face you can make out")
		expect.equal(DesktopHud.faceBesideCash("column"), true)
		expect.equal(DesktopHud.faceBesideCash("bar"), false, "the bar layout keeps your whole row together")
		expect.equal(DesktopHud.faceBesideCash(nil), false)
		assert(Config.FACE.rowHeight >= 30 and Config.FACE.rowHeight < 64, "the line under them only as tall as the bar and its badge")
	end,
}
