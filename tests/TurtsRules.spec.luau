--!strict
-- Turts' rug shop (spec 2026-11-13-turts-shop-design; owner: "after the timer ends, the shop restocks 3 random items.
-- make sure odds stays balanced, not game breaking, and also not impossible to get"; "make sure the prices are higher
-- than usual ... make sure its abuse proof and balance"; "restock also stocks only 1qty per item")
local TurtsRules = require("../src/shared/Util/TurtsRules")
local Turts = require("../src/shared/Config/Turts")
local Grading = require("../src/shared/Config/Grading")
local Weapons = require("../src/shared/Config/Weapons")
local WalkerRules = require("../src/shared/Util/WalkerRules")
local TownLayout = require("../src/shared/Util/TownLayout")
local PlazaLayout = require("../src/shared/Util/PlazaLayout")
local Customers = require("../src/shared/Config/Customers")
local Plaza = require("../src/shared/Config/Plaza")
local Town = require("../src/shared/Config/Town")
local Wild = require("../src/shared/Config/Wild")
local expect = require("./lib/expect")

local WORLD = {
	perRow = 3,
	plotWidth = 50,
	plotDepth = 60,
	gap = 14,
	streetWidth = 96,
	spring = { x = Wild.SPRING.x, z = Wild.SPRING.z },
}

