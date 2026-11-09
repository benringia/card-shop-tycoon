--!strict
-- Thousand Cuts' slashes across your own screen (owner 2026-11-09: "the slashes are hard to see. can add the slashes
-- and flashes across the screen"): where each wave's lines cross the screen and the harvest's X
local ScreenSlashRules = require("../src/shared/Util/ScreenSlashRules")
local SwordSkillFx = require("../src/shared/Config/SwordSkillFx")
local expect = require("./lib/expect")

-- A fixed sequence standing in for math.random
local function sequence(values: { number }): () -> number
	local index = 0
	return function(): number
		index = index % #values + 1
		return values[index]
	end
end

return {
	["a wave's slashes cross the middle of the screen, longer than the screen, spread over every angle"] = function()
		local slashes = ScreenSlashRules.wave(5, sequence({ 0, 0.5, 1, 0.25, 0.75 }))
		expect.equal(#slashes, 5)
		for _, slash in slashes do
			expect.equal(slash.x >= 0.15 and slash.x <= 0.85, true, `x {slash.x}`)
			expect.equal(slash.y >= 0.15 and slash.y <= 0.85, true, `y {slash.y}`)
			expect.equal(slash.length >= 1, true, "past the screen's edges")
		end
		local angles = {}
		for _, slash in slashes do
			table.insert(angles, slash.angle % 180)
		end
		table.sort(angles)
		for index = 2, #angles do
			expect.equal(angles[index] - angles[index - 1] >= 15, true, "no two nearly parallel")
		end
		expect.equal(angles[1] + 180 - angles[#angles] >= 15, true, "nor round the wrap")
	end,

	["the harvest's X: two long slashes crossing at the middle"] = function()
		local cross = ScreenSlashRules.cross()
		expect.equal(#cross, 2)
		for _, slash in cross do
			expect.equal(slash.x, 0.5)
			expect.equal(slash.y, 0.5)
			expect.equal(slash.length >= 1.2, true)
		end
		expect.equal(cross[1].angle * cross[2].angle < 0, true, "one each way")
	end,

	["the screen's slashes and flashes are set: a few a wave, a brighter flash on the harvest"] = function()
		local screen = SwordSkillFx.SCREEN
		expect.equal(screen.perWave >= 3, true)
		expect.equal(screen.flash > 0 and screen.flash < screen.hitFlash and screen.hitFlash <= 1, true)
		expect.equal(screen.draw > 0 and screen.hold > 0 and screen.flashSeconds > 0, true)
		expect.equal(screen.core < screen.thick, true, "a white core inside the glow")
	end,
}
