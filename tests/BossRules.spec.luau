--!strict
local BossRules = require("../src/shared/Util/BossRules")
local Bosses = require("../src/shared/Config/Bosses")
local Combat = require("../src/shared/Config/Combat")
local Frontier = require("../src/shared/Config/Frontier")
local Wild = require("../src/shared/Config/Wild")
local expect = require("./lib/expect")
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function record(fields: { [string]: any }): BossRules.Record
	local base = BossRules.read(nil, false)
	for key, value in fields do
		(base :: any)[key] = value
	end
	return base
end

return {
	["insideRing: who gets moved out of a sealed arena"] = function()
		expect.equal(BossRules.insideRing(10, 20, Bosses.ARENA_RADIUS), true, "well inside")
		expect.equal(BossRules.insideRing(Bosses.ARENA_RADIUS + 0.5, 0, Bosses.ARENA_RADIUS), true, "on the wall line still counts")
		expect.equal(BossRules.insideRing(Bosses.ARENA_RADIUS + 3, 0, Bosses.ARENA_RADIUS), false, "outside the gate")
	end,

	["scatter: every drop lands in the ring, none on another"] = function()
		local spots = BossRules.scatter(7, Bosses.LOOT_SCATTER.min, Bosses.LOOT_SCATTER.max, 0.3)
		expect.equal(#spots, 7, "one per drop")
		for index, spot in spots do
			local distance = math.sqrt(spot.x ^ 2 + spot.z ^ 2)
			expect.equal(distance >= Bosses.LOOT_SCATTER.min - 1e-9 and distance <= Bosses.LOOT_SCATTER.max + 1e-9, true, `spot {index} in the ring`)
			for other = index + 1, #spots do
				local gap = math.sqrt((spot.x - spots[other].x) ^ 2 + (spot.z - spots[other].z) ^ 2)
				expect.equal(gap > 1.5, true, `spots {index} and {other} apart`)
			end
		end
		expect.equal(#BossRules.scatter(0, 4, 10, 0), 0, "no loot, no spots")
	end,

	["config: the Frontier bosses sit in Frontier zones"] = function()
		expect.equal(#Bosses.LADDER, 7, "seven bosses")
		for index, id in Bosses.LADDER do
			local boss = Bosses.BOSSES[id]
			local world = if boss.place == "Wild" then Wild else Frontier
			expect.equal(world.ZONES[boss.zone] ~= nil, true, `{id} zone`)
			expect.equal(boss.place, if index <= 3 then "Wild" elseif index <= 6 then "Frontier" else "Dungeon", `{id} place`)
		end
	end,

	["config: each boss opens at a shop level, rising along the ladder"] = function()
		local before = 0
		for _, id in Bosses.LADDER do
			local needed = Bosses.BOSSES[id].shopLevel
			expect.equal(typeof(needed) == "number" and needed >= 1 and needed % 1 == 0, true, `{id} shopLevel`)
			expect.equal(needed > before, true, `{id} opens after the boss before it`)
			before = needed
		end
	end,

	["shouldUnseal: only the arena's own fight drops its wall"] = function()
		local ended = { alive = false }
		local next = { alive = true }
		expect.equal(BossRules.shouldUnseal(ended, nil), true, "nobody else in the arena")
		expect.equal(BossRules.shouldUnseal(ended, ended), true, "its own fight ended")
		expect.equal(BossRules.shouldUnseal(ended, next), false, "a newer fight already sealed it")
		expect.equal(BossRules.shouldUnseal(ended, { alive = false }), true, "the newer fight is over too")
	end,

	["readIds: a list of distinct drop ids, capped"] = function()
		local ids = BossRules.readIds({ "a", "b", "a" }, 5)
		expect.equal(ids and #ids, 2, "duplicates once")
		expect.equal(BossRules.readIds("a", 5), nil, "not a list")
		expect.equal(BossRules.readIds({}, 5), nil, "empty")
		expect.equal(BossRules.readIds({ "a", 3 }, 5), nil, "a non-string")
		expect.equal(BossRules.readIds({ "a", "b", "c" }, 2), nil, "over the cap")
		expect.equal(BossRules.readIds({ [1] = "a", [3] = "c" }, 5), nil, "a gappy list")
		expect.equal(BossRules.readIds({ string.rep("x", 65) }, 5), nil, "an id far longer than a GUID")
		expect.equal(Bosses.LOOT_PICKUP_BATCH >= 6, true, "a whole drop of loot fits in one request")
		expect.equal(Bosses.LOOT_AUTO_SECONDS, nil, "loot is never collected by itself")
	end,

	["phaseAt: by HP share, and never back"] = function()
		local phases = { { below = 1 }, { below = 0.8 }, { below = 0.6 } }
		expect.equal(BossRules.phaseAt(phases, 1, 1), 1, "full HP")
		expect.equal(BossRules.phaseAt(phases, 0.79, 1), 2, "under 80%")
		expect.equal(BossRules.phaseAt(phases, 0.1, 1), 3, "skips straight to the last reached")
		expect.equal(BossRules.phaseAt(phases, 0.9, 3), 3, "a heal never takes it back")
	end,

	["levelReady: the shop level must reach the boss's"] = function()
		expect.equal(BossRules.levelReady(12, 11), false, "one short")
		expect.equal(BossRules.levelReady(12, 12), true, "exactly")
		expect.equal(BossRules.levelReady(12, 30), true, "above")
	end,

	["config: the Prism Hydra has five phases, one per element, in falling order"] = function()
		local hydra = Bosses.BOSSES.prismHydra
		expect.equal(Bosses.LADDER[7], "prismHydra", "last on the ladder")
		expect.equal(hydra.place, "Dungeon", "its place")
		expect.equal(hydra.shopLevel, 22, "shop level")
		expect.equal(hydra.unlock and hydra.unlock.count, 10, "10 fragments")
		local phases = hydra.phases :: { any }
		expect.equal(#phases, 5, "five phases")
		expect.equal(phases[1].below, 1, "the first starts at full HP")
		local seen = {}
		for index, phase in phases do
			seen[phase.element] = true
			if index > 1 then
				expect.equal(phase.below < phases[index - 1].below, true, `phase {index} below the one before`)
			end
		end
		for _, element in { "Tide", "Volt", "Shade", "Bloom", "Ember" } do
			expect.equal(seen[element], true, element)
		end
		local m = function(i: number): any
			return phases[i].mechanics
		end
		expect.equal(m(1).shield ~= nil and m(2).thunderclap ~= nil and m(3).adds ~= nil and m(4).heal ~= nil and m(5).enrage ~= nil, true, "shield, clap, adds, heal, enrage")
	end,

	["config: the Hydra's five heads are its five phase elements"] = function()
		local hydra = Bosses.BOSSES.prismHydra
		local heads = hydra.heads :: { string }
		expect.equal(#heads, 5, "five heads")
		local phaseElements = {}
		for _, phase in hydra.phases :: { any } do
			phaseElements[phase.element] = true
		end
		for index, element in heads do
			expect.equal(phaseElements[element], true, `head {index - 1}: {element}`)
		end
		expect.equal(typeof(Bosses.DEATH_SECONDS) == "number" and Bosses.DEATH_SECONDS > 0, true, "a death scene")
	end,

	["config: the Hydra is the biggest boss, with room round it and a rainbow aura"] = function()
		local hydra = Bosses.BOSSES.prismHydra
		for id, boss in Bosses.BOSSES do
			if id ~= "prismHydra" then
				expect.equal(hydra.scale > boss.scale, true, `bigger than {id}`)
			end
		end
		expect.equal((hydra.ringRadius :: number) + 4 < Bosses.ARENA_RADIUS, true, "its fighters still stand inside the ring")
		local shot = hydra.introShot :: any
		expect.equal(shot.back > Bosses.INTRO_SHOT.back and shot.up > Bosses.INTRO_SHOT.up, true, "the intro camera stands further off")
		expect.equal(hydra.rainbowAura, true, "a rainbow aura")
		local aura = Bosses.RAINBOW_AURA
		for _, key in { "hueSeconds", "outlineTransparency", "fillTransparency", "lightBrightness", "lightRange" } do
			expect.equal(typeof(aura[key]), "number", key)
		end
		expect.equal(aura.fillTransparency >= 0.7, true, "a glow over the model, never hiding it")
		expect.equal(hydra.auroraFlame, true, "an aurora flame over the glow")
		local flame = Bosses.AURORA_FLAME
		expect.equal(#flame.bones >= 1, true, "flames rise from some bones")
		for _, key in { "rate", "sizeStart", "sizeEnd", "lifetimeMin", "lifetimeMax", "rise", "transparency" } do
			expect.equal(typeof(flame[key]), "number", key)
		end
		expect.equal(flame.rate <= 12 and flame.transparency >= 0.3, true, "light: never overwhelming")
		expect.equal(Bosses.BOSSES.caveBroodQueen.mechanics.heal and Bosses.BOSSES.caveBroodQueen.mechanics.heal.uses ~= nil, true, "the Brood Queen's heals are limited")
	end,

	["config: the Rift Devourer drops the Hydra's fragments"] = function()
		local rift = Bosses.BOSSES.riftDevourer
		expect.equal(rift.fragment, "fragment_prismHydra", "its fragment")
		local inDrops, inChest = false, false
		for _, drop in rift.drops do
			inDrops = inDrops or drop.item == "fragment_prismHydra"
		end
		for _, grant in rift.firstClear do
			inChest = inChest or (grant.item == "fragment_prismHydra" and grant.count == 3)
		end
		expect.equal(inDrops and inChest, true, "drop and 3 in the first clear")
	end,

	["read: Frontier bosses start locked"] = function()
		expect.equal(BossRules.read(nil, Bosses.BOSSES.frostTyrant.unlock == nil).unlocked, false, "needs its key")
	end,

	["intro: the camera part ends before the 3-2-1 countdown starts"] = function()
		expect.equal(Bosses.INTRO_SECONDS, 6, "intro length")
		expect.equal(Bosses.INTRO_SECONDS - Bosses.INTRO_CAMERA_SECONDS >= 3, true, "room for 3, 2, 1")
		for id, boss in Bosses.BOSSES do
			expect.equal(typeof(boss.title) == "string" and #boss.title > 0, true, `{id} has a title`)
		end
	end,

	["ringSegments: the barrier closes the whole ring"] = function()
		local angles = BossRules.ringSegments(Bosses.ARENA_RADIUS, Bosses.BARRIER_SEGMENT)
		expect.equal(#angles * Bosses.BARRIER_SEGMENT >= 2 * math.pi * Bosses.ARENA_RADIUS, true, "no gaps")
		expect.equal(math.abs((angles[2] - angles[1]) - 2 * math.pi / #angles) < 1e-9, true, "evenly spaced")
		expect.equal(Bosses.ARENA_RADIUS, 36, "the bigger arena")
	end,

	["group prompt: the leader sees Start now, everyone else Join"] = function()
		expect.equal(BossRules.groupPromptText(Bosses, 0, false), "Start group", "no group yet")
		expect.equal(BossRules.groupPromptText(Bosses, 2, false), `Join group (2/{Bosses.GROUP_MAX})`, "others join")
		expect.equal(BossRules.groupPromptText(Bosses, 2, true), `Start now (2/{Bosses.GROUP_MAX})`, "the leader starts")
	end,

	["ring: an extra stands nearer its own leader than the next member's"] = function()
		expect.equal(Bosses.GROUP_SPACING - Combat.EXTRA_SIDE > Combat.EXTRA_SIDE, true, "gap to the next leader")
	end,

	["read: bad saves become safe defaults"] = function()
		expect.equal(BossRules.read(nil, true).unlocked, true, "an open boss starts unlocked")
		local bad = BossRules.read({ lootAt = -5, rewardedToday = 0 / 0 }, false)
		expect.equal(bad.lootAt, 0, "negative lootAt")
		expect.equal(bad.rewardedToday, 0, "NaN kills")
		expect.equal(bad.unlocked, false, "locked")
		expect.equal(bad.cleared, false, "not cleared")
		expect.equal(BossRules.read({ unlocked = true, cleared = true }, false).cleared, true, "kept")
	end,

	["canStart: open bosses start, locked ones need the fragments"] = function()
		local unlock = { item = "fragment_caveBroodQueen", count = 3 }
		expect.equal((BossRules.canStart(record({ unlocked = true }), unlock, 0)), true, "already unlocked")
		local ok, reason = BossRules.canStart(record({ unlocked = false }), unlock, 2)
		expect.equal(ok, false, "two of three")
		expect.equal(reason, "locked:2:3", "reason")
		expect.equal((BossRules.canStart(record({ unlocked = false }), unlock, 3)), true, "enough fragments")
		expect.equal((BossRules.canStart(record({ unlocked = false }), nil, 0)), true, "no unlock cost")
	end,

	["lootEligible: once the saved cooldown has passed"] = function()
		local saved = record({ lootAt = 1000 })
		expect.equal(BossRules.lootEligible(saved, 999), false, "still cooling down")
		expect.equal(BossRules.lootEligible(saved, 1000), true, "ready")
	end,

	["dayCounts: a new UTC day resets today's kills"] = function()
		local newDay = BossRules.dayCounts(record({ day = 5, rewardedToday = 9 }), 6)
		expect.equal(newDay.rewardedToday, 0, "reset")
		expect.equal(newDay.day, 6, "today")
		local sameDay = BossRules.dayCounts(record({ day = 6, rewardedToday = 9 }), 6)
		expect.equal(sameDay.rewardedToday, 9, "same day kept")
		expect.equal(BossRules.dayNumber(86400 * 3 + 5), 3, "UTC day number")
	end,

	["softCapFactor: full for 6 kills, then x0.75 each, never under 0.2"] = function()
		for kills = 0, 5 do
			expect.equal(BossRules.softCapFactor(Bosses, kills), 1, `kill {kills}`)
		end
		expect.near(BossRules.softCapFactor(Bosses, 6), 0.75, 1e-9, "7th rewarded kill")
		expect.near(BossRules.softCapFactor(Bosses, 7), 0.5625, 1e-9, "8th")
		expect.equal(BossRules.softCapFactor(Bosses, 40), 0.2, "floor")
	end,

	["overPowerFactor: far above the recommended Power drops less"] = function()
		expect.equal(BossRules.overPowerFactor(Bosses, 500, 200), 1, "2.5x is fine")
		expect.equal(BossRules.overPowerFactor(Bosses, 501, 200), 0.35, "above 2.5x")
		expect.near(BossRules.dropFactor(Bosses, record({ rewardedToday = 6 }), 501, 200), 0.75 * 0.35, 1e-9, "both together")
	end,

	["config: every boss after the first unlocks with the fragment the one before drops"] = function()
		local first = Bosses.BOSSES[Bosses.LADDER[1]]
		expect.isNil(first.unlock, "boss 1 is open")
		for index = 2, #Bosses.LADDER do
			local boss = Bosses.BOSSES[Bosses.LADDER[index]]
			local before = Bosses.BOSSES[Bosses.LADDER[index - 1]]
			assert(boss.unlock, `{boss.name} has no unlock`)
			expect.equal(boss.unlock.item, before.fragment, `{boss.name} unlocks with what {before.name} drops`)
		end
		for id, boss in Bosses.BOSSES do
			for _, drop in boss.drops do
				assert(drop.chance >= 0 and drop.chance <= 1, `{id} drop chance out of range`)
				assert(drop.min >= 1 and drop.max >= drop.min, `{id} drop count`)
			end
			assert(boss.recommended > 0 and boss.hp > 0 and boss.minFightSeconds > 0, `{id} numbers`)
		end
	end,
	["gate: the server accepts a press from anywhere its prompt shows"] = function()
		assert(typeof(Bosses.GATE_PROMPT_DISTANCE) == "number", "GATE_PROMPT_DISTANCE")
		assert(Bosses.GATE_DISTANCE >= Bosses.GATE_PROMPT_DISTANCE + 2, "GATE_DISTANCE leaves room past the prompt's reach")
	end,

	["save: records of bosses this server doesn't know are kept"] = function()
		local saved = { meadowWarden = { cleared = false }, frostTyrant = { unlocked = true, cleared = true, lootAt = 5 } }
		local out = BossRules.write(saved, { meadowWarden = record({ cleared = true }) })
		expect.equal(out.meadowWarden.cleared, true, "known boss written")
		expect.equal(out.frostTyrant.cleared, true, "unknown boss kept")
		expect.equal(out.frostTyrant.lootAt, 5, "unknown boss untouched")
		expect.equal(BossRules.write(nil, { meadowWarden = record({}) }).meadowWarden.cleared, false, "no save yet")
	end,
	["the ladder can be climbed: each key's fragments come from the boss before"] = function()
		for index, bossId in Bosses.LADDER do
			local unlock = Bosses.BOSSES[bossId].unlock
			if index == 1 then
				assert(unlock == nil, "the first boss is open")
				continue
			end
			assert(unlock, `{bossId} needs a key`)
			local previous = Bosses.BOSSES[Bosses.LADDER[index - 1]]
			local fromClear, dropped = 0, false
			for _, grant in previous.firstClear do
				if grant.item == unlock.item then
					fromClear += grant.count
				end
			end
			for _, drop in previous.drops do
				dropped = dropped or (drop.item == unlock.item and drop.chance > 0)
			end
			assert(fromClear > 0, `{previous.name}'s first clear gives {unlock.item}`)
			assert(fromClear >= unlock.count or dropped, `{unlock.item}: {fromClear} from the first clear and no drop for the rest`)
		end
	end,
	["groupStats: more HP and ATK per extra player, and extra swings so every creature feels the boss"] = function()
		local hp, atk, swings = BossRules.groupStats(Bosses, 1200, 9, 1)
		expect.equal(hp, 1200, "solo HP")
		expect.equal(swings, 1, "solo: one target per attack")
		hp, atk, swings = BossRules.groupStats(Bosses, 1200, 9, 2)
		expect.equal(hp, math.round(1200 * (1 + Bosses.GROUP_HP_STEP)), "2 players HP")
		expect.equal(atk, math.round(9 * (1 + Bosses.GROUP_ATK_STEP)), "2 players ATK")
		expect.equal(swings, 1 + Bosses.GROUP_SWINGS_STEP, "2 players: hits more targets")
		hp, atk, swings = BossRules.groupStats(Bosses, 4800, 18, 4)
		expect.equal(swings, 1 + 3 * Bosses.GROUP_SWINGS_STEP, "4 players")
		expect.equal(swings <= 4, true, "never more targets than players")
		-- A boss may bring its own ATK step (the Frontier ones: Legendary parties shrug off the default)
		local _, ownAtk = BossRules.groupStats(Bosses, 1000, 10, 3, 0.5)
		expect.equal(ownAtk, 20, "ATK x (1 + 0.5 x 2)")
	end,

	["contributed: 10% of the damage or 15% of the hits taken"] = function()
		expect.equal(BossRules.contributed(Bosses, 10, 0, 100, 100), true, "10% damage")
		expect.equal(BossRules.contributed(Bosses, 9, 15, 100, 100), true, "15% tanked")
		expect.equal(BossRules.contributed(Bosses, 9, 14, 100, 100), false, "carried")
		expect.equal(BossRules.contributed(Bosses, 0, 0, 0, 0), true, "nothing happened: no penalty")
	end,

	["carriedDrop: a quarter of the chance, never fragments"] = function()
		expect.equal(BossRules.carriedDrop(Bosses, "xpTonic", 0.6, false), 0.15, "tonic")
		expect.equal(BossRules.carriedDrop(Bosses, "fragment_caveBroodQueen", 0.7, true), 0, "fragment")
	end,
	["every rule exists as soon as the module loads (none nested inside another)"] = function()
		local fresh = luau.load(luau.compile(fs.readFile("src/shared/Util/BossRules.luau")), { debugName = "BossRules" })()
		for _, name in { "read", "write", "dayNumber", "dayCounts", "canStart", "lootEligible", "softCapFactor", "overPowerFactor", "dropFactor", "groupStats", "contributed", "carriedDrop", "groupPromptText", "ringSegments", "scatter", "insideRing", "levelReady", "shouldUnseal", "readIds", "phaseAt", "stepState", "travelChoice", "lockReason", "counterElements", "fullDropsLeft", "chanceText", "countText", "watchOut", "revealTricks" } do
			expect.equal(typeof(fresh[name]), "function", name)
		end
	end,
	["stepState: beaten, ready, too weak or locked"] = function()
		local base: BossRules.Step = { cleared = false, unlocked = true, keyNeeded = 0, fragments = 0, shopLevel = 10, needLevel = 5, power = 500, recommended = 400 }
		local function with(fields: { [string]: any }): BossRules.Step
			local step = table.clone(base) :: any
			for key, value in fields do
				step[key] = value
			end
			return step
		end
		expect.equal(BossRules.stepState(with({ cleared = true, power = 1 })), "beaten", "beaten first")
		expect.equal(BossRules.stepState(base), "ready", "open and strong enough")
		expect.equal(BossRules.stepState(with({ power = 399 })), "tooWeak", "open, Power short")
		expect.equal(BossRules.stepState(with({ shopLevel = 4 })), "locked", "below the shop level")
		expect.equal(BossRules.stepState(with({ unlocked = false, keyNeeded = 3, fragments = 2 })), "locked", "short of fragments")
		expect.equal(BossRules.stepState(with({ unlocked = false, keyNeeded = 3, fragments = 3 })), "ready", "enough fragments counts as open")
		expect.equal(BossRules.stepState(with({ unlocked = false, keyNeeded = 3, fragments = 3, power = 10 })), "tooWeak", "can start, too weak")
		expect.equal(BossRules.stepState(with({ unlocked = false })), "ready", "no key needed, no data yet")
	end,
	["travelChoice: the gate in this place, else the normal travel"] = function()
		expect.equal(BossRules.travelChoice("Wild", "Main"), "gate", "Wild boss from the main game")
		-- The Frontier portal stands at the end of the Frostpeak trail now: walk there (the server only travels from it)
		expect.equal(BossRules.travelChoice("Frontier", "Main"), "walkToFrontier", "Frontier boss from the main game")
		expect.equal(BossRules.travelChoice("Dungeon", "Main"), "viaPortal", "the Hydra")
		expect.equal(BossRules.travelChoice("Frontier", "Frontier"), "gate", "in the Frontier")
		expect.equal(BossRules.travelChoice("Wild", "Frontier"), "toMain", "Wild boss from the Frontier")
		expect.equal(BossRules.travelChoice("Dungeon", "Frontier"), "viaPortal", "the Hydra from the Frontier")
		expect.equal(BossRules.travelChoice("Wild", "Dungeon"), "none", "in a run")
		expect.equal(BossRules.travelChoice("Dungeon", "Dungeon"), "none", "in a run")
	end,
	["lockReason: what keeps a boss shut, shop level first"] = function()
		local base: BossRules.Step = { cleared = false, unlocked = false, keyNeeded = 3, fragments = 3, shopLevel = 10, needLevel = 5, power = 1, recommended = 400 }
		local function with(fields: { [string]: any }): BossRules.Step
			local step = table.clone(base) :: any
			for key, value in fields do
				step[key] = value
			end
			return step
		end
		expect.isNil(BossRules.lockReason(base), "level and keys in hand")
		expect.equal(BossRules.lockReason(with({ shopLevel = 4 })), "level", "below the shop level")
		expect.equal(BossRules.lockReason(with({ fragments = 2 })), "keys", "short of fragments")
		expect.equal(BossRules.lockReason(with({ shopLevel = 4, fragments = 0 })), "level", "both short: the level first")
		expect.isNil(BossRules.lockReason(with({ unlocked = true, fragments = 0 })), "opened already, keys used")
		expect.isNil(BossRules.lockReason(with({ cleared = true, shopLevel = 1 })), "beaten bosses are never locked")
	end,
	["counterElements: the elements that hit a boss harder"] = function()
		expect.equal(table.concat(BossRules.counterElements(Combat.BEATS, "Volt"), ","), "Shade", "Shade beats Volt")
		expect.equal(table.concat(BossRules.counterElements(Combat.BEATS, "Bloom"), ","), "Ember", "Ember beats Bloom")
		expect.equal(#BossRules.counterElements(Combat.BEATS, "Nothing"), 0, "unknown element")
		expect.equal(table.concat(BossRules.counterElements({ A = { "C" }, B = { "C" } }, "C"), ","), "A,B", "several, sorted")
	end,
	["fullDropsLeft: wins left today before the soft cap"] = function()
		expect.equal(BossRules.fullDropsLeft(Bosses, 0), Bosses.SOFT_CAP_AFTER, "none yet")
		expect.equal(BossRules.fullDropsLeft(Bosses, Bosses.SOFT_CAP_AFTER - 1), 1, "one left")
		expect.equal(BossRules.fullDropsLeft(Bosses, Bosses.SOFT_CAP_AFTER + 3), 0, "past the cap")
	end,
	["chanceText and countText: drop odds in words"] = function()
		expect.equal(BossRules.chanceText(0.25), "25%", "quarter")
		expect.equal(BossRules.chanceText(0.6), "60%", "sixty")
		expect.equal(BossRules.chanceText(0.002), "1%", "never shows 0%")
		expect.equal(BossRules.chanceText(1), "100%", "always")
		expect.equal(BossRules.countText(1, 1), "x1", "one")
		expect.equal(BossRules.countText(1, 2), "x1-2", "a range")
		expect.equal(BossRules.countText(3, 3), "x3", "fixed")
	end,
	["watchOut: each boss's tricks in kid words"] = function()
		expect.equal(#BossRules.watchOut(Bosses.BOSSES.meadowWarden), 0, "the first boss has none")
		local heal = BossRules.watchOut(Bosses.BOSSES.caveBroodQueen)
		expect.equal(#heal, 1, "one trick")
		expect.equal(heal[1].kind, "heal", "heal")
		expect.equal(heal[1].name, "Heals", "heal name")
		expect.equal(heal[1].text, "Heals 15% of its health when under 50% (3 times).", "heal words")
		local enrage = BossRules.watchOut(Bosses.BOSSES.emberColossus)[1]
		expect.equal(enrage.text, "Hits 1.5x harder when under 50% health.", "enrage words")
		local shield = BossRules.watchOut(Bosses.BOSSES.frostTyrant)[1]
		expect.equal(shield.text, "Puts up a shield every 20 s. Break it to stun it for 3 s.", "shield words")
		local clap = BossRules.watchOut(Bosses.BOSSES.stormSovereign)[1]
		expect.equal(clap.text, "Stuns your cards every 14 s. Faster cards shake it off sooner.", "thunderclap words")
		local adds = BossRules.watchOut(Bosses.BOSSES.riftDevourer)[1]
		expect.equal(adds.text, "Calls 2 Rift Horrors at 50% health. Beat them first: it's tougher while they stand.", "adds words")
		local hydra = BossRules.watchOut(Bosses.BOSSES.prismHydra)
		expect.equal(#hydra, 1, "the Hydra: one entry for its phases")
		expect.equal(hydra[1].kind, "phases", "phases")
		expect.equal(hydra[1].text, "As it gets hurt: Tide, then Volt, Shade, Bloom, Ember. Each part fights like an earlier boss.", "phase words")
		for _, id in Bosses.LADDER do
			for _, entry in BossRules.watchOut(Bosses.BOSSES[id]) do
				expect.equal(string.find(entry.text, "[^%w%s%p]") == nil, true, `{id} {entry.kind}: plain ASCII`)
			end
		end
	end,
	["revealTricks: a boss's tricks stay a surprise until you can reach it"] = function()
		expect.equal(BossRules.revealTricks("beaten", false), true, "beaten")
		expect.equal(BossRules.revealTricks("ready", false), true, "open")
		expect.equal(BossRules.revealTricks("tooWeak", false), true, "open, too weak")
		expect.equal(BossRules.revealTricks("locked", true), true, "the next boss, even locked")
		expect.equal(BossRules.revealTricks("locked", false), false, "locked further up")
	end,
	["a remote arena copy is free once its boss is gone and its fighters have left"] = function()
		expect.equal(BossRules.copyFree(nil, 0), true, "never used")
		expect.equal(BossRules.copyFree({ alive = true }, 0), false, "a fight on")
		expect.equal(BossRules.copyFree({ alive = false }, 2), false, "fighters still picking up loot")
		expect.equal(BossRules.copyFree({ alive = false }, 0), true, "done and empty")
	end,

	["the first free copy is picked; none when all are busy"] = function()
		expect.equal(BossRules.pickCopy({ false, true, true, false }), 2, "copy 2")
		expect.equal(BossRules.pickCopy({ false, false, false, false }), nil, "all busy")
	end,

	["a forming group blocks solo fights only where there's a single arena"] = function()
		expect.equal(BossRules.soloBlockedByLobby(1), true, "the Frontier's ring")
		expect.equal(BossRules.soloBlockedByLobby(4), false, "the valley's copies")
	end,

	["someone who left the game or the copy no longer holds it"] = function()
		expect.equal(BossRules.stillInCopy(true, 20, 90), true, "in the ring")
		expect.equal(BossRules.stillInCopy(true, 85, 90), true, "in a corner of the clearing")
		expect.equal(BossRules.stillInCopy(true, 95, 90), false, "past the clearing")
		expect.equal(BossRules.stillInCopy(false, 0, 90), false, "left the game")
		expect.equal(BossRules.stillInCopy(true, 500, 90), false, "respawned at their shop")
	end,

	["sending everyone back reaches every fighter, though each one sent leaves the list"] = function()
		local list = { "A", "B", "C", "D" }
		local sent = {}
		BossRules.forEachOf(list, function(player)
			table.insert(sent, player)
			table.remove(list, table.find(list, player) :: number)
		end)
		expect.equal(#sent, 4, "all four sent back")
		expect.equal(sent[2], "B", "the second isn't skipped")
		expect.equal(sent[4], "D", "nor the fourth")
	end,

	["sending a fighter back never waits on streaming (it runs inside a fight's leave)"] = function()
		-- Line endings depend on the checkout (core.autocrlf), so match against LF only
		local source = (string.gsub(fs.readFile("src/server/Services/BossService.luau"), "\r", ""))
		local body = string.match(source, "local function sendBack%(.-\nend\n")
		assert(body, "sendBack")
		assert(string.find(body, "task.spawn(WildService.MoveInWild", 1, true), "sendBack moves the player in its own thread")
		assert(not string.find(body, "\n%s*WildService.MoveInWild%("), "sendBack calls MoveInWild directly (it streams, so it yields)")
	end,

	["each Wild boss has its arena copies"] = function()
		expect.equal(Bosses.ARENA_COPIES, 4, "up to 4 fights per boss at once")
		assert(Bosses.ARENA_LINGER > 0 and Bosses.ARENA_LINGER <= 120, "time to pick up loot, then back")
	end,
}
