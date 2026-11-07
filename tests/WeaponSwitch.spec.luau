--!strict
-- The quick weapon switch (spec 2026-11-07-weapons-round2-design 6): which weapons the chip steps through, in order
local WeaponSwitch = require("../src/shared/Util/WeaponSwitch")
local Weapons = require("../src/shared/Config/Weapons")
local expect = require("./lib/expect")

-- The catalogue with every weapon built (the spears aren't until their models are in)
local function readyCopy(cfg: any): any
	local copy = table.clone(cfg)
	copy.ById = {}
	copy.WEAPONS = {}
	for _, weapon in cfg.WEAPONS do
		local built = table.clone(weapon)
		built.ready = true
		copy.ById[built.id] = built
		table.insert(copy.WEAPONS, built)
	end
	return copy
end

return {
	["nothing to switch below the sword's shop level, or with only the Steel Sword"] = function()
		expect.equal(#WeaponSwitch.list(Weapons, {}, false), 0)
		local only = WeaponSwitch.list(Weapons, {}, true)
		expect.equal(#only, 1)
		expect.equal(only[1], "starterSword")
		expect.equal(WeaponSwitch.visible(only), false)
		expect.equal(WeaponSwitch.visible({ "starterSword", "verdantBlade" }), true)
	end,

	["weapons in order: swords, then spears, each by rarity then name"] = function()
		local list = WeaponSwitch.list(readyCopy(Weapons), { prismBlade = {}, forgeSpear_Tide = {}, forgeSpear_Ember = {}, verdantBlade = {}, titansLance = {} }, true)
		expect.equal(table.concat(list, ","), "starterSword,verdantBlade,prismBlade,forgeSpear_Ember,forgeSpear_Tide,titansLance")
	end,

	["not-ready and unknown weapons are left out"] = function()
		local list = WeaponSwitch.list(Weapons, { riftReaper = {}, nothing = {} }, true) -- a scythe: not built yet
		expect.equal(table.concat(list, ","), "starterSword")
	end,

	["stepping wraps both ways and an unknown weapon starts at the first"] = function()
		local list = { "a", "b", "c" }
		expect.equal(WeaponSwitch.step(list, "a", 1), "b")
		expect.equal(WeaponSwitch.step(list, "c", 1), "a")
		expect.equal(WeaponSwitch.step(list, "a", -1), "c")
		expect.equal(WeaponSwitch.step(list, "zzz", 1), "a")
		expect.equal(WeaponSwitch.step(list, nil, -1), "a")
		expect.isNil(WeaponSwitch.step({}, nil, 1))
	end,

	["equip sends: at once after a quiet spell, else when the server's cooldown (plus slack) has passed"] = function()
		local gap = Weapons.EQUIP_COOLDOWN + Weapons.EQUIP_SEND_SLACK
		expect.equal(gap > Weapons.EQUIP_COOLDOWN, true, "a little past the server's cooldown")
		expect.equal(WeaponSwitch.sendAt(10, nil, gap), 10, "the first send goes now")
		expect.equal(WeaponSwitch.sendAt(10, 10 - gap - 0.01, gap), 10, "long after the last one: now")
		expect.near(WeaponSwitch.sendAt(10, 9.8, gap), 9.8 + gap, 1e-9, "too soon: when the gap has passed")
	end,
}
