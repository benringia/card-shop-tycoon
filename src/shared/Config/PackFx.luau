--!strict
-- The pack opening's effects (UI project 3, spec section 5): sheets rendered in Blender (tools/blender/build_pack_fx.py),
-- packed by tools/textures/make_flipbooks.py into assets/ui/fx and uploaded. White light with alpha, so a
-- ParticleEmitter's Color tints them per pack or rarity. Plain data (Lune-tested: tests/PackFxConfig.spec).
export type Sheet = {
	image: string,
	grid: number, -- 2, 4 or 8 (Roblox flipbook layouts)
	frames: number, -- frames in the sheet
}

return {
	SHEETS = {
		-- A flash, light streaks, two shockwave rings, sparks. The rings and sparks are gone by about frame 40: give a
		-- OneShot particle a lifetime of the wanted seconds x 64 / 40.
		RipBurst = { image = "rbxassetid://120158379746484", grid = 8, frames = 64 },
		ShardHolo = { image = "rbxassetid://86753044781562", grid = 4, frames = 16 }, -- an iridescent foil shard tumbling (loops)
		ShardGold = { image = "rbxassetid://111907657947581", grid = 4, frames = 16 }, -- the same in gold
		Glint = { image = "rbxassetid://76441609517939", grid = 4, frames = 16 }, -- a four-point twinkle
	} :: { [string]: Sheet },
	IMAGES = {
		mote = "rbxassetid://116965241657239", -- a soft dot
		rays = "rbxassetid://139701534930046", -- soft rays fading out from the middle
		leak = "rbxassetid://96433664991463", -- a soft bright bar (light out of the tear)
		aura = "rbxassetid://118302663239247", -- the Glow Circle (CardDesign.IMAGES.GLOW)
	},
}
