--!strict
local Dungeon = require("../src/shared/Config/Dungeon")
local Frontier = require("../src/shared/Config/Frontier")
local Places = require("../src/shared/Config/Places")
local expect = require("./lib/expect")
local fs = require("@lune/fs")
local serde = require("@lune/serde")

return {
	["rooms: three, packs of 2-3 elites from Frontier species at Lv 45-50"] = function()
		expect.equal(#Dungeon.ROOMS, 3, "three rooms")
		for index, room in Dungeon.ROOMS do
			expect.equal(room.count >= 2 and room.count <= 3, true, `room {index} size`)
			expect.equal(room.level >= 45 and room.level <= 50, true, `room {index} level`)
			for _, species in room.species do
				expect.equal(Frontier.SPECIES[species] ~= nil, true, `room {index}: {species}`)
			end
		end
		expect.equal(Dungeon.BOSS, "prismHydra", "the chamber's boss")
	end,

	["dungeon.project.json syncs the Dungeon window on its own port"] = function()
		local project = serde.decode("json", fs.readFile("dungeon.project.json"))
		expect.equal(project.servePort, 34874, "port")
		expect.equal(project.tree.Workspace["$attributes"].PlaceKind, "Dungeon", "PlaceKind")
	end,

	["places: the Dungeon has its id"] = function()
		expect.equal(Places.DUNGEON_PLACE_ID, 79143483483478, "place id")
	end,
}
