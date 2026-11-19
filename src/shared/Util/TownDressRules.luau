--!strict
-- The town's dressing (Config/TownDress): an event day's banner and where it hangs on a lamp post, and when the
-- night's shooting star shows. Pure (plain numbers in and out), Lune-tested; TownDressController builds the parts.
local TownDressRules = {}

export type Point = { x: number, z: number }
export type Look = { color: { number }, image: string, tint: { number } }

-- The day's banner: the event's (its Config/Events id) when it has one; nil on a plain day
function TownDressRules.look(cfg: { LOOKS: { [string]: Look } }, eventId: string?): Look?
	return if eventId then cfg.LOOKS[eventId] else nil
end

-- Where a lamp's banner hangs: `out` studs beside its pole (away from the town's middle, so the pair at a crossing
-- frame it), at `height`, in line with the lamps; and the way it faces along z: toward the street (the town's middle)
function TownDressRules.banner(lamp: Point, banners: { out: number, height: number }): (number, number, number, number)
	local side = if lamp.x < 0 then -1 else 1
	return lamp.x + side * banners.out, banners.height, lamp.z, if lamp.z < 0 then 1 else -1
end

-- Whether a shooting star may cross at this share of the night (0 day .. 1 full night)
function TownDressRules.starShows(night: number, star: { night: number }): boolean
	return night >= star.night
end

return TownDressRules
