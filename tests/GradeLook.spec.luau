--!strict
-- A card's grade you notice (owner 2026-11-26: "Make grade more noticeable in general. when pulling a card, drops, etc.
-- in the binder, highgrade cards should be highlighted too", pick A "Medal + glow"; Config/GradeLook,
-- Shared/Util/GradeLook): the medal on the card's corner, the A and S glow, the pull's words and the drop's tag
local ContrastRules = require("../src/shared/Util/ContrastRules")
local GradeLook = require("../src/shared/Util/GradeLook")
local Look = require("../src/shared/Config/GradeLook")
local expect = require("./lib/expect")

local GRADES = { "C", "B", "A", "S" }
local WHITE = { 255, 255, 255 }
local EPSILON = 1e-9

local function reads(ink: { number }, fill: { number }, what: string)
	local ratio = ContrastRules.ratio(ink, fill)
	assert(ratio >= 4.5, `{what}: {math.floor(ratio * 100) / 100}:1, under 4.5:1`)
end

return {
	["the medal grows with the grade, C smallest and S biggest"] = function()
		for index = 2, #GRADES do
			local bigger, smaller = GRADES[index], GRADES[index - 1]
			assert(GradeLook.medal(Look, bigger).size > GradeLook.medal(Look, smaller).size, `{bigger} over {smaller}`)
		end
	end,

	["every medal sits inside the card's top-right corner (a 3D card and a scrolling list cut what's past the edge)"] = function()
		for _, grade in GRADES do
			local circle = GradeLook.medal(Look, grade)
			expect.near(circle.x + circle.size, 1 - Look.INSET, EPSILON, `{grade}: in from the right edge`)
			expect.near(circle.y, Look.INSET, EPSILON, `{grade}: in from the top edge`)
			assert(circle.x > 0.5, `{grade}: on the right half`)
			-- its picture holds the circle and its soft shadow, the circle in its middle
			local picture = GradeLook.picture(Look, grade)
			assert(picture.size > circle.size, `{grade}: the picture is bigger than its circle`)
			expect.near(picture.x + picture.size / 2, circle.x + circle.size / 2, EPSILON, `{grade}: centred across`)
			expect.near(picture.y + picture.size / 2, circle.y + circle.size / 2, EPSILON, `{grade}: centred down`)
		end
	end,

	["an unknown grade draws as C"] = function()
		expect.equal(GradeLook.medal(Look, "Z").size, Look.MEDAL.C)
	end,

	["the name stops short of the medal, with room for a name"] = function()
		for _, grade in GRADES do
			local width = GradeLook.nameWidth(Look, grade)
			assert(width >= 0.45, `{grade}: room for a name ({width})`)
			assert(Look.NAME.x + width + Look.NAME.gap <= GradeLook.medal(Look, grade).x + EPSILON, `{grade}: clear of the medal`)
		end
		assert(GradeLook.nameWidth(Look, "S") < GradeLook.nameWidth(Look, "C"), "a bigger medal leaves less room")
	end,

	["the Level chip hangs under the medal, centred on it and inside the card"] = function()
		for _, grade in GRADES do
			local circle = GradeLook.medal(Look, grade)
			local chip = GradeLook.level(Look, grade)
			expect.near(chip.y, circle.y + circle.size + Look.LEVEL.gap, EPSILON, `{grade}: just under the medal`)
			expect.near(chip.x + chip.w / 2, circle.x + circle.size / 2, EPSILON, `{grade}: centred on it`)
			assert(chip.x + chip.w <= 1 - Look.INSET + EPSILON, `{grade}: inside the card`)
		end
	end,

	["only A and S cards glow; S glows brighter, breathes and twinkles"] = function()
		expect.isNil(GradeLook.glow(Look, "C"), "C stays calm")
		expect.isNil(GradeLook.glow(Look, "B"), "B stays calm")
		local a, s = GradeLook.glow(Look, "A"), GradeLook.glow(Look, "S")
		assert(a and s, "A and S glow")
		expect.equal(a.pulse, 0, "A's glow holds still")
		expect.equal(a.twinkle, false, "A doesn't twinkle")
		assert(s.pulse > 0 and s.breath > 0, "S's glow breathes")
		assert(s.transparency + s.breath < 1, "S's glow never goes out")
		expect.equal(s.twinkle, true, "S twinkles")
		assert(s.transparency < a.transparency, "S glows brighter")
		for _, look in { a, s } do
			expect.equal(#look.color, 3)
			expect.equal(#look.ring, 3)
			assert(look.width > 0 and look.width < 0.05, "a thin ring")
		end
		assert(GradeLook.standsOut(Look, "A") and GradeLook.standsOut(Look, "S"), "A and S stand out")
		assert(not GradeLook.standsOut(Look, "B") and not GradeLook.standsOut(Look, "C"), "B and C don't")
	end,

	-- sizes as shares of the card (no pixels: a window's UIScale would scale them twice)
	["the glow reaches as far past every edge of the card, on any card's shape"] = function()
		for _, aspect in { 0.69, 1 / 1.4, 0.72 } do
			local wide, tall = GradeLook.glowSize(Look, aspect)
			local reach = Look.GLOW_PICTURE.reach
			expect.near((wide - 1) / 2, reach, EPSILON, "past the sides, in card widths")
			expect.near((tall - 1) / 2 / aspect, reach, EPSILON, "past the top and bottom, in card widths")
		end
	end,

	["the ring round an A or S card is as wide on every side, its corner the card's corner plus the ring"] = function()
		local aspect, corner = 1 / 1.4, 0.07
		for _, grade in { "A", "S" } do
			local glow = GradeLook.glow(Look, grade) :: any
			local wide, tall, round = GradeLook.ring(Look, grade, aspect, corner)
			expect.near((wide - 1) / 2, glow.width, EPSILON, `{grade}: its sides`)
			expect.near((tall - 1) / 2 / aspect, glow.width, EPSILON, `{grade}: its top and bottom`)
			-- UICorner's scale is of the shorter side: the ring's width
			expect.near(round * wide, corner + glow.width, EPSILON, `{grade}: its corner`)
		end
	end,

	["an S card's sparkles straddle its edges on a screen and come inside on a 3D surface"] = function()
		local left, right = GradeLook.sparkle(Look, 1, false), GradeLook.sparkle(Look, 2, false)
		assert(left.x < 0.05 and right.x > 0.95, "on the left and right edges, as the mockup")
		for index = 1, #Look.SPARKLES do
			local inside = GradeLook.sparkle(Look, index, true)
			assert(inside.x - inside.size / 2 >= 0 and inside.x + inside.size / 2 <= 1, `sparkle {index} inside`)
			expect.equal(inside.y, Look.SPARKLES[index].y)
		end
	end,

	["a pulled A or S card says it out loud; C and B don't"] = function()
		expect.equal(GradeLook.callout(Look, "A"), "GRADE A!")
		expect.equal(GradeLook.callout(Look, "S"), "GRADE S!")
		expect.isNil(GradeLook.callout(Look, "B"))
		expect.isNil(GradeLook.callout(Look, "C"))
		for _, grade in { "A", "S" } do
			local colours = Look.CALLOUT.looks[grade]
			reads(colours.ink, colours.top, `GRADE {grade}!, its pill's top`)
			reads(colours.ink, colours.bottom, `GRADE {grade}!, its pill's bottom`)
		end
		assert(Look.DING.pitch.S > Look.DING.pitch.A, "S dings higher")
		assert(string.find(Look.DING.id, "^rbxassetid://%d+$") ~= nil, "a sound id")
	end,

	["a dropped A or S card's tag names it and its grade; none for C and B"] = function()
		expect.equal(GradeLook.dropTag(Look, "Voidmaw", "A"), "Voidmaw · Grade A!")
		expect.equal(GradeLook.dropTag(Look, "Solarion", "S"), "Solarion · Grade S!")
		expect.isNil(GradeLook.dropTag(Look, "Mossmole", "B"))
		expect.isNil(GradeLook.dropTag(Look, "Mossmole", "C"))
		for _, grade in { "A", "S" } do
			reads(Look.DROP.ink[grade], WHITE, `a Grade {grade} drop's tag`)
		end
	end,

	["every grade has its medal picture; the glow and the sparkle have theirs"] = function()
		for _, grade in GRADES do
			assert(string.find(Look.IMAGES.medal[grade], "^rbxassetid://%d+$") ~= nil, `medal {grade}`)
		end
		assert(string.find(Look.IMAGES.glow, "^rbxassetid://%d+$") ~= nil, "the glow")
		assert(string.find(Look.IMAGES.sparkle, "^rbxassetid://%d+$") ~= nil, "the sparkle")
	end,
}
