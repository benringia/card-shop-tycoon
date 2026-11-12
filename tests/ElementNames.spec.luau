--!strict
-- The owner 2026-11-12: "for elements, let's just call them water, fire, electric, dark and so on" and "replace
-- everywhere. use icons not emojis"
local fs = require("@lune/fs")
local ElementNames = require("../src/shared/Util/ElementNames")
local Names = require("../src/shared/Config/ElementNames")
local Weapons = require("../src/shared/Config/Weapons")
local Combat = require("../src/shared/Config/Combat")
local WeaponText = require("../src/shared/Util/WeaponText")
local expect = require("./lib/expect")

local function listFiles(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			listFiles(path, out)
		elseif string.match(name, "%.luau$") then
			table.insert(out, path)
		end
	end
end

return {
	["every element has its plain name"] = function()
		expect.equal(ElementNames.display("Ember", Names), "Fire")
		expect.equal(ElementNames.display("Tide", Names), "Water")
		expect.equal(ElementNames.display("Bloom", Names), "Nature")
		expect.equal(ElementNames.display("Volt", Names), "Electric")
		expect.equal(ElementNames.display("Shade", Names), "Dark")
		expect.equal(ElementNames.display("None", Names), "None", "an unknown key reads back as given")
		expect.equal(ElementNames.display(nil, Names), "", "none: empty")
		expect.equal(#ElementNames.all(Names), 5, "the five, in wheel order")
		expect.equal(ElementNames.all(Names)[1], "Ember")
	end,

	["weapons and their text use the plain names"] = function()
		expect.equal(Weapons.ById.forgeSword_Ember.name, "Fire Forge Sword")
		expect.equal(Weapons.ById.forgeSpear_Tide.name, "Water Forge Spear")
		expect.equal(Weapons.ById.forgeScythe_Shade.name, "Dark Forge Scythe")
		local element = nil
		for _, row in WeaponText.stats(Weapons, "forgeSword_Ember", nil, Combat) do
			if row.label == "Element" then
				element = row.value
			end
		end
		expect.equal(element, "Fire · bonds with Fire creatures")
		local bond = WeaponText.bond(Weapons, "forgeSword_Volt") :: string
		expect.equal(string.find(bond, "Electric creatures", 1, true) ~= nil, true, "the bond line")
	end,

	-- every place that prints an element goes through ElementNames, and the fight UI uses image icons, not emoji
	["no player text shows a raw element key"] = function()
		local files = {}
		listFiles("src/client", files)
		listFiles("src/shared/Util", files)
		local found = {}
		for _, path in files do
			local source = fs.readFile(path)
			for _, pattern in { "{[%w_%.]*%.element}", "{event%.kind} phase", "{boss%.element}" } do
				if string.find(source, pattern) then
					table.insert(found, `{path}: {pattern}`)
				end
			end
			if string.find(path, "BattleController") and string.find(source, "PERKS%[[^%]]*%]%.icon") then
				table.insert(found, `{path}: an element emoji (Party.PERKS icon)`)
			end
		end
		expect.equal(#found, 0, table.concat(found, "\n"))
	end,
}
