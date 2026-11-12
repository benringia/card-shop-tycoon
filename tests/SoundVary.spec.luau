--!strict
-- Owner 2026-11-12: "randomize basic attack sound for pets. adjust pitch every attack, so that it doesnt feel repeating,
-- same with monster basic attack" (Util/SoundVary, used by Util/ElementFx.sound)
local SoundVary = require("../src/shared/Util/SoundVary")
local AttackFx = require("../src/shared/Config/AttackFx")
local expect = require("./lib/expect")

-- A repeatable roll
local function rolls(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

return {
	["never the same clip twice in a row"] = function()
		local roll = rolls(7)
		local last: number? = nil
		local seen = {}
		for _ = 1, 200 do
			local index = SoundVary.pick(3, last, roll)
			expect.equal(index >= 1 and index <= 3, true, "in the list")
			expect.equal(index ~= last, true, "not the last one again")
			seen[index] = true
			last = index
		end
		expect.equal(seen[1] and seen[2] and seen[3], true, "every clip comes up")
		expect.equal(SoundVary.pick(1, 1, roll), 1, "one clip: that one")
	end,

	["each pitch differs from the last by at least the gap, inside the range"] = function()
		local roll = rolls(11)
		local range, gap = { 0.8, 1.2 }, 0.08
		local last: number? = nil
		for _ = 1, 300 do
			local pitch = SoundVary.pitch(range, last, gap, roll)
			expect.equal(pitch >= range[1] - 1e-9 and pitch <= range[2] + 1e-9, true, `in range ({pitch})`)
			if last then
				expect.equal(math.abs(pitch - last) >= gap - 1e-9, true, `apart from the last ({last} -> {pitch})`)
			end
			last = pitch
		end
	end,

	["every basic attack has a few clips to pick from, and a wider pitch range"] = function()
		for element, sounds in AttackFx.SOUNDS do
			if typeof(sounds) == "table" and sounds.hit then
				expect.equal(typeof(sounds.hit) == "table" and #sounds.hit >= 3, true, `{element}'s hit`)
			end
		end
		for species, spec in AttackFx.MONSTER do
			expect.equal(typeof(spec.sounds.strike) == "table" and #spec.sounds.strike >= 3, true, `{species}'s strike`)
		end
		expect.equal(AttackFx.VARY.pitch[2] - AttackFx.VARY.pitch[1] >= 0.4, true, "a wider pitch range than 0.85-1.15")
	end,
}
