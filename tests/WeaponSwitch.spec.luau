--!strict
-- The quick weapon switch (spec 2026-11-07-weapons-round2-design 6): which weapons the chip steps through, in order
local WeaponSwitch = require("../src/shared/Util/WeaponSwitch")
local Weapons = require("../src/shared/Config/Weapons")
local expect = require("./lib/expect")

-- The catalogue with one weapon not built yet (every weapon is built since weapons round 3; the rule still matters for
-- the next round's)
local function unbuiltCopy(cfg: any, id: string): any
	local copy = table.clone(cfg)
	copy.ById = table.clone(cfg.ById)
	copy.WEAPONS = {}
	for _, weapon in cfg.WEAPONS do
		local entry = weapon
		if weapon.id == id then
			entry = table.clone(weapon)
			entry.ready = false
			copy.ById[id] = entry
		end
		table.insert(copy.WEAPONS, entry)
	end
	return copy
end

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
	-- owner 2026-11-12: "add a carousel effect which I can see whats next or previous weapon but smaller"
	["the carousel's neighbours: both with three or more, only the next with two, none with one"] = function()
		local before, after = WeaponSwitch.neighbours({ "a", "b", "c" }, "a")
		expect.equal(before, "c", "the one before wraps round")
		expect.equal(after, "b")
		local middleBefore, middleAfter = WeaponSwitch.neighbours({ "a", "b", "c", "d" }, "c")
		expect.equal(middleBefore, "b")
		expect.equal(middleAfter, "d")
		local twoBefore, twoAfter = WeaponSwitch.neighbours({ "a", "b" }, "a")
		expect.equal(twoBefore, nil, "two weapons: the other one shows once, on the right")
		expect.equal(twoAfter, "b")
		local oneBefore, oneAfter = WeaponSwitch.neighbours({ "a" }, "a")
		expect.equal(oneBefore == nil and oneAfter == nil, true, "one weapon: none")
		local _, unknownAfter = WeaponSwitch.neighbours({ "a", "b", "c" }, "z")
		expect.equal(unknownAfter, "b", "an unknown weapon counts as the first")
	end,

	-- spec 2026-11-12-timed-upgrades-revive-design: an item being upgraded is locked till done
	["a weapon in the Forge is out of the switch till it's back"] = function()
		local someOwnedId
		for _, weapon in Weapons.WEAPONS do
			if weapon.ready and weapon.id ~= Weapons.STARTER then
				someOwnedId = weapon.id
				break
			end
		end
		local owned = { [someOwnedId] = { grade = "B", level = 2 } }
		expect.equal(table.find(WeaponSwitch.list(Weapons, owned, true), someOwnedId) ~= nil, true, "owned: in the switch")
		expect.equal(table.find(WeaponSwitch.list(Weapons, owned, true, { [someOwnedId] = true }), someOwnedId), nil, "in the Forge: out")
	end,

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
		local list = WeaponSwitch.list(unbuiltCopy(Weapons, "riftReaper"), { riftReaper = {}, nothing = {} }, true)
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

	-- Weapons round 3: the scythes after the spears, the five Forge Scythes together, then by rarity
	["the scythes come after the spears, the Forge Scythes together, then by rarity"] = function()
		local owned = { riftReaper = {}, forgeScythe_Volt = {}, stormReaper = {}, forgeScythe_Ember = {}, widowsReaper = {}, forgeSpear_Tide = {} }
		local list = WeaponSwitch.list(readyCopy(Weapons), owned, true)
		-- the Forge Scythes by name: Electric before Fire since the plain element names (owner 2026-11-12)
		expect.equal(table.concat(list, ","), "starterSword,forgeSpear_Tide,forgeScythe_Volt,forgeScythe_Ember,widowsReaper,stormReaper,riftReaper")
	end,
}
