--!strict
-- The town's music (owner 2026-11-04: "a subtle gentle town music" with the birds and the wind; Config/Music,
-- TownMusicController plays it): where the town is and which track comes next. Pure, Lune-tested.
local MusicRules = {}

-- In the town: inside the island's bounds (Config/Town BOUNDS, centred on the plaza) or within `margin` studs of them
function MusicRules.inTown(x: number, z: number, bounds: { HALF_X: number, HALF_Z: number }, margin: number): boolean
	return math.abs(x) <= bounds.HALF_X + margin and math.abs(z) <= bounds.HALF_Z + margin
end

-- The track after `current` (0: none yet) of `count`, round and round
function MusicRules.nextTrack(current: number, count: number): number
	return current % count + 1
end

return MusicRules
