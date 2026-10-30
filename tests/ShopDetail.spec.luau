--!strict
-- How far each client draws a shop's small screens (Config/ShopDetail, DESIGN 10.5). A full server's 594 shop screens
-- (card faces, price tags, shelf headers, machine screens) cost 5.4 ms a frame on a PC until each got a draw distance.
local fs = require("@lune/fs")
local ShopDetail = require("../src/shared/Config/ShopDetail")
local expect = require("./lib/expect")

-- Every file that puts screens on shop items
local SHOP_SCREEN_FILES = {
	"src/server/Services/PlacementService.luau",
	"src/shared/Util/ShelfLooks.luau",
	"src/shared/Util/Props.luau",
	"src/shared/Util/BrandBox.luau",
	"src/client/Controllers/CardEffectsController.luau",
	"src/client/Controllers/CaseSpinController.luau",
}

local function number(path: string, key: string): number
	local value = tonumber(string.match(fs.readFile(path), key .. "%s*=%s*([%d%.]+)"))
	assert(value, `{key} not found in {path}`)
	return value :: number
end

return {
	["every screen on a shop item has a draw distance"] = function()
		for _, path in SHOP_SCREEN_FILES do
			local lines = string.split(fs.readFile(path), "\n")
			for index, line in lines do
				local kind = string.match(line, 'Instance%.new%("(%a+Gui)"%)')
				if kind == "SurfaceGui" or kind == "BillboardGui" then
					local found = false
					for ahead = index + 1, math.min(index + 12, #lines) do
						if string.find(lines[ahead], "%.MaxDistance%s*=") then
							found = true
							break
						end
					end
					assert(found, `{path}:{index}: this {kind} has no MaxDistance`)
				end
			end
		end
	end,

	["from anywhere in your own shop, every screen in it still draws"] = function()
		local width = number("src/shared/Config/Plots.luau", "WIDTH")
		local depth = number("src/shared/Config/Plots.luau", "DEPTH")
		local across = math.sqrt(width * width + depth * depth)
		assert(ShopDetail.SCREEN_DISTANCE >= across, `SCREEN_DISTANCE {ShopDetail.SCREEN_DISTANCE} is shorter than the shop's diagonal {across}`)
	end,

	["cards show their full face as far as a shelf can be tapped for info"] = function()
		local reach = number("src/shared/Config/Placement.luau", "REACH")
		assert(ShopDetail.FULL_CARD_DISTANCE >= reach, "a card you can tap shows only its flat picture")
		assert(ShopDetail.FULL_CARD_DISTANCE <= ShopDetail.SCREEN_DISTANCE, "full card faces draw further than the other screens")
		expect.equal(typeof(ShopDetail.FLAT_BACK_COLOR), "table", "the far card back's colour is { r, g, b }")
		expect.equal(#ShopDetail.FLAT_BACK_COLOR, 3, "the far card back's colour is { r, g, b }")
	end,
}
