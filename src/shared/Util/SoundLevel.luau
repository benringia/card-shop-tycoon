--!strict
-- A skill sound's volume factor from its measured loudness (Config/SoundLevels): loud ones turned down toward the target,
-- quiet or unmeasured ones left alone. Pure (Lune-tested): Util/SuperFx and Util/MoveFx multiply their Volume by it.
local SoundLevel = {}

function SoundLevel.gain(cfg: any, soundId: string): number
	local key = string.match(soundId, "%d+")
	local level = if key then cfg.LEVELS[key] else nil
	if not level or level <= cfg.TARGET then
		return 1
	end
	return (cfg.TARGET / level) ^ cfg.KNEE
end

return SoundLevel
