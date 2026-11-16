--!strict
-- Icons made of other icons (Config/IconStacks; owner 2026-11-17 picked B for To Bag: a gold pack and a down arrow by
-- the backpack): every layer is a real UIIcons picture, sized and placed inside its holder's reach.
local IconStacks = require("../src/shared/Config/IconStacks")
local UIIcons = require("../src/shared/Config/UIIcons")
local expect = require("./lib/expect")

return {
	["every layer is a real icon, sized and placed sensibly"] = function()
		for name, layers in IconStacks do
			assert(UIIcons[name] == nil, `{name} is a stack, so it can't also be a picture`)
			assert(#layers >= 2, `{name} stacks at least two pictures`)
			for index, layer in layers do
				assert(UIIcons[layer.icon], `{name} layer {index}: {layer.icon} is a Config/UIIcons picture`)
				assert(layer.size > 0 and layer.size <= 1.2, `{name} layer {index}: size {layer.size}`)
				assert(layer.x >= -0.2 and layer.x <= 1.2 and layer.y >= -0.2 and layer.y <= 1.2, `{name} layer {index}: inside`)
			end
		end
	end,

	["To Bag: the backpack with a gold pack and a down arrow"] = function()
		local icons = {}
		for _, layer in IconStacks.ToBag do
			table.insert(icons, layer.icon)
		end
		expect.equal(table.concat(icons, ","), "Bag,BoosterPack,Next")
	end,
}
