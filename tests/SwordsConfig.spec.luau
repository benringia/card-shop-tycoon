--!strict
-- The player in boss fights (spec 2026-11-02-you-in-the-fight-design): rest time, the boss attack ladder, the starter sword
local Bosses = require("../src/shared/Config/Bosses")
local Combat = require("../src/shared/Config/Combat")
local Swords = require("../src/shared/Config/Swords")
local SwordFx = require("../src/shared/Config/SwordFx")
local AttackFx = require("../src/shared/Config/AttackFx")
local SwordRules = require("../src/shared/Util/SwordRules")
local expect = require("./lib/expect")

local ANIMATIONS = { "draw", "sheath", "cut1", "cut2", "cut3", "skill", "dodge", "flinch", "down", "getUp", "ready", "run" }
local SOUNDS = { "swing1", "swing2", "swing3", "hit", "draw", "dodge", "ring", "down", "getUp" }

return {
	-- Weapons round 2 (owner 2026-11-07: "hold the sword the right way, not flat"): every sword model has its edge along
	-- X and its flat along Z, so the hand's grip turns it a quarter turn about the blade, the flat facing the palm. Measured
	-- in Studio over the starter's cuts: without the turn the flat led every cut (0.63-0.79 of the swing), with it the edge
	-- Grips are per weapon family since spears (spec 2026-11-07-weapons-round2-design 5.1)
	["every family has a hand grip, a back grip and a back size"] = function()
		expect.equal(Swords.GRIPS.sword.hand.twist, 90, "the sword's flat to the palm")
		expect.equal(Swords.GRIPS.sword.backScale, 1.05)
		expect.equal(Swords.GRIPS.spear.backScale, 1)
	end,

	-- Weapons round 2 (spec 2026-11-07-weapons-round2-design 5.2): one moveset for all four spears, owner's storyboard
	["the spear moveset: thrust, sweep, sky pierce and piercing rush at the sword's damage a second"] = function()
		local spear = Swords.SWORDS.spear
		expect.equal(#spear.combo, 3)
		expect.equal(spear.combo[1].reach, 12, "the thrust's reach")
		expect.equal(spear.combo[1].arc, 30)
		expect.equal(spear.combo[2].reach, 11, "the sweep's reach")
		expect.equal(spear.combo[2].arc, 120)
		local line = spear.combo[3].line :: Swords.Line
		expect.equal(line.length, 8, "the plunge point")
		expect.equal(line.width, 3)
		expect.equal(line.burst, 4)
		expect.near(SwordRules.comboPowerPerSecond(spear.combo), SwordRules.comboPowerPerSecond(Swords.SWORDS.starterSword.combo), 1e-3)
		expect.equal(spear.skill.power, 0.9)
		expect.equal(spear.skill.cooldown, Swords.SKILL_COOLDOWN)
		expect.equal(spear.skill.shape.kind, "dash")
		local dash = spear.skill.dash :: Swords.Dash
		expect.equal(dash.studs, 12)
		expect.equal(dash.width, 3)
		expect.equal(spear.model, "Spear", "its animation folder")
	end,

	-- The spear's timings are its animations' (tools/blender/anim_spear.py, built by tools/anim/build_kfs: their Hit
	-- markers and lengths) and its moves carry you as they were keyed (the lunges, the leap, the rush)
	["the spear's timings are its animations' markers"] = function()
		local spear = Swords.SWORDS.spear
		expect.equal(spear.combo[1].hitAt, 0.22, "the thrust's Hit marker")
		expect.equal(spear.combo[1].length, 0.62, "the thrust's length")
		expect.equal(spear.combo[2].hitAt, 0.20, "the sweep's Hit marker")
		expect.equal(spear.combo[2].length, 0.62, "the sweep's length")
		expect.equal(spear.combo[3].hitAt, 0.70, "Sky Pierce's Hit marker")
		expect.equal(spear.combo[3].length, 1.25, "Sky Pierce's length")
		expect.equal(spear.skill.hitAt, 0.45, "Piercing Rush's Hit marker (as the rush arrives)")
		expect.equal(spear.skill.length, 1.0, "Piercing Rush's length")
		local thrust = spear.combo[1].lunge :: Swords.Lunge
		expect.equal(thrust.studs, 2.0, "the thrust's deep lunge")
		local dash = spear.skill.dash :: Swords.Dash
		expect.equal(dash.from, 0.28, "the rush leaves")
		expect.equal(dash.to, 0.42, "and arrives")
	end,

	-- Weapons round 2.5 (spec 2026-11-08-forge-relayout-and-titans-wrath-design 3): the Titan's Lance its own skill, the
	-- Halberd and the Trident keep Piercing Rush
	["the Titan's Lance: the spear's cuts and moves, its own skill Titan's Wrath (a 14 x 4 line at today's strength)"] = function()
		local Weapons = require("../src/shared/Config/Weapons")
		expect.equal(Weapons.ById.titansLance.moveset, "titansLance")
		local lance, spear = Swords.SWORDS.titansLance, Swords.SWORDS.spear
		expect.equal(lance.combo, spear.combo, "the spear's cuts, the same table")
		expect.equal(lance.sounds.thrustAir, spear.sounds.thrustAir, "the spear's sounds")
		for _, key in { "ready", "draw", "sheath", "run", "cut1", "cut2", "cut3" } do
			expect.equal(lance.animations[key], spear.animations[key], key)
		end
		expect.equal(lance.model, "TitansLance", "its skill's animation folder")
		local skill = lance.skill
		expect.equal(skill.power, 0.9)
		expect.equal(skill.cooldown, Swords.SKILL_COOLDOWN)
		expect.equal(skill.shape.kind, "line")
		expect.equal(skill.shape.length, 14)
		expect.equal(skill.shape.width, 4)
		expect.equal(skill.hitAt, 1.35, "the thrust, after the long charge")
		expect.equal(skill.hitAt < skill.length, true)
		expect.isNil(skill.dash, "no rush: you stay put")
		expect.equal((skill.free :: Swords.Free).at, skill.hitAt, "free from the thrust")
	end,

	-- Weapons round 2.5 part 2 (spec 2026-11-09-halberd-and-trident-skills-design): the Halberd and the Trident their
	-- own skills, the Forge Spear keeps Piercing Rush
	["the Halberd's Magma Cleave and the Trident's Torrent Strike: the spear's cuts, their own skills"] = function()
		local Weapons = require("../src/shared/Config/Weapons")
		local SkillFx = require("../src/shared/Config/SwordSkillFx")
		for _, element in { "Ember", "Tide", "Bloom", "Volt", "Shade" } do
			expect.equal(Weapons.ById[`forgeSpear_{element}`].moveset, "spear", `the {element} Forge Spear keeps Piercing Rush`)
		end
		local spear = Swords.SWORDS.spear
		local cases = {
			{ id = "magmaHalberd", model = "MagmaHalberd", look = "magmaCleave", hitAt = 0.6, length = 1.2 },
			{ id = "tidalTrident", model = "TidalTrident", look = "torrentStrike", hitAt = 0.75, length = 1.9 },
		}
		for _, case in cases do
			expect.equal(Weapons.ById[case.id].moveset, case.id, `{case.id}: its own moveset`)
			local moves = Swords.SWORDS[case.id]
			expect.equal(moves.combo, spear.combo, `{case.id}: the spear's cuts, the same table`)
			for _, key in { "ready", "draw", "sheath", "run", "cut1", "cut2", "cut3" } do
				expect.equal(moves.animations[key], spear.animations[key], `{case.id} {key}`)
			end
			expect.equal(moves.model, case.model, `{case.id}: its skill's animation folder`)
			local skill = moves.skill
			expect.equal(skill.power, 0.9, case.id)
			expect.equal(skill.cooldown, Swords.SKILL_COOLDOWN, case.id)
			expect.equal(skill.hitAt, case.hitAt, case.id)
			expect.equal(skill.length, case.length, case.id)
			expect.isNil(skill.dash, `{case.id}: you stay put`)
			expect.equal((skill.free :: Swords.Free).at, skill.hitAt, `{case.id}: free from the hit`)
			expect.equal(moves.fx.skill, case.look, case.id)
			local look = SkillFx.LOOKS[case.look]
			assert(look, `{case.look} exists`)
			expect.equal(look.kind, "skill", case.look)
			expect.equal((look.beats :: any).hit, skill.hitAt, `{case.look}: its hit on the skill's`)
		end
		local cleave = Swords.SWORDS.magmaHalberd.skill.shape
		expect.equal(cleave.kind, "arc")
		expect.equal(cleave.radius, 11)
		expect.equal(cleave.angle, 180)
		local torrent = Swords.SWORDS.tidalTrident.skill.shape
		expect.equal(torrent.kind, "spin")
		expect.equal(torrent.radius, 12)
		expect.equal(SkillFx.LOOKS.torrentStrike.cinematic, true, "your own Torrent Strike's camera pull-back")
	end,

	["Magma Cleave has its own sounds: the whoosh of the swing and the fire burst on the hit; the spear's are untouched"] = function()
		local halberd, spear = Swords.SWORDS.magmaHalberd, Swords.SWORDS.spear
		local keys = {}
		for _, cue in halberd.cues.skill do
			keys[cue.key] = cue.at
		end
		for _, key in { "cleaveWhoosh", "cleaveFire" } do
			assert(keys[key], `the skill cues {key}`)
			expect.equal(halberd.sounds[key] ~= nil and halberd.sounds[key] ~= "", true, `{key} has a sound`)
			expect.isNil(spear.sounds[key], `the spear's sounds stay its own ({key})`)
		end
		expect.equal(keys.cleaveWhoosh < halberd.skill.hitAt, true, "the whoosh as it swings")
		expect.equal(math.abs(keys.cleaveFire - halberd.skill.hitAt) < 0.1, true, "the fire on the hit")
		expect.equal(halberd.sounds.thrustAir, spear.sounds.thrustAir, "the spear's cut sounds")
	end,

	-- Owner 2026-11-09 (Studio): "on magma halberd skill. add a charging up sound while charging"
	["Magma Cleave charges up with a sound: fire building through the wind-up, rushing in to the swing"] = function()
		local halberd = Swords.SWORDS.magmaHalberd
		local keys = {}
		for _, cue in halberd.cues.skill do
			keys[cue.key] = cue.at
		end
		for _, key in { "cleaveCharge", "cleaveRush" } do
			assert(keys[key], `the skill cues {key}`)
			expect.equal(string.sub(halberd.sounds[key] or "", 1, 13), "rbxassetid://", `{key} has a sound`)
			expect.equal(keys[key] < halberd.skill.hitAt, true, `{key} in the wind-up: a dodge before the swing stops it`)
			expect.equal(type((Swords.SOUND_VOLUMES :: any)[key]), "number", `{key} a charge's volume, under the swing`)
		end
		expect.equal(keys.cleaveCharge < 0.15, true, "from the start of the wind-up")
		expect.equal(keys.cleaveRush > keys.cleaveCharge and keys.cleaveRush < keys.cleaveWhoosh, true, "rushing in before the swing's whoosh")
	end,

	["Torrent Strike has its own sounds: the slam, the splash, the torrents surging, the rain falling back"] = function()
		local trident, spear = Swords.SWORDS.tidalTrident, Swords.SWORDS.spear
		local keys = {}
		for _, cue in trident.cues.skill do
			keys[cue.key] = cue.at
		end
		for _, key in { "torrentSlam", "torrentSplash", "torrentSurge", "torrentRain" } do
			assert(keys[key], `the skill cues {key}`)
			expect.equal(trident.sounds[key] ~= nil and trident.sounds[key] ~= "", true, `{key} has a sound`)
			expect.isNil(spear.sounds[key], `the spear's sounds stay its own ({key})`)
		end
		local beats = require("../src/shared/Config/SwordSkillFx").LOOKS.torrentStrike.beats :: { [string]: number }
		expect.equal(math.abs(keys.torrentSlam - beats.slam) < 0.05, true, "the boom on the slam")
		expect.equal(math.abs(keys.torrentSurge - trident.skill.hitAt) < 0.05, true, "the surge on the torrents")
		expect.equal(keys.torrentRain >= beats.fall - 0.1, true, "the rain as it falls back")
	end,

	["Titan's Wrath has its own sounds: the charge, the rumble, the thrust, thorns and the fissure; the spear's are untouched"] = function()
		local lance, spear = Swords.SWORDS.titansLance, Swords.SWORDS.spear
		local keys = {}
		for _, cue in lance.cues.skill do
			keys[cue.key] = cue.at
		end
		for _, key in { "wrathCharge", "wrathRumble", "wrathThrust", "thornsTear" } do
			assert(keys[key], `the skill cues {key}`)
			expect.equal(lance.sounds[key] ~= nil and lance.sounds[key] ~= "", true, `{key} has a sound`)
			expect.isNil(spear.sounds[key], `the spear's sounds stay its own ({key})`)
		end
		expect.equal(keys.wrathThrust < lance.skill.hitAt and lance.skill.hitAt - keys.wrathThrust < 0.1, true, "the thrust's boom on the hit")
		expect.equal(lance.sounds.wrathFissure ~= nil, true, "the fissure's (its burst sound)")
		expect.equal(lance.sounds.thrustAir, spear.sounds.thrustAir, "the spear's cut sounds")
	end,

	-- The line's ends are rounded by half its width (SwordRules.inDashPath, as the dash's path): past its end means more
	-- than 14 + 2 studs out, plus the foe's own radius
	["Titan's Wrath hits every foe on the 14-stud line ahead and none beside or past it"] = function()
		local shape = Swords.SWORDS.titansLance.skill.shape
		local function t(id: string, x: number, z: number): SwordRules.Target
			return { id = id, x = x, z = z, radius = 1 }
		end
		local hits = SwordRules.skillHits(shape, 0, 0, 0, 0, 0, -1, { t("near", 0, -3), t("far", 0, -14.5), t("past", 0, -17.5), t("side", 6, -5), t("edge", 2.5, -8) })
		local got = {}
		for _, hit in hits do
			got[hit.id] = hit.share
		end
		expect.equal(got.near, 1, "close ahead")
		expect.equal(got.far, 1, "its edge inside 14 studs")
		expect.equal(got.edge, 1, "its edge inside the 4-stud width")
		expect.isNil(got.past, "past the end")
		expect.isNil(got.side, "beside you")
	end,

	-- No spear move reaches past a boss's swipe (its ring radius + RING_SWIPE_EXTRA, measured from the boss's centre), so
	-- reach never buys a spot the boss can't hit
	["a spear's reach never makes a spot a boss's swipe can't reach"] = function()
		local longest = 0
		for _, cut in Swords.SWORDS.spear.combo do
			longest = math.max(longest, if cut.line then cut.line.length + cut.line.burst else cut.reach)
		end
		for id, boss in Bosses.BOSSES do
			local ring = boss.ringRadius or Bosses.RING_RADIUS
			expect.equal(longest + ring * Bosses.HIT_RADIUS_SHARE <= ring + Bosses.RING_SWIPE_EXTRA, true, id)
		end
	end,

	-- Weapons round 3 (spec 2026-11-09-weapons-round3-scythes-design 5.2; the owner: "epic, exaggerated moves, wide
	-- slashes in all directions", "a bit slower but still flashy"): the scythe's sweeps, its whirlwind, Reaping Cyclone
	["the scythe moveset: reap, back sweep, whirlwind and Reaping Cyclone at the sword's damage a second"] = function()
		local scythe = Swords.SWORDS.scythe
		assert(scythe, "the scythe moveset")
		expect.equal(#scythe.combo, 3)
		expect.equal(scythe.combo[1].reach, 10)
		expect.equal(scythe.combo[1].arc, 180)
		expect.equal(scythe.combo[2].reach, 10)
		expect.equal(scythe.combo[2].arc, 180)
		expect.equal(scythe.combo[3].reach, 10)
		expect.equal(scythe.combo[3].arc, 360)
		expect.near(SwordRules.comboPowerPerSecond(scythe.combo), SwordRules.comboPowerPerSecond(Swords.SWORDS.starterSword.combo), 1e-3)
		for index, cut in scythe.combo do
			local sword = Swords.SWORDS.starterSword.combo[index]
			expect.equal(cut.length >= sword.length * 1.25, true, `cut {index} a third slower than the sword's`)
		end
		expect.equal(scythe.skill.power, 0.9)
		expect.equal(scythe.skill.cooldown, Swords.SKILL_COOLDOWN)
		expect.equal(scythe.skill.shape.kind, "spin")
		expect.equal(scythe.skill.shape.radius, 9)
		expect.equal(scythe.model, "Scythe")
		expect.equal(Swords.GRIPS.scythe.backScale, 1)
	end,

	["a scythe's reach never makes a spot a boss's swipe can't reach"] = function()
		local longest = 0
		for _, cut in Swords.SWORDS.scythe.combo do
			longest = math.max(longest, cut.reach)
		end
		for id, boss in Bosses.BOSSES do
			local ring = boss.ringRadius or Bosses.RING_RADIUS
			expect.equal(longest + ring * Bosses.HIT_RADIUS_SHARE <= ring + Bosses.RING_SWIPE_EXTRA, true, id)
		end
	end,

	-- Sword skills round (spec 2026-11-06-sword-skills-design): each round 1 sword its own moveset, the starter's cuts
	["each round 1 sword has its own moveset: the starter's cuts and animations, its own skill at today's strength"] = function()
		local Weapons = require("../src/shared/Config/Weapons")
		expect.equal(Weapons.ById.sunforgedBlade.moveset, "sunforgedBlade")
		expect.equal(Weapons.ById.verdantBlade.moveset, "verdantBlade")
		expect.equal(Weapons.ById.prismBlade.moveset, "prismBlade")
		for _, element in { "Ember", "Tide", "Bloom", "Volt", "Shade" } do
			expect.equal(Weapons.ById[`forgeSword_{element}`].moveset, "forgeSword", element)
		end
		expect.equal(Weapons.ById.starterSword.moveset, "starterSword")
		local starter = Swords.SWORDS.starterSword
		local kinds = { dash = true, spin = true, line = true, wave = true, judgment = true }
		-- the swords' movesets (the spear has its own cuts: weapons round 2)
		local swordMovesets = {}
		for _, weapon in Weapons.WEAPONS do
			if weapon.family == "sword" and weapon.moveset then
				swordMovesets[weapon.moveset] = true
			end
		end
		for id, sword in Swords.SWORDS do
			if not swordMovesets[id] then
				continue
			end
			expect.equal(sword.combo, starter.combo, `{id} swings the starter's cuts`)
			for _, key in { "cut1", "cut2", "cut3" } do
				expect.equal(sword.animations[key], starter.animations[key], `{id} {key}`)
			end
			expect.equal(sword.skill.power, 0.9, `{id} skill power`)
			expect.equal(sword.skill.cooldown, Swords.SKILL_COOLDOWN, `{id} skill cooldown`)
			assert(sword.skill.shape and kinds[sword.skill.shape.kind], `{id} skill shape`)
		end
		expect.equal(starter.skill.shape.kind, "dash")
		expect.equal(starter.fx, nil, "the Steel Sword keeps today's look")
		local fx = {
			forgeSword = { "elementTrail", "elementBurst", "elementalSpin" },
			verdantBlade = { "leafShed", "rootBurst", "thornline" },
			sunforgedBlade = { "fireTrail", "lavaCrack", "sunfallCleave" },
			prismBlade = { "rainbowArc", "prismShatter", "prismJudgment" },
		}
		for id, names in fx do
			local sword = Swords.SWORDS[id]
			assert(sword and sword.fx, id)
			expect.equal(sword.fx.slash, names[1])
			expect.equal(sword.fx.finisher, names[2])
			expect.equal(sword.fx.skill, names[3])
		end
	end,

	["the Sunforged Blade's cuts carry a fire layer, its skill its own sounds; the Steel Sword's are untouched"] = function()
		local sun = Swords.SWORDS.sunforgedBlade
		local starter = Swords.SWORDS.starterSword
		local function keys(list: { any }): { [string]: boolean }
			local found = {}
			for _, cue in list do
				found[cue.key] = true
			end
			return found
		end
		for _, move in { "cut1", "cut2", "cut3" } do
			expect.equal(keys(sun.cues[move]).fireWhoosh, true, `{move}: the fire whoosh`)
			expect.equal(keys(starter.cues[move]).fireWhoosh, nil, `the Steel Sword's {move}`)
			expect.equal(#sun.cues[move], #starter.cues[move] + (if move == "cut3" then 2 else 1), `{move}: the starter's cues kept`)
		end
		expect.equal(keys(sun.cues.cut3).lavaBurst, true, "the finisher's lava burst")
		local skill = keys(sun.cues.skill)
		expect.equal(skill.flameLicks and skill.fireSwing, true, "the charge and the cleave")
		for _, key in { "fireWhoosh", "lavaBurst", "flameLicks", "fireSwing", "fireBurst" } do
			expect.equal(string.sub(sun.sounds[key] or "", 1, 13), "rbxassetid://", key)
			expect.equal(starter.sounds[key], nil, `the Steel Sword has no {key}`)
		end
	end,

	["the Verdant Blade's cuts carry a leafy rustle, its skill the vines tearing up and snapping shut"] = function()
		local verdant = Swords.SWORDS.verdantBlade
		local starter = Swords.SWORDS.starterSword
		local function keys(list: { any }): { [string]: boolean }
			local found = {}
			for _, cue in list do
				found[cue.key] = true
			end
			return found
		end
		for _, move in { "cut1", "cut2", "cut3" } do
			expect.equal(keys(verdant.cues[move]).leafRustle, true, `{move}: the rustle`)
		end
		expect.equal(keys(verdant.cues.cut3).rootCrack, true, "the finisher's roots cracking")
		expect.equal(keys(verdant.cues.skill).vinesTear, true, "the vines tearing up")
		for _, key in { "leafRustle", "rootCrack", "vinesTear", "vineSnap" } do
			expect.equal(string.sub(verdant.sounds[key] or "", 1, 13), "rbxassetid://", key)
			expect.equal(starter.sounds[key], nil, `the Steel Sword has no {key}`)
		end
	end,

	["the Prism Blade's cuts carry a crystal chime, its skill its summon, strikes and pillar"] = function()
		local prism = Swords.SWORDS.prismBlade
		local starter = Swords.SWORDS.starterSword
		local function keys(list: { any }): { [string]: boolean }
			local found = {}
			for _, cue in list do
				found[cue.key] = true
			end
			return found
		end
		for _, move in { "cut1", "cut2", "cut3" } do
			expect.equal(keys(prism.cues[move]).crystalChime, true, `{move}: the chime`)
		end
		expect.equal(keys(prism.cues.cut3).prismShatter, true, "the finisher's shatter")
		expect.equal(keys(prism.cues.skill).prismSummon, true, "the summon")
		for _, key in { "crystalChime", "prismShatter", "prismSummon", "prismStrike", "prismBoom" } do
			expect.equal(string.sub(prism.sounds[key] or "", 1, 13), "rbxassetid://", key)
			expect.equal(starter.sounds[key], nil, `the Steel Sword has no {key}`)
		end
		expect.equal(prism.skill.length, 1.75, "the animation's length")
	end,

	["the Forge Sword's sounds are its element's: a layer under every cut, a blast on the finisher and the ring wave"] = function()
		local forge = Swords.SWORDS.forgeSword
		local function keys(list: { any }): { [string]: boolean }
			local found = {}
			for _, cue in list do
				found[cue.key] = true
			end
			return found
		end
		for _, move in { "cut1", "cut2", "cut3" } do
			expect.equal(keys(forge.cues[move]).elementLayer, true, `{move}: the element layer`)
		end
		expect.equal(keys(forge.cues.cut3).elementBlast and keys(forge.cues.skill).elementBlast, true, "the blast on the finisher and the wave")
		for _, element in { "Ember", "Tide", "Bloom", "Volt", "Shade" } do
			for _, key in { "elementLayer", "elementBlast" } do
				expect.equal(string.sub(forge.sounds[`{key}_{element}`] or "", 1, 13), "rbxassetid://", `{key}_{element}`)
			end
		end
		expect.equal(forge.skill.hitAt, 0.8, "the ring wave")
		expect.equal(forge.skill.length, 1.1, "the animation's length")
	end,

	["each round 1 sword's skill animation is published (the owner's ids, 2026-11-07)"] = function()
		local ids = {
			forgeSword = "rbxassetid://87540825929374",
			verdantBlade = "rbxassetid://101505841745641",
			sunforgedBlade = "rbxassetid://135525152609348",
			prismBlade = "rbxassetid://136391900364573",
		}
		for moveset, id in ids do
			expect.equal(Swords.SWORDS[moveset].animations.skill, id, moveset)
		end
		expect.equal(Swords.SWORDS.starterSword.animations.skill ~= ids.forgeSword, true, "the Steel Sword keeps its dash slash")
	end,

	["the Halberd's and the Trident's skill animations are published (the owner's ids, 2026-11-09)"] = function()
		local ids = {
			magmaHalberd = "rbxassetid://139376815690800",
			tidalTrident = "rbxassetid://97640469455794",
		}
		for moveset, id in ids do
			expect.equal(Swords.SWORDS[moveset].animations.skill, id, moveset)
		end
		expect.equal(Swords.SWORDS.spear.animations.skill ~= ids.magmaHalberd, true, "the spear keeps Piercing Rush")
		expect.equal(Swords.SWORDS.magmaHalberd.animations.cut1, Swords.SWORDS.spear.animations.cut1, "the cuts stay the spear's")
	end,

	["each round 1 skill frees you once its damage is committed, inside the move (owner 2026-11-07)"] = function()
		local wants = { forgeSword = 0.8, verdantBlade = 0.45, sunforgedBlade = 1.78, prismBlade = 1.2 }
		for moveset, at in wants do
			local skill = Swords.SWORDS[moveset].skill
			local free = skill.free :: { at: number, reach: boolean? }
			expect.equal(free.at, at, moveset)
			expect.equal(free.at >= skill.hitAt and free.at <= skill.length, true, `{moveset}: after its hit, inside its move`)
		end
		expect.equal((Swords.SWORDS.verdantBlade.skill.free :: any).reach, true, "Thornline: once the vines reach the foe")
		local prism = Swords.SWORDS.prismBlade.skill
		expect.near(prism.free.at, prism.hitAt + (prism.shape.strikes - 1) * prism.shape.gap, 1e-9, "the Prism: its last strike")
		expect.equal(Swords.SWORDS.starterSword.skill.free, nil, "the Steel Sword: as before")
	end,

	["each new skill has the spec's shape"] = function()
		local shapes = Swords.SWORDS
		expect.equal(shapes.forgeSword.skill.shape.kind, "spin")
		expect.equal(shapes.forgeSword.skill.shape.radius, 9)
		local thorn = shapes.verdantBlade.skill.shape
		expect.equal(thorn.length, 18); expect.equal(thorn.width, 4)
		-- owner 2026-11-07: the blade stays in the ground until the vines reach the foe, where they snap shut
		expect.equal(thorn.kind, "wave"); expect.equal(thorn.speed, 20); expect.equal(thorn.blast, 4)
		local hold = shapes.verdantBlade.skill.hold :: { at: number, snap: number }
		expect.equal(hold.at, 0.5); expect.equal(hold.snap, 0.58)
		expect.equal(shapes.verdantBlade.skill.hitAt < hold.at and hold.at < hold.snap, true, "the vines leave, the pose holds, then the snap")
		local sun = shapes.sunforgedBlade.skill.shape
		expect.equal(sun.kind, "wave"); expect.equal(sun.length, 24); expect.equal(sun.width, 6)
		-- owner 2026-11-07: the crescent glides slowly (14 studs a second) and bursts on contact, foes within 6 studs
		expect.equal(sun.speed, 14); expect.equal(sun.blast, 6)
		local prism = shapes.prismBlade.skill.shape
		expect.equal(prism.kind, "judgment"); expect.equal(prism.range, 24); expect.equal(prism.strikes, 5); expect.equal(prism.gap, 0.15)
	end,

	-- Owner 2026-11-08 (free VFX packs, picked in game): a landed cut bursts with the Yona pack's hit (a white flash,
	-- sparks and a shockwave) and its golden sparks; bigger on the finisher and the skill
	["a landed cut's impact: every emitter bursts with a known effect texture"] = function()
		local impact = SwordFx.IMPACT
		assert(#impact.emitters >= 2, "a flash and sparks at least")
		for index, emitter in impact.emitters do
			local id = (AttackFx.TEXTURES :: any)[emitter.texture]
			expect.equal(typeof(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil, true, `emitter {index}: {emitter.texture}`)
			assert(emitter.count >= 1 and emitter.lifetime[1] > 0 and emitter.lifetime[2] >= emitter.lifetime[1], `emitter {index}`)
		end
		assert(impact.big > 1, "the finisher and the skill hit bigger")
		assert(impact.seconds >= 1, "it cleans up after the longest emitter")
	end,

	-- Owner 2026-11-08 ("I can't see this effect when I hit an enemy"): the white slash streaks from the in-game test
	-- (the Euphoric pack's Slash-Impact-01 and the Yona pack's Slash-01) burst with every landed cut too. They fly a set
	-- way from the impact's holder, which faces your camera.
	["a landed cut's impact carries the slash streaks, each flying a valid way"] = function()
		local textures: { [string]: boolean } = {}
		local directions = { Top = true, Bottom = true, Left = true, Right = true, Front = true, Back = true }
		local facings = { camera = true, perpendicular = true, parallel = true }
		for index, emitter in SwordFx.IMPACT.emitters do
			textures[emitter.texture] = true
			assert(emitter.direction == nil or directions[emitter.direction], `emitter {index}: direction {emitter.direction}`)
			assert(emitter.facing == nil or facings[emitter.facing], `emitter {index}: facing {emitter.facing}`)
			assert(emitter.accel == nil or #emitter.accel == 3, `emitter {index}: accel x, y, z`)
		end
		expect.equal(textures.slashStreak, true, "Slash-Impact's streak")
		expect.equal(textures.slashArc, true, "Slash-01's arc")
	end,

	-- Owner 2026-11-08 ("make it look exactly like these"): the picked picture is the slash streaks alone, its arcs
	-- layered (the test burst them back to back), so each hit bursts again a beat later, lighter
	["a landed cut's impact is the slash streaks alone, echoed a beat later"] = function()
		for index, emitter in SwordFx.IMPACT.emitters do
			local slash = emitter.texture == "slashStreak" or emitter.texture == "slashArc" or emitter.texture == "sparkStreak"
			expect.equal(slash, true, `emitter {index}: {emitter.texture}`)
		end
		local echo = SwordFx.IMPACT.echo
		assert(echo.after > 0 and echo.after < 0.4, "inside the streaks' 0.4 s life")
		assert(echo.share > 0 and echo.share <= 1, "lighter or the same")
	end,

	-- Owner 2026-11-08: "update the effect colors/particles based on weapon elements": the streaks take the weapon's
	-- colour (its trail colour, a white core kept), and each element adds its own particles
	["a hit takes the weapon's colour, and each element adds its own particles"] = function()
		local tinted = 0
		for _, emitter in SwordFx.IMPACT.emitters do
			if emitter.color == "tint" then
				tinted += 1
				assert(emitter.whiten == nil or (emitter.whiten >= 0 and emitter.whiten < 1), "a share toward white")
			end
		end
		expect.equal(tinted, #SwordFx.IMPACT.emitters, "every streak, the arc and the sparks")
		for _, element in { "Ember", "Tide", "Bloom", "Volt", "Shade" } do
			local set = (SwordFx.ELEMENT_HIT :: any)[element]
			assert(set and #set >= 1, element)
			for index, emitter in set do
				local id = (AttackFx.TEXTURES :: any)[emitter.texture]
				expect.equal(typeof(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil, true, `{element} {index}: {emitter.texture}`)
				assert(emitter.count >= 1 and emitter.lifetime[1] > 0, `{element} {index}`)
			end
		end
	end,

	-- The sword-moves round's effect textures (tools/textures/make_sword_fx.py), uploaded as images
	["the sword effects' textures are uploaded images"] = function()
		for _, key in { "crescent", "burst", "line", "star" } do
			local id = (SwordFx.TEXTURES :: any)[key]
			expect.equal(typeof(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil, true, `TEXTURES.{key}: {id}`)
		end
	end,

	-- Every swing's candy sparkle arc (Util/HitFx.swingArc): one Beam per arc, so a sweep of at most 180 degrees; it
	-- wipes inside its move and shows before the strike lands
	["every cut and the skill have a swing arc that wipes in before the strike"] = function()
		local starter = Swords.SWORDS.starterSword
		local moves: { [string]: { hitAt: number, length: number } } = { skill = starter.skill }
		for index, cut in starter.combo do
			moves[`cut{index}`] = cut
		end
		for key, move in moves do
			local arc = SwordFx.ARCS[key]
			expect.equal(arc ~= nil, true, `{key} has an arc`)
			expect.equal(math.abs(arc.sweep) > 0 and math.abs(arc.sweep) <= 180, true, `{key} sweep {arc.sweep}`)
			expect.equal(arc.radius > 0 and arc.width > 0 and arc.wipe > 0 and arc.fade > 0, true, `{key} sizes`)
			expect.equal(arc.from >= 0 and arc.from <= move.hitAt and arc.from + arc.wipe <= move.length, true, `{key} timing`)
		end
		expect.equal(SwordFx.ARC_CORE > 0 and SwordFx.ARC_CORE < 1, true, "the white core is narrower")
		expect.equal(SwordFx.BURST.big > SwordFx.BURST.size, true, "big hits burst bigger")
	end,

	["drawing the sword gleams: a short flare at the blade's tip"] = function()
		local gleam = SwordFx.GLEAM
		expect.equal(gleam.seconds > 0 and gleam.seconds <= 0.5, true, "a short gleam")
		expect.equal(gleam.brightness > 0 and gleam.range > 0 and gleam.size > 0, true, "it shows")
		expect.equal(#gleam.color, 3)
	end,

	["the group retune leaves Dungeon room packs alone"] = function()
		expect.equal(Bosses.GROUP_ATK_STEP, 0.15, "rooms scale with the old step")
		for _, bossId in { "meadowWarden", "caveBroodQueen", "emberColossus" } do
			expect.equal(Bosses.BOSSES[bossId].groupAtkStep, 0.08, `{bossId} keeps its retuned step`)
		end
	end,

	["rest takes five minutes"] = function()
		expect.equal(Combat.REST_SECONDS, 300)
	end,

	["every ladder boss attacks players, harder up the ladder"] = function()
		local want = {
			{ 10, 1.4, 0.30, 0.10 },
			{ 9, 1.3, 0.35, 0.12 },
			{ 8, 1.2, 0.40, 0.14 },
			{ 7, 1.1, 0.45, 0.15 },
			{ 6.5, 1.0, 0.50, 0.17 },
			{ 6, 1.0, 0.55, 0.18 },
			{ 5, 0.9, 0.60, 0.20 },
		}
		expect.equal(#Bosses.LADDER, #want, "one row per ladder boss")
		for index, bossId in Bosses.LADDER do
			local attacks = Bosses.BOSSES[bossId].playerAttacks
			expect.equal(attacks.every, want[index][1], `{bossId} every`)
			expect.equal(attacks.warning, want[index][2], `{bossId} warning`)
			expect.near(attacks.big, want[index][3], 1e-9, `{bossId} big`)
			expect.near(attacks.quick, want[index][4], 1e-9, `{bossId} quick`)
		end
		expect.equal((Bosses.BOSSES.prismHydra.playerAttacks.doubleChance or 0) > 0, true, "the Hydra sometimes rings twice")
	end,

	["the starter sword has three cuts, a skill and every animation and sound key"] = function()
		local sword = Swords.SWORDS[Swords.STARTER]
		expect.equal(#sword.combo, 3)
		expect.equal(sword.skill.cooldown, Swords.SKILL_COOLDOWN)
		for _, key in ANIMATIONS do
			expect.equal(typeof(sword.animations[key]), "string", `animation {key}`)
		end
		for _, key in SOUNDS do
			expect.equal(typeof(sword.sounds[key]), "string", `sound {key}`)
		end
		expect.equal(Swords.UNLOCK_SHOP_LEVEL, Bosses.BOSSES[Bosses.LADDER[1]].shopLevel, "the sword comes when boss 1 opens")
	end,

	-- The sword's sound cues (owner 2026-11-04: a whoosh as the finisher jumps, better slash sounds overall): each move
	-- plays its layered sounds at set moments, every cue is a sound the sword has, inside its move, and the cuts' swish
	-- comes with the swing, not at the tap. A skill's cue may also come while its effect still plays after the move
	-- (owner 2026-11-09: Torrent Strike's torrents last longer, its rain falls after the move ends)
	-- Owner 2026-11-09: "increase the weapon skill cooldown and make the weapons share cooldowns. to avoid abuse
	-- (switching to another weapon then pressing the skill and repeat)": one longer cooldown for every weapon's skill (the
	-- server keeps one timer per fighter, whatever weapon is in hand)
	["every weapon's skill shares one longer cooldown"] = function()
		expect.equal(Swords.SKILL_COOLDOWN >= 12, true, `{Swords.SKILL_COOLDOWN} s (was 8)`)
		for id, sword in Swords.SWORDS do
			expect.equal(sword.skill.cooldown, Swords.SKILL_COOLDOWN, id)
		end
	end,

	["every move's sound cues play the sword's own sounds, inside the move"] = function()
		local looks = require("../src/shared/Config/SwordSkillFx").LOOKS
		for _, sword in Swords.SWORDS do
			local look = if sword.fx then looks[sword.fx.skill] else nil
			local fall = if look and look.beats then (look.beats :: { [string]: number }).fall else nil
			local lengths: { [string]: number } = { skill = math.max(sword.skill.length, if fall then fall + 0.1 else 0) }
			for index, cut in sword.combo do
				lengths[`cut{index}`] = cut.length
			end
			for move, length in lengths do
				local cues = sword.cues[move]
				expect.equal(cues ~= nil and #cues > 0, true, `{sword.name} {move} has sound cues`)
				for _, cue in cues do
					local id = sword.sounds[cue.key]
					expect.equal(typeof(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil, true, `{move} cue {cue.key}`)
					expect.equal(cue.at >= 0 and cue.at < length, true, `{move} cue {cue.key} at {cue.at}`)
				end
			end
		end
	end,

	["the finisher whooshes as it jumps and lands with a slam"] = function()
		local sword = Swords.SWORDS.starterSword
		local finisher = sword.combo[3]
		local hang = finisher.hang :: Swords.Hang
		local found: { [string]: number } = {}
		for _, cue in sword.cues.cut3 do
			found[cue.key] = cue.at
		end
		expect.equal(found.jump ~= nil and found.jump < hang.from, true, "the jump's whoosh comes with the launch")
		expect.equal(found.slam ~= nil and math.abs(found.slam - finisher.hitAt) <= 0.06, true, "the slam lands with the hit")
		for index = 1, 2 do
			for _, cue in sword.cues[`cut{index}`] do
				expect.equal(cue.at <= sword.combo[index].hitAt, true, `cut {index}'s {cue.key} before its strike`)
			end
		end
	end,

	["each cut lands inside its own length"] = function()
		for _, sword in Swords.SWORDS do
			for index, cut in sword.combo do
				expect.equal(cut.hitAt > 0 and cut.hitAt < cut.length, true, `{sword.name} cut {index}`)
			end
			expect.equal(sword.skill.hitAt > 0 and sword.skill.hitAt < sword.skill.length, true, `{sword.name} skill`)
		end
	end,
	-- The sword-moves round (spec 2026-11-04-sword-moves-design)
	["each cut strikes, then reaches its cancel point, inside its length; lunges and the dash come before the strike"] = function()
		for _, sword in Swords.SWORDS do
			for index, cut in sword.combo do
				local cancel = cut.cancelAt or cut.length
				expect.equal(cut.hitAt < cancel and cancel <= cut.length, true, `{sword.name} cut {index} cancel point`)
				if cut.lunge then
					expect.equal(cut.lunge.from < cut.lunge.to and cut.lunge.from <= cut.hitAt and cut.lunge.to <= cut.length, true, `{sword.name} cut {index} lunge`)
					expect.equal(cut.lunge.studs > 0 and cut.lunge.studs <= 4, true, `{sword.name} cut {index} lunge length`)
				end
			end
			-- Only a dash-shaped skill (the Steel Sword's dash slash) moves you; the round 1 swords' skills stand
			local dash = sword.skill.dash
			expect.equal(dash ~= nil, sword.skill.shape.kind == "dash", `{sword.name} dashes only with a dash shape`)
			if dash then
				expect.equal(dash.from < dash.to and dash.to <= sword.skill.hitAt, true, `{sword.name} dash before the cut lines`)
				expect.equal(dash.studs <= dash.maxStuds and dash.width > 0 and dash.slack > 0, true, `{sword.name} dash numbers`)
			end
		end
		local starter = Swords.SWORDS.starterSword
		expect.equal(starter.combo[1].hitAt, 0.217, "the forehand's Hit marker")
		expect.equal(starter.combo[2].hitAt, 0.183, "the backhand's Hit marker")
		expect.equal(starter.combo[3].hitAt, 0.70, "the finisher's Hit marker (after the big jump, owner 2026-11-04)")
		expect.equal(starter.skill.hitAt, 0.62, "the dash slash's cut lines")
		expect.equal(Swords.LUNGE_STOP > 0, true)
	end,

	-- The finisher's big jump (owner 2026-11-04): a slow-motion hang at the top of the leap, between the launch and the
	-- slam, while your camera eases in a little
	["the finisher hangs at the top of its jump before the slam"] = function()
		local finisher = Swords.SWORDS.starterSword.combo[3]
		local hang = finisher.hang
		expect.equal(hang ~= nil, true, "the finisher has a hang")
		local lunge = finisher.lunge :: Swords.Lunge
		expect.equal(lunge.from < hang.from and hang.from < hang.to and hang.to < finisher.hitAt, true, "launch, hang, slam")
		expect.equal(finisher.hitAt < finisher.length, true)
		local zoom = SwordFx.HANG_ZOOM
		expect.equal(zoom.degrees > 0 and zoom.degrees <= 12 and zoom.back > 0, true, "a little zoom, eased back")
	end,

	["the starter combo's damage a second is today's, within 2 % (chained on cancel points)"] = function()
		local today = 1.30 / 1.81 -- 0.35 + 0.35 + 0.6 over 0.56 + 0.5 + 0.75 s (round before the sword-moves round)
		local now = SwordRules.comboPowerPerSecond(Swords.SWORDS.starterSword.combo)
		expect.equal(math.abs(now - today) / today <= 0.02, true, `{now} vs {today}`)
	end,

	["every sword has its slash look, the starter a plain steel one"] = function()
		for id, sword in Swords.SWORDS do
			expect.equal(sword.slash ~= nil and #sword.slash.color == 3, true, `{id} colour`)
			expect.equal(sword.slash.scale > 0, true, `{id} size`)
		end
		local starter = Swords.SWORDS.starterSword.slash
		expect.equal(starter.scale, 1, "the starter is the base size")
		expect.equal(starter.color[3] >= starter.color[1], true, "a cool steel colour, no element")
	end,
}