-- A seeded stand-in for Random: the same numbers every run
local function lcg(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

return {
	["the clock: every server restocks on the same 480 s boundary"] = function()
		expect.equal(TurtsRules.restockIndex(960, 480), 2)
		expect.equal(TurtsRules.restockIndex(959, 480), 1)
		expect.equal(TurtsRules.secondsLeft(959, 480), 1)
		expect.equal(TurtsRules.secondsLeft(960, 480), 480)
		expect.equal(Turts.RESTOCK_SECONDS, 480, "the owner's 8 minutes")
	end,

	["a restock is 3 different offers, rarer ones less often"] = function()
		local random = lcg(7)
		local seen: { [string]: number } = {}
		local rolls = 20000
		for _ = 1, rolls do
			local stock = TurtsRules.roll(Turts.OFFERS, Turts.PICKS, random)
			expect.equal(#stock, 3, "three offers")
			local once: { [string]: boolean } = {}
			for _, id in stock do
				assert(Turts.OFFERS[id], `{id} is an offer`)
				assert(not once[id], `{id} twice in one restock`)
				once[id] = true
				seen[id] = (seen[id] or 0) + 1
			end
		end
		local function share(id: string): number
			return (seen[id] or 0) / rolls
		end
		assert(share("wildOre") > share("vrPack"), "Wild Ore more often than a Very Rare Pack")
		assert(share("vrPack") > share("epicPack"), "a Very Rare Pack more often than an Epic Pack")
		assert(share("epicPack") > share("legendaryPack"), "an Epic Pack more often than a Legendary Pack")
		-- owner 2026-11-13: "lower the chances of getting a rare items like legendary card pack and other high level boss
		-- items": a Legendary Pack about once every 3-4 hours of play (7.5 restocks an hour), never impossible
		local legendary = share("legendaryPack")
		assert(legendary >= 0.02 and legendary <= 0.05, `a Legendary Pack in {legendary * 100}% of restocks`)
		assert(share("goldSeal") <= 0.03 and share("goldSeal") > 0, "the Gold Seal is rare")
		-- the later bosses' materials rarer than the first ones', the Prism Hydra's the rarest
		assert(share("material_meadowWarden") > share("material_frostTyrant"), "a high-level boss's material is rarer")
		assert(share("material_frostTyrant") > share("material_prismHydra"), "the Prism Hydra's is the rarest")
		assert(share("material_prismHydra") > 0, "never impossible")
		-- the same seed gives the same roll (every server agrees)
		local a = TurtsRules.roll(Turts.OFFERS, 3, lcg(42))
		local b = TurtsRules.roll(Turts.OFFERS, 3, lcg(42))
		expect.equal(table.concat(a, ","), table.concat(b, ","))
	end,

	["buy once per restock, only what's in your stock, and nothing after the restock turns"] = function()
		local state = { index = 5, bought = { "vrPack" } }
		local stock = { "vrPack", "xpTonic", "starShard" }
		expect.equal(TurtsRules.canBuy(state, 5, stock, "xpTonic"), true)
		expect.equal(select(2, TurtsRules.canBuy(state, 5, stock, "vrPack")), "bought")
		expect.equal(select(2, TurtsRules.canBuy(state, 5, stock, "goldSeal")), "notInStock")
		expect.equal(select(2, TurtsRules.canBuy(state, 6, stock, "xpTonic")), "restocked")
		-- a buy pressed on the last restock's window lands after the new one: refused, even when the new stock has an
		-- offer of the same name (the player saw, and meant, the old one)
		local fresh = { index = 6, bought = {} }
		expect.equal(select(2, TurtsRules.canBuy(fresh, 6, stock, "xpTonic", 5)), "restocked")
		expect.equal(TurtsRules.canBuy(fresh, 6, stock, "xpTonic", 6), true)
	end,

	-- owner 2026-11-13 "only 1qty per item", 2026-11-17 "turts should only sell 1 quantity" (Wild Ore came 10 at a time)
	["Turts sells one of each thing, and no name says more"] = function()
		for id, offer in Turts.OFFERS do
			expect.equal(offer.count, 1, `{id} sells one`)
			assert(not string.find(offer.name, "x%d"), `{id}'s name says a quantity: {offer.name}`)
		end
	end,

	["every price is at least 1.5x its usual value; the Gold Seal above the most it can pay"] = function()
		expect.equal(Turts.PREMIUM, 1.5)
		for id, offer in Turts.OFFERS do
			assert(TurtsRules.priceOk(offer, Turts.PREMIUM), `{id}: $${offer.price} for a ${offer.value} value`)
			assert(offer.count >= 1 and offer.weight > 0 and offer.name ~= "", `{id} is complete`)
			assert(not string.find(offer.item, "^fragment_"), `{id} sells a boss key fragment`)
			assert(not string.find(offer.item, "^trophy_"), `{id} sells a trophy`)
		end
		local most = 0
		for rarity, steps in Grading.COSTS do
			for grade, step in steps do
				if not (rarity == "Legendary" and grade == "S") then
					most = math.max(most, step.cash)
				end
			end
		end
		assert(Turts.OFFERS.goldSeal.price > most, `the Gold Seal pays up to {most}`)
		-- every boss's weapon material is its own rare offer
		for _, item in Weapons.MATERIALS do
			local offer = Turts.OFFERS[item]
			assert(offer and offer.item == item, `{item} is sold`)
			assert(offer.weight < Turts.OFFERS.epicPack.weight, `{item} is rarer than an Epic Pack`)
		end
	end,

	["a rejoin keeps what you bought; a new restock (or an old Robux roll) resets it"] = function()
		local state = { index = 5, bought = { "vrPack" }, personal = { index = 5, offers = { "goldSeal", "xpTonic", "starShard" } } }
		expect.equal(#TurtsRules.refresh(state, 5).bought, 1, "same restock: still bought")
		expect.equal(TurtsRules.stockFor(state, 5, { "vrPack", "wildOre", "epicPack" })[1], "goldSeal", "your Robux roll")
		local next = TurtsRules.refresh(state, 6)
		expect.equal(#next.bought, 0, "a new restock: nothing bought")
		expect.equal(next.personal, nil, "the Robux roll ends with its restock")
		expect.equal(TurtsRules.stockFor(next, 6, { "vrPack", "wildOre", "epicPack" })[1], "vrPack", "back to everyone's stock")
		expect.equal(next.index, 6)
	end,

	-- every server works his spot out from the restock number alone (a new server has no "last spot"): street corners
	-- and plaza edges take turns, a random one of the group, so he never sets up on the same spot twice in a row
	["every server puts him on the same spot, never the last restock's"] = function()
		local groups: { [string]: number } = {}
		for _, spot in Turts.SPOTS do
			groups[spot.group] = (groups[spot.group] or 0) + 1
		end
		assert((groups.corner or 0) >= 2 and (groups.edge or 0) >= 2, "both groups have a choice")
		local last: number? = nil
		for index = 1000, 1400 do
			local spot = TurtsRules.spotFor(index, Turts.SPOTS, lcg(index))
			expect.equal(spot, TurtsRules.spotFor(index, Turts.SPOTS, lcg(index)), "the same in every server")
			assert(spot ~= last, `the same spot twice in a row at restock {index}`)
			expect.equal(Turts.SPOTS[spot].group, if index % 2 == 0 then "corner" else "edge")
			last = spot
		end
	end,

	["his spots stay clear of walker stops and exits, crosswalks, the plaza's props and the shops"] = function()
		local rug = Turts.RUG_RADIUS
		local points = WalkerRules.townStops(Customers, Town, WORLD :: any)
		for _, exit in WalkerRules.exits(Customers, Town) do
			table.insert(points, exit :: any)
		end
		local roadHalf = WORLD.streetWidth / 2 - Town.LAYOUT.SIDEWALK
		for _, spot in Turts.SPOTS do
			for _, point in points do
				local gap = math.sqrt((spot.x - point.x) ^ 2 + (spot.z - point.z) ^ 2)
				assert(gap >= rug + 2, `{spot.name}: {gap} studs from a walker stop`)
			end
			for _, rect in TownLayout.crosswalks(WORLD :: any, Town) do
				local inside = spot.x > rect.minX - rug and spot.x < rect.maxX + rug and spot.z > rect.minZ - rug and spot.z < rect.maxZ + rug
				assert(not inside, `{spot.name} sits on a crosswalk`)
			end
			for _, footprint in PlazaLayout.footprints(Plaza) do
				local gap = math.sqrt((spot.x - footprint.x) ^ 2 + (spot.z - footprint.z) ^ 2) - footprint.radius
				assert(gap >= rug + 1, `{spot.name}: {gap} studs from the plaza's {footprint.kind}`)
			end
			assert(math.abs(spot.z) <= roadHalf - rug, `{spot.name} is off the road`)
			assert(math.abs(spot.x) <= Town.LAYOUT.STREET_HALF_LENGTH - rug, `{spot.name} is past the street's end`)
			assert(spot.name ~= "", "named for the toast")
		end
	end,

	["his head shakes small and quick"] = function()
		local shake = Turts.SHAKE
		local period = 1 / shake.hz
		local signs: { [number]: boolean } = {}
		for step = 0, 200 do
			local t = step * 0.013
			local angle = TurtsRules.shakeAngle(t, shake)
			assert(math.abs(angle) <= shake.degrees + 1e-9, `{angle} degrees`)
			if t <= period then
				signs[if angle >= 0 then 1 else -1] = true
			end
		end
		assert(signs[1] and signs[-1], "it shakes both ways within one period")
	end,

	-- His chip under the quest strip (owner 2026-11-17: "can a turts store restock timer be put somewhere on the
	-- screen?", look A): gold "Turts restocked!" a short while after a restock you haven't looked at, else the countdown
	["his chip: gold a short while after a restock you haven't seen, else the countdown"] = function()
		local seconds, glow = Turts.RESTOCK_SECONDS, Turts.CHIP.glowSeconds
		local start = 1000 * seconds -- restock 1000 just happened
		local fresh, left = TurtsRules.chip(start + 5, seconds, 999, glow)
		expect.equal(fresh, true, "a new restock since your last look")
		expect.equal(left, seconds - 5, "and the time to the next")
		expect.equal((TurtsRules.chip(start + glow, seconds, 999, glow)), false, "back to the countdown after the glow")
		expect.equal((TurtsRules.chip(start + 5, seconds, 1000, glow)), false, "seen already: no glow")
		expect.equal((TurtsRules.chip(start + 2 * seconds + 5, seconds, 999, glow)), true, "a later restock glows too")
		expect.equal(glow, Turts.BEACON_SECONDS, "as long as his light shines over the rug")
		assert(Turts.CHIP.trailSeconds > 0, "a tap shows the way for a while")
	end,

	-- (a phone shows his chip only while he's just restocked: owner 2026-11-17, "go A"; CompactHud.phonePieces)
	["his chip's words: the countdown, or that he just restocked"] = function()
		expect.equal(TurtsRules.chipText(false, 272), "Turts \u{B7} new stock in 4:32")
		expect.equal(TurtsRules.chipText(false, 5), "Turts \u{B7} new stock in 0:05")
		expect.equal(TurtsRules.chipText(true, 300), "Turts restocked!")
		expect.equal(TurtsRules.clock(480), "8:00")
		expect.equal(TurtsRules.clock(-3), "0:00")
	end,

	-- owner 2026-11-20: "I meant increase the price of the upgrade materials on turts", then "x2 price is a bit harsh.
	-- just x1.3 or 1.4": everything he sells that isn't a pack costs about a third more than it did (at least
	-- UPGRADE_PREMIUM times its usual value); his packs cost what they did
	["Turts' upgrade materials cost about a third more than they did; his packs don't"] = function()
		expect.equal(Turts.UPGRADE_PREMIUM, 2)
		local before = { wildOre = 40, xpTonic = 120, starShard = 300, gradingSeal = 400, goldSeal = 15000 }
		for id, offer in Turts.OFFERS do
			local pack = string.find(id, "Pack", 1, true) ~= nil
			expect.equal(offer.upgrade == true, not pack, `{id}: an upgrade material or a pack`)
			if offer.upgrade then
				assert(offer.price >= offer.value * Turts.UPGRADE_PREMIUM, `{id}: ${offer.price} for a ${offer.value} value`)
				local times = offer.price / (before[id] or 350)
				assert(times >= 1.3 and times <= 1.4, `{id}: {times}x its old price, want 1.3 to 1.4`)
				expect.equal(offer.price % 5, 0, `{id}: a round price`)
			end
		end
		expect.equal(Turts.OFFERS.vrPack.price, 25)
		expect.equal(Turts.OFFERS.epicPack.price, 75)
		expect.equal(Turts.OFFERS.legendaryPack.price, 600)
	end,
}
