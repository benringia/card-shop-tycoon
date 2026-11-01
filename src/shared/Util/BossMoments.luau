--!strict
-- The Wild bosses' moments (spec 2026-11-01-wild-bosses-arenas-design): when the intro roar is due, whether a heal
-- flares, and which effect bones a moment uses. Pure, Lune-tested; MonsterController plays them from the boss marker's
-- attributes (SpawnedAt, Heals, Enraged), so a player who streams in mid-fight sees the state, never a replay.
local BossMoments = {}

-- Seconds until the intro roar (roarAt seconds after the boss spawned), or nil once it has passed or with no spawn time
function BossMoments.roarIn(spawnedAt: number?, now: number, roarAt: number): number?
	if not spawnedAt then
		return nil
	end
	local left = spawnedAt + roarAt - now
	return if left >= 0 then left else nil
end

-- Whether the heal count rose past one already seen (the first sight of a count never flares)
function BossMoments.flares(seen: number?, current: number?): boolean
	return seen ~= nil and current ~= nil and current > seen
end

-- The moment's effect bones if the model has all of them; nil otherwise (no model, no effect)
function BossMoments.anchors(moment: any?, boneNames: { [string]: boolean }): { string }?
	if not moment or not moment.bones then
		return nil
	end
	for _, name in moment.bones do
		if not boneNames[name] then
			return nil
		end
	end
	return moment.bones
end

return BossMoments
