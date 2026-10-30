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

	["the swirl covers the whole opening"] = function()
		local fx = town.PORTAL_FX
		-- the swirl image's disc fades out from 85% of its radius: what shows must still reach the opening's far side
		assert(fx.VORTEX_SCALE * 0.85 >= 1, `VORTEX_SCALE {fx.VORTEX_SCALE} leaves the opening's edge uncovered`)
		expect.equal(PortalLooks.vortexSize(15, 16.8, town), 16.8 * fx.VORTEX_SCALE, "a tall opening: sized by its height")
		expect.equal(PortalLooks.vortexSize(18, 12, town), 18 * fx.VORTEX_SCALE, "a wide opening: sized by its width")
	end,

	["the swirl's layers move together"] = function()
		local fx = town.PORTAL_FX
		local look = town.PORTAL_LOOKS.Arena
		local at0 = PortalLooks.animate(0, look, town)
		local at1 = PortalLooks.animate(1, look, town)
		expect.near((at1.swirl - at0.swirl) % 360, look.vortex.spin % 360, 1e-6, "the swirl turns at the look's spin")
		-- the inner swirl turns the other way, faster
		expect.near((at1.inner - at0.inner) % 360, (look.vortex.spin * fx.INNER.speed) % 360, 1e-6, "the inner swirl's turn")
		assert(fx.INNER.speed < -1, "the inner swirl turns the other way, faster")
		assert(fx.INNER.scale > 0.3 and fx.INNER.scale < 0.8, "the inner swirl sits inside the swirl")
		-- the glow breathes inside its range, and the light with it
		for t = 0, fx.PULSE.period, fx.PULSE.period / 8 do
			local at = PortalLooks.animate(t, look, town)
			assert(at.glow >= fx.PULSE.glow[1] - 1e-9 and at.glow <= fx.PULSE.glow[2] + 1e-9, `glow transparency {at.glow} at {t}`)
			assert(at.light >= 1 - fx.PULSE.light - 1e-9 and at.light <= 1 + fx.PULSE.light + 1e-9, `light share {at.light} at {t}`)
		end
		for _, angle in { at0.swirl, at0.inner, at1.swirl, at1.inner } do
			assert(angle >= 0 and angle < 360, `angle {angle} kept in 0..360`)
		end
	end,

	["a portal sinks its buried roots back into the ground"] = function()
		-- Props stands a model's lowest point on the ground, but the Blender builds sink roots, shards and drifts below
		-- their ground (z 0): the ground part (a pool, the lava, the drift's marker) must sit at its Blender height
		for _, key in LOOKS do
			local ground = town.PORTAL_LOOKS[key].ground
			assert(ground and table.find(PortalLooks.parts(town.PORTAL_LOOKS[key]), ground.part), `{key}'s ground part is one of its parts`)
		end
		-- a pool's bottom 1.3 above the foot, meant to be 0.15 above the ground, at scale 1: down 1.15
		expect.near(PortalLooks.groundShift(1.3, 0, 0.15, 1), -1.15, 1e-6, "sink at scale 1")
		-- the same at scale 0.9 (the model shrunk to its slot's height): the Blender height scales too
		expect.near(PortalLooks.groundShift(1.3, 0, 0.15, 0.9), -1.165, 1e-6, "sink at scale 0.9")
		expect.near(PortalLooks.groundShift(10.5, 10, 0.5, 1), 0, 1e-6, "already at its height: no shift")
	end,

	["a portal's name shows from down its trail"] = function()
		-- With the default camera (about 9 studs up, the top of the view about 20 degrees over level) a name more than 20
		-- degrees up is off screen: it must come into view far enough out to read for 15 studs of the walk
		for _, key in LOOKS do
			local above = PortalLooks.labelHeight(town.PORTAL_LOOKS[key].slot, town) - 9
			local inView = above / math.tan(math.rad(20)) -- closer than this, it climbs off the top
			assert(town.PORTAL_LABEL_DISTANCE >= inView + 15, `{key}: shown within {town.PORTAL_LABEL_DISTANCE} studs, in view only beyond {inView}`)
		end
	end,

	["every portal area has a look"] = function()
		for _, area in town.PORTAL_AREAS do
			assert(town.PORTAL_LOOKS[area.effect] ~= nil, `{area.key} ({area.effect}) has no look`)
		end
	end,
}
