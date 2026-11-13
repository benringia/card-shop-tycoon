--!strict
-- The pack opening's reveal sounds (owner 2026-11-13: "change the opening card sound effects to be more premium
-- sounding? specially when you got rare cards and above"): a stack per rarity, a riser swelling into the flip and
-- layered hits, bigger the rarer the card (Config/RevealSounds, Util/RevealSoundRules)
local RevealSounds = require("../src/shared/Config/RevealSounds")
local RevealSoundRules = require("../src/shared/Util/RevealSoundRules")
local expect = require("./lib/expect")

local ORDER = { "Rare", "Very Rare", "Epic", "Legendary" }

local function layers(stack: RevealSoundRules.Stack?): number
	return if stack then #stack.hit else 0
end

return {
	["a Common flips plainly; every Rare-or-better card gets a riser and layered hits"] = function()
		expect.equal(RevealSoundRules.stack(RevealSounds, "Common", false, false), nil)
		for _, rarity in ORDER do
			local stack = RevealSoundRules.stack(RevealSounds, rarity, false, false)
			assert(stack, `{rarity} has a stack`)
			assert(stack.riser, `{rarity} swells into the flip`)
			assert(#stack.hit >= 2, `{rarity} hits with layers`)
		end
		assert(RevealSoundRules.stack(RevealSounds, "Legendary", false, true), "a Frontier card too")
	end,

	["the rarer the card, the bigger its hit, and no two rarities sound the same"] = function()
		local seen: { [string]: string } = {}
		for index, rarity in ORDER do
			local stack = RevealSoundRules.stack(RevealSounds, rarity, false, false) :: RevealSoundRules.Stack
			if index > 1 then
				local below = RevealSoundRules.stack(RevealSounds, ORDER[index - 1], false, false)
				assert(layers(stack) >= layers(below), `{rarity} has fewer layers than {ORDER[index - 1]}`)
			end
			local main = stack.hit[1].id
			expect.equal(seen[main], nil, `{rarity}'s hit is {seen[main]}'s`)
			seen[main] = rarity
		end
	end,

	["a foil card adds its shimmer on top"] = function()
		local plain = RevealSoundRules.stack(RevealSounds, "Rare", false, false) :: RevealSoundRules.Stack
		local foil = RevealSoundRules.stack(RevealSounds, "Rare", true, false) :: RevealSoundRules.Stack
		expect.equal(#foil.hit, #plain.hit + #RevealSounds.FOIL)
		local commonFoil = RevealSoundRules.stack(RevealSounds, "Common", true, false)
		assert(commonFoil and #commonFoil.hit == #RevealSounds.FOIL, "a foil Common: the shimmer")
		expect.equal(commonFoil.riser, RevealSounds.BY_RARITY[RevealSounds.FOIL_RISER].riser, "and a swell into its flip (it's teased too)")
	end,

	["the riser peaks as the card lands: it starts that far into the sound, or waits"] = function()
		local early = RevealSoundRules.riserTiming(3, 0.88)
		expect.near(early.startAt, 2.12, 1e-9, "the last 0.88 s of a 3 s swell")
		expect.equal(early.delay, 0)
		local late = RevealSoundRules.riserTiming(1, 2.5)
		expect.equal(late.startAt, 0)
		expect.near(late.delay, 1.5, 1e-9, "a short swell waits, so it still peaks on the hit")
	end,

	["every sound is a Roblox asset at a sensible volume"] = function()
		-- owner 2026-11-13: "lower music/sound volume": the whole reveal plays quieter, rarities still apart
		assert(RevealSounds.MASTER > 0 and RevealSounds.MASTER < 1, "a master below full")
		for _, rarity in ORDER do
			local stack = RevealSoundRules.stack(RevealSounds, rarity, true, false) :: RevealSoundRules.Stack
			local sounds: { any } = table.clone(stack.hit)
			table.insert(sounds, stack.riser)
			for _, sound in sounds do
				assert(string.match(sound.id, "^rbxassetid://%d+$"), `{rarity}: {sound.id}`)
				assert(sound.volume > 0 and sound.volume <= 0.6, `{rarity}: volume {sound.volume}`)
				assert(sound.loud > 0, `{rarity}: {sound.id} has a measured loudness`)
			end
		end
	end,

	-- Measured in Studio (Config/RevealSounds `loud`): the old Rare chime barely sounded; now every step up is louder,
	-- and a Legendary stays short of deafening
	["heard loudness climbs Rare, Very Rare, Epic, Legendary, and every Rare-or-better hit is clearly heard"] = function()
		local last = 0
		for _, rarity in ORDER do
			local heard = RevealSoundRules.heard(RevealSounds.BY_RARITY[rarity].hit)
			assert(heard > last, `{rarity} ({heard}) isn't louder than the one below ({last})`)
			assert(heard >= 120, `{rarity} is too quiet ({heard})`)
			last = heard
		end
		assert(last <= 520, `the Legendary is too loud ({last})`)
		expect.near(RevealSoundRules.heard({ { id = "x", volume = 0.5, loud = 100 }, { id = "y", volume = 0.2, loud = 50 } }), 60, 1e-9)
	end,
}
