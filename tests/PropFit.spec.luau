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

	["fixture slots: order computer, condenser"] = function()
		for _, name in { "Computer", "Condenser" } do
			local slot = town.SLOTS[name]
			assert(slot ~= nil, `no {name} slot`)
			expect.equal(slot.collide, false, `{name} collide (the fixture part is the hitbox)`)
		end
		expect.equal(town.SLOTS.Computer.built, true, "the modern workstation is code-built (no model file)")
		expect.equal(town.SLOTS.Condenser.built, true, "the Card Condenser is code-built (no model file)")
		local look = town.CONDENSER_LOOK
		local CONDENSER = { x = 6, y = 7, z = 6 } -- Config/Shelves Condenser size
		assert(look.BASE_RADIUS * 2 <= math.min(CONDENSER.x, CONDENSER.z), "the machine is wider than its spot")
		assert(look.BASE_HEIGHT + look.CHAMBER_HEIGHT + look.CAP_HEIGHT <= CONDENSER.y, "the machine is taller than its box")
		assert(look.CORE_RADIUS + 0.3 < look.CHAMBER_RADIUS, "the floating cards hit the glass")
		expect.equal(town.SLOTS.Computer.yaw, nil, "the code-built desk faces -Z already")
	end,

	["each shelf type has its own look"] = function()
		local slots = town.SLOTS
		for _, name in { "Shelf", "WallShelf", "HookRack", "DisplayRack" } do
			expect.equal(slots[name].built, true, `{name}: code-built (Util/ShelfLooks)`)
			expect.equal(slots[name].yaw, nil, `{name}: built facing -Z`)
			assert(town.SHELF_LOOK.HEADERS[name] ~= nil, `{name}: header words`)
		end
		expect.equal(slots.Showcase.yaw, 90, "Showcase: long side along its Z")
		expect.equal(slots.Showcase.stretch, true, "Showcase stretches")
	end,

	["counter props stay behind the scan items"] = function()
		local itemZ, propZ = PropFit.counterZ(COUNTER_DEPTH, ITEM_DEPTH, town.COUNTER.PROP_DEPTH)
		local itemBack = itemZ + ITEM_DEPTH / 2
		local propFront = propZ - town.COUNTER.PROP_DEPTH / 2
		assert(itemBack <= propFront + 0.001, `items reach z {itemBack}, props start at {propFront}`)
		assert(itemZ - ITEM_DEPTH / 2 >= -COUNTER_DEPTH / 2 - 0.001, "items hang off the front")
		assert(propZ + town.COUNTER.PROP_DEPTH / 2 <= COUNTER_DEPTH / 2 + 0.001, "props hang off the back")
	end,

	["the checkout's pendant lights hang clear of the cashier and from the ceiling"] = function()
		local COUNTER_HEIGHT = 2.5 -- Plots.REGISTER_SIZE.Y
		local BIGGEST_PET = 4.2 -- Party.CREATURE_HEIGHT x Legendary size
		local PLAYER_HEIGHT = 5.5
		local pendant = town.COUNTER.PENDANT
		assert(pendant.BOTTOM >= math.max(BIGGEST_PET, PLAYER_HEIGHT) + 0.3, "a cashier's head hits the lights")
		assert(pendant.BOTTOM + pendant.SHADE_HEIGHT < town.WALL_HEIGHT, "the lights reach the ceiling")
		assert(COUNTER_HEIGHT < BIGGEST_PET * 0.7, "the counter hides small pets")
		assert(pendant.SPREAD / 2 + pendant.SHADE_WIDTH / 2 <= COUNTER_WIDTH / 2, "a light hangs past the counter's end")
	end,

	["the delivery spot sits outside on the sidewalk, clear of the doors and planters"] = function()
		local delivery = town.DELIVERY
		local SIDEWALK_GAP = 8 - 1 -- Town.LAYOUT.SIDEWALK minus the front wall's thickness
		expect.equal(town.LAYOUT.SIDEWALK, 8, "sidewalk width (update SIDEWALK_GAP)")
		local halfWidth = delivery.SIZE[1] / 2
		local planterEdge = town.SHOP.DOOR_WIDTH / 2 + town.SHOP.PLANTER_OFFSET + town.SHOP.PLANTER_SIZE / 2
		assert(math.abs(delivery.X) - halfWidth >= planterEdge, "the pad overlaps the doorway planter")
		assert(math.abs(delivery.X) + halfWidth + delivery.BOLLARD_SIZE <= 20, "the pad reaches past the shop's side") -- Plots.WIDTH / 2
		assert(delivery.GAP + delivery.SIZE[3] <= SIDEWALK_GAP, "the pad sticks out into the road")
		expect.equal(town.SLOTS.DeliveryPad, nil, "the pallet slot is gone (the spot is code-built)")
	end,

	["the checkout is code-built: a POS terminal, no market stall or cash register model"] = function()
		local slot = town.SLOTS.Terminal
		assert(slot ~= nil, "Terminal slot")
		expect.equal(slot.collide, false, "Terminal collide")
		expect.equal(town.SLOTS.Counter, nil, "the market stall slot is gone")
		expect.equal(town.SLOTS.Register, nil, "the cash register slot is gone")
		expect.equal(town.COUNTER.STALL, nil, "no stall box")
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

	["shop fronts: glass under the ceiling, room for the sign band above it, doors fit"] = function()
		local SIGN_HEIGHT = 4 -- Plots.SIGN_SIZE.Y
		local shop = town.SHOP
		expect.equal(town.WALL_HEIGHT, 18, "wall height")
		assert(town.AWNING_HEIGHT < town.WALL_HEIGHT, "the glass front is above the ceiling")
		assert(town.WALL_HEIGHT - town.AWNING_HEIGHT >= SIGN_HEIGHT + 1, "no room for the sign above the glass")
		assert(shop.DOOR_HEIGHT < town.AWNING_HEIGHT, "the doors are taller than the glass front")
		assert(shop.DOOR_WIDTH >= 8, "the doorway is too narrow for customers to path through")
		assert(shop.DOOR_WIDTH <= 40 - 8, "no room for windows beside the doors")
		assert(#shop.PANEL_ROWS * #shop.PANEL_COLS >= 4, "ceiling panels")
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
