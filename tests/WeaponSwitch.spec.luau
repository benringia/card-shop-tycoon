--!strict
-- The quick weapon switch (spec 2026-11-07-weapons-round2-design 6): which weapons the chip steps through, in order
local WeaponSwitch = require("../src/shared/Util/WeaponSwitch")
local Weapons = require("../src/shared/Config/Weapons")
local Mutations = require("../src/shared/Config/Mutations")
local expect = require("./lib/expect")
local fs = require("@lune/fs")

-- Config/HudLayout WEAPON_SWITCH's numbers, read from its source (it needs Roblox to load), its comments left out
local function switchLook(): { [string]: number }
	local source = (string.gsub(fs.readFile("src/shared/Config/HudLayout.luau"), "\r", ""))
	local block = string.match(source, "WEAPON_SWITCH = (%b{})")
	assert(block, "Config/HudLayout has WEAPON_SWITCH")
	block = string.gsub(block, "%-%-[^\n]*", "")
	local look = {}
	for key, value in string.gmatch(block, "([%a_][%w_]*)%s*=%s*(%-?[%d%.]+)") do
		look[key] = tonumber(value)
	end
	return look
end

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
	-- 2026-11-27 pick B (the row, twin of the party dock): the one before on the left, the next on the right, no more
	["the row: the one before and the next with three or more, only the next with two, nothing more"] = function()
		local three = WeaponSwitch.track({ "a", "b", "c" }, "a")
		expect.equal(three.before, "c", "the one before wraps round")
		expect.equal(three.after, "b")
		local four = WeaponSwitch.track({ "a", "b", "c", "d" }, "c")
		expect.equal(four.before, "b")
		expect.equal(four.after, "d")
		expect.equal((four :: any).later, nil, "no faded fourth weapon (owner 2026-11-27, pick B)")
		local two = WeaponSwitch.track({ "a", "b" }, "a")
		expect.equal(two.before, nil, "two weapons: the other one shows once, as the next")
		expect.equal(two.after, "b")
		local one = WeaponSwitch.track({ "a" }, "a")
		expect.equal(one.before == nil and one.after == nil, true, "one weapon: none")
		expect.equal(WeaponSwitch.track({ "a", "b", "c" }, "z").after, "b", "an unknown weapon counts as the first")
	end,

	-- the row slides a step: each weapon starts where it was (the middle, a side) and moves to its new spot; one that
	-- wasn't showing fades in where it lands
	["the row's slide: each weapon starts where it was"] = function()
		local list = { "a", "b", "c", "d", "e" }
		local forward = WeaponSwitch.roll(list, "b", "c")
		expect.equal(forward.current, "after", "the next weapon comes in from the right")
		expect.equal(forward.before, "center", "the old one leaves the middle for the left")
		expect.equal(forward.after, nil, "a new one fades in on the right")
		expect.equal((forward :: any).later, nil)
		local back = WeaponSwitch.roll(list, "b", "a")
		expect.equal(back.current, "before", "the one before comes in from the left")
		expect.equal(back.after, "center")
		expect.equal(back.before, nil)
		local around = WeaponSwitch.roll({ "a", "b", "c" }, "b", "c")
		expect.equal(around.after, "before", "three weapons: the one on the left goes round to the right")
		expect.equal(around.before, "center")
		local two = WeaponSwitch.roll({ "a", "b" }, "a", "b")
		expect.equal(two.current, "after")
		expect.equal(two.after, "center", "two weapons: they swap")
		local same = WeaponSwitch.roll(list, "b", "b")
		expect.equal(same.current, "center", "no switch: nothing moves")
		expect.equal(same.before, "before")
		expect.equal(same.after, "after")
	end,

	-- the sides beside the weapon in hand: `row` px off its edge, a little lower (`drop`), like the party dock
	["a side of the row: beside the middle, a little lower"] = function()
		local look = { chip = 72, side = 44, row = 8, drop = 8 }
		local x, y = WeaponSwitch.rowSpot("before", look)
		expect.near(x, -66, 1e-6, "left: half the big one, the gap, half the small one")
		expect.near(y, 8, 1e-6, "a little lower")
		x, y = WeaponSwitch.rowSpot("after", look)
		expect.near(x, 66, 1e-6, "right")
		expect.near(y, 8, 1e-6)
		x, y = WeaponSwitch.rowSpot("center", look)
		expect.equal(x == 0 and y == 0, true, "the middle")
	end,

	-- the medallion's top edge (owner 2026-11-28: "make sure no overlapping elements"; the level pill touched both
	-- badges on a phone's 64 px medallion): the grade's medal, the level's pill ("+10" its widest) and the mutation's
	-- mark `topGap` px apart counting the pill's and the mark's white outlines, on a computer's medallion and a phone's;
	-- the badges in step with the medallion's size and still reaching onto its ring, never floating off it
	["the medallion's top: the grade medal, the level pill and the mutation mark never touch"] = function()
		local look = switchLook()
		local markEdge = Mutations.CHIP.mark.edge
		for _, chip in { look.chip, look.compactChip } do
			local top = WeaponSwitch.chipTop(chip, look :: any, markEdge)
			local where = `a {chip} px medallion`
			local pillLeft = chip / 2 - look.pill / 2 - look.pillEdge
			local pillRight = chip / 2 + look.pill / 2 + look.pillEdge
			local medalRight = -top.x + top.badge -- an image, no outline
			local markLeft = chip + top.x - top.badge - markEdge
			assert(pillLeft - medalRight >= look.topGap - 1e-6, `{where}: the medal ends at {medalRight}, the pill starts at {pillLeft}`)
			assert(markLeft - pillRight >= look.topGap - 1e-6, `{where}: the pill ends at {pillRight}, the mark starts at {markLeft}`)
			expect.near(top.badge, look.medal * chip / look.chip, 1e-6, `{where}: the badges in step with the medallion`)
			expect.equal(top.y, look.overhang, `{where}: as high as ever`)
			local r = chip / 2
			local innerX, innerY = -top.x + top.badge, -top.y + top.badge
			local reach = r - math.sqrt((innerX - r) ^ 2 + (innerY - r) ^ 2)
			assert(reach >= 4, `{where}: the medal's inner corner {reach} px onto the medallion`)
		end
	end,

	-- the row's box (UiLayout.switchBox) holds what stands over the medallion: the level pill with its outline, the badges
	["the row's box holds the level pill and the badges over the medallion"] = function()
		local look = switchLook()
		assert(look.rise >= look.pillHeight / 2 + look.pillEdge, `rise {look.rise}: the pill reaches {look.pillHeight / 2 + look.pillEdge} over`)
		assert(look.rise >= look.overhang, `rise {look.rise}: the badges reach {look.overhang} over`)
	end,

	-- a phone's medallion swipes: its chevrons over and under it clear of the level pill on its top edge
	["the phone medallion's chevrons clear of its level pill"] = function()
		local look = switchLook()
		local chevronHalf = 5.25 -- Util/PickWheel's chevron: two 3 x 9 bars at 45 degrees, a 1 px edge round them
		local pillTop = look.pillHeight / 2 + look.pillEdge -- over the medallion's top edge
		assert(look.hint - chevronHalf - pillTop >= 2, `the chevron's foot {look.hint - chevronHalf} px over the top edge, the pill's top {pillTop}`)
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
