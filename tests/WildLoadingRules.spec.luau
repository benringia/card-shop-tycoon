--!strict
-- The Wild's loading screen (owner 2026-11-05: "make sure everything is loaded before player can walk in", look A)
local WildLoadingRules = require("../src/shared/Util/WildLoadingRules")
local WildLoading = require("../src/shared/Config/WildLoading")
local expect = require("./lib/expect")

local NONE = { ground = false, scenery = false, monsters = false, sounds = false }
local ALL = { ground = true, scenery = true, monsters = true, sounds = true }

return {
	["before you arrive: the first step, an empty bar, until the wait runs out"] = function()
		local step, share, finished = WildLoadingRules.progress(NONE, nil, 5, WildLoading)
		expect.equal(step, 1)
		expect.equal(share, 0)
		expect.equal(finished, false)
		local _, _, gaveUp = WildLoadingRules.progress(NONE, nil, WildLoading.WAIT_SECONDS, WildLoading)
		expect.equal(gaveUp, true, "nobody is stuck if the move never comes")
		local _, _, early = WildLoadingRules.progress(ALL, nil, 5, WildLoading)
		expect.equal(early, false, "never done before you've arrived")
	end,

	["the step follows the first thing still loading, so a later one finishing early doesn't jump the bar"] = function()
		local status = { ground = true, scenery = false, monsters = true, sounds = false }
		local step, share = WildLoadingRules.progress(status, 0.5, 2, WildLoading)
		expect.equal(step, 2)
		expect.near(share, 0.25, 1e-9)
		expect.equal(WildLoading.STEPS[step], "Growing the valley...")
	end,

	["all loaded: it closes once it has been up MIN_SECONDS"] = function()
		local step, share, finished = WildLoadingRules.progress(ALL, 0.1, 0.5, WildLoading)
		expect.equal(step, #WildLoading.STEPS + 1)
		expect.equal(share, 1)
		expect.equal(finished, false, "not a flash")
		local _, _, ready = WildLoadingRules.progress(ALL, 0.3, WildLoading.MIN_SECONDS, WildLoading)
		expect.equal(ready, true)
	end,

	["after you arrive it never holds you past MAX_SECONDS"] = function()
		local _, _, finished = WildLoadingRules.progress(NONE, WildLoading.MAX_SECONDS, WildLoading.MAX_SECONDS + 3, WildLoading)
		expect.equal(finished, true)
		local _, _, holding = WildLoadingRules.progress(NONE, WildLoading.MAX_SECONDS - 0.5, 4, WildLoading)
		expect.equal(holding, false)
	end,

	["one step per thing it waits for, and plain text"] = function()
		expect.equal(#WildLoading.STEPS, #WildLoadingRules.ORDER)
		expect.equal(WildLoading.MIN_SECONDS < WildLoading.MAX_SECONDS and WildLoading.MAX_SECONDS < WildLoading.WAIT_SECONDS, true)
		for _, line in { WildLoading.TITLE, WildLoading.READY, table.unpack(WildLoading.STEPS) } do
			assert(not string.find(line, "[^\32-\126]"), `plain ASCII: {line}`)
		end
		for _, line in WildLoading.TIPS do
			assert(not string.find(line, "[^\32-\126]"), `plain ASCII: {line}`)
		end
	end,
}
