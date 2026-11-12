--!strict
local FightFxRules = require("../src/shared/Util/FightFxRules")
local AttackFx = require("../src/shared/Config/AttackFx")
local Combat = require("../src/shared/Config/Combat")
local Bosses = require("../src/shared/Config/Bosses")
local Wild = require("../src/shared/Config/Wild")
local Frontier = require("../src/shared/Config/Frontier")
local SwordFx = require("../src/shared/Config/SwordFx")
local expect = require("./lib/expect")

return {
	["effects stay within their budget, smaller with extras off"] = function()
		expect.equal(AttackFx.MAX_ACTIVE, 12)
		expect.equal(AttackFx.MAX_ACTIVE_LOW, 4)
		expect.equal(FightFxRules.budget(11, true, AttackFx), true)
		expect.equal(FightFxRules.budget(12, true, AttackFx), false)
		expect.equal(FightFxRules.budget(3, false, AttackFx), true)
		expect.equal(FightFxRules.budget(4, false, AttackFx), false)
	end,

	["each element's attack kind comes from the config"] = function()
		for element, entry in AttackFx.ELEMENT do
			expect.equal(FightFxRules.kindFor(element, AttackFx), entry.kind, element)
		end
		expect.isNil(FightFxRules.kindFor("Plasma", AttackFx), "an unknown element has none")
	end,

	["projectile and bolt attackers fight from range, combo ones up close"] = function()
		expect.equal(FightFxRules.isRanged("Ember", AttackFx), true, "Ember throws fireballs")
		expect.equal(FightFxRules.isRanged("Tide", AttackFx), true, "Tide throws water")
		expect.equal(FightFxRules.isRanged("Volt", AttackFx), true, "Volt shoots a bolt")
		expect.equal(FightFxRules.isRanged("Bloom", AttackFx), false, "Bloom lashes up close")
		-- The owner (2026-11-05): "Remodel shade basic attack, change it to a ranged moon slash dark purple"
		expect.equal(FightFxRules.isRanged("Shade", AttackFx), true, "Shade flings a moon slash")
		expect.equal(FightFxRules.isRanged("Plasma", AttackFx), false, "an unknown element stands close")
		expect.equal(Combat.RANGED_BACK > 0, true, "ranged creatures stand further back")
	end,

	["every element attack has its sounds"] = function()
		for element in AttackFx.ELEMENT do
			local sounds = AttackFx.SOUNDS[element]
			expect.equal(sounds ~= nil and typeof(sounds.hit) == "string", true, element)
		end
		expect.equal(typeof(AttackFx.SOUNDS.charge), "string")
	end,

	["every Pet button move and super move has its effect"] = function()
		for element, ability in Combat.ABILITIES do
			expect.equal(FightFxRules.hasEffect(ability.kind, AttackFx), true, `{element} {ability.kind}`)
		end
		for name, signature in Combat.SIGNATURES do
			expect.equal(FightFxRules.hasEffect(signature.kind, AttackFx), true, `{name} {signature.kind}`)
		end
		expect.equal(FightFxRules.hasEffect("Nothing", AttackFx), false)
	end,

	["every boss move effect is a real boss's, with its looks and sounds"] = function()
		-- frost: the Frost Tyrant's, drawn by Util/IceFx (2026-11-10); volt and storm: the Storm Sovereign's (2026-11-11);
		-- voidbite and rift: the Rift Devourer's (2026-11-11)
		local styles = { strike = { leaves = true, fangs = true, embers = true, frost = true, volt = true, voidbite = true, voidclaw = true }, release = { roots = true, web = true, lava = true, frost = true, storm = true, rift = true } }
		for bossId, moves in AttackFx.BOSS do
			expect.equal(Bosses.BOSSES[bossId] ~= nil, true, bossId)
			expect.equal(styles.strike[moves.strike], true, `{bossId} strike`)
			expect.equal(styles.release[moves.release], true, `{bossId} release`)
			expect.equal(#moves.color, 3, bossId)
			expect.equal(string.match(moves.sounds.strike, "^rbxassetid://%d+$") ~= nil, true, `{bossId} strike sound`)
			expect.equal(string.match(moves.sounds.release, "^rbxassetid://%d+$") ~= nil, true, `{bossId} release sound`)
		end
		-- the Prism Hydra (owner 2026-11-12): a look per head's element, switched by its phase
		local hydra = AttackFx.BOSS.prismHydra
		for _, element in Bosses.BOSSES.prismHydra.heads do
			local look = hydra.byPhase[element]
			expect.equal(look ~= nil, true, `the Hydra's {element} phase has a look`)
			expect.equal(styles.strike[look.strike] and styles.release[look.release] and #look.color == 3, true, `its {element} look is real`)
		end
		local rift = AttackFx.BOSS.riftDevourer
		expect.equal(rift and rift.strike, "voidbite", "the Rift Devourer bites with its mandibles")
		expect.equal(rift.release, "rift", "its swipe tears a rift")
		expect.equal(rift.rift, true, "its summons come through rifts (Util/RiftFx)")
	end,

	-- The owner 2026-11-12: "what's that hydra attack that has an orange cone? add a rock fissure effect to it"
	["the Prism Hydra's cone tears a rock fissure: cracks, thrown rocks, gone soon, within budget"] = function()
		local fissure = AttackFx.BOSS.prismHydra.fissure
		expect.equal(fissure ~= nil, true, "its cone attack has a fissure")
		expect.equal(fissure.cracks >= 3 and fissure.cracks <= 7, true, "a fan of cracks across the cone")
		expect.equal(fissure.segments >= 3 and fissure.segments <= 8, true, "each crack jagged in a few pieces")
		expect.equal(fissure.rocks >= 6 and fissure.rocks <= 16, true, "rocks thrown up, not too many parts")
		expect.equal(fissure.rockSize[1] < fissure.rockSize[2] and fissure.rise[1] < fissure.rise[2], true, "rock sizes and throws are ranges")
		expect.equal(fissure.grow > 0 and fissure.grow + fissure.linger + fissure.fade <= 3, true, "it tears open fast and is gone in 3 s")
		expect.equal(#fissure.rock == 3, true, "its rock colour")
		-- the owner 2026-11-12: "just do a rainbow rock fissure with the tip being the biggest rock"
		expect.equal(fissure.rainbow, true, "its cracks glow in every colour")
		expect.equal(fissure.only, true, "the cone shows only the fissure (no phase effect over it)")
		local spikes = fissure.spikes
		expect.equal(spikes.base > 0 and spikes.grow > 0, true, "rock spikes grow along each crack")
		expect.equal(spikes.tip > 1 and spikes.biggest > spikes.tip, true, "each crack's tip is its biggest rock, the middle one's the biggest of all")
		expect.equal((spikes.base + spikes.grow) * spikes.biggest * spikes.height <= 14, true, "the biggest stays a rock, not a tower")
		expect.equal(Bosses.BOSSES.prismHydra.playerAttacks.every, 10, "its attack on players comes every 10 s")
	end,

	-- The owner 2026-11-12: "shield, heal, and enrage should be noticeable" (any boss's; Util/BossSkillFx)
	["a boss's heal and enrage are big and lit; the Hydra's shield is the ice bubble"] = function()
		local skills = AttackFx.BOSS_SKILLS
		local heal, enrage = skills.heal, skills.enrage
		expect.equal(#heal.color == 3 and #enrage.color == 3 and #enrage.fire == 3, true, "their colours")
		expect.equal(heal.pillar >= 1.5 and heal.ring >= 1.2, true, "the heal's pillar towers over it, its ring spreads wide")
		expect.equal(heal.seconds >= 1.2 and heal.seconds <= 3, true, "the heal's moment is seen, then gone")
		expect.equal(heal.glow > 0 and heal.glow < 1 and enrage.glow > 0 and enrage.glow < 1, true, "the body glows (a fill, never solid)")
		expect.equal(enrage.ring >= 1.5 and enrage.flash > 0 and enrage.pulse > 0, true, "the enrage bursts out and its aura pulses")
		for name, skill in { heal = heal, enrage = enrage } do
			expect.equal(string.match(skill.sound, "^rbxassetid://%d+$") ~= nil, true, `{name} sound`)
		end
		local hydra = AttackFx.BOSS.prismHydra
		expect.equal(hydra.iceShield, true, "the Hydra's Tide shield is the Frost Tyrant's ice bubble")
		expect.equal(hydra.iceShieldMax < Bosses.BOSSES.prismHydra.ringRadius - 3, true, "its bubble stays off its fighters")
		expect.equal(hydra.storm and hydra.rift, true, "its clap and summons reuse the Frontier bosses' looks")
	end,

	-- The owner 2026-11-11: "add a noticeable summoning effect when creatures are summoned"
	["the summoning's rifts: big, lit, loud and gone soon after"] = function()
		local rift = AttackFx.RIFT
		expect.equal(#rift.color, 3)
		expect.equal(#rift.core, 3)
		assert(rift.tear.size >= 1.5, "the portal stands well over its summon")
		assert(rift.pool.radius >= 0.8, "a pool of void round it on the ground")
		assert(rift.tear.light.range >= 16, "it lights the arena round it")
		assert(rift.close > 0 and rift.close <= 1, "it closes soon after its summon is out")
		for name, sound in rift.sounds do
			expect.equal(string.match(sound, "^rbxassetid://%d+$") ~= nil, true, `{name} sound`)
		end
	end,

	["every wild monster's attack look is a real species', with its sound"] = function()
		-- voidclaw: the Rift Horror's (the Rift Devourer's summons, 2026-11-11)
		local styles = { bite = true, dive = true, embers = true, headbutt = true, snap = true, spark = true, voidclaw = true }
		local count = 0
		for species, moves in AttackFx.MONSTER do
			count += if Wild.SPECIES[species] then 1 else 0
			expect.equal(Wild.SPECIES[species] ~= nil or Frontier.SPECIES[species] ~= nil, true, species)
			expect.equal(styles[moves.strike], true, `{species} strike`)
			expect.equal(#moves.color, 3, species)
			expect.equal(string.match(moves.sounds.strike, "^rbxassetid://%d+$") ~= nil, true, `{species} sound`)
		end
		local wild = 0
		for _ in Wild.SPECIES do
			wild += 1
		end
		expect.equal(count, wild, "every Wild species has one")
		expect.equal(AttackFx.MONSTER["Rift Horror"] and AttackFx.MONSTER["Rift Horror"].strike, "voidclaw", "the summons claw")
	end,

	["a creature's grade sets how big its attack looks"] = function()
		local c, b, a, s = FightFxRules.tier("C", AttackFx), FightFxRules.tier("B", AttackFx), FightFxRules.tier("A", AttackFx), FightFxRules.tier("S", AttackFx)
		expect.equal(c.scale, 1)
		expect.equal(c.extra, 0)
		expect.near(b.scale, 1.25, 1e-9)
		expect.equal(b.extra, 0)
		expect.near(a.scale, 1.55, 1e-9)
		expect.equal(a.extra, 1)
		expect.near(s.scale, 2, 1e-9)
		expect.equal(s.extra, 2)
		expect.equal(c.sparks < b.sparks and b.sparks < a.sparks and a.sparks < s.sparks, true, "more sparks each grade")
		expect.equal(c.shake < b.shake and b.shake < a.shake and a.shake < s.shake, true, "more shake each grade")
		expect.equal(FightFxRules.tier(nil, AttackFx), c, "no grade: C")
		expect.equal(FightFxRules.tier("Z", AttackFx), c, "unknown: C")
	end,

	-- Owner 2026-11-09: creature hits get the sword hit's pack effects, "slashes on slash attacks and no slash on non
	-- slash attacks", the element's own particles on all
	["a creature's cut lands with the slash streaks, its other attacks without"] = function()
		expect.equal(FightFxRules.cuts("Bloom", AttackFx), true, "the Bloom combo")
		expect.equal(FightFxRules.cuts("Shade", AttackFx), true, "the moon slash")
		for _, element in { "Ember", "Tide", "Volt" } do
			expect.equal(FightFxRules.cuts(element, AttackFx), false, element)
		end
		expect.equal(FightFxRules.cuts("Plasma", AttackFx), false, "an unknown element")
	end,

	["a combo's earlier hits and the extra moon slashes land lighter than the hit with the damage"] = function()
		local light = AttackFx.LIGHT_HIT
		assert(light.size > 0 and light.size < 1, `size {light.size}`)
		assert(light.share > 0 and light.share < 1, `share {light.share}`)
	end,

	["a hit's pack emitters: the streaks and arc only on a cut, the sparks and the element's own always"] = function()
		local slashTextures = { slashStreak = true, slashArc = true }
		for element, own in SwordFx.ELEMENT_HIT do
			local cut = FightFxRules.hitSpecs(SwordFx, element, true)
			expect.equal(#cut, #SwordFx.IMPACT.emitters + #own, `{element} cut`)
			local plain = FightFxRules.hitSpecs(SwordFx, element, false)
			local textures: { [string]: boolean } = {}
			for _, spec in plain do
				assert(not slashTextures[spec.texture], `{element}: a {spec.texture} on a hit that isn't a cut`)
				textures[spec.texture] = true
			end
			assert(textures.sparkStreak, `{element}: the spark streaks stay`)
			for index, spec in own do
				assert(table.find(plain, spec) ~= nil, `{element}: its particle {index}`)
			end
		end
		expect.equal(#FightFxRules.hitSpecs(SwordFx, nil, true), #SwordFx.IMPACT.emitters, "no element: the cut alone")
	end,

	-- The owner 2026-11-10: "the basic attack effects of the creature fighting with me is causing my weapon skill
	-- animation to be hard to see... special skills animation/fx should always be visible": while a special holds the
	-- spotlight (your sword skill, a super) or a camera moment plays, creatures' basic attacks draw nothing new,

	["creatures' basic attacks keep out of a special's spotlight"] = function()
		expect.equal(FightFxRules.quiet(10, 0, false), false, "nothing special playing")
		expect.equal(FightFxRules.quiet(10, 12, false), true, "a skill holds the spotlight")
		expect.equal(FightFxRules.quiet(12.5, 12, false), false, "its hold is over")
		expect.equal(FightFxRules.quiet(10, 0, true), true, "a camera moment plays")
	end,

	["a special holds the spotlight for its length and a tail, never shortening a longer hold"] = function()
		local tail = AttackFx.SPOTLIGHT.tail
		assert(tail > 0 and tail <= 2, "a short tail after the special")
		assert(AttackFx.SPOTLIGHT.super >= 1.5, "a super's moves play on past its charge")
		-- then (2026-11-11, "apply this and the previous adjustments to all skills"): the Pet button moves too
		assert(AttackFx.SPOTLIGHT.move >= 1, "a Pet button move plays on past its wind-up")
		expect.equal(FightFxRules.spotlightUntil(10, 0, 2, tail), 12 + tail)
		expect.equal(FightFxRules.spotlightUntil(10, 20, 2, tail), 20, "a longer hold stands")
	end,

	-- The owner 2026-11-11: "basic attack bolt type is still using the drawn particles which is a bunch of lines. use the
	-- free particles we added from creators market and add it to every skill/attack that still using the drawn lines":
	-- every effect's lightning, sparks and streaks are the Yona pack's pictures now (one table: every user swaps at once)
	["the lightning, sparks and streaks are the packs' pictures, not drawn lines"] = function()
		local textures = AttackFx.TEXTURES :: any
		for _, drawn in { "rbxassetid://118502374622454", "rbxassetid://110131144237409", "rbxassetid://72806596201777" } do
			for key, id in textures do
				assert(id ~= drawn, `{key} is still a drawn line`)
			end
		end
		expect.equal(textures.bolt, "rbxassetid://13592365549", "Yona's Electricity-02: an upright bolt, as a beam wants")
		assert(textures.boltAlt and textures.boltAlt ~= textures.bolt, "a second bolt picture to flicker to")
		expect.equal(textures.spark, textures.sparkStreak, "Yona's spark")
		expect.equal(textures.streak, textures.sparkStreak)
		local impact = AttackFx.LIGHTNING.impact
		assert(#impact >= 3, "the pack's electricity impact")
		for index, spec in impact do
			assert(textures[spec.texture], `impact {index}: {spec.texture}`)
			assert(spec.count > 0 and #spec.size >= 2 and #spec.transparency >= 2, `impact {index}`)
		end
	end,
}
