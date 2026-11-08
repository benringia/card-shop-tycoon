--!strict
-- The round 1 swords' effects (sword skills round, spec 2026-11-06-sword-skills-design 4): every look a moveset names
-- exists with its kind and real textures, every Forge Sword element has its colours, the scale and others' budget rules
local SwordSkillFx = require("../src/shared/Config/SwordSkillFx")
local SwordSkillFxRules = require("../src/shared/Util/SwordSkillFxRules")
local Swords = require("../src/shared/Config/Swords")
local Weapons = require("../src/shared/Config/Weapons")
local WeaponLooks = require("../src/shared/Config/WeaponLooks")
local AttackFx = require("../src/shared/Config/AttackFx")
local MoveFx = require("../src/shared/Config/MoveFx")
local SuperFx = require("../src/shared/Config/SuperFx")
local SwordFx = require("../src/shared/Config/SwordFx")
local AdminPanel = require("../src/shared/Config/AdminPanel")
local expect = require("./lib/expect")

local TEXTURE_TABLES = { AttackFx.TEXTURES, MoveFx.TEXTURES, SuperFx.TEXTURES, SwordFx.TEXTURES }

local function textureExists(key: string): boolean
	for _, list in TEXTURE_TABLES do
		if (list :: any)[key] ~= nil then
			return true
		end
	end
	return false
end

