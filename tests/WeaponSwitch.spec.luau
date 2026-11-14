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
	-- owner 2026-11-12: "add a carousel effect which I can see whats next or previous weapon but smaller"; owner
	-- 2026-11-14 pick C (the medallion dial): the one before on the left, the next on top, the one after it between
	["the dial's track: before and next with three or more, the one after next with four, only the next with two"] = function()
		local three = WeaponSwitch.track({ "a", "b", "c" }, "a")
		expect.equal(three.before, "c", "the one before wraps round")
		expect.equal(three.after, "b")
		expect.equal(three.later, nil, "three weapons: the one after next is the one before")
		local four = WeaponSwitch.track({ "a", "b", "c", "d" }, "c")
		expect.equal(four.before, "b")
		expect.equal(four.after, "d")
		expect.equal(four.later, "a", "four weapons: the one after next, wrapping round")
		local two = WeaponSwitch.track({ "a", "b" }, "a")
		expect.equal(two.before, nil, "two weapons: the other one shows once, as the next")
		expect.equal(two.after, "b")
		expect.equal(two.later, nil)
		local one = WeaponSwitch.track({ "a" }, "a")
		expect.equal(one.before == nil and one.after == nil and one.later == nil, true, "one weapon: none")
		expect.equal(WeaponSwitch.track({ "a", "b", "c" }, "z").after, "b", "an unknown weapon counts as the first")
	end,

	-- the dial rolls (owner 2026-11-14): each weapon starts where it was (the medallion, another spot) and moves to its
	-- new spot; one that wasn't showing fades in where it lands
	["the dial's roll: each weapon starts where it was"] = function()
		local list = { "a", "b", "c", "d", "e" }
		local forward = WeaponSwitch.roll(list, "b", "c")
		expect.equal(forward.current, "after", "the next weapon comes in from the top")
		expect.equal(forward.before, "center", "the old one leaves the medallion for the left")
		expect.equal(forward.after, "later", "the one after next moves up")
		expect.equal(forward.later, nil, "a new one fades in")
		local back = WeaponSwitch.roll(list, "b", "a")
		expect.equal(back.current, "before", "the one before comes in from the left")
		expect.equal(back.after, "center")
		expect.equal(back.later, "after")
		expect.equal(back.before, nil)
		local threeList = { "a", "b", "c" }
		local around = WeaponSwitch.roll(threeList, "b", "c")
		expect.equal(around.after, "before", "three weapons: the one on the left rolls round to the top")
		expect.equal(around.before, "center")
		local two = WeaponSwitch.roll({ "a", "b" }, "a", "b")
		expect.equal(two.current, "after")
		expect.equal(two.after, "center", "two weapons: they swap")
		local same = WeaponSwitch.roll(list, "b", "b")
		expect.equal(same.current, "center", "no switch: nothing moves")
		expect.equal(same.before, "before")
		expect.equal(same.after, "after")
		expect.equal(same.later, "later")
	end,

	["a spot on the dial: degrees round the medallion, y down the screen"] = function()
		local x, y = WeaponSwitch.arcPoint(180, 70)
		expect.near(x, -70, 1e-6, "180: left")
		expect.near(y, 0, 1e-6)
		x, y = WeaponSwitch.arcPoint(90, 70)
		expect.near(x, 0, 1e-6, "90: straight up")
		expect.near(y, -70, 1e-6)
		x, y = WeaponSwitch.arcPoint(135, 10)
		expect.near(x, -10 * math.sqrt(0.5), 1e-6, "135: up and left")
		expect.near(y, -10 * math.sqrt(0.5), 1e-6)
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
