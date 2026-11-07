--!strict
-- The player in boss fights (spec 2026-11-02-you-in-the-fight-design): rest time, the boss attack ladder, the starter sword
local Bosses = require("../src/shared/Config/Bosses")
local Combat = require("../src/shared/Config/Combat")
local Swords = require("../src/shared/Config/Swords")
local SwordFx = require("../src/shared/Config/SwordFx")
local SwordRules = require("../src/shared/Util/SwordRules")
local expect = require("./lib/expect")

local ANIMATIONS = { "draw", "sheath", "cut1", "cut2", "cut3", "skill", "dodge", "flinch", "down", "getUp", "ready", "run" }
local SOUNDS = { "swing1", "swing2", "swing3", "hit", "draw", "dodge", "ring", "down", "getUp" }

return {
	-- Weapons round 2 (owner 2026-11-08: "hold the sword the right way, not flat"): every sword model has its edge along
	-- X and its flat along Z, so the hand's grip turns it a quarter turn about the blade, the flat facing the palm. Measured
	-- in Studio over the starter's cuts: without the turn the flat led every cut (0.63-0.79 of the swing), with it the edge
	["the hand holds a sword with its flat to the palm, so the edge leads the cuts"] = function()
		expect.equal(Swords.HAND_GRIP.twist, 90)
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
		for id, sword in Swords.SWORDS do
			expect.equal(sword.combo, starter.combo, `{id} swings the starter's cuts`)
			for _, key in { "cut1", "cut2", "cut3" } do
				expect.equal(sword.animations[key], starter.animations[key], `{id} {key}`)
			end
			expect.equal(sword.skill.power, 0.9, `{id} skill power`)
			expect.equal(sword.skill.cooldown, 8, `{id} skill cooldown`)
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
		expect.equal(sword.skill.cooldown, 8)
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
	-- comes with the swing, not at the tap
	["every move's sound cues play the sword's own sounds, inside the move"] = function()
		for _, sword in Swords.SWORDS do
			local lengths: { [string]: number } = { skill = sword.skill.length }
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
