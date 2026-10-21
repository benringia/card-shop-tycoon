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

	["counter props stay behind the scan items"] = function()
		local itemZ, propZ = PropFit.counterZ(COUNTER_DEPTH, ITEM_DEPTH, town.COUNTER.PROP_DEPTH)
		local itemBack = itemZ + ITEM_DEPTH / 2
		local propFront = propZ - town.COUNTER.PROP_DEPTH / 2
		assert(itemBack <= propFront + 0.001, `items reach z {itemBack}, props start at {propFront}`)
		assert(itemZ - ITEM_DEPTH / 2 >= -COUNTER_DEPTH / 2 - 0.001, "items hang off the front")
		assert(propZ + town.COUNTER.PROP_DEPTH / 2 <= COUNTER_DEPTH / 2 + 0.001, "props hang off the back")
	end,

	["portal signs clear the portal frame"] = function()
		assert(
			wild.PORTAL_SIGN_HEIGHT - WILD_SIGN_HALF_HEIGHT >= town.SLOTS.Portal.height,
			`sign bottom {wild.PORTAL_SIGN_HEIGHT - WILD_SIGN_HALF_HEIGHT} is inside the {town.SLOTS.Portal.height}-stud frame`
		)
	end,
}
