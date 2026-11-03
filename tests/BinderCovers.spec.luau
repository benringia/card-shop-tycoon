--!strict
-- The binder's set covers (spec 2026-11-04-round4-design section 1): one creature-free painting per set and its candy
-- logo (one or two lines, a three-colour fill, a drop colour). Plain data in Config/BinderCovers. Config/Cards
-- requires its siblings, so Lune reads the set names from its BySet line.
local fs = require("@lune/fs")
local BinderCovers = require("../src/shared/Config/BinderCovers")
local expect = require("./lib/expect")

local function isColor(value: any): boolean
	if typeof(value) ~= "table" or #value ~= 3 then
		return false
	end
	for _, channel in value do
		if typeof(channel) ~= "number" or channel < 0 or channel > 255 then
			return false
		end
	end
	return true
end

return {
	["every set has a cover"] = function()
		local line = string.match(fs.readFile("src/shared/Config/Cards.luau"), "local BySet[^\n]*")
		assert(line, "Config/Cards has a BySet line")
		local sets: { string } = {}
		for quoted in string.gmatch(line :: string, '%["([^"]+)"%]') do
			table.insert(sets, quoted)
		end
		for bare in string.gmatch(line :: string, "[,{]%s*(%a+)%s*=") do
			table.insert(sets, bare)
		end
		expect.equal(#sets, 2, "sets found")
		for _, set in sets do
			local cover = BinderCovers.SETS[set]
			assert(cover, `{set} has no cover`)
			assert(string.match(cover.art, "^rbxassetid://%d+$"), `{set} art is an uploaded id`)
			assert(#cover.lines == 1 or #cover.lines == 2, `{set} logo has 1 or 2 lines`)
			expect.equal(#cover.fill, 3, `{set} fill colours`)
			for index, color in cover.fill do
				assert(isColor(color), `{set} fill {index} is an RGB colour`)
			end
			assert(isColor(cover.drop), `{set} drop is an RGB colour`)
		end
	end,
}
