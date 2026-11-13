--!strict
-- The pack opening's reveal sounds by card (Config/RevealSounds; Util/OpeningCards plays them): which riser and hit
-- layers a card gets, and when the riser starts so it peaks as the card lands. Pure, Lune-tested.
local RevealSoundRules = {}

export type Sound = { id: string, volume: number, loud: number, at: number? }
export type Riser = { id: string, volume: number, loud: number, peak: number }
export type Stack = { riser: Riser?, hit: { Sound } }
export type Timing = { startAt: number, delay: number }

-- A card's sounds: its rarity's riser and hit layers (a Frontier card's: cfg.FRONTIER's), a foil card's shimmer on top
-- (a foil card without a look of its own swells with cfg.FOIL_RISER's riser); nil for a plain card with none (a Common)
function RevealSoundRules.stack(cfg: any, rarity: string, foil: boolean, frontier: boolean): Stack?
	local look = cfg.BY_RARITY[if frontier then cfg.FRONTIER else rarity]
	if not look and not foil then
		return nil
	end
	local hit: { Sound } = if look then table.clone(look.hit) else {}
	if foil then
		for _, sound in cfg.FOIL do
			table.insert(hit, sound)
		end
	end
	return { riser = if look then look.riser else cfg.BY_RARITY[cfg.FOIL_RISER].riser, hit = hit }
end

-- Where a riser starts so its loudest moment (`peak` seconds in) lands `lead` seconds after it's started: that far
-- into the sound, or, for a swell shorter than the lead, from its start after waiting the difference
function RevealSoundRules.riserTiming(peak: number, lead: number): Timing
	if peak >= lead then
		return { startAt = peak - lead, delay = 0 }
	end
	return { startAt = 0, delay = lead - peak }
end

-- How loud a set of layers is heard, about: each one's measured loudness (`loud`) times its volume, added up
function RevealSoundRules.heard(sounds: { Sound }): number
	local total = 0
	for _, sound in sounds do
		total += sound.loud * sound.volume
	end
	return total
end

return RevealSoundRules
