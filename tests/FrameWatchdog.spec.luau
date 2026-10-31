--!strict
-- The frame watchdog (Portal Worlds spec): turns the town's extras (tree sway, animals, butterflies) off after a stretch
-- of slow frames and back on only after a longer fast stretch. Numbers in Config/Ambient.
local ambient = require("../src/shared/Config/Ambient")
local town = require("../src/shared/Config/Town")
local FrameWatchdog = require("../src/shared/Util/FrameWatchdog")
local expect = require("./lib/expect")

-- A watchdog past its warm-up (the loading seconds after joining, which never count)
local function warmed()
	local dog = FrameWatchdog.new(ambient.WATCHDOG)
	for _ = 1, ambient.WATCHDOG.WARMUP_SECONDS * 60 do
		dog:push(1 / 60)
	end
	return dog
end

return {
	["the loading seconds after joining don't switch the extras off"] = function()
		local dog = FrameWatchdog.new(ambient.WATCHDOG)
		assert(ambient.WATCHDOG.WARMUP_SECONDS >= 10, "long enough to cover the join's loading")
		for _ = 1, ambient.WATCHDOG.WARMUP_SECONDS * 30 do
			dog:push(1 / 30)
		end
		expect.equal(dog.on, true, "slow loading frames aren't a slow device")
		for _ = 1, 3 * 30 do
			dog:push(1 / 30)
		end
		expect.equal(dog.on, false, "slow frames after the warm-up still count")
	end,

	["extras switch off after 3 s of slow frames"] = function()
		local dog = warmed()
		expect.equal(dog.on, true, "on to start with")
		for _ = 1, 3 * 30 do
			dog:push(1 / 30)
		end
		expect.equal(dog.on, false, "off after a slow stretch")
	end,

	["a short hitch doesn't switch them off"] = function()
		local dog = warmed()
		for _ = 1, 10 do
			dog:push(1 / 20)
		end
		for _ = 1, 120 do
			dog:push(1 / 60)
		end
		expect.equal(dog.on, true, "still on")
	end,

	["they come back only after 10 s of fast frames"] = function()
		local dog = warmed()
		for _ = 1, 3 * 30 do
			dog:push(1 / 30)
		end
		for _ = 1, 5 * 60 do
			dog:push(1 / 60)
		end
		expect.equal(dog.on, false, "not yet")
		for _ = 1, 6 * 60 do
			dog:push(1 / 60)
		end
		expect.equal(dog.on, true, "back on")
	end,

	["one huge frame (a loading hitch) is ignored"] = function()
		local dog = warmed()
		dog:push(5)
		for _ = 1, 60 do
			dog:push(1 / 60)
		end
		expect.equal(dog.on, true, "a single stall isn't a slow stretch")
	end,

	["butterflies stay within the agreed number"] = function()
		local total = 0
		for _, spot in town.BUTTERFLIES.SPOTS do
			total += spot.count
		end
		assert(total <= 20, `{total} butterflies`)
		assert(#town.BUTTERFLIES.SPOTS >= 3, "the plaza and along the trails")
	end,

	["sway is gentle and runs near the camera only"] = function()
		local sway = ambient.SWAY
		assert(sway.ANGLE <= 0.05, "a big sway")
		assert(sway.RANGE <= 150 and sway.HZ <= 30, "sway range and rate within the measured budget")
	end,
}
