--!strict
-- The prologue (spec 2026-11-14-prologue-hydra-design): the real boss fight against the Prism Hydra with a lent, maxed
-- loadout. Its HP is held between two curves so the fight lasts FIGHT.min-FIGHT.max seconds whatever you do; each
-- player's lair has its own spot in the sky; the lent cards are the best there are.
local PrologueRules = require("../src/shared/Util/PrologueRules")
local Prologue = require("../src/shared/Config/Prologue")
local Weapons = require("../src/shared/Config/Weapons")
local Bosses = require("../src/shared/Config/Bosses")
local BossRules = require("../src/shared/Util/BossRules")
local CardList = require("../src/shared/Config/CardList")
local expect = require("./lib/expect")

local cfg = Prologue

local function cardRows(): { [string]: { any } }
	local rows = {}
	for _, set in { CardList.SET1, CardList.FRONTIER } do
		for _, row in set do
			rows[row[1]] = row
		end
	end
	return rows
end

return {
	["spamming can't end the fight before FIGHT.min"] = function()
		local share = PrologueRules.hpShare(10, 1, cfg)
		assert(share > cfg.END_SHARE, `at 10 s with everything dealt it's still {share}`)
		assert(not PrologueRules.done(share, cfg), "not over yet")
		assert(PrologueRules.done(PrologueRules.hpShare(cfg.FIGHT.min, 1, cfg), cfg), "but over at FIGHT.min")
	end,

	["idling still ends it by FIGHT.max"] = function()
		expect.equal(PrologueRules.done(PrologueRules.hpShare(cfg.FIGHT.max, 0, cfg), cfg), true)
		assert(PrologueRules.hpShare(cfg.FIGHT.max / 2, 0, cfg) < 1, "it drains on its own")
	end,

	["dealt damage shows between the curves"] = function()
		expect.near(PrologueRules.hpShare(20, 0.3, cfg), 0.7, 1e-9, "inside the curves: 1 - dealt")
		expect.near(PrologueRules.hpShare(0, 0, cfg), 1, 1e-9, "full at the start")
	end,

	["each player's lair has its own spot"] = function()
		local first = PrologueRules.arenaCentre(0, cfg)
		expect.equal(first.x, 0)
		expect.equal(first.y, cfg.ARENA.height)
		expect.equal(first.z, 0)
		local third = PrologueRules.arenaCentre(2, cfg)
		expect.equal(third.x, 2 * cfg.ARENA.spacing)
		assert(cfg.ARENA.spacing > cfg.ARENA.radius * 10, "far enough apart that nobody sees another's Hydra")
	end,

	["the lowest free lair is taken"] = function()
		expect.equal(PrologueRules.freeSlot({}), 0)
		expect.equal(PrologueRules.freeSlot({ [0] = true, [1] = true }), 2)
		expect.equal(PrologueRules.freeSlot({ [0] = true, [2] = true }), 1)
	end,

	["the lent cards are maxed Legendaries in the loadout's order"] = function()
		local ids: { [string]: string } = {}
		for _, name in cfg.LOADOUT.creatures do
			ids[name] = `card_{name}`
		end
		local best = { level = 30, stars = 5, grade = "S" }
		local beasts = PrologueRules.lentBeasts(cfg, ids, best)
		expect.equal(#beasts, #cfg.LOADOUT.creatures)
		for index, beast in beasts do
			local name = cfg.LOADOUT.creatures[index]
			expect.equal(beast.cardId, ids[name], `{name} in slot {index}`)
			expect.equal(beast.id, `prologue_{index}`, "an id no saved card can have")
			expect.equal(beast.level, 30)
			expect.equal(beast.stars, 5)
			expect.equal(beast.grade, "S")
			expect.equal(beast.foil, true)
			expect.equal(beast.xp, 0)
		end
		expect.equal(#PrologueRules.lentBeasts(cfg, {}, best), 0, "an unknown card is left out, never made up")
	end,

	["the loadout is real"] = function()
		assert(Weapons.ById[cfg.LOADOUT.weapon], `{cfg.LOADOUT.weapon} is a weapon`)
		local rows = cardRows()
		for _, name in cfg.LOADOUT.creatures do
			expect.equal(rows[name] and rows[name][3], "Legendary", `{name} is a Legendary card`)
		end
		expect.equal(cfg.HYDRA.boss, "prismHydra")
		assert(Bosses.BOSSES[cfg.HYDRA.boss], "the real boss it fights")
		assert(cfg.HYDRA.model ~= cfg.HYDRA.boss, "drawn with its own two-headed model, not the five-headed one")
		assert(cfg.FIGHT.atk > 0 and cfg.FIGHT.atk < Bosses.BOSSES.prismHydra.atk, "it hits softer than the real Hydra")
	end,

	["the Hydra's leash stays on the lair's floor"] = function()
		local hydra = cfg.ARENA.hydra
		local leash = BossRules.leashRadius(Bosses.BOSSES[cfg.HYDRA.boss], Bosses)
		local fromCentre = math.sqrt(hydra[1] ^ 2 + hydra[3] ^ 2)
		assert(fromCentre + leash <= cfg.ARENA.radius + cfg.ARENA.rim, `{fromCentre} + {leash} past the floor's edge`)
		local you = cfg.ARENA.player
		local apart = math.sqrt((you[1] - hydra[1]) ^ 2 + (you[3] - hydra[3]) ^ 2)
		assert(apart < leash, "you start inside its ring")
	end,

	["the knock-back starts where you stood and lands you face down, flat"] = function()
		local k = cfg.KNOCK
		local start = PrologueRules.knock(0, cfg)
		expect.equal(start.back, 0)
		expect.equal(start.up, 0)
		expect.equal(start.flip, 0)
		local landed = PrologueRules.knock(k.seconds + 1, cfg)
		expect.near(landed.back, k.back, 1e-9, "thrown back its distance")
		expect.near(landed.up, 0, 1e-9, "on the floor")
		expect.near(landed.flip, -k.flip, 1e-9, "tumbled backwards onto the face")
		local top = PrologueRules.knock(k.seconds / 2, cfg)
		expect.near(top.up, k.height, 1e-6, "highest halfway")
		local last = -1
		for i = 0, 20 do
			local back = PrologueRules.knock(k.seconds * i / 20, cfg).back
			assert(back >= last - 1e-9, "it never flies back toward the Hydra")
			last = back
		end
	end,

	["the crawl: arms take turns and you only ever move forward"] = function()
		local c = cfg.CRAWL
		local first = PrologueRules.crawl(0, cfg)
		expect.near(first.rightShoulder, c.reach, 1e-9, "the right arm starts reaching")
		expect.near(first.leftShoulder, c.pull, 1e-9, "the left starts pulled in")
		local second = PrologueRules.crawl(c.stroke, cfg)
		expect.near(second.rightShoulder, c.pull, 1e-9, "the right has pulled")
		expect.near(second.leftShoulder, c.reach, 1e-9, "the left reaches next")
		local last = -1
		for i = 0, 200 do
			local pose = PrologueRules.crawl(i * 0.05, cfg)
			assert(pose.advance >= last - 1e-9, "never slides back")
			last = pose.advance
			for _, key in { "rightShoulder", "leftShoulder" } do
				assert(pose[key] >= math.min(c.reach, c.pull) - 1e-9 and pose[key] <= math.max(c.reach, c.pull) + 1e-9, `{key} stays in its swing`)
			end
		end
		expect.near(PrologueRules.crawl(c.stroke * c.strokes + 5, cfg).advance, c.step * c.strokes, 1e-9, "a step per stroke")
	end,

	["the crawl ends with your head down on the floor"] = function()
		local c = cfg.CRAWL
		assert(PrologueRules.crawl(c.stroke * 1.5, cfg).neck > 0, "head lifted while crawling")
		expect.near(PrologueRules.crawl(c.stroke * c.strokes + c.collapse + 0.1, cfg).neck, 0, 1e-9, "head down after")
	end,

	["waking up: eyes closed, a blink, then open"] = function()
		local lids = cfg.WAKE.lids
		expect.equal(PrologueRules.lids(0, cfg), 0, "eyes closed at first")
		expect.equal(PrologueRules.lids(lids[#lids][1] + 1, cfg), 1, "open at the end")
		local blinked, highest = false, 0
		for i = 0, 100 do
			local open = PrologueRules.lids(lids[#lids][1] * i / 100, cfg)
			assert(open >= 0 and open <= 1, "between shut and open")
			if open < highest - 0.2 then
				blinked = true
			end
			highest = math.max(highest, open)
		end
		assert(blinked, "they blink before they open")
	end,

	["everything is taken: your three Legendaries first, then the rest"] = function()
		local names = { "Ember Pup", "Solarion", "Tide Kit", "Moss Mole", "Voidmaw" }
		local taken = PrologueRules.stolenCards(cfg, names, 6)
		expect.equal(#taken, 6)
		for index, name in cfg.LOADOUT.creatures do
			expect.equal(taken[index], name)
		end
		expect.equal(taken[4], "Ember Pup", "then the others in order, the Legendaries not twice")
		expect.equal(taken[5], "Tide Kit")
		expect.equal(taken[6], "Moss Mole")
		expect.equal(#PrologueRules.stolenCards(cfg, {}, 2), 2, "never more than asked")
	end,

	["the knock-back never throws you off the lair's floor"] = function()
		local k = cfg.KNOCK
		expect.near(PrologueRules.knockRoom(0, 0, 1, 0, cfg), k.back, 1e-9, "from the middle: the whole way")
		local edge = cfg.ARENA.radius + cfg.ARENA.rim - k.margin
		local room = PrologueRules.knockRoom(edge - 5, 0, 1, 0, cfg)
		expect.near(room, 5, 1e-6, "near the edge: only to the edge's margin")
		expect.near(PrologueRules.knockRoom(edge - 5, 0, -1, 0, cfg), k.back, 1e-9, "thrown back toward the middle: the whole way")
		expect.equal(PrologueRules.knockRoom(edge + 3, 0, 1, 0, cfg), 0, "already past it: not thrown further")
	end,
}
