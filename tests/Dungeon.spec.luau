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

	["steps: the owner's order, three fights, room 3 has 3 pylons"] = function()
		local kinds = {}
		for _, step in Dungeon.STEPS do
			table.insert(kinds, step.kind)
		end
		expect.equal(table.concat(kinds, ","), "fight,beams,fight,plates,fight,lock", "order")
		local rooms = {}
		for _, step in Dungeon.STEPS do
			if step.kind == "fight" then
				table.insert(rooms, step.room)
			end
		end
		expect.equal(table.concat(rooms, ","), "1,2,3", "every room once, in order")
		expect.equal(Dungeon.ROOMS[3].pylons.count, 3, "pylons")
		expect.equal(Dungeon.ROOMS[1].pylons, nil, "only room 3")
		expect.equal(Dungeon.SECRET.TITLE, "Crystal Seeker", "title")
		expect.equal(Dungeon.SECRET.MATERIAL, "material_prismHydra", "the Hydra's material")
		expect.equal(Dungeon.SECRET.MATERIAL_CHANCE, 0.25, "material chance")
		expect.equal(Dungeon.SECRET.TAPS, 3, "three taps")
		for _, kind in { "beams", "plates", "lock" } do
			expect.equal(typeof(Dungeon.STAGES[kind]), "string", `run line name for {kind}`)
		end
	end,

	["layout: the Hydra's arena in its lair (the ring and its gate inside the dome)"] = function()
		local Bosses = require("../src/shared/Config/Bosses")
		local BossRules = require("../src/shared/Util/BossRules")
		local ring = BossRules.arenaRadius(Bosses.BOSSES.prismHydra, Bosses)
		expect.equal(ring + 4 + 10 < Dungeon.ABYSS.LAIR.radius, true, "the ring and where the portal sets you down")
		expect.equal(Dungeon.ROOM_RADIUS, 40, "bigger fight rings")
		expect.equal(Bosses.BOSSES.prismHydra.arenaRadius, 48, "a bigger chamber")
	end,

	["layout: run leash puts you back inside the ring"] = function()
		-- measured from the ring's centre (BattleService RunOptions.leashCenter): the put-back point is on the island
		expect.equal(Dungeon.ROOM_LEASH, Dungeon.ROOM_RADIUS + Dungeon.ABYSS.RIM, "the ring plus its rim")
		expect.equal(Dungeon.ROOM_LEASH - 2 <= Dungeon.ROOM_RADIUS, true, "put back inside the ring")
		expect.equal(Dungeon.ENTRY_STEP, 16, "members enter deep enough for the camera")
	end,

	["layout: three plate spots, the lock's crystals in another order than the Hydra's"] = function()
		local Bosses = require("../src/shared/Config/Bosses")
		expect.equal(#Dungeon.PUZZLE.PLATES, Dungeon.PLATES.GROUP, "a spot for every plate")
		local order = {}
		for _, phase in Bosses.BOSSES.prismHydra.phases do
			table.insert(order, phase.element)
		end
		local seen = {}
		for _, element in Dungeon.PUZZLE.LOCK_LAYOUT do
			seen[element] = true
		end
		for _, element in order do
			expect.equal(seen[element], true, `{element} has a crystal`)
		end
		expect.equal(#Dungeon.PUZZLE.LOCK_LAYOUT, #order, "five crystals")
		expect.equal(table.concat(Dungeon.PUZZLE.LOCK_LAYOUT, ",") ~= table.concat(order, ","), true, "not already in order")
	end,

	["hints: every puzzle step and room 3's pylons say what to do"] = function()
		for _, step in Dungeon.STEPS do
			if step.kind ~= "fight" then
				expect.equal(typeof(Dungeon.HINTS[step.kind]), "string", `hint for {step.kind}`)
			end
		end
		expect.equal(typeof(Dungeon.HINTS.pylons), "string", "room 3's pylons")
	end,

	["puzzle rooms: their name and clues over the objective, short and plain"] = function()
		local stages = { "pylons" }
		for _, step in Dungeon.STEPS do
			if step.kind ~= "fight" then
				table.insert(stages, step.kind)
			end
		end
		for _, stage in stages do
			expect.equal(typeof(Dungeon.OBJECTIVE_LABELS[stage]), "string", `label for {stage}`)
			local clues = Dungeon.CLUES[stage]
			expect.equal(typeof(clues) == "table" and #clues >= 2, true, `clues for {stage}`)
			for _, clue in clues do
				expect.equal(#clue <= 64 and string.match(clue, "^[%w%p ]+$") ~= nil, true, `"{clue}" short, plain ASCII`)
			end
		end
		expect.equal(string.find(table.concat(Dungeon.CLUES.lock, " "), "{order}", 1, true) ~= nil, true, "the lock spells out its order")
		expect.equal(Dungeon.CLUE_EVERY >= 20, true, "time to try first")
	end,

	["INTRO: beats ascend from 0, the eyes before the roar, full ends at 15 with a blink and a look, short within 3 s"] = function()
		for kind, limit in { full = 15, short = 3 } do
			local beats = Dungeon.INTRO[kind]
			expect.equal(beats[1].at, 0, `{kind} starts at 0`)
			local seen = {}
			for index, beat in beats do
				if index > 1 then
					expect.equal(beat.at > beats[index - 1].at, true, `{kind} beat {index} after the one before`)
				end
				seen[beat.beat] = index
			end
			expect.equal(beats[#beats].beat, "end", `{kind} ends`)
			expect.equal(beats[#beats].at <= limit, true, `{kind} within {limit} s`)
			expect.equal(seen.pairs ~= nil and seen.roar ~= nil and seen.pairs < seen.roar, true, `{kind}: eyes before the roar`)
		end
		expect.equal(Dungeon.INTRO.full[#Dungeon.INTRO.full].at, 15, "full is 15 s (owner 2026-11-12: longer)")
		local full = {}
		for index, beat in Dungeon.INTRO.full do
			full[beat.beat] = index
		end
		expect.equal(full.eyes < full.blink and full.blink < full.pairs and full.pairs < full.look and full.look < full.roar, true, "one pair opens and blinks, the rest open, they look, the roar")
		for _, stage in { "waiting", "room", "beams", "plates", "pylons", "lock", "boss", "won", "out", "gather" } do
			expect.equal(typeof(Dungeon.OBJECTIVES[stage]), "string", `objective for {stage}`)
		end
	end,

	["cinematics and room monsters: sane numbers"] = function()
		local Bosses = require("../src/shared/Config/Bosses")
		local door, hydra = Dungeon.CINEMATIC.door, Dungeon.CINEMATIC.hydra
		expect.equal(door.openAt < door.seconds, true, "the gate opens while the door shot plays")
		expect.equal(hydra.fly <= hydra.socketsAt and hydra.socketsAt + 5 * hydra.socketEvery <= hydra.openAt, true, "fly, the gems, then the door")
		expect.equal(hydra.openAt < hydra.roarAt and hydra.roarAt < hydra.seconds, true, "the door, the roar, the end")
		local pack = Bosses.IDLE_PACK
		expect.equal(pack.wander.radius <= 6, true, "short walks: swords still land")
		expect.equal(pack.weights.wander > pack.weights.roar, true, "mostly moving")
		for key, spec in Dungeon.PUZZLE_SOUNDS do
			expect.equal(string.match(spec.id, "^rbxassetid://%d+$") ~= nil and spec.volume > 0, true, `sound {key}`)
		end
	end,

	["places: the Dungeon has its id"] = function()
		expect.equal(Places.DUNGEON_PLACE_ID, 79143483483478, "place id")
	end,
}
