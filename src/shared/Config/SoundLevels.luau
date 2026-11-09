--!strict
-- How loud each combat sound is, so the skill sounds can be brought to one level (owner 2026-11-05: "adjust skill
-- volumes make sure its not too loud"). LEVELS: the sound's Roblox PlaybackLoudness (it ignores Volume), the louder of
-- its 90th percentile and half its peak while it plays, measured in Studio on 2026-11-06 (tools/audio/measure_loudness;
-- the ids from tools/audio/sound_ids). A sound louder than TARGET is turned down by (TARGET / level) ^ KNEE: KNEE 1
-- would flatten every loud sound to the target, 0.75 squeezes them toward it so a big impact still sounds bigger than a
-- chime; quieter sounds stay as they are (Util/SoundLevel). The super moves and the Pet button moves use it; a new
-- sound needs measuring (tests/SoundLevel). Plain data.
return {
	TARGET = 120,
	KNEE = 0.75,
	LEVELS = {
		["9112780193"] = 11, -- Inferno.linger
		["9112793880"] = 23, -- Rain.layer
		["9112852465"] = 3, -- Thunderstorm.linger, Rain.loop
		["9112872239"] = 1, -- TidalShield.hit
		["9113216700"] = 281, -- Supernova.impact
		["9113224030"] = 261, -- Supernova.linger
		["9113551598"] = 53, -- Eclipse.impact
		["9113612888"] = 28, -- Attack Bloom.hit
		["9113802079"] = 39, -- Curse.layer
		["9113985717"] = 134, -- Inferno.call
		["9114055189"] = 126, -- Supernova.call
		["9114245570"] = 179, -- Stampede.linger, Overcharge.hum
		["9114277757"] = 65, -- Attack Volt.hit
		["9114353377"] = 127, -- Devour.linger, Eclipse.linger, Curse.drone
		["9114369623"] = 72, -- TidalBlessing.heal, Rain.cast
		["9114438917"] = 160, -- Attack big.Ember
		["9114446277"] = 114, -- Inferno.charge
		["9114446802"] = 57, -- Inferno.layer
		["9114463208"] = 121, -- Attack Ember.release
		["9114519078"] = 6, -- Snare.wrap
		["9114554531"] = 362, -- MagmaSlam.impact, Supernova.layer
		["9114554567"] = 358, -- Inferno.impact
		["9114590297"] = 84, -- RiftStep.call
		["9114591515"] = 336, -- RiftStep.layer
		["9114791989"] = 126, -- TidalBlessing.linger
		["9116272073"] = 365, -- Overcharge.cast
		["9116276946"] = 260, -- Stampede.layer, Overcharge.zap
		["9116317695"] = 117, -- TidalShield.charge
		["9116394545"] = 9, -- Attack charge
		["9116394876"] = 28, -- TidalBlessing.impact
		["9116420139"] = 51, -- Supernova.charge
		["9116422213"] = 112, -- RiftStep.impact
		["9118587494"] = 108, -- MagmaSlam.layer
		["9118617328"] = 452, -- Devour.impact
		["9118617342"] = 413, -- MagmaSlam.charge
		["9118675035"] = 48, -- Snare.burst
		["9119746598"] = 248, -- Attack Ember.hit
		["9119749812"] = 32, -- Attack Shade.hit
		["9120016037"] = 151, -- Thunderstorm.impact
		["9120016256"] = 107, -- Stampede.thunder
		["9120113588"] = 175, -- Curse.hex
		["9120585252"] = 107, -- TidalShield.burst, TidalShield.call
		["9120607089"] = 230, -- Attack big.Tide
		["9120611318"] = 76, -- TidalBlessing.layer, TidalShield.impact
		["9120697982"] = 165, -- Eclipse.charge
		["9120717850"] = 195, -- RiftStep.slash, Attack Shade.release
		["9120742493"] = 82, -- Thunderstorm.call
		["9120749129"] = 68, -- RiftStep.blink
		["9120749463"] = 162, -- Devour.charge
		["9120790529"] = 403, -- Eclipse.call
		["9125405388"] = 68, -- Snare.creak
		["9125409816"] = 86, -- TidalShield.layer
		["9125484367"] = 194, -- MagmaSlam.call, Attack boom
		["9125602386"] = 92, -- TidalBlessing.call, TidalBlessing.revive
		["9125603019"] = 83, -- Devour.call
		["9125635430"] = 144, -- TidalBlessing.charge
		["9125637449"] = 23, -- Eclipse.layer, Curse.swell
		["9125644310"] = 101, -- Rain.tick
		["9125703162"] = 16, -- Attack Tide.hit
		["9125883906"] = 65, -- MagmaSlam.linger
		["9125980435"] = 41, -- Stampede.charge
		["9125981170"] = 53, -- RiftStep.charge
		["9126013644"] = 104, -- Attack Tide.release
		["9126069838"] = 97, -- Thunderstorm.charge
		["9126082854"] = 136, -- Stampede.impact, Thunderstorm.layer, Overcharge.thunder
		["9126100173"] = 148, -- Devour.layer
		["9126100408"] = 187, -- Stampede.call
		["9126239755"] = 19, -- Snare.layer
		-- The Sunforged Blade's (Config/Swords sunforgedBlade sounds, 2026-11-07)
		["9114446852"] = 77, -- fireWhoosh
		["9125615451"] = 106, -- lavaBurst
		["9114463410"] = 110, -- flameLicks
		["9114446277"] = 114, -- fireSwing
		["9117985933"] = 149, -- fireBurst
		-- The Verdant Blade's (2026-11-07)
		["9114518070"] = 116, -- leafRustle
		["9120258724"] = 74, -- rootCrack
		["9118676043"] = 35, -- vinesTear
		["9113582284"] = 77, -- vineSnap
		-- The Prism Blade's (2026-11-07)
		["9116394876"] = 28, -- crystalChime
		["9114591515"] = 336, -- prismShatter
		["9120747619"] = 32, -- prismSummon
		["9116393976"] = 109, -- prismStrike
		["9114224721"] = 190, -- prismBoom
		-- The Forge Sword's element sounds (2026-11-07; Ember's and Bloom's reuse the Sunforged's and the Verdant's)
		["9118859146"] = 115, -- elementLayer_Tide
		["9120585252"] = 96, -- elementBlast_Tide
		["9114277757"] = 52, -- elementLayer_Volt
		["9114277402"] = 82, -- elementBlast_Volt
		["9125404581"] = 46, -- elementLayer_Shade
		["9113551598"] = 51, -- elementBlast_Shade
		-- The Steel Sword's moves (shared by every moveset; 2026-11-07, tests/SoundLevel: every sword sound measured)
		["9119750447"] = 106, -- swing1
		["9119749263"] = 12, -- swing3
		["9120704978"] = 63, -- air1
		["9120704940"] = 27, -- air2
		["9125805579"] = 62, -- jump
		["9120730138"] = 167, -- slam
		["9118678952"] = 10, -- ground
		["9119749145"] = 127, -- dashDraw
		["9126229255"] = 226, -- dash
		["9119384855"] = 99, -- cutLines
		["9113487341"] = 72, -- hitThud
		["9116385079"] = 84, -- hitBig
		["9119744642"] = 37, -- draw
		["9113473249"] = 94, -- down
		["9126013811"] = 96, -- getUp
		-- the spear (weapons round 2), measured 2026-11-07
		["9114326590"] = 75, -- thrustAir: Energy Cloud Whooshing By Very Fast 3
		["9119226861"] = 46, -- spinWhoosh: Slow Whoosh Airy Rumble Slicing Spinning 2
		["9118631275"] = 92, -- rockBurst: Rock Impacts 12
		["9118159097"] = 116, -- rushCharge: Reverse Suck 3
		["9114344093"] = 93, -- wrathRumble: Energy Presence 8 (2026-11-08)
		["9125973984"] = 102, -- wrathCharge: Spaceship Blast High Pitch Energy Charge Up
		["9120023325"] = 104, -- wrathThrust: Thunder With Lion Roar Searing Blast 5
		["9120629528"] = 115, -- rushDash: Web Whoosh Fast Heavy Swooshes 3
		["9114658416"] = 123, -- skid: Gravel Slide 1
		-- Magma Cleave's charge-up (weapons round 2.5 part 2), measured 2026-11-09
		["9114463016"] = 110, -- cleaveCharge: Flame Licks 4
		["9118158113"] = 92, -- cleaveRush: Reversed Whoosh Backwards Hissing Burst 2
		["9125989548"] = 134, -- riftGrowl: Spirit Whooshes Low End Airy Growls Fast Bys (2026-11-09)
		["9120358057"] = 66, -- reaperWail: Unhappy Angels Discordant Choral Wail Airy 1 (2026-11-09)
		["9126013644"] = 80, -- flurryA: Swish Med High End Sharp Swords Fast Punches (2026-11-09)
		["9126013382"] = 100, -- flurryB: Swish Med High End Sharp Swords Fast Punches (2026-11-09)
		["9126014020"] = 117, -- flurryC: Swish Med High End Sharp Swords Fast Punches (2026-11-09)
	} :: { [string]: number },
}
