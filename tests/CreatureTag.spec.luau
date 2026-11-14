--!strict
-- A summoned creature's name tag (owner 2026-11-14: "search internet on how successful games show their summon's name
-- stars grade and etc and get an idea, then rework the pet display names", option B of three: the gacha title). The
-- stars crown the name, the name big in its rarity colour, a pill under it with the element, level and grade; the
-- owner's name small on top, only on other players' creatures.
local CreatureTag = require("../src/shared/Util/CreatureTag")
local Party = require("../src/shared/Config/Party")
local expect = require("./lib/expect")

local TAG = Party.TAG

local function input(over: { [string]: any }?): CreatureTag.Input
	local base: { [string]: any } = { cardName = "Solarion", level = 30, stars = 5, grade = "S", foil = false, ownerName = "n0gginss", mine = false, maxStars = 5 }
	for key, value in over or {} do
		base[key] = value
	end
	return base :: any
end

return {
	["your own creature's tag never repeats your name; another's shows its owner"] = function()
		expect.isNil(CreatureTag.info(input({ mine = true })).owner, "yours: no owner line")
		expect.equal(CreatureTag.info(input()).owner, "n0gginss", "a friend's: their name")
		local gone = input()
		gone.ownerName = nil
		expect.isNil(CreatureTag.info(gone).owner, "an owner who left: none")
	end,

	["the stars show earned and faint ones out of the most there can be"] = function()
		local info = CreatureTag.info(input({ stars = 3 }))
		expect.equal(info.stars, 3)
		expect.equal(info.emptyStars, 2, "3 of 5: two faint")
		expect.equal(CreatureTag.info(input({ stars = 9 })).stars, 5, "never more than the most")
		expect.equal(CreatureTag.info(input({ stars = -1 })).stars, 0, "never fewer than none")
		expect.equal(CreatureTag.info(input({ stars = "x" })).emptyStars, 5, "no stars yet: five faint ones")
	end,

	["level, grade and name fall back to plain values"] = function()
		local bare = input({ grade = "Z" })
		bare.level, bare.cardName = nil, nil
		local info = CreatureTag.info(bare)
		expect.equal(info.level, "Lv 1")
		expect.equal(info.grade, "C", "an unknown grade reads C")
		expect.equal(info.name, "Creature")
		expect.equal(CreatureTag.info(input()).level, "Lv 30")
		expect.equal(CreatureTag.info(input({ level = 12.7 })).level, "Lv 12", "whole levels")
		expect.equal(CreatureTag.info(input({ grade = "A" })).grade, "A")
	end,

	["the tag grows up from where the old one's bottom was, the heal pill above it"] = function()
		assert(TAG, "Party.TAG")
		local height = CreatureTag.height(TAG)
		expect.equal(height, TAG.OWNER + TAG.STARS + TAG.NAME + TAG.PILL + 3 * TAG.GAP, "its rows and gaps")
		-- SizeOffset moves a billboard by fractions of its size: the bottom stays BELOW pixels under its point
		local lift = CreatureTag.lift(TAG)
		expect.near(height / 2 - lift * height, TAG.BELOW, 1e-9, "the bottom BELOW pixels under its point")
		-- the heal pill (HEAL_PILL tall) sits on the tag's top, its own point the same
		local healLift = CreatureTag.healLift(TAG)
		local pillBottom = healLift * TAG.HEAL_PILL - TAG.HEAL_PILL / 2
		expect.near(pillBottom, height - TAG.BELOW + TAG.GAP, 1e-9, "just above the tag's top")
		assert(TAG.WIDTH >= 200, "wide enough for Tideborne Kirin")
	end,
}
