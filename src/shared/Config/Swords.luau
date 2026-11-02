--!strict
-- Swords the player fights bosses with (spec 2026-11-02-you-in-the-fight-design). Only the starter sword for now; the
-- Forge (project 2) adds one per boss, each with its own combo and skill. Plain data so Lune tests can load it.
-- A cut's damage: the summoned creature's ATK x the cut's power x the sword's power (BattleSim.swordHit). Times are
-- seconds from the cut's start: `hitAt` is the strike frame of its animation, `length` the whole cut. `reach` counts
-- from the target's edge; `arc` is the cone in front of you it hits (degrees).
export type Cut = { power: number, hitAt: number, length: number, reach: number, arc: number }
export type Skill = { power: number, hitAt: number, length: number, radius: number, cooldown: number }
-- animations: published asset ids by move ("" until published: Studio plays ReplicatedStorage.SwordAnimations);
-- sounds: asset ids by moment ("" plays nothing)
export type Sword = {
	name: string,
	power: number,
	element: string?,
	model: string, -- ReplicatedStorage.WeaponModels child
	combo: { Cut },
	skill: Skill,
	animations: { [string]: string },
	sounds: { [string]: string },
}

local SWORDS: { [string]: Sword } = {
	starterSword = {
		name = "Steel Sword",
		power = 1,
		element = nil,
		model = "StarterSword",
		combo = {
			{ power = 0.35, hitAt = 0.28, length = 0.56, reach = 9, arc = 70 }, -- crouched wind-up, a stepping cut down across the body
			{ power = 0.35, hitAt = 0.2, length = 0.5, reach = 9, arc = 90 }, -- a sideways sweep
			{ power = 0.6, hitAt = 0.35, length = 0.75, reach = 10, arc = 60 }, -- a leaping overhead slam
		},
		skill = { power = 0.9, hitAt = 0.3, length = 0.8, radius = 11, cooldown = 8 }, -- a spinning slash all round
		animations = {
			draw = "",
			sheath = "",
			cut1 = "",
			cut2 = "",
			cut3 = "",
			skill = "",
			dodge = "",
			flinch = "",
			down = "",
			getUp = "",
			ready = "",
			run = "",
		},
		sounds = {
			swing1 = "",
			swing2 = "",
			swing3 = "",
			hit = "",
			draw = "",
			dodge = "",
			ring = "",
			down = "",
			getUp = "",
		},
	},
}

return {
	STARTER = "starterSword",
	SWORDS = SWORDS,
	UNLOCK_SHOP_LEVEL = 3, -- everyone gets the starter sword here (when boss 1 opens)
	SHEATH_SECONDS = 4, -- the sword goes back on your back after this long without attacking
	COMBO_RESET = 0.9, -- a tap this long after a cut ends still continues the combo; later starts it again
	SOFT_AIM_RANGE = 14, -- attacking turns you toward a target whose edge is this close...
	SOFT_AIM_ANGLE = 75, -- ...and within this many degrees of where you face
	PLAYER_DAMAGE_COLOR = { 255, 214, 92 }, -- your hits' numbers (your creature's stay white)
}
