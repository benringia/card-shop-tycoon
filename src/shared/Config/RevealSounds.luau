--!strict
-- The pack opening's reveal sounds (owner 2026-11-13: "change the opening card sound effects to be more premium
-- sounding? specially when you got rare cards and above"; Util/RevealSoundRules, played by Util/OpeningCards): each
-- Rare-or-better card swells into its flip with a riser timed to peak as the card lands (`peak`: seconds into the sound
-- where it's loudest) and lands on a stack of layers, `at` seconds after the landing: a hit, low weight and a sparkling
-- tail, bigger the rarer the card; a foil card adds a shimmer. A Common just flips (Config/PackOpening SOUNDS flip).
-- `loud`: the sound's peak PlaybackLoudness at full volume, measured in Studio 2026-11-13 (heard ~ loud x volume; the
-- old Rare chime measured 11 against the Epic's 300: it barely sounded). All Roblox-licensed: Pro Sound Effects unless
-- marked APM. Plain data.
export type Sound = { id: string, volume: number, loud: number, at: number? }
export type Riser = { id: string, volume: number, loud: number, peak: number }
export type Look = { riser: Riser, hit: { Sound } }

return {
	BY_RARITY = {
		-- A bright magic pulse and a bell ding, an airy rising whoosh before
		Rare = {
			riser = { id = "rbxassetid://9113078189", volume = 0.35, loud = 127, peak = 3.12 }, -- Air Whoosh High End Ascending Short 3
			hit = {
				{ id = "rbxassetid://9116393976", volume = 0.4, loud = 240 }, -- Magic Glow Short Pulsing Bursts 9
				{ id = "rbxassetid://9126073011", volume = 0.5, loud = 91 }, -- Synth Sparkle Tone High Pitch Bell Tone Ding
			},
		},
		-- Brighter and longer: sparkling chimes over a magic burst, spinning chimes trailing off; a phasey magic suck before
		["Very Rare"] = {
			riser = { id = "rbxassetid://9120746721", volume = 0.45, loud = 65, peak = 4.31 }, -- Whooshy Magic Sucks Somewhat Phasey 3
			hit = {
				{ id = "rbxassetid://9125635650", volume = 0.35, loud = 325 }, -- Magical Exit Sparkling Pass Bys Clinking Chimes
				{ id = "rbxassetid://9116385087", volume = 0.3, loud = 259 }, -- Magic Burst 5
				{ id = "rbxassetid://9125644775", volume = 0.35, loud = 89, at = 0.15 }, -- Magic Twirling Small High Pitch Spinning Chimes
			},
		},
		-- Cinematic: a reverse-cymbal build into a tonal impact with a sub boom under it, a harp and angel sparkle after
		Epic = {
			riser = { id = "rbxassetid://9125626856", volume = 0.35, loud = 250, peak = 2.99 }, -- Light Cone Suck Synth And Reverse Cymbal Build
			hit = {
				{ id = "rbxassetid://9120113574", volume = 0.45, loud = 298 }, -- Tonal Impact 1
				{ id = "rbxassetid://9119661511", volume = 0.35, loud = 371 }, -- Sub Boom Slapback Element 1
				{ id = "rbxassetid://125706237686412", volume = 0.3, loud = 244, at = 0.1 }, -- Glistening Harp - Sting (APM)
				{ id = "rbxassetid://9113122880", volume = 0.25, loud = 207, at = 0.3 }, -- Angel Sparkle 5
			},
		},
		-- The biggest: a long reverse-cymbal build into the orchestral hit, a deep boom, a tonal impact, a heavenly sting
		-- and a long angel sparkle
		Legendary = {
			riser = { id = "rbxassetid://9125626779", volume = 0.45, loud = 208, peak = 4.88 }, -- Light Cone Suck Synth And Reverse Cymbal Build (long)
			hit = {
				{ id = "rbxassetid://1844539433", volume = 0.6, loud = 205 }, -- Orchestral Hits (APM)
				{ id = "rbxassetid://9119661508", volume = 0.35, loud = 377 }, -- Sub Boom Slapback Element 2
				{ id = "rbxassetid://9120113588", volume = 0.3, loud = 303 }, -- Tonal Impact 2
				{ id = "rbxassetid://1839901317", volume = 0.3, loud = 269, at = 0.2 }, -- Heavenly sting (APM)
				{ id = "rbxassetid://9113122722", volume = 0.25, loud = 192, at = 0.4 }, -- Angel Sparkle 2
			},
		},
	} :: { [string]: Look },
	-- A Frontier card: the Legendary's stack
	FRONTIER = "Legendary",
	-- A foil Common is teased too: it swells with this rarity's riser
	FOIL_RISER = "Rare",
	-- A foil card's shimmer, added to its stack
	FOIL = {
		{ id = "rbxassetid://9114369623", volume = 0.25, loud = 95, at = 0.2 }, -- Fairy Dust 1
	} :: { Sound },
	FADE = 0.12, -- the riser fades out this fast as the hit lands
	-- Every reveal sound plays at this share of its volume (owner 2026-11-13: "lower music/sound volume"; the ladder
	-- between rarities stays as measured)
	MASTER = 0.7,
}
