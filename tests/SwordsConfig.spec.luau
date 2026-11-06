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

	["each new skill has the spec's shape"] = function()
		local shapes = Swords.SWORDS
		expect.equal(shapes.forgeSword.skill.shape.kind, "spin")
		expect.equal(shapes.forgeSword.skill.shape.radius, 9)
		local thorn = shapes.verdantBlade.skill.shape
		expect.equal(thorn.kind, "line"); expect.equal(thorn.length, 18); expect.equal(thorn.width, 4)
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