return {
	["every look a moveset names exists with the right kind and real textures"] = function()
		local named = 0
		for id, sword in Swords.SWORDS do
			if sword.fx then
				for kind, look in sword.fx :: any do
					named += 1
					local spec = SwordSkillFx.LOOKS[look]
					assert(spec, `{id} {kind}: no look {look}`)
					expect.equal(spec.kind, kind, `{look} is a {kind}`)
					expect.equal(#spec.textures > 0, true, `{look} has textures`)
					for _, texture in spec.textures do
						expect.equal(textureExists(texture), true, `{look}: texture {texture}`)
					end
				end
			end
		end
		expect.equal(named, 24, "four swords, the spear, the Halberd, the Trident and the Titan's Lance x slash, finisher, skill")
	end,

	["every element has its look colours, so each Forge Sword is coloured (Review Focus 5)"] = function()
		for _, weapon in Weapons.WEAPONS do
			if weapon.element and weapon.ready then
				local look = WeaponLooks.BY_ELEMENT[weapon.element]
				assert(look, `{weapon.id}: {weapon.element} has no look`)
				expect.equal(#look.glow, 3, `{weapon.element} glow`)
				expect.equal(#look.deep, 3, `{weapon.element} deep`)
				local own = WeaponLooks.WEAPONS[weapon.id]
				assert(own and own.glow and own.deep, `{weapon.id} has its own glow and deep`)
			end
		end
	end,

	["effects keep their size below +7, then grow with the trail's scale"] = function()
		expect.equal(SwordSkillFxRules.scale(1), 1)
		expect.equal(SwordSkillFxRules.scale(1.5), 1.5)
		expect.equal(SwordSkillFxRules.scale(0), 1, "no trail yet: full size")
	end,

	["others' effects: full nearby until a few are drawn, then light, none far away (Review Focus 4)"] = function()
		local others = SwordSkillFx.OTHERS
		expect.equal(others.range, 90)
		expect.equal(others.full, 3)
		expect.equal(SwordSkillFxRules.drawsOthers(30, 0, others), "full")
		expect.equal(SwordSkillFxRules.drawsOthers(30, 3, others), "light")
		expect.equal(SwordSkillFxRules.drawsOthers(200, 0, others), "none")
		expect.equal(SwordSkillFxRules.drawsOthers(90, 0, others), "full", "at the edge of range")
	end,

	["/skillfx names a round 1 weapon with effects for each sword and element"] = function()
		for name, weaponId in SwordSkillFx.PREVIEW do
			local weapon = Weapons.ById[weaponId]
			assert(weapon and weapon.moveset, `{name}: {weaponId} is a weapon with a moveset`)
			expect.equal(Swords.SWORDS[weapon.moveset].fx ~= nil, true, `{name}: its moveset has effects`)
		end
		for _, name in { "sunforged", "verdant", "prism", "forge", "ember", "tide", "bloom", "volt", "shade", "spear", "halberd", "trident", "lance" } do
			expect.equal(SwordSkillFx.PREVIEW[name] ~= nil, true, name)
		end
	end,

	["Sunfall Cleave's effect keeps time with its moveset: the crescent leaves at the hit, at the shape's speed and blast"] = function()
		local beats = SwordSkillFx.LOOKS.sunfallCleave.beats :: { [string]: number }
		local skill = Swords.SWORDS.sunforgedBlade.skill
		expect.equal(beats.release, skill.hitAt, "the cleave's Hit marker")
		expect.equal(beats.speed, skill.shape.speed)
		expect.equal(beats.blast, skill.shape.blast)
		expect.equal(beats.charge < beats.charged and beats.charged < beats.release, true, "charging before the cleave")
		expect.equal(SwordSkillFx.SHAKE.release > 0 and SwordSkillFx.SHAKE.impact >= SwordSkillFx.SHAKE.release, true, "a shake on the cleave, a bigger one on the burst")
	end,

	["Thornline's vines keep time with its moveset: they leave at the hit, race at the shape's speed, snap with its catch"] = function()
		local beats = SwordSkillFx.LOOKS.thornline.beats :: { [string]: number }
		local skill = Swords.SWORDS.verdantBlade.skill
		expect.equal(beats.release, skill.hitAt, "the vines leave at the Hit marker")
		expect.equal(beats.speed, skill.shape.speed)
		expect.equal(beats.blast, skill.shape.blast)
		expect.equal(beats.spacing > 0 and beats.height > 0, true, "rows of vines, standing tall")
		expect.equal(SwordSkillFx.SHAKE.thornline > 0 and SwordSkillFx.SHAKE.thornline < SwordSkillFx.SHAKE.impact, true, "a small shake on the snap")
	end,

	["every number the exaggerated looks read is set (a missing one would break the effect mid-fight)"] = function()
		local needs = {
			sunfallCleave = { "charge", "charged", "release", "glow", "gather", "launch", "ahead", "speed", "height", "width", "flame", "blast", "heat", "swirl", "fissure", "pillar", "boom" },
			thornline = { "release", "speed", "blast", "spacing", "side", "height", "thick", "trap", "trapVines", "trapTall", "linger", "wither", "gather", "swirl", "fissure" },
			rootBurst = { "roots", "height", "thick" },
			prismShatter = { "crystals", "height", "thick" },
			elementalSpin = { "spinFrom", "release", "tornado", "tornadoHeight", "ring", "wall", "wallHeight", "grow" },
			prismJudgment = { "summon", "command", "release", "gap", "strikes", "pillar", "ringRadius", "ringHeight", "blade", "spin", "spinUp", "dive", "rune", "pillarHeight", "pillarWidth", "pillarSeconds", "camAt", "camHold", "camLookUp", "camUp" },
			spearStreak = { "streak", "arc", "arcAngle", "flash", "sparks" },
			skyPierce = { "ahead", "burst", "rings", "ring", "cracks", "crackLength", "rocks", "rockSpeed", "dust", "flash" },
			piercingRush = { "charge", "leave", "arrive", "hit", "length", "width", "afterimages", "glow", "swirl", "flashSeconds", "bursts", "skid" },
		}
		for look, keys in needs do
			local beats = SwordSkillFx.LOOKS[look].beats :: { [string]: number }
			for _, key in keys do
				expect.equal(type(beats[key]), "number", `{look}.{key}`)
			end
		end
	end,

	-- Weapons round 2 (spec 2026-11-07-weapons-round2-design 5.2; the owner's storyboard OK and "more exaggerated, with
	-- particles and all", 2026-11-07): the spear's effects keep time and place with its moves
	["the spear's effects keep time with its moves: the rush along its dash, the plunge's burst where its line ends"] = function()
		local spear = Swords.SWORDS.spear
		expect.equal(spear.fx and spear.fx.slash, "spearStreak")
		local rush = SwordSkillFx.LOOKS.piercingRush.beats :: { [string]: number }
		local dash = spear.skill.dash :: any
		expect.equal(rush.hit, spear.skill.hitAt, "the line flashes at the Hit marker")
		expect.equal(rush.leave, dash.from, "the rush leaves with the dash")
		expect.equal(rush.arrive, dash.to, "and arrives with it")
		expect.equal(rush.length, dash.studs)
		expect.equal(rush.width, dash.width)
		expect.equal(rush.charge < rush.leave and rush.leave < rush.arrive and rush.arrive <= rush.hit, true, "charge, rush, flash")
		local plunge = SwordSkillFx.LOOKS.skyPierce.beats :: { [string]: number }
		local line = spear.combo[3].line :: any
		expect.equal(plunge.ahead, line.length, "the burst where the plunge's line ends")
		expect.equal(plunge.burst, line.burst)
		local streak = SwordSkillFx.LOOKS.spearStreak.beats :: { [string]: number }
		expect.equal(streak.streak, spear.combo[1].reach, "the thrust's streak as long as its reach")
		expect.equal(streak.arc, spear.combo[2].reach, "the sweep's crescent as wide as its reach")
		expect.equal(streak.arcAngle, spear.combo[2].arc)
	end,

	["Prism Judgment keeps time with its moveset: the first blade strikes at the hit, the rest its gap apart"] = function()
		local spec = SwordSkillFx.LOOKS.prismJudgment
		local beats = spec.beats :: { [string]: number }
		local skill = Swords.SWORDS.prismBlade.skill
		expect.equal(beats.release, skill.hitAt, "the first strike at the Hit marker")
		expect.equal(beats.gap, skill.shape.gap)
		expect.equal(beats.strikes, skill.shape.strikes)
		expect.equal(beats.summon < beats.command and beats.command < beats.release, true, "summoned, then commanded, then the strikes")
		expect.equal(beats.release + (beats.strikes - 1) * beats.gap < beats.pillar and beats.pillar < skill.length, true, "the pillar after the last strike, inside the move")
		expect.equal(spec.cinematic, true, "the Legendary's camera moment")
		-- one ghost blade per element, in the storyboard's order, each with its colours
		expect.equal(table.concat(SwordSkillFx.PRISM.order, ","), "Ember,Tide,Bloom,Volt,Shade")
		for _, element in SwordSkillFx.PRISM.order do
			expect.equal(WeaponLooks.BY_ELEMENT[element] ~= nil, true, element)
		end
		expect.equal(SwordSkillFx.SHAKE.prismStrike > 0 and SwordSkillFx.SHAKE.prismJudgment > SwordSkillFx.SHAKE.impact, true, "a shake per strike, the biggest on the pillar")
	end,

	["Elemental Spin keeps time with its moveset and every element has its look (Review Focus 5)"] = function()
		local beats = SwordSkillFx.LOOKS.elementalSpin.beats :: { [string]: number }
		local skill = Swords.SWORDS.forgeSword.skill
		expect.equal(beats.release, skill.hitAt, "the ring wave at the Hit marker")
		expect.equal(beats.ring, skill.shape.radius, "the wave reaches as far as the spin hits")
		expect.equal(beats.spinFrom < beats.release, true, "the turns before the wave")
		for _, element in { "Ember", "Tide", "Bloom", "Volt", "Shade" } do
			local look = SwordSkillFx.ELEMENTS[element]
			assert(look, `{element} has an element look`)
			expect.equal(textureExists(look.particle), true, `{element}: its particle`)
		end
		expect.equal(SwordSkillFx.SHAKE.elementalSpin > 0 and SwordSkillFx.SHAKE.finisher > 0, true, "a shake on the wave and on every finisher")
	end,

	["the skill cinematic: up to the low angle, held through the charge, chasing the crescent, held on the burst, back"] = function()
		local cfg = SwordSkillFx.CINEMATIC
		local function beat(t: number): (string, number)
			return SwordSkillFxRules.cinematicBeat(t, 1.18, 0.8, cfg)
		end
		expect.equal((beat(0)), "rise")
		local name, alpha = beat(cfg.rise / 2)
		expect.equal(name, "rise"); expect.near(alpha, 0.5, 1e-9)
		expect.equal((beat(1.0)), "charge")
		name, alpha = beat(1.18 + 0.4)
		expect.equal(name, "chase"); expect.near(alpha, 0.5, 1e-9)
		expect.equal((beat(1.18 + 0.8 + cfg.hold / 2)), "impact")
		expect.equal((beat(1.18 + 0.8 + cfg.hold + cfg.back / 2)), "back")
		name, alpha = beat(1.18 + 0.8 + cfg.hold + cfg.back + 0.01)
		expect.equal(name, "done"); expect.equal(alpha, 1)
		expect.equal((SwordSkillFxRules.cinematicBeat(1.18, 1.18, 0, cfg)), "impact", "no travel: straight to the burst")
	end,

	["the wide side shot stands far enough out to fit the whole flight, never closer than its least"] = function()
		-- 16 studs of flight (plus you) with a 5-stud margin either side, 62 degrees tall on a 16:9 screen
		local half = math.rad(62) / 2
		local across = 2 * math.atan(math.tan(half) * 16 / 9)
		local want = (20 / 2 + 5) / math.tan(across / 2)
		expect.near(SwordSkillFxRules.wideDistance(20, 5, 62, 16 / 9, 4), want, 1e-9)
		expect.equal(SwordSkillFxRules.wideDistance(2, 1, 62, 16 / 9, 14), 14, "a short flight: its least")
		expect.equal(SwordSkillFxRules.wideDistance(40, 5, 62, 1, 4) > SwordSkillFxRules.wideDistance(40, 5, 62, 16 / 9, 4), true, "a narrow screen stands further out")
	end,

	["the Verdant's vines: every one in full for your own, a light version on low graphics and for another player's"] = function()
		local own = SwordSkillFxRules.vineBudget(false, false)
		expect.equal(own.spacing, 1); expect.equal(own.share, 1); expect.equal(own.details, true)
		for _, case in { { true, false }, { false, true }, { true, true } } do
			local lite = SwordSkillFxRules.vineBudget(case[1], case[2])
			expect.equal(lite.spacing, 2, "rows twice as far apart")
			expect.equal(lite.share, 0.5, "half the trap and the roots")
			expect.equal(lite.details, false, "stems only: no thorns, leaf or bud")
		end
	end,

	["the admin panel has a Sword skills section of /skillfx buttons"] = function()
		local found = false
		for _, section in AdminPanel.SECTIONS do
			if section.title == "Sword skills" then
				found = true
				expect.equal(#section.buttons >= 8, true, "four swords x finisher and skill")
				for _, button in section.buttons do
					expect.equal(string.sub(button.command, 1, 8), "/skillfx", button.label)
				end
			end
		end
		expect.equal(found, true, "a Sword skills section")
	end,

	-- Weapons round 2.5 (spec 2026-11-08-forge-relayout-and-titans-wrath-design 3; the owner's storyboard): Titan's Wrath
	["Titan's Wrath: the Lance's skill look, its beats in the storyboard's order, its hit and fissure the skill's"] = function()
		local lance = Swords.SWORDS.titansLance
		expect.equal(lance.fx.skill, "titansWrath")
		local look = SwordSkillFx.LOOKS.titansWrath
		assert(look, "the titansWrath look")
		expect.equal(look.kind, "skill")
		expect.equal(look.form, "ahead")
		expect.equal(look.cinematic, true, "your own plays the camera moment")
		local b = look.beats :: { [string]: number }
		expect.equal(b.charge < b.peak and b.peak < b.hit and b.hit < b.close, true, "charge, peak, thrust, then the fissure closes")
		expect.equal(b.hit, lance.skill.hitAt, "the thrust is the skill's hit")
		expect.equal(b.camAt, b.hit, "the wide shot at the thrust")
		expect.equal(b.length, lance.skill.shape.length, "the fissure runs the hit's whole line")
		expect.equal(b.width, lance.skill.shape.width)
		expect.equal(lance.sounds[look.burstSound :: string] ~= nil, true, "its burst sound is the Lance's")
		local shake = SwordSkillFx.SHAKE :: any
		expect.equal(shake.titansRumble > 0 and shake.titansRumble < shake.titansWrath, true, "a rumble under the fissure's big shake")
		expect.equal(shake.titansWrath >= shake.impact, true, "the fissure shakes at least as hard as a burst")
	end,

	-- Studio 2026-11-08: the cinematic's hero shot looked 5.5 studs above you (Sunfall Cleave's jump), so Titan's Wrath's
	-- low stance sat at the screen's bottom edge: it frames your stance, and its wide shot looks low along the fissure
	["Titan's Wrath's camera moment frames the low stance and the fissure on the ground"] = function()
		local b = SwordSkillFx.LOOKS.titansWrath.beats :: { [string]: number }
		expect.equal(b.camFocus ~= nil and b.camFocus < SwordSkillFx.CINEMATIC.lookUp, true, "the hero shot at your stance")
		expect.equal(b.camLookUp ~= nil and b.camLookUp < SwordSkillFx.CINEMATIC.wide.lookUp, true, "the wide shot low, on the ground")
	end,

	-- Final review 2026-11-08: the rumble's pulses stacked to the shake's cap before the thrust, so the fissure's big
	-- shake barely stood out. Pulses every rumbleEvery s grow from a fifth to all of titansRumble (SwordController's rumble
	-- hook) against the shake's decay (Util/ScreenFx): it must build, stay well under the cap, and have died down by the
	-- thrust so the fissure lands as a jump
	["Titan's Wrath's rumble builds through the charge and leaves room for the fissure's big shake"] = function()
		local ShakeRules = require("../src/shared/Util/ShakeRules")
		local b = SwordSkillFx.LOOKS.titansWrath.beats :: { [string]: number }
		local shake, strongest, early = 0, 0, 0
		local charging = b.peak - b.charge
		local dt = 1 / 60
		local t, nextPulse = 0, 0
		while t < b.hit - b.charge do
			if t < charging and t >= nextPulse then
				nextPulse += b.rumbleEvery
				shake = ShakeRules.add(shake, SwordSkillFx.SHAKE.titansRumble * (0.2 + 0.8 * t / charging))
			end
			if t < charging * 0.3 then
				early = math.max(early, shake)
			end
			strongest = math.max(strongest, shake)
			shake = ShakeRules.decay(shake, dt, AttackFx.SHAKE.DECAY)
			t += dt
		end
		expect.equal(strongest > early * 1.5, true, `it builds ({early} early, {strongest} at most)`)
		expect.equal(strongest <= 0.5, true, `under half the cap ({strongest})`)
		expect.equal(ShakeRules.add(shake, SwordSkillFx.SHAKE.titansWrath) - shake >= 0.6, true, `the fissure jumps the shake (from {shake})`)
	end,
}
