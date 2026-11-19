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

	-- Owner 2026-11-20 (first public playthrough): "all creature attacks should not be melee ... the bramble pet is
	-- attacking in melee where it should be range like its element. no melee attacks on pets"
	["no creature fights up close: every element attacks from range, Bloom with a volley of three thorns"] = function()
		for _, element in { "Ember", "Tide", "Bloom", "Volt", "Shade" } do
			expect.equal(FightFxRules.isRanged(element, AttackFx), true, `{element} attacks from range`)
			assert(FightFxRules.kindFor(element, AttackFx) ~= "combo", `{element}: no lash up close`)
		end
		expect.equal(FightFxRules.kindFor("Bloom", AttackFx), "projectile")
		expect.equal(FightFxRules.shots("Bloom", 0, AttackFx), 3, "three thorns at once")
		expect.equal(FightFxRules.shots("Bloom", 2, AttackFx), 3, "the same at every grade")
		expect.equal(FightFxRules.shots("Ember", 0, AttackFx), 1, "one fireball")
		expect.equal(FightFxRules.shots("Ember", 2, AttackFx), 3, "a grade S Ember throws two more")
		expect.equal(FightFxRules.shots("Tide", 2, AttackFx), 1, "Tide always one")
		assert(AttackFx.FLIGHT.Bloom and AttackFx.FLIGHT.Bloom > 0, "its thorns' flight")
		assert(AttackFx.SOUNDS.Bloom.release, "a sound as they leave")
	end,

	["projectile and bolt attackers fight from range, combo ones up close"] = function()
		expect.equal(FightFxRules.isRanged("Ember", AttackFx), true, "Ember throws fireballs")
		expect.equal(FightFxRules.isRanged("Tide", AttackFx), true, "Tide throws water")
		expect.equal(FightFxRules.isRanged("Volt", AttackFx), true, "Volt shoots a bolt")
		expect.equal(FightFxRules.isRanged("Bloom", AttackFx), true, "Bloom throws thorns (it lashed up close until 2026-11-20)")
		-- The owner (2026-11-05): "Remodel shade basic attack, change it to a ranged moon slash dark purple"
		expect.equal(FightFxRules.isRanged("Shade", AttackFx), true, "Shade flings a moon slash")
		expect.equal(FightFxRules.isRanged("Plasma", AttackFx), false, "an unknown element stands close")
		expect.equal(Combat.RANGED_BACK > 0, true, "ranged creatures stand further back")
	end,

	["every element attack has its sounds"] = function()
		for element in AttackFx.ELEMENT do
			local sounds = AttackFx.SOUNDS[element]
			-- a list of clips, one picked each hit (owner 2026-11-12; Util/SoundVary)
			expect.equal(sounds ~= nil and typeof(sounds.hit) == "table" and #sounds.hit > 0, true, element)
			for _, id in sounds.hit do
				expect.equal(string.match(id, "^rbxassetid://%d+$") ~= nil, true, `{element} hit clip`)
			end
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

	-- The owner 2026-11-12: "if there are 4 people in a party with all the particle effects, does it affect performance?":
	-- three fissures at once cost 21 ms to build on a desktop (one 67 ms frame); a phone is several times slower
	["a fissure's size: full when it's the only one, small right after another, lighter on low graphics"] = function()
		local spec = AttackFx.BOSS.prismHydra.fissure
		local full = FightFxRules.fissureDetail(spec, true, false)
		expect.equal(full.cracks, spec.cracks, "full: every crack")
		expect.equal(full.segments, spec.segments)
		expect.equal(full.rocks, spec.rocks)
		expect.equal(full.spikes and full.caps, true, "spikes with their rainbow caps")
		local low = FightFxRules.fissureDetail(spec, false, false)
		expect.equal(low.cracks < full.cracks and low.segments < full.segments and low.rocks < full.rocks, true, "low graphics: fewer of each")
		expect.equal(low.spikes, true, "still a rock fissure: spikes stay")
		expect.equal(low.caps, false, "no caps but the tips' crystals")
		local small = FightFxRules.fissureDetail(spec, true, true)
		expect.equal(small.cracks <= 2 and small.spikes == false and small.rocks <= 3, true, "a second one at once: a small crack")
		-- the parts it builds stay within a budget (each piece: an edge and a seam, a spike one rock (two at a tip) and a cap)
		local function parts(detail: any): number
			local pieces = detail.cracks * detail.segments * 2
			local spikes = if detail.spikes then detail.cracks * (detail.segments - 1) * (if detail.caps then 2 else 1) + detail.cracks * 2 else 0
			return pieces + spikes + detail.rocks
		end
		expect.equal(parts(full) <= 130, true, `full builds at most 130 parts ({parts(full)})`)
		expect.equal(parts(low) <= 50, true, `low builds at most 50 ({parts(low)})`)
		expect.equal(parts(small) <= 20, true, `small builds at most 20 ({parts(small)})`)
		-- one full fissure at a time: another within the window is small
		expect.equal(FightFxRules.fissureCrowded(10, 9.8, spec.window), true, "0.2 s after the last: crowded")
		expect.equal(FightFxRules.fissureCrowded(10, 9, spec.window), false, "a second later: full again")
		expect.equal(FightFxRules.fissureCrowded(10, nil, spec.window), false, "the first one")
	end,

	["the ice shield has fewer shards on low graphics"] = function()
		local ice = AttackFx.ICE.shield
		expect.equal(ice.lowShards < ice.shards and ice.lowShards >= 6, true, "fewer shards, still a crystal bubble")
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
			for _, id in moves.sounds.strike do
				expect.equal(string.match(id, "^rbxassetid://%d+$") ~= nil, true, `{species} sound`)
			end
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
		expect.equal(FightFxRules.cuts("Shade", AttackFx), true, "the moon slash")
		for _, element in { "Ember", "Tide", "Volt", "Bloom" } do
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
	-- Boss normal hits that travel and land hard (owner 2026-11-18, pick A + C of artifact G67X6HmoKnXNe9NRM9cm2q): what
	-- each strike throws at its target, when it leaves and how long it flies so it lands with the hit
	["a boss's normal hit flies over the end of its wind-up and lands with the hit"] = function()
		local cfg = AttackFx.BOSS_HIT
		local wait, travel = FightFxRules.bossThrow(0.5, cfg)
		expect.near(travel, 0.3, 1e-6, "a usual half-second wind-up: it flies the last 0.3 s")
		expect.near(wait + travel, 0.5, 1e-6, "it lands as the hit does")
		local _, quick = FightFxRules.bossThrow(0.25, cfg)
		expect.near(quick, cfg.minTravel, 1e-6, "a quick wind-up: still long enough to see")
		local longWait, long = FightFxRules.bossThrow(2, cfg)
		expect.near(long, cfg.maxTravel, 1e-6, "a long wind-up: it waits, then flies")
		expect.near(longWait, 2 - cfg.maxTravel, 1e-6)
		local noWait, short = FightFxRules.bossThrow(0.1, cfg)
		expect.equal(noWait, 0, "shorter than the shortest flight: it leaves at once")
		expect.near(short, 0.1, 1e-6, "and still lands with the hit")
	end,

	["every boss's strike throws something at its target, the Hydra's phases too"] = function()
		local drawn = { roots = true, venom = true, fireball = true, iceShard = true, bolt = true, tendril = true }
		for bossId, spec in AttackFx.BOSS do
			local strikes = { spec.strike }
			for _, variant in spec.byPhase or {} do
				table.insert(strikes, variant.strike)
			end
			for _, strike in strikes do
				local throw = FightFxRules.throwStyle(strike, AttackFx.BOSS_HIT)
				assert(throw ~= nil and drawn[throw], `{bossId}'s {strike} throws something drawn ({tostring(throw)})`)
			end
		end
		expect.isNil(FightFxRules.throwStyle("headbutt", AttackFx.BOSS_HIT), "a wild monster's strike throws nothing")
	end,

	["a boss's hit on a creature lands harder than a wild monster's"] = function()
		local hit = AttackFx.BOSS_HIT
		expect.equal(hit.strikeScale >= 1.5, true, "its impact is bigger")
		expect.equal(hit.shake > AttackFx.SHAKE.bossStrike, true, "it shakes more than a wild monster's strike")
		expect.equal(hit.stop > 0 and hit.stop <= 0.1, true, "a hit-stop you feel, not a stall")
		expect.equal(hit.knock > 0 and hit.knockSeconds > hit.stop, true, "knocked back after the stop")
		expect.equal(hit.flash > 0 and hit.flash < 0.3, true, "a quick white flash")
	end,
	-- Your creatures' basic attacks toned down in a boss fight (owner 2026-11-18: "toning it a bit is a good idea": a
	-- Grade S Lv 30 creature hitting every 0.6 s covered the boss and its hits)
	["in a boss fight creatures' basic attacks are toned down: smaller, fewer sparks, no grade S extras, less shake"] = function()
		local tone = AttackFx.BOSS_TONE
		local s = FightFxRules.tier("S", AttackFx)
		local same = FightFxRules.toned(s, false, tone)
		expect.equal(same.scale, s.scale, "outside a boss fight: as before")
		expect.equal(same.extra, s.extra)
		local boss = FightFxRules.toned(s, true, tone)
		expect.near(boss.scale, s.scale * tone.scale, 1e-6, "smaller")
		expect.near(boss.sparks, s.sparks * tone.sparks, 1e-6, "fewer sparks")
		expect.near(boss.shake, s.shake * tone.shake, 1e-6, "less shake")
		expect.equal(boss.extra < 2, true, "no grade S sky strike, pillar or screen flash on every hit")
		expect.equal(FightFxRules.toned(FightFxRules.tier("C", AttackFx), true, tone).extra, 0, "a Grade C has no extras to cap")
		expect.equal(tone.scale >= 0.5 and tone.scale < 1, true, "toned a bit, not hidden")
		expect.equal(AttackFx.GRADE.S.scale, s.scale, "the grade table itself is untouched")
	end,

	["in a boss fight a creature's hits grow less with the boss's size"] = function()
		local tone = AttackFx.BOSS_TONE
		expect.equal(FightFxRules.foeCap(2.83, false, tone), 2.83, "outside a boss fight: as big as the foe makes them")
		expect.equal(FightFxRules.foeCap(2.83, true, tone), tone.foeMax, "on a big boss: capped")
		expect.equal(FightFxRules.foeCap(1, true, tone), 1, "on a small foe: as before")
		expect.equal(tone.foeMax >= 1.5, true, "still bigger on a boss than on a creature")
	end,
}
