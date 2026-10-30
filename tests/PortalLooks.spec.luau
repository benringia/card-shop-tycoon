--!strict
-- The town portals remodel (spec 2026-10-30-town-portals-design, the user's pick A): each portal grown out of its
-- world, a Blender model per portal in a slot of its own (PortalWild, PortalFrontier, PortalArena). Today's frame
-- (the Portal slot) stands in until a model is saved. Looks in Config/Town PORTAL_LOOKS, rules in Util/PortalLooks.
local town = require("../src/shared/Config/Town")
local TownLayout = require("../src/shared/Util/TownLayout")
local PortalLooks = require("../src/shared/Util/PortalLooks")
local expect = require("./lib/expect")

local LOOKS = { "Wild", "Frontier", "Arena" }

local function joined(list: { string }): string
	return table.concat(list, ",")
end

return {
	["each portal falls back on its own"] = function()
		local function hasModel(slot: string): boolean
			return slot == "PortalFrontier"
		end
		expect.equal(PortalLooks.slot("Wild", town, hasModel), "Portal", "the Wild with no model")
		expect.equal(PortalLooks.slot("Frontier", town, hasModel), "PortalFrontier", "the Frontier with its model")
		expect.equal(PortalLooks.slot("Arena", town, hasModel), "Portal", "the Arena with no model")
	end,

	["the old frame never picks up the new models"] = function()
		for _, key in LOOKS do
			local slot = town.PORTAL_LOOKS[key].slot
			expect.equal(TownLayout.isVariant("Portal", slot, town.SLOTS), false, `{slot} as a Portal variant`)
			expect.equal(TownLayout.isVariant(slot, slot, town.SLOTS), true, `{slot} in its own slot`)
		end
	end,

	["labels float above whichever model stands"] = function()
		expect.equal(PortalLooks.labelHeight("Portal", town), 14 + 3, "over the old frame")
		expect.equal(PortalLooks.labelHeight("PortalWild", town), 28 + 3, "over the root arch")
	end,

	["each portal keeps to 4 effects"] = function()
		expect.equal(town.PORTAL_FX.MAX_EFFECTS, 4, "the cap")
		for _, key in LOOKS do
			local count = PortalLooks.effectCount(town.PORTAL_LOOKS[key])
			assert(count <= town.PORTAL_FX.MAX_EFFECTS, `{key} has {count} effects`)
		end
	end,

	["new portal slots don't collide and stand about 28 tall"] = function()
		for _, key in LOOKS do
			local slot = town.SLOTS[town.PORTAL_LOOKS[key].slot]
			assert(slot ~= nil, `{key}'s slot is in SLOTS`)
			expect.equal(slot.collide, false, `{key} collides`)
			assert(slot.height >= 24 and slot.height <= 32, `{key} is {slot.height} tall`)
		end
	end,

	["each look names the parts its model must have"] = function()
		expect.equal(joined(PortalLooks.parts(town.PORTAL_LOOKS.Wild)), "Flowers,Frame,Fx_Pool,Fx_Trickle,Opening,Pool", "Wild")
		expect.equal(joined(PortalLooks.parts(town.PORTAL_LOOKS.Frontier)), "Frame,Fx_Base,Opening", "Frontier")
		expect.equal(joined(PortalLooks.parts(town.PORTAL_LOOKS.Arena)), "Frame,Fx_DripA,Fx_DripB,Fx_Pool,Lava,Opening", "Arena")
	end,

	["effects skip spots the model lacks"] = function()
		local arena = town.PORTAL_LOOKS.Arena
		local kept = PortalLooks.effectsFor(arena, function(part: string): boolean
			return part ~= "Fx_DripB"
		end)
		expect.equal(#kept, #arena.effects - 1, "effects kept without Fx_DripB")
		local all = PortalLooks.effectsFor(arena, function(): boolean
			return true
		end)
		expect.equal(#all, #arena.effects, "effects kept with every part")
	end,

	["the swirl is round and fits inside the opening"] = function()
		local scale = town.PORTAL_FX.VORTEX_SCALE
		assert(scale > 0.5 and scale <= 1, `VORTEX_SCALE {scale}`)
		-- a round swirl turns about its own middle; a stretched one wobbles and swings past a narrow arch top
		expect.equal(PortalLooks.vortexSize(15, 16.8, town), 15 * scale, "a tall opening: sized by its width")
		expect.equal(PortalLooks.vortexSize(18, 12, town), 12 * scale, "a wide opening: sized by its height")
	end,

	["every portal area has a look"] = function()
		for _, area in town.PORTAL_AREAS do
			assert(town.PORTAL_LOOKS[area.effect] ~= nil, `{area.key} ({area.effect}) has no look`)
		end
	end,
}
