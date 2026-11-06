--!strict
-- Your creature's voice (owner 2026-11-04: "an occasional chirp" while it's summoned; Config/Party VOICE,
-- CreatureController plays it): small creatures chirp, Epics and Legendaries give a low huff, each keeping one voice,
-- pitched lower the bigger it is, every 18-40 s, with a little squash-bounce. Pure, Lune-tested.
local PetVoice = {}

export type Config = {
	small: { string },
	big: { string },
	bigRarities: { [string]: boolean },
	every: { number }, -- seconds between chirps, min and max
	pitch: { min: number, max: number, vary: number, power: number },
	bounce: number, -- how much it swells on a chirp (0.08: 8%)
}
export type State = { mine: boolean, inFight: boolean, fainted: boolean, benched: boolean, leaving: boolean }

-- The creature's voice: from the big list for big rarities, else the small one; `seed` keeps it the same each time
function PetVoice.voice(rarity: string, seed: number, cfg: Config): string
	local list = if cfg.bigRarities[rarity] then cfg.big else cfg.small
	return list[math.floor(seed) % #list + 1]
end

-- How loud it is: big rarities' huff at cfg.bigVolume (a pitched-down hiss was harsh at a chirp's volume), else cfg.volume
function PetVoice.volume(rarity: string, cfg: { bigRarities: { [string]: boolean }, volume: number, bigVolume: number }): number
	return if cfg.bigRarities[rarity] then cfg.bigVolume else cfg.volume
end

-- Seconds until the next chirp, `roll` 0-1 picking within cfg.every
function PetVoice.nextChirp(roll: number, cfg: Config): number
	return cfg.every[1] + (cfg.every[2] - cfg.every[1]) * math.clamp(roll, 0, 1)
end

-- PlaybackSpeed: (baseHeight / height) ^ power kept within min-max, then a 1 ± vary wobble from `roll` 0-1
function PetVoice.pitch(height: number, baseHeight: number, roll: number, cfg: Config): number
	local p = cfg.pitch
	local size = if height > 0 then (baseHeight / height) ^ p.power else math.huge
	local wobble = 1 + p.vary * (math.clamp(roll, 0, 1) * 2 - 1)
	return math.clamp(size, p.min, p.max) * wobble
end

-- Your own creature, out and about: not fighting, fainted, swapped out or on its way back to you. Only then it chirps
-- (and heals at the spring, Util/HealFx)
function PetVoice.isFree(state: State): boolean
	return state.mine and not state.inFight and not state.fainted and not state.benched and not state.leaving
end

-- Its size `t` seconds into a chirp that lasts `seconds`: swells by cfg.bounce halfway and settles back
function PetVoice.bounce(t: number, seconds: number, cfg: Config): number
	if t <= 0 or t >= seconds then
		return 1
	end
	return 1 + cfg.bounce * math.sin(t / seconds * math.pi)
end

return PetVoice
