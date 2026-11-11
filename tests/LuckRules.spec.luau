--!strict
-- Pish's Luck and the gift's floor (spec 2026-11-09-tutorial-pish-design 5, 7): a pack's hit slot raised for luck,
-- floored for the gift, and luck at most once per cooldown
local LuckRules = require("../src/shared/Util/LuckRules")
local PackOdds = require("../src/shared/Config/PackOdds")
local Pish = require("../src/shared/Config/Pish")
local expect = require("./lib/expect")

local HIT = PackOdds.SLOTS.FirstSparkPack[5]
local RANK = PackOdds.RANK

local function weightOf(slot: { { rarity: string, weight: number } }, rarity: string): number?
	for _, option in slot do
		if option.rarity == rarity then
			return option.weight
		end
	end
	return nil
end

local function total(slot: { { rarity: string, weight: number } }): number
	local sum = 0
	for _, option in slot do
		sum += option.weight
	end
	return sum
end

return {
	["the spec's numbers: 3 minutes, once per 15, +25% from Very Rare"] = function()
		expect.equal(Pish.LUCK.seconds, 180)
		expect.equal(Pish.LUCK.cooldown, 900)
		expect.equal(Pish.LUCK.boost, 0.25)
		expect.equal(Pish.LUCK.fromRarity, "Very Rare")
	end,

	["boost: +25% on Very Rare and up, Rare gives up the difference"] = function()
		local slot = LuckRules.boost(HIT, RANK, "Very Rare", 0.25)
		expect.near(weightOf(slot, "Very Rare") :: number, 0.1875, 1e-9)
		expect.near(weightOf(slot, "Epic") :: number, 0.175, 1e-9)
		expect.near(weightOf(slot, "Legendary") :: number, 0.0125, 1e-9)
		expect.near(weightOf(slot, "Rare") :: number, 0.625, 1e-9)
		expect.near(total(slot), 1, 1e-9)
		expect.near(weightOf(HIT, "Rare") :: number, 0.7, 1e-12, "the config's slot isn't changed")
	end,

	["boost: a slot with nothing below Very Rare stays as it was"] = function()
		local slot = LuckRules.boost({ { rarity = "Epic", weight = 1 } }, RANK, "Very Rare", 0.25)
		expect.equal(#slot, 1)
		expect.near(slot[1].weight, 1, 1e-12)
	end,

	["boost: the lowest rarity never goes below nothing"] = function()
		local slot = LuckRules.boost({ { rarity = "Rare", weight = 0.01 }, { rarity = "Epic", weight = 0.99 } }, RANK, "Very Rare", 0.25)
		expect.equal(weightOf(slot, "Rare"), 0)
	end,

	["atLeast: Very Rare or better"] = function()
		local slot = LuckRules.atLeast(HIT, RANK, "Very Rare")
		expect.equal(#slot, 3)
		expect.equal(weightOf(slot, "Rare"), nil)
		expect.near(weightOf(slot, "Very Rare") :: number, 0.15, 1e-12)
		expect.near(weightOf(slot, "Epic") :: number, 0.14, 1e-12)
		expect.near(weightOf(slot, "Legendary") :: number, 0.01, 1e-12)
		local none = LuckRules.atLeast({ { rarity = "Common", weight = 1 } }, RANK, "Very Rare")
		expect.equal(#none, 1)
		expect.equal(none[1].rarity, "Very Rare")
		expect.equal(none[1].weight, 1)
	end,

	["canGrant: once per cooldown"] = function()
		expect.equal(LuckRules.canGrant(nil, 1000, 900), false, "not loaded yet: the saved time could still say no (final review I1)")
		expect.equal(LuckRules.canGrant(0, 1000, 900), true, "never had it")
		expect.equal(LuckRules.canGrant(500, 1000, 900), false)
		expect.equal(LuckRules.canGrant(100, 1000, 900), true)
	end,

	["badgeText: a clover and m:ss counting up to whole seconds, nil once it's over"] = function()
		expect.equal(LuckRules.badgeText(1180, 1000), "🍀 3:00")
		expect.equal(LuckRules.badgeText(1125.4, 1000), "🍀 2:06", "part of a second still shows as a second")
		expect.equal(LuckRules.badgeText(1009, 1000), "🍀 0:09")
		expect.equal(LuckRules.badgeText(1000, 1000), nil)
		expect.equal(LuckRules.badgeText(nil, 1000), nil)
		expect.equal(LuckRules.badgeText(1180, 1000, "💪"), "💪 3:00", "Chikin's Courage: its own icon")
	end,

	["left: seconds of luck left, never below 0"] = function()
		expect.equal(LuckRules.left(1180, 1000), 180)
		expect.equal(LuckRules.left(900, 1000), 0)
		expect.equal(LuckRules.left(nil, 1000), 0)
	end,
}
