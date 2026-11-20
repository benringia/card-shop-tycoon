--!strict
local MusicRules = require("../src/shared/Util/MusicRules")
local Music = require("../src/shared/Config/Music")
local Town = require("../src/shared/Config/Town")
local Bosses = require("../src/shared/Config/Bosses")
local WildValley = require("../src/shared/Config/WildValley")
local expect = require("./lib/expect")

-- Every place with music: the town, the Wild valley's areas and its boss arenas (owner 2026-11-04)
local function places(): { any }
	local list = { Music.TOWN }
	for _, area in Music.WILD.areas do
		table.insert(list, area)
	end
	for _, arena in Music.WILD.arenas do
		table.insert(list, arena)
	end
	return list
end

local BOUNDS = { HALF_X = 130, HALF_Z = 110 }

return {
	-- The Frontier valley (spec 2026-11-10-frontier-valley-design, plan Task 6): its areas' and arenas' own music
	["the Frontier's places play their own music"] = function()
		local world = (Music :: any).FRONTIER
		expect.equal(MusicRules.place(Music, 2, nil, false, nil, world), "sovereign", "in the Storm Sovereign's arena")
		expect.equal(MusicRules.place(Music, nil, 1, false, nil, world), "frostwood", "in Frostwood")
		expect.equal(MusicRules.place(Music, nil, nil, false, "rift", world), "rift", "on a pass: keeps playing")
		expect.isNil(MusicRules.place(Music, nil, nil, false, "meadow", world), "the Wild's music doesn't carry on")
		expect.equal(MusicRules.place(Music, nil, 1, false, nil), "meadow", "the Wild's world by default")
	end,

	["find knows the Frontier's places"] = function()
		local world = (Music :: any).FRONTIER
		expect.equal(MusicRules.find(Music, "stormpeak"), world.areas[2])
		expect.equal(MusicRules.find(Music, "devourer"), world.arenas[3])
	end,

	["every Frontier place has three options, its track among them, a quiet volume and an ambient loop"] = function()
		local world = (Music :: any).FRONTIER
		expect.equal(#world.areas, 3, "Frostwood, Stormpeak, the Rift")
		expect.equal(#world.arenas, 3, "one per boss")
		for _, list in { world.areas, world.arenas } do
			for _, place in list do
				expect.equal(#place.options, 3, `{place.key}: options`)
				local found = false
				for _, option in place.options do
					found = found or option.id == place.tracks[1]
				end
				assert(found, `{place.key}: its track is one of its options`)
				assert(place.volume > 0 and place.volume <= 0.02, `{place.key}: volume {place.volume}`)
				assert(place.compressor, `{place.key}: the leveler`)
			end
		end
		for _, area in world.areas do
			assert(area.ambient and string.match(area.ambient.id, "^rbxassetid://%d+$"), `{area.key}: an ambient loop`)
		end
	end,

	-- The welcome flight's music (the owner 2026-11-11: "more epic/jolly/welcoming")
	["the welcome flight has its own music, found by its key"] = function()
		local welcome = (Music :: any).WELCOME
		assert(welcome and #welcome.tracks >= 1, "a piece")
		expect.equal(MusicRules.find(Music, welcome.key), welcome)
		assert(welcome.volume > 0 and welcome.volume <= 0.3, "under the whooshes")
		for _, option in welcome.options do
			assert(string.match(option.id, "^rbxassetid://%d+$"), option.name)
		end
	end,

	-- The prologue (owner 2026-11-15: "add some music"): a piece for each of its parts
	["the prologue has a piece for each part, found by its key"] = function()
		local prologue = (Music :: any).PROLOGUE
		assert(prologue, "the prologue's music")
		for _, part in { "lair", "fight", "taken", "wake" } do
			local place = prologue[part]
			assert(place and #place.tracks >= 1, `{part}: a piece`)
			expect.equal(MusicRules.find(Music, place.key), place)
			assert(place.volume > 0 and place.volume <= 0.3, `{part}: under the fight and the cinematics' sounds`)
			local listed = false
			for _, option in place.options do
				assert(string.match(option.id, "^rbxassetid://%d+$"), option.name)
				listed = listed or option.id == place.tracks[1]
			end
			assert(listed, `{part}: its piece is one of its options (/music can play it back)`)
		end
	end,

	["music keys are unique across the town, the Wild, the Frontier and the opening"] = function()
		local seen = { [Music.TOWN.key] = true, [Music.OPENING.key] = true, [(Music :: any).WELCOME.key] = true }
		for _, place in (Music :: any).PROLOGUE do
			assert(not seen[place.key], `{place.key} twice`)
			assert(string.match(place.key, "^%a+$"), `{place.key}: /music reads letters only`)
			seen[place.key] = true
		end
		for _, world in { Music.WILD, (Music :: any).FRONTIER } do
			for _, list in { world.areas, world.arenas } do
				for _, place in list do
					assert(not seen[place.key], `{place.key} twice`)
					assert(string.match(place.key, "^%a+$"), `{place.key}: /music reads letters only`)
					seen[place.key] = true
				end
			end
		end
	end,

	["the town is the island inside the hedge, plus a margin to fade in and out"] = function()
		expect.equal(MusicRules.inTown(0, 0, BOUNDS, 40), true, "the plaza")
		expect.equal(MusicRules.inTown(-165, 140, BOUNDS, 40), true, "just past the hedge")
		expect.equal(MusicRules.inTown(171, 0, BOUNDS, 40), false, "past the margin east")
		expect.equal(MusicRules.inTown(0, -151, BOUNDS, 40), false, "past the margin south")
		expect.equal(MusicRules.inTown(900, 400, BOUNDS, 40), false, "the Wild valley")
	end,

	-- Owner 2026-11-19 ("should we have a playlist for music for town? instead of just one?", then "add the two extra
	-- music with volume 0.21"): White Owl, Wistful Wonderings and Soft Tranquility take turns, each at its own volume
	-- ...each a little louder since 2026-11-20 (owner: "make town musics a little bit louder"): 0.18 -> 0.22, 0.21 -> 0.25
	["the town plays three pieces in turn, each at its own volume"] = function()
		local town = Music.TOWN
		expect.equal(#town.tracks, 3)
		local names = {}
		for index, id in town.tracks do
			for _, option in town.options do
				if option.id == id then
					names[index] = option.name
				end
			end
			assert(names[index], `track {index} is one of the vetted options`)
		end
		assert(string.find(names[1], "White Owl", 1, true), "White Owl first")
		assert(string.find(names[2], "Wistful Wonderings", 1, true), "then Wistful Wonderings")
		assert(string.find(names[3], "Soft Tranquility", 1, true), "then Soft Tranquility")
		expect.equal(MusicRules.trackVolume(town, 1), 0.3, "White Owl")
		expect.equal(MusicRules.trackVolume(town, 2), 0.34)
		expect.equal(MusicRules.trackVolume(town, 3), 0.34, "the two added pieces stay a touch over it, as the owner set them")
		expect.equal(MusicRules.trackVolume({ volume = 0.05 }, 2), 0.05, "a place without its own numbers: its volume")
		expect.equal(MusicRules.trackVolume({ volume = 0.05, volumes = { [2] = 0.1 } }, 1), 0.05, "a track without one")
	end,

	-- Owner 2026-11-19: "randomize the town music between those 3 music every time player came back to town or
	-- starting the game"
	["the town starts on a random piece each time you arrive, never the one just heard"] = function()
		expect.equal(Music.TOWN.rotate, "random")
		expect.equal(MusicRules.randomTrack(nil, 3, 0), 1, "starting the game: any of the three")
		expect.equal(MusicRules.randomTrack(nil, 3, 0.5), 2)
		expect.equal(MusicRules.randomTrack(nil, 3, 0.999), 3)
		for previous = 1, 3 do
			local seen = {}
			for step = 0, 9 do
				local pick = MusicRules.randomTrack(previous, 3, step / 10)
				assert(pick >= 1 and pick <= 3 and pick ~= previous, `after {previous}: another piece ({pick})`)
				seen[pick] = true
			end
			local others = 0
			for _ in seen do
				others += 1
			end
			expect.equal(others, 2, "either of the other two")
		end
		expect.equal(MusicRules.randomTrack(1, 1, 0.7), 1, "one piece: it repeats")
		expect.equal(MusicRules.randomTrack(nil, 3, 1), 3, "a roll of exactly 1 stays in range")
	end,

	-- Owner 2026-11-19 ("do 1 and 2 now"): in the Frontier, drums fade in over the area's music while you fight a
	-- monster and out when it ends; louder against an elite. Never in a boss fight (the arenas have their own music)
	["Frontier fights get a drum layer: in for a monster, louder for an elite, never for a boss"] = function()
		local frontier = (Music :: any).FRONTIER
		local fight = frontier.fight
		assert(fight and string.match(fight.tracks[1], "^rbxassetid://%d+$"), "its loop")
		assert(#fight.options >= 3, "options to pick by ear (/music frontierfight <n>)")
		assert(fight.volume > 0 and fight.volume <= 0.05, "under the hits, like the valley's quiet music")
		assert(fight.elite > 1 and fight.elite <= 2, "an elite's fight drums a little louder")
		expect.equal(MusicRules.find(Music, fight.key), fight, "the preview finds it")
		expect.equal(MusicRules.fightVolume(frontier, { fighting = true }), fight.volume)
		expect.equal(MusicRules.fightVolume(frontier, { fighting = true, elite = true }), fight.volume * fight.elite)
		expect.equal(MusicRules.fightVolume(frontier, { fighting = true, boss = true }), 0, "a boss arena has its own music")
		expect.equal(MusicRules.fightVolume(frontier, { fighting = false }), 0, "no fight, no drums")
		expect.equal(MusicRules.fightVolume(Music.WILD, { fighting = true }), 0, "the Wild has no drum layer")
	end,

	["the tracks take turns and wrap round"] = function()
		expect.equal(MusicRules.nextTrack(0, 2), 1, "nothing played yet: the first")
		expect.equal(MusicRules.nextTrack(1, 2), 2)
		expect.equal(MusicRules.nextTrack(2, 2), 1)
		expect.equal(MusicRules.nextTrack(1, 1), 1, "one track: it repeats")
	end,

	["/music picks a place's option to hear (0 goes back), with an optional volume"] = function()
		local counts = { town = 5, meadow = 3, warden = 3 }
		local place, index, volume = MusicRules.parsePreview("/music 2", counts)
		expect.equal(place, "town", "no place: the town")
		expect.equal(index, 2)
		expect.isNil(volume)
		place, index, volume = MusicRules.parsePreview("/music 3 0.08", counts)
		expect.equal(place, "town")
		expect.equal(index, 3)
		expect.equal(volume, 0.08)
		place, index, volume = MusicRules.parsePreview("/music meadow 3 0.1", counts)
		expect.equal(place, "meadow")
		expect.equal(index, 3)
		expect.equal(volume, 0.1)
		place, index = MusicRules.parsePreview("/music warden 0", counts)
		expect.equal(place, "warden")
		expect.equal(index, 0, "back to the normal tracks")
		place, index = MusicRules.parsePreview("/music 0", counts)
		expect.equal(index, 0)
		expect.isNil(MusicRules.parsePreview("/music 6", counts), "no such town option")
		expect.isNil(MusicRules.parsePreview("/music meadow 4", counts), "no such meadow option")
		expect.isNil(MusicRules.parsePreview("/music lava 1", counts), "no such place")
		expect.isNil(MusicRules.parsePreview("/music meadow", counts), "no number")
		expect.isNil(MusicRules.parsePreview("/music", counts), "nothing")
		local _, _, loud = MusicRules.parsePreview("/music meadow 1 9", counts)
		expect.equal(loud, 1, "a volume is kept within 0-1")
	end,

	["the music follows where you are: a boss arena, then the Wild's area, then the town"] = function()
		expect.equal(MusicRules.place(Music, 2, 1, false, nil), "brood", "in an arena: its music")
		expect.equal(MusicRules.place(Music, nil, 1, false, "town"), "meadow", "in the meadow")
		expect.equal(MusicRules.place(Music, nil, 3, false, "meadow"), "ridge")
		expect.equal(MusicRules.place(Music, nil, nil, true, "ridge"), "town", "back in town")
		expect.equal(MusicRules.place(Music, nil, nil, false, "meadow"), "meadow", "on the pass between areas: keeps playing")
		expect.isNil(MusicRules.place(Music, nil, nil, false, "town"), "nowhere with music after the town: quiet")
		expect.isNil(MusicRules.place(Music, nil, nil, false, "warden"), "out of an arena, nowhere else: quiet")
		expect.isNil(MusicRules.place(Music, nil, nil, false, nil))
	end,

	-- The owner's picks by ear (2026-11-04): the town's White Owl, and a track, volume and leveler for each Wild place
	["the owner's picks play, each Wild one through a leveler, the valley's areas with their ambience"] = function()
		expect.equal(Music.TOWN.tracks[1], "rbxassetid://9048757009", "the town: White Owl")
		local picks = {
			meadow = { "rbxassetid://1838420686", 0.005 }, -- Woodland Walk (classical solo guitar)
			gorge = { "rbxassetid://1842181702", 0.01 }, -- Calm Waters (solo guitar)
			ridge = { "rbxassetid://1842276365", 0.005 }, -- Air Currents (classical solo guitar)
			warden = { "rbxassetid://1845205138", 0.006 }, -- Forest Chase (owner 2026-11-05: down from 0.1)
			brood = { "rbxassetid://1841360723", 0.008 }, -- Creepy Crawlers (down with the warden, keeping its lift over it)
			colossus = { "rbxassetid://96625587462633", 0.006 }, -- Giant's Grave (down with the warden)
		}
		for key, pick in picks do
			local place = MusicRules.find(Music, key)
			expect.equal(place.tracks[1], pick[1], `{key} track`)
			expect.equal(place.volume, pick[2], `{key} volume`)
			local leveler = place.compressor
			expect.equal(leveler ~= nil, true, `{key} has a leveler`)
			expect.equal(leveler.threshold < 0 and leveler.ratio > 1 and leveler.makeup > 0, true, `{key} leveler evens it out and gives the level back`)
		end
		for _, area in Music.WILD.areas do
			local ambient = area.ambient
			expect.equal(ambient ~= nil and string.match(ambient.id, "^rbxassetid://%d+$") ~= nil, true, `{area.key} ambience`)
			expect.equal(ambient.volume > 0 and ambient.volume <= 0.5, true, `{area.key} ambience volume`)
		end
		-- The Meadow's birds were buried under its music (PlaybackLoudness ignores Volume: heard ~ loudness x volume, 4.6 x
		-- 0.3 against ~98 x 0.1): a fuller field loop, about half the music's level (owner 2026-11-04: "add ambient sound")
		-- The valley plays only solo piano or acoustic guitar (owner 2026-11-04), each option named for its instrument
		for _, area in Music.WILD.areas do
			for _, option in area.options do
				local name = string.lower(option.name)
				expect.equal(string.find(name, "solo piano", 1, true) ~= nil or string.find(name, "solo guitar", 1, true) ~= nil, true, `{area.key}: {option.name} is piano or guitar only`)
			end
			local picked = false
			for _, option in area.options do
				picked = picked or option.id == area.tracks[1]
			end
			expect.equal(picked, true, `{area.key} plays one of its options`)
		end
		local meadow = MusicRules.find(Music, "meadow").ambient
		expect.equal(meadow.id, "rbxassetid://9112779471", "the Meadow: Field Birds Tweeting 1")
		expect.equal(meadow.volume, 0.03, "the Meadow's field loop")
		for _, area in Music.WILD.areas do
			local wanted = ({ meadow = 0.03, gorge = 0.05, ridge = 0.008 })[area.key] -- the lava rumble is a much louder loop
			expect.equal(area.ambient.volume, wanted, `{area.key} ambience (owner 2026-11-04)`)
		end
	end,

	["each place's music is found by its key"] = function()
		expect.equal(MusicRules.find(Music, "town"), Music.TOWN)
		expect.equal(MusicRules.find(Music, "gorge"), Music.WILD.areas[2])
		expect.equal(MusicRules.find(Music, "colossus"), Music.WILD.arenas[3])
		expect.isNil(MusicRules.find(Music, "lava"))
	end,

	["the Wild valley's areas and its boss arenas each have licensed music to pick from"] = function()
		expect.equal(#Music.WILD.areas, #WildValley.BIOMES, "one per area of the valley")
		local wildBosses = 0
		for _, boss in Bosses.BOSSES do
			if boss.place == "Wild" then
				wildBosses += 1
			end
		end
		expect.equal(#Music.WILD.arenas, wildBosses, "one per Wild boss arena")
		local keys = {}
		for _, place in places() do
			expect.equal(typeof(place.key) == "string" and not keys[place.key], true, `unique key {place.key}`)
			keys[place.key] = true
			expect.equal(#place.tracks >= 1, true, `{place.key} plays something`)
			for _, id in place.tracks do
				expect.equal(string.match(id, "^rbxassetid://%d+$") ~= nil, true, `{place.key} track {id}`)
			end
			expect.equal(#place.options >= 3, true, `{place.key}: options to pick from (/music {place.key} <n>)`)
			for _, option in place.options do
				expect.equal(string.match(option.id, "^rbxassetid://%d+$") ~= nil and #option.name > 0, true, option.name)
			end
			expect.equal(place.volume > 0 and place.volume <= 0.5, true, `{place.key} volume under the sounds`)
		end
		expect.equal(Music.WILD.fade >= 1, true)
	end,

	["the town music is quiet, licensed and fades gently"] = function()
		local town = Music.TOWN
		expect.equal(#town.tracks >= 1, true)
		for _, id in town.tracks do
			expect.equal(string.match(id, "^rbxassetid://%d+$") ~= nil, true, id)
		end
		expect.equal(town.volume, 0.3, "up again (owner 2026-11-20: \"turn the townmusic volume up\"; 0.22 that morning, 0.18 since 2026-11-04)")
		-- The limiter still flattens the swells: its threshold is unchanged, so the loudest part rises with the volume
		-- (round 5: "still too low" outweighs 2026-11-03's "never louder on the loudest part")
		expect.equal(town.compressor.threshold, -48.5)
		expect.equal(town.compressor.ratio, 20)
		local squash = town.compressor
		expect.equal(squash ~= nil, true, "a compressor evens out the louder parts (owner: too loud in the later parts)")
		expect.equal(squash.threshold < 0 and squash.threshold >= -60, true, "threshold in dB, -60 to 0")
		expect.equal(squash.ratio >= 15 and squash.ratio <= 50, true, "a limiter: the loudest parts never get louder (owner)")
		expect.equal(squash.attack > 0 and squash.release > 0, true)
		expect.equal(#town.options >= 3, true, "options for the owner to pick from (/music <n> in Studio)")
		for _, option in town.options do
			expect.equal(string.match(option.id, "^rbxassetid://%d+$") ~= nil and #option.name > 0, true, option.name)
		end
		expect.equal(town.fade >= 1, true)
		expect.equal(town.margin > 0, true)
		expect.equal(MusicRules.inTown(0, 0, Town.BOUNDS, town.margin), true, "the plaza is in town with the real numbers")
	end,
	["the pack opening has its own music (owner 2026-11-10: too plain), licensed, levelled, with options to pick from"] = function()
		local opening = Music.OPENING
		expect.equal(MusicRules.find(Music, "opening"), opening)
		assert(#opening.options >= 4, "options to audition with /music opening <n>")
		local ids = {}
		for _, option in opening.options do
			assert(string.match(option.id, "^rbxassetid://%d+$"), `{option.name} is an asset id`)
			ids[option.id] = true
		end
		for _, track in opening.tracks do
			assert(ids[track], `{track} is one of the options`)
		end
		expect.equal(opening.volume, 0.07, "lowered from the owner's 0.1 (2026-11-13: \"lower music/sound volume\")")
		assert(opening.compressor, "through the leveler")
		assert(opening.fade and opening.fade <= 1.5, "a quick crossfade in and out of the opening")
		for _, list in { Music.WILD.areas, Music.WILD.arenas } do
			for _, place in list do
				for _, option in place.options do
					assert(option.id ~= opening.tracks[1], `the opening's track isn't {place.key}'s too`)
				end
			end
		end
	end,
	["each pack opening plays the next of its three pieces, looping while it's up (owner: not the same music always)"] = function()
		local opening = Music.OPENING
		expect.equal(#opening.tracks, 3, "options 3, 1 and 2")
		expect.equal(opening.tracks[1], opening.options[3].id, "the owner's pick first")
		expect.equal(opening.tracks[2], opening.options[1].id)
		expect.equal(opening.tracks[3], opening.options[2].id)
		expect.equal(opening.rotate, "visit", "one piece per opening, the next one next time")
		expect.equal(MusicRules.visitTrack(nil, 3), 1, "the first opening")
		expect.equal(MusicRules.visitTrack(1, 3), 2)
		expect.equal(MusicRules.visitTrack(3, 3), 1, "round again")
	end,
}
