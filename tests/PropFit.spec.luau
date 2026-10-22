--!strict
local town = require("../src/shared/Config/Town")
local wild = require("../src/shared/Config/Wild")
local PropFit = require("../src/shared/Util/PropFit")
local expect = require("./lib/expect")

-- The owner's Shelf.rbxm: long side on Z, front facing -X (needs YawOffset 90)
local SHELF_BOX = { x = 3.6, y = 9.4, z = 12.9 }
local PACK_RACK = { x = 4, y = 5, z = 2 } -- Small Pack Rack hitbox

-- Config/Register and Config/Plots hold Vector3 values, so Lune can't load them: copied here
local COUNTER_DEPTH = 2 -- Plots.REGISTER_SIZE.Z
local ITEM_DEPTH = 1.4 -- Register.ITEM_SIZE.Z
local ITEM_WIDTH = 1 -- Register.ITEM_SIZE.X
local ITEM_SPACING = 1.3 -- Register.ITEM_SPACING
local COUNTER_WIDTH = 6 -- Plots.REGISTER_SIZE.X
local WILD_SIGN_HALF_HEIGHT = 2.5 -- WildService sign boards are 5 tall

return {
	["a turned model fits by its turned size"] = function()
		local turned = PropFit.turnedSize(SHELF_BOX, 90)
		expect.near(turned.x, 12.9, 0.001, "x")
		expect.near(turned.y, 9.4, 0.001, "y")
		expect.near(turned.z, 3.6, 0.001, "z")
		expect.near(PropFit.fitRatio(SHELF_BOX, PACK_RACK, 90), 4 / 12.9, 0.001, "ratio")
	end,

	["an unturned model fits by its own size"] = function()
		expect.near(PropFit.fitRatio(SHELF_BOX, PACK_RACK, 0), 2 / 12.9, 0.001, "ratio")
	end,

	["a YawOffset attribute beats the slot's turn"] = function()
		expect.equal(PropFit.resolveYaw(180, 90), 180, "attribute")
		expect.equal(PropFit.resolveYaw(nil, 90), 90, "slot turn")
		expect.equal(PropFit.resolveYaw("x", nil), 0, "neither")
	end,

	["the shelf slot turns the owner's sideways shelf"] = function()
		expect.equal(town.SLOTS.Shelf.yaw, 90, "Shelf yaw")
	end,

	["a stretched prop fills its box on every axis"] = function()
		local sx, sy, sz = PropFit.stretchFactors(SHELF_BOX, PACK_RACK, 90)
		expect.near(sx, 4 / 12.9, 0.001, "x")
		expect.near(sy, 5 / 9.4, 0.001, "y")
		expect.near(sz, 2 / 3.6, 0.001, "z")
	end,

	["only straight parts can stretch"] = function()
		local up = { x = 0, y = 1, z = 0 }
		assert(PropFit.isAxisAligned({ { x = 1, y = 0, z = 0 }, up, { x = 0, y = 0, z = -1 } }), "straight")
		assert(PropFit.isAxisAligned({ { x = 0, y = 0, z = 1 }, up, { x = 1, y = 0, z = 0 } }), "quarter turn")
		local tilt = math.sqrt(0.5)
		assert(not PropFit.isAxisAligned({ { x = tilt, y = 0, z = tilt }, up, { x = -tilt, y = 0, z = tilt } }), "45 degrees")
	end,

	["lamps hang their lantern toward the street"] = function()
		-- The lantern pole's arm points along the model's -X; a quarter turn points it along -Z (the facing)
		expect.equal(town.SLOTS.Lamp.yaw, 90, "Lamp yaw")
	end,

	["the glass case slot stretches to fill the Collector Case"] = function()
		local slot = town.SLOTS.GlassCase
		assert(slot ~= nil, "no GlassCase slot")
		expect.equal(slot.stretch, true, "GlassCase stretch")
		expect.equal(slot.collide, false, "GlassCase collide (the case part is the hitbox)")
		-- GlassCaseA has its glass doors on its +Z side and a solid wood back on -Z: turned round to face out
		expect.equal(slot.yaw, 180, "GlassCase yaw")
	end,

	["fixture slots: order computer, condenser, register counter"] = function()
		for _, name in { "Computer", "Condenser", "Counter" } do
			local slot = town.SLOTS[name]
			assert(slot ~= nil, `no {name} slot`)
			expect.equal(slot.collide, false, `{name} collide (the fixture part is the hitbox)`)
		end
		expect.equal(town.SLOTS.Computer.yaw, 90, "the desk set's monitor faces its -X")
	end,

	["the shelf slot stretches"] = function()
		expect.equal(town.SLOTS.Shelf.stretch, true, "Shelf stretch")
	end,

	["counter props stay behind the scan items"] = function()
		local itemZ, propZ = PropFit.counterZ(COUNTER_DEPTH, ITEM_DEPTH, town.COUNTER.PROP_DEPTH)
		local itemBack = itemZ + ITEM_DEPTH / 2
		local propFront = propZ - town.COUNTER.PROP_DEPTH / 2
		assert(itemBack <= propFront + 0.001, `items reach z {itemBack}, props start at {propFront}`)
		assert(itemZ - ITEM_DEPTH / 2 >= -COUNTER_DEPTH / 2 - 0.001, "items hang off the front")
		assert(propZ + town.COUNTER.PROP_DEPTH / 2 <= COUNTER_DEPTH / 2 + 0.001, "props hang off the back")
	end,

	["the cashier pet stands inside the stall, under its canopy"] = function()
		local COUNTER_HEIGHT = 2.5 -- Plots.REGISTER_SIZE.Y
		local BIGGEST_PET = 4.2 -- Party.CREATURE_HEIGHT x Legendary size
		local stall = town.COUNTER.STALL
		local staffZ = COUNTER_DEPTH / 2 + town.COUNTER.STAFF_BEHIND -- from the counter centre
		local stallBack = -COUNTER_DEPTH / 2 + stall.depth -- the stall's front lines up with the counter's
		assert(staffZ < stallBack, `cashier at {staffZ} is outside the stall (back at {stallBack})`)
		assert(stall.height * stall.canopyFrom >= BIGGEST_PET + 0.3, "the biggest pet hits the canopy")
		assert(COUNTER_HEIGHT < BIGGEST_PET * 0.7, "the counter hides small pets")
	end,

	["the register faces the customers"] = function()
		-- Its price display faces the model's +X; a -90 turn points that along -Z (the counter's customer side)
		expect.equal(town.SLOTS.Register.yaw, -90, "Register yaw")
	end,

	["scan items spread right of the register"] = function()
		local counter = town.COUNTER
		local registerRight = counter.REGISTER.x + counter.REGISTER.width / 2
		for _, count in { 1, 2, 4, 8 } do
			local xs = PropFit.itemXs(count, registerRight + counter.ITEM_GAP, COUNTER_WIDTH / 2, ITEM_WIDTH, ITEM_SPACING)
			expect.equal(#xs, count, `{count} items`)
			for _, x in xs do
				assert(x - ITEM_WIDTH / 2 >= registerRight + counter.ITEM_GAP - 0.001, `{count} items: one is under the register`)
				assert(x + ITEM_WIDTH / 2 <= COUNTER_WIDTH / 2 + 0.001, `{count} items: one hangs off the end`)
			end
		end
	end,

	["the register sits on the counter"] = function()
		local register = town.COUNTER.REGISTER
		assert(register.x - register.width / 2 >= -COUNTER_WIDTH / 2 - 0.001, "register hangs off the end")
		assert(register.depth <= COUNTER_DEPTH + 0.001, "register is deeper than the counter")
	end,

	["awnings tile across the shop front"] = function()
		-- The owner's awning: 13.9 wide, 7.4 deep; shop fronts are 42 wide, awnings about 5 deep
		local count, scale = PropFit.tileAcross(42, 13.9, 7.4, town.AWNING_DEPTH)
		expect.equal(count, 4, "copies")
		expect.near(count * 13.9 * scale, 42, 0.001, "they fill the front exactly")
		local one, wide = PropFit.tileAcross(10, 13.9, 7.4, 5)
		expect.equal(one, 1, "a narrow front still gets one")
		expect.near(13.9 * wide, 10, 0.001, "and it fits")
	end,

	["tinted part names"] = function()
		assert(PropFit.isTintPart("COLOUR ME"), "COLOUR ME")
		assert(PropFit.isTintPart("ColorMe"), "ColorMe")
		assert(PropFit.isTintPart("Tint"), "Tint")
		assert(not PropFit.isTintPart("White"), "White")
	end,

	["shop fronts: awning under the ceiling, room for the sign above it"] = function()
		local SIGN_HEIGHT = 4 -- Plots.SIGN_SIZE.Y
		expect.equal(town.WALL_HEIGHT, 18, "wall height")
		assert(town.AWNING_HEIGHT < town.WALL_HEIGHT, "the awning is above the ceiling")
		assert(town.WALL_HEIGHT - town.AWNING_HEIGHT >= SIGN_HEIGHT + 1, "no room for the sign above the awning")
		assert(town.GABLE.RISE > 0 and town.GABLE.OVERHANG >= 0, "gable roof")
		expect.equal(#town.CEILING_LIGHTS.XS, 3, "ceiling lights")
	end,

	["each plaza portal has its own light effects"] = function()
		for _, key in { "Wild", "Frontier", "Arena" } do
			local effect = town.PORTAL_EFFECTS[key]
			assert(effect ~= nil, `no effects for {key}`)
			assert(#effect.ring == 3, `{key} ring colour`)
			assert(#effect.colors >= 2, `{key} needs at least 2 particle colours`)
			for _, color in effect.colors do
				assert(#color == 3, `{key} colour`)
			end
			assert(#effect.emitters >= 1 and #effect.emitters <= 3, `{key}: 1 to 3 emitters (phones)`)
		end
	end,

	["portal signs clear the portal frame"] = function()
		assert(
			wild.PORTAL_SIGN_HEIGHT - WILD_SIGN_HALF_HEIGHT >= town.SLOTS.Portal.height,
			`sign bottom {wild.PORTAL_SIGN_HEIGHT - WILD_SIGN_HALF_HEIGHT} is inside the {town.SLOTS.Portal.height}-stud frame`
		)
	end,
}
