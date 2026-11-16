--!strict
-- Effects toned to the scene (the owner 2026-11-10: "the particles are too bright on a white map like this... when I
-- cast my prism sword skill I only see white flashes instead of the animation/rays of different colors"; Util/FxTone,
-- maths in Util/FxToneRules). Additive light on white ground adds up to white, so on bright ground effects blend their
-- colours in instead. Plain data.
return {
	-- How bright the scene round you is, 0 (dark: effects as made) to 1 (snow): the luminance (0-1) of the ground under
	-- you (`ground` of it) and the fog (`fog` of it), from `from` (nothing changes) up to `to` (fully toned)
	ground = 0.7,
	fog = 0.3,
	from = 0.6,
	to = 0.82,
	-- At full tone: an effect's LightEmission (its additive share) loses `emission` of itself, its Brightness
	-- `brightness`; a glowing white core (its LightEmission at least `coreLight`, every colour channel at least
	-- `white`) fades `whiteFade` toward clear; an effect's light loses `light` of its brightness
	emission = 0.8,
	brightness = 0.3,
	coreLight = 0.7,
	white = 235,
	whiteFade = 0.6,
	light = 0.55,
	-- Seconds between checks of the ground under you; a change of more than `retone` re-tones the effects already out
	check = 0.5,
	retone = 0.1,
	-- Kept as made: the world's own weather and scenery (snow, rain, crystals' lights...), by top-level Workspace name;
	-- the plaza's spring and portals and the fountain's rune, light column and orbs too (owner 2026-11-17: the Frontier
	-- fountain's glow turned black on its snow)
	skip = { "Scenery", "FrontierFx", "Wild", "TownDecor", "Terrain", "Plaza", "FountainFx" },
	-- Textures drawn on black with no transparency: they only look right fully additive (blended in, their black square
	-- shows: owner 2026-11-17, "mistfins glow is black and also the fountain"). Found by checking every effect texture
	-- (the source PNGs, the store packs' downloads and on a white test floor): the Yona pack's ember specks (creature
	-- auras), assets/ui/fx/waterfall-streaks.png (the fountains' water, the town's trickles) and rune-circle.png. On
	-- bright ground they keep their LightEmission and fade `additiveFade` (at full tone) instead
	additive = { "rbxassetid://1084996976", "rbxassetid://139671283074387", "rbxassetid://131308578602059" },
	additiveFade = 0.45,
}
