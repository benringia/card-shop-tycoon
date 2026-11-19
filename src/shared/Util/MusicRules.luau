--!strict
-- Background music (Config/Music, MusicController plays it; owner 2026-11-04: the town's "subtle gentle town music",
-- then music in the Wild valley and its boss arenas): where the town is, whose music plays where you are, which track
-- comes next and Studio's "/music" previews. Pure, Lune-tested.
local MusicRules = {}

-- In the town: inside the island's bounds (Config/Town BOUNDS, centred on the plaza) or within `margin` studs of them
function MusicRules.inTown(x: number, z: number, bounds: { HALF_X: number, HALF_Z: number }, margin: number): boolean
	return math.abs(x) <= bounds.HALF_X + margin and math.abs(z) <= bounds.HALF_Z + margin
end

-- A place's volume for its track `index`: its own number (`volumes`, pieces differ in loudness) or the place's
function MusicRules.trackVolume(place: { volume: number, volumes: { [number]: number }? }, index: number): number
	local own = if place.volumes then place.volumes[index] else nil
	return own or place.volume
end

-- A world's fight layer volume right now (its `fight` loop: drums over the area's music): in for a fight with a
-- monster, louder against an elite, 0 otherwise (no fight, a boss arena with its own music, a world without one)
function MusicRules.fightVolume(world: any, state: { fighting: boolean, elite: boolean?, boss: boolean? }): number
	local fight = world.fight
	if not fight or not state.fighting or state.boss then
		return 0
	end
	return fight.volume * (if state.elite then fight.elite else 1)
end

-- The track after `current` (0: none yet) of `count`, round and round
function MusicRules.nextTrack(current: number, count: number): number
	return current % count + 1
end

-- A place that starts on a random piece each time you arrive and after each one ends (`rotate = "random"`, the
-- town): any of `count` the first time, then one of the others, by `roll` in [0, 1]
function MusicRules.randomTrack(previous: number?, count: number, roll: number): number
	if count <= 1 then
		return 1
	end
	if not previous or previous < 1 or previous > count then
		return math.min(count, math.floor(roll * count) + 1)
	end
	local pick = math.min(count - 1, math.floor(roll * (count - 1)) + 1)
	return if pick >= previous then pick + 1 else pick
end

-- A place that changes piece each time you come (`rotate = "visit"`, the pack opening): the next one after `previous`
-- (nil: the first time)
function MusicRules.visitTrack(previous: number?, count: number): number
	return MusicRules.nextTrack(previous or 0, count)
end

-- Studio's "/music [place] <n> [volume]": the place (its key; none: the town), the option to hear (0: back to the
-- normal tracks) and a volume kept within 0-1 (nil: the configured one); nil for an unknown place or option.
-- `counts`: each place's number of options, by key
function MusicRules.parsePreview(text: string, counts: { [string]: number }): (string?, number?, number?)
	local place, index, volume = string.match(text, "^%S+%s+(%a+)%s+(%d+)%s*([%d%.]*)")
	if not place then
		place = "town"
		index, volume = string.match(text, "^%S+%s+(%d+)%s*([%d%.]*)")
	end
	local count = counts[place :: string]
	local number = tonumber(index or "")
	if not count or not number or number > count then
		return nil, nil, nil
	end
	local level = tonumber(volume or "")
	return place, number, if level then math.clamp(level, 0, 1) else nil
end

-- Whose music plays where you are (its key, nil: none): a boss arena's (`arena`, its zone, WildValley.arenaZoneAt),
-- else the Wild area you're in (`area`, WildValley.zoneAt), else the town's (`inTown`); on a pass between two areas of
-- the valley (in none of them) the area playing keeps on (`last`)
-- `world`: the valley's music (Config/Music WILD, the default, or FRONTIER in the Frontier)
function MusicRules.place(music: any, arena: number?, area: number?, inTown: boolean, last: string?, world: any?): string?
	local valley = world or music.WILD
	if arena and valley.arenas[arena] then
		return valley.arenas[arena].key
	elseif area and valley.areas[area] then
		return valley.areas[area].key
	elseif inTown then
		return music.TOWN.key
	end
	for _, other in valley.areas do
		if other.key == last then
			return last
		end
	end
	return nil
end

-- A place's music settings by its key (nil: no such place)
function MusicRules.find(music: any, key: string): any
	if music.TOWN.key == key then
		return music.TOWN
	end
	if music.OPENING and music.OPENING.key == key then
		return music.OPENING
	end
	if music.WELCOME and music.WELCOME.key == key then
		return music.WELCOME
	end
	for _, place in music.PROLOGUE or {} do
		if place.key == key then
			return place
		end
	end
	if music.FRONTIER and music.FRONTIER.fight and music.FRONTIER.fight.key == key then
		return music.FRONTIER.fight
	end
	local lists = { music.WILD.areas, music.WILD.arenas }
	if music.FRONTIER then
		table.insert(lists, music.FRONTIER.areas)
		table.insert(lists, music.FRONTIER.arenas)
	end
	for _, list in lists do
		for _, place in list do
			if place.key == key then
				return place
			end
		end
	end
	return nil
end

return MusicRules
