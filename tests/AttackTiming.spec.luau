--!strict
local AttackTiming = require("../src/shared/Util/AttackTiming")
local AttackFx = require("../src/shared/Config/AttackFx")
local expect = require("./lib/expect")

return {
	["a charge releases so the effect lands with the hit"] = function()
		local t = AttackTiming.schedule(0.6, 0.35)
		expect.near(t.releaseIn, 0.25, 1e-9)
		expect.equal(t.impactIn, 0.6)
	end,

	["a short charge releases at once and flies faster"] = function()
		local t = AttackTiming.schedule(0.2, 0.35)
		expect.equal(t.releaseIn, 0)
		expect.equal(t.impactIn, 0.2)
	end,

	["no charge at all: an instant strike"] = function()
		local t = AttackTiming.schedule(0, 0.35)
		expect.equal(t.releaseIn, 0)
		expect.equal(t.impactIn, 0)
	end,

	["a charge with no attack expires after its grace"] = function()
		expect.equal(AttackFx.CHARGE_GRACE, 0.3)
		expect.equal(AttackTiming.expired(10, 0.6, 10.85, 0.3), false)
		expect.equal(AttackTiming.expired(10, 0.6, 10.91, 0.3), true)
	end,

	["a combo's hits spread over its window, the last at the end"] = function()
		local times = AttackTiming.comboTimes(3, 0.45)
		expect.equal(#times, 3)
		expect.near(times[1], 0.15, 1e-9)
		expect.near(times[2], 0.3, 1e-9)
		expect.near(times[3], 0.45, 1e-9)
		expect.equal(#AttackTiming.comboTimes(0, 0.45), 0)
	end,

	["every element has a known attack kind"] = function()
		local known = { projectile = true, combo = true, bolt = true, slash = true }
		for _, element in { "Ember", "Tide", "Bloom", "Volt", "Shade" } do
			local entry = AttackFx.ELEMENT[element]
			expect.equal(entry ~= nil and known[entry.kind] == true, true, element)
		end
		expect.equal(AttackFx.ELEMENT.Ember.kind, "projectile")
		expect.equal(AttackFx.ELEMENT.Bloom.kind, "combo")
		expect.equal(AttackFx.ELEMENT.Volt.kind, "bolt") -- shot from where it stands (the owner's mockup), no dash
		-- A crescent of dark purple moonlight flung at the foe (owner 2026-11-05), flying like a projectile
		expect.equal(AttackFx.ELEMENT.Shade.kind, "slash")
		expect.equal(AttackFx.FLIGHT.Shade ~= nil and AttackFx.FLIGHT.Shade > 0, true, "it flies a while")
		expect.equal(AttackFx.SOUNDS.Shade.release ~= nil, true, "a whoosh as it's flung")
		local c = AttackFx.ELEMENT.Shade.color
		expect.equal(c[1] < 150 and c[3] > c[1] and c[3] > c[2], true, "dark purple")
	end,
}
