--!strict
-- The put-a-card-in windows' look (owner 2026-11-26, the redesign mockups: the Card Condenser, the Grading Station and
-- the Bulk Bin window; Config/StationLook): every word reads on what it sits on, and each window has its band
local ContrastRules = require("../src/shared/Util/ContrastRules")
local CreamTheme = require("../src/shared/Config/CreamTheme")
local StationLook = require("../src/shared/Config/StationLook")
local expect = require("./lib/expect")

local WHITE = { 255, 255, 255 }

local function reads(ink: { number }, fill: { number }, what: string)
	local ratio = ContrastRules.ratio(ink, fill)
	assert(ratio >= 4.5, `{what}: {math.floor(ratio * 100) / 100}:1, under 4.5:1`)
end

return {
	["each station's tabs read, on and off"] = function()
		for name, look in { CONDENSER = StationLook.CONDENSER, GRADING = StationLook.GRADING } do
			reads(look.tabInk, look.tabOn, `{name}: the chosen tab`)
			reads(CreamTheme.inkSoft, WHITE, `{name}: a tab not chosen`)
			reads(CreamTheme.ink, look.slot, `{name}: Put a card in, on the slot`)
			reads(CreamTheme.inkSoft, look.slot, `{name}: Tap to pick one, on the slot`)
			reads(look.tabInk, look.plus, `{name}: the slot's +`)
		end
	end,

	["badges, chips and tiles read"] = function()
		reads(StationLook.BADGE.ink, StationLook.BADGE.fill, "the Ready count and Ready!")
		reads(StationLook.FILLED.ink, StationLook.FILLED.fill, "Filled in for you")
		reads(StationLook.COUNT.ink, StationLook.COUNT.fill, "a Bulk Bin tile's xN")
		reads(StationLook.KEPT.ink, StationLook.KEPT.badge, "a Bulk Bin tile's Kept")
		reads(CreamTheme.ink, StationLook.USE_ON.fill, "a USE tile that's in")
		reads(CreamTheme.inkSoft, StationLook.USE_ON.fill, "a USE tile's small line")
		reads(CreamTheme.ink, StationLook.RECIPE_FILL, "the recipe box's sentence")
		reads(CreamTheme.inkSoft, StationLook.RECIPE_FILL, "the recipe box's small line")
	end,

	["each window has its own band: the Condenser pink, the Grading Station sky, the Bulk Bin mint"] = function()
		for _, band in { "Condenser", "Grading", "BulkBin" } do
			local colors = CreamTheme.headers[band]
			assert(colors and #colors.top == 3 and #colors.bottom == 3, band)
		end
		expect.equal(table.concat(CreamTheme.headers.Condenser.bottom, ","), table.concat(CreamTheme.headers.Bag.bottom, ","), "the Bag's pink")
		expect.equal(table.concat(CreamTheme.headers.BulkBin.bottom, ","), table.concat(CreamTheme.headers.Shop.bottom, ","), "the Shop's mint")
	end,

	["tap targets are finger-sized"] = function()
		assert(StationLook.TAB.hit >= 48, "a tab")
		assert(StationLook.BUTTON >= 48, "Change card, Not now")
	end,

	-- owner 2026-11-26: "put the arrow on the center and use a different arrow, not an emoji arrow"
	["the recipe's arrow is drawn in the middle of its room, with space each side"] = function()
		local arrow = StationLook.ARROW
		assert(arrow.room >= arrow.wide + 16, "at least 8 px either side of the arrow")
		assert(arrow.thick >= 3 and arrow.thick * 4 <= arrow.tall, "a bold line, its head taller than the line")
		expect.equal(#arrow.color, 3)
		for _, size in { StationLook.COPY_TILE.desktop, StationLook.COPY_TILE.phone } do
			assert(size[1] >= 48 and size[2] >= 48, "a copy tile is a finger-sized tap")
		end
		assert(StationLook.COPY_TILE.face.desktop[1] < StationLook.COPY_TILE.desktop[1], "the face fits its tile")
		assert(StationLook.COPY_TILE.face.phone[1] < StationLook.COPY_TILE.phone[1], "the face fits its tile")
	end,
}
