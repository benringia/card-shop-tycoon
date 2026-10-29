--!strict
-- Config/PackFx: the pack opening's Blender effects as uploaded flipbook sheets (UI project 3)
local PackFx = require("../src/shared/Config/PackFx")
local expect = require("./lib/expect")

local equal = expect.equal

return {
	["every sheet is a Roblox flipbook grid with an uploaded image"] = function()
		for name, sheet in PackFx.SHEETS do
			equal(sheet.grid == 2 or sheet.grid == 4 or sheet.grid == 8, true, name .. " grid")
			equal(sheet.frames <= sheet.grid * sheet.grid and sheet.frames > 0, true, name .. " frames")
			equal(string.match(sheet.image, "^rbxassetid://%d+$") ~= nil, true, name .. " image")
		end
		for _, name in { "RipBurst", "ShardHolo", "ShardGold", "Glint" } do
			equal(PackFx.SHEETS[name] ~= nil, true, name)
		end
	end,
	["the plain images are uploaded too"] = function()
		for _, name in { "mote", "rays", "leak", "aura" } do
			local image = (PackFx.IMAGES :: any)[name]
			equal(type(image) == "string" and string.match(image, "^rbxassetid://%d+$") ~= nil, true, name)
		end
	end,
}
