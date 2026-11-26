--!strict
-- Weapon mutations (weapons round 4 part 2, spec 2026-11-25-weapons-round4-design; owner 2026-11-25: "every weapon
-- should have a chance for a mutation (common to legendary)", grouped "Offensive / Defensive / supportive"): the roll,
-- the words a child reads, what each does in a fight, the Essence for the one you don't keep, the Forge's Mutate
local MutationRules = require("../src/shared/Util/MutationRules")
local Mutations = require("../src/shared/Config/Mutations")
local Weapons = require("../src/shared/Config/Weapons")
local expect = require("./lib/expect")

local function m(id: string, rarity: string): MutationRules.Mutation
	return { id = id, rarity = rarity }
end

return {
	["a roll's rarity follows the odds and its kind the list"] = function()
		local function rarity(roll: number): string
			return MutationRules.roll(Mutations, roll, 0).rarity
		end
		expect.equal(rarity(0), "Common")
		expect.equal(rarity(0.44), "Common")
		expect.equal(rarity(0.46), "Rare")
		expect.equal(rarity(0.76), "Very Rare")
		expect.equal(rarity(0.91), "Epic")
		expect.equal(rarity(0.99), "Legendary")
		expect.equal(MutationRules.roll(Mutations, 0.5, 0).id, "sharp", "the first in the list")
		expect.equal(MutationRules.roll(Mutations, 0.5, 0.999).id, "scholar", "the last")
		local total = 0
		for _, rarityName in Mutations.RARITIES do
			total += Mutations.ODDS[rarityName]
		end
		expect.near(total, 1, 1e-9, "the odds add up")
		assert(Mutations.ODDS.Legendary < Mutations.ODDS.Epic and Mutations.ODDS.Epic < Mutations.ODDS.Common, "rarer is rarer")
	end,

	["three groups, thirteen mutations, each with its group's icon"] = function()
		local count = { offense = 0, defense = 0, support = 0 }
		for _, entry in Mutations.LIST do
			count[entry.group] += 1
		end
		expect.equal(count.offense, 4)
		expect.equal(count.defense, 4)
		expect.equal(count.support, 5)
		expect.equal(Mutations.GROUPS.offense.icon, "Sword")
		expect.equal(Mutations.GROUPS.defense.icon, "Shield")
		expect.equal(Mutations.GROUPS.support.icon, "Heal", "the heart glyph: white, so it takes the rarity colour")
	end,

	["every mutation has words a child reads"] = function()
		local sharp = MutationRules.words(Mutations, m("sharp", "Epic"))
		expect.equal(sharp.name, "Sharp")
		expect.equal(sharp.title, "Sharp · Epic mutation")
		expect.equal(sharp.line, "Your sword deals +12% damage.")
		expect.equal(sharp.short, "Epic · Sharp · your sword deals +12% damage")
		expect.equal(sharp.yours, "Epic · Sharp (your sword deals +12% damage)")
		expect.equal(sharp.icon, "Sword")
		expect.equal(sharp.group, "offense")
		expect.equal(sharp.rarity, "Epic")
		expect.equal(MutationRules.words(Mutations, m("tough", "Rare")).yours, "Rare · Tough (you and your creatures get +4% max HP)", "the mockup's line, creatures too (option C)")
		expect.equal(MutationRules.words(Mutations, m("tough", "Legendary")).line, "You and your creatures get +12% max HP. Second Wind: below 30% HP, heal 30% once.")
		expect.equal(MutationRules.words(Mutations, m("petBoost", "Legendary")).line, "Your creatures get +6% ATK and max HP. Rally: your teammates' creatures get +5% ATK.")
		-- the part 3 boss pass (2026-11-26): Lifesteal heals a share of your own HP a landed sword hit, small numbers with
		-- one decimal
		expect.equal(MutationRules.words(Mutations, m("lifesteal", "Common")).line, "Each sword hit heals you 0.3% of your max HP.")
		expect.equal(MutationRules.words(Mutations, m("lifesteal", "Legendary")).line, "Each sword hit heals you 1.6% of your max HP.")
		expect.equal(MutationRules.words(Mutations, m("treasure", "Common")).line, "+2% cash from fights you win.", "Treasure at half")
		-- the defensive ones protect your creatures too (owner 2026-11-26, option C)
		expect.equal(MutationRules.words(Mutations, m("guard", "Very Rare")).line, "You and your creatures take 6% less damage.")
		expect.equal(MutationRules.words(Mutations, m("thorns", "Rare")).line, "Reflects 30% of the damage you and your creatures take back at the foe.")
		expect.equal(MutationRules.words(Mutations, m("quickStep", "Epic")).line, "Your dodge recharges 9% faster; your creatures dodge 9% of hits.")
		expect.equal(MutationRules.words(Mutations, m("tough", "Rare")).line, "You and your creatures get +4% max HP.")
		expect.equal(MutationRules.words(Mutations, m("critical", "Rare")).line, "5% chance your sword deals double damage.")
		for _, entry in Mutations.LIST do
			for _, rarityName in Mutations.RARITIES do
				local words = MutationRules.words(Mutations, m(entry.id, rarityName))
				for _, text in { words.title, words.line, words.short, words.yours } do
					local plain = string.gsub(text, "·", "")
					assert(not string.find(plain, "[^\32-\126]"), `{entry.id} {rarityName}: plain text: {text}`)
					-- (Super effective, the element advantage, is its own word: tests/SkillText allows it too)
					local said = string.gsub(string.lower(text), "super effective", "")
					assert(not string.find(said, "%f[%a]supers?%f[%A]"), `{entry.id}: ultimates, never supers: {text}`)
				end
				-- (90 since the words say exactly what they change, owner 2026-11-26: "make this description more specific")
				assert(#words.line <= 90, `{entry.id} {rarityName}: one short line ({#words.line})`)
			end
		end
	end,

	["stats: neutral without a mutation, each stat by its rule"] = function()
		local none = MutationRules.stats(Mutations, nil)
		for _, key in { "sword", "strong", "boss", "hp", "taken", "dodge", "petAtk", "petHp", "meter", "cash", "xp" } do
			expect.equal((none :: any)[key], 1, `{key} x1`)
		end
		for _, key in { "crit", "thorns", "lifesteal", "secondWind", "rally" } do
			expect.equal((none :: any)[key], 0, `{key} none`)
		end
		expect.near(MutationRules.stats(Mutations, m("sharp", "Epic")).sword, 1.12, 1e-9)
		-- the defensive ones by their own sizes since option C (the part 3 sims: on creatures too, 16% was twice a Sharp)
		expect.near(MutationRules.stats(Mutations, m("guard", "Rare")).taken, 0.96, 1e-9)
		expect.near(MutationRules.stats(Mutations, m("quickStep", "Epic")).dodge, 0.91, 1e-9)
		expect.near(MutationRules.stats(Mutations, m("critical", "Rare")).crit, 0.05, 1e-9)
		expect.near(MutationRules.stats(Mutations, m("elementEdge", "Common")).strong, 1.03, 1e-9)
		expect.near(MutationRules.stats(Mutations, m("bossHunter", "Very Rare")).boss, 1.08, 1e-9)
		expect.near(MutationRules.stats(Mutations, m("thorns", "Epic")).thorns, 0.75, 1e-9)
		expect.near(MutationRules.stats(Mutations, m("lifesteal", "Rare")).lifesteal, 0.005, 1e-9, "a share of your HP a hit")
		expect.near(MutationRules.stats(Mutations, m("ultimateCharge", "Epic")).meter, 1.12, 1e-9)
		-- Pet Boost at half size (the boss sim, 2026-11-26: +16% on every creature took the Prism Hydra at 0.8x from 59%
		-- to 95% while a Legendary Sharp gave 61%; the creatures do most of a fight's damage)
		local pet = MutationRules.stats(Mutations, m("petBoost", "Legendary"))
		-- then 1 / 2 / 3 / 4 / 6% (the part 3 boss pass: +8% added about 17 points to a 0.8x fight, a Legendary Sharp 10)
		expect.near(pet.petAtk, 1.06, 1e-9)
		expect.near(pet.petHp, 1.06, 1e-9)
		expect.near(MutationRules.stats(Mutations, m("petBoost", "Common")).petAtk, 1.01, 1e-9)
		expect.near(pet.rally, 0.05, 1e-9, "Legendary's twist")
		expect.equal(MutationRules.stats(Mutations, m("petBoost", "Epic")).rally, 0, "no twist below Legendary")
		local tough = MutationRules.stats(Mutations, m("tough", "Legendary"))
		expect.near(tough.hp, 1.12, 1e-9)
		expect.near(tough.secondWind, 0.3, 1e-9)
		expect.near(MutationRules.stats(Mutations, m("scholar", "Epic")).xp, 1.06, 1e-9, "Scholar at half")
		expect.near(MutationRules.stats(Mutations, m("treasure", "Legendary")).cash, 1.08, 1e-9, "Treasure at half")
	end,

	-- owner 2026-11-26: "player should only get essence in drops. not in the forge mutations"
	-- The mutation audit (owner 2026-11-26): Treasure and Scholar pay by the share of the fight their weapon was in hand,
	-- so switching to a Treasure weapon for the last hit doesn't pay its whole share
	["audit: Treasure and Scholar count the time their weapon was in hand"] = function()
		local treasure = { cash = 1.08, xp = 1 }
		local plain = { cash = 1, xp = 1 }
		local held = MutationRules.holding(0, treasure)
		held = MutationRules.switched(held, 10, plain)
		local cash, xp = MutationRules.averaged(held, 40)
		expect.near(cash, (1.08 * 10 + 1 * 30) / 40, 1e-9, "10 s of 40 with Treasure")
		expect.near(xp, 1, 1e-9)
		local late = MutationRules.switched(MutationRules.holding(0, plain), 39, treasure)
		local lateCash = MutationRules.averaged(late, 40)
		expect.near(lateCash, (1 * 39 + 1.08 * 1) / 40, 1e-9, "switched to it for the last second: a sliver")
		local instant = MutationRules.holding(5, treasure)
		expect.near((MutationRules.averaged(instant, 5)), 1.08, 1e-9, "a fight over at once: the weapon in hand")
		-- a boss's intro: the clock starts when the fight does (held from 10), so the intro never counts for a weapon
		local intro = MutationRules.switched(MutationRules.holding(10, treasure), 4, plain) -- switched during the intro
		expect.near((MutationRules.averaged(intro, 40)), 1, 1e-9, "Treasure held only through the intro: nothing")
		local introLate = MutationRules.switched(MutationRules.holding(10, plain), 4, treasure)
		expect.near((MutationRules.averaged(introLate, 40)), 1.08, 1e-9, "switched to it before the start: the whole fight")
		-- Treasure from the intro (4) to 20, plain to 40: 10 s of the fight's 30 with it, the intro's 6 s never counted
		local twice = MutationRules.switched(MutationRules.switched(MutationRules.holding(10, plain), 4, treasure), 20, plain)
		expect.near((MutationRules.averaged(twice, 40)), (1.08 * 10 + 1 * 20) / 30, 1e-9, "the intro's seconds don't count")
	end,

	["a Forge roll's choice gives no Essence either way, and keeps a plain mutation"] = function()
		local have = m("tough", "Rare")
		local rolled = { id = "sharp", rarity = "Epic", forge = true }
		local kept, essence = MutationRules.resolve(Mutations, have, rolled, true)
		expect.equal(kept and kept.id, "sharp", "Take new")
		expect.equal(essence, 0, "no Essence for the old one")
		expect.isNil(kept and (kept :: any).forge, "the kept one is a plain mutation")
		kept, essence = MutationRules.resolve(Mutations, have, rolled, false)
		expect.equal(kept and kept.id, "tough", "Keep current")
		expect.equal(essence, 0, "no Essence for the rolled one")
		kept, essence = MutationRules.resolve(Mutations, nil, rolled, false)
		expect.equal(kept and kept.id, "sharp", "its first: on at once")
		expect.isNil(kept and (kept :: any).forge, "plain")
		expect.equal(essence, 0)
	end,

	["Essence for the one you don't keep"] = function()
		expect.equal(MutationRules.essence(Mutations, nil), 0)
		expect.equal(MutationRules.essence(Mutations, m("sharp", "Epic")), 12, "the mockup's 12")
		local have, new = m("tough", "Rare"), m("sharp", "Epic")
		local kept, essence = MutationRules.resolve(Mutations, have, new, true)
		expect.equal(kept and kept.id, "sharp", "Take new")
		expect.equal(essence, 4, "the old Rare turns into 4")
		kept, essence = MutationRules.resolve(Mutations, have, new, false)
		expect.equal(kept and kept.id, "tough", "Keep mine")
		expect.equal(essence, 12, "the new Epic turns into 12")
		kept, essence = MutationRules.resolve(Mutations, nil, new, false)
		expect.equal(kept and kept.id, "sharp", "nothing to keep: the new one stays")
		expect.equal(essence, 0)
		for index = 2, #Mutations.RARITIES do
			local before, now = Mutations.RARITIES[index - 1], Mutations.RARITIES[index]
			assert(Mutations.ESSENCE[now] > Mutations.ESSENCE[before], `{now} gives more than {before}`)
		end
	end,

	["a saved mutation is read only when it's known"] = function()
		local read = MutationRules.read(Mutations, { id = "guard", rarity = "Epic", extra = 1 })
		expect.equal(read and read.id, "guard")
		expect.equal(read and read.rarity, "Epic")
		expect.isNil((read :: any).extra, "only its two fields")
		expect.isNil(MutationRules.read(Mutations, { id = "nope", rarity = "Epic" }))
		expect.isNil(MutationRules.read(Mutations, { id = "guard", rarity = "Mythic" }))
		expect.isNil(MutationRules.read(Mutations, "guard"))
		expect.isNil(MutationRules.read(Mutations, nil))
	end,

	["Mutate at the Forge: yours, not the Steel Sword, nothing waiting, enough Essence"] = function()
		local cost = Mutations.MUTATE.essence
		expect.equal(cost, 30)
		local ok, why = MutationRules.canMutate(Mutations, Weapons, Weapons.STARTER, { grade = "C", level = 0 }, 99)
		expect.equal(ok, false)
		expect.equal(why, "The Steel Sword can't mutate.")
		ok, why = MutationRules.canMutate(Mutations, Weapons, "verdantBlade", nil, 99)
		expect.equal(ok, false)
		expect.equal(why, "You don't have this weapon.")
		ok, why = MutationRules.canMutate(Mutations, Weapons, "verdantBlade", { pending = m("guard", "Rare") }, 99)
		expect.equal(ok, false)
		expect.equal(why, "Choose your waiting mutation first.")
		ok, why = MutationRules.canMutate(Mutations, Weapons, "verdantBlade", {}, cost - 1)
		expect.equal(ok, false)
		expect.equal(why, `Need {cost} Mutation Essence.`)
		ok, why = MutationRules.canMutate(Mutations, Weapons, "verdantBlade", { mutation = m("sharp", "Rare") }, cost)
		expect.equal(ok, true)
		expect.isNil(why)
	end,

	["the Essence item is in the Bag's list"] = function()
		local Items = require("../src/shared/Config/Items")
		local item = Items.ITEMS[Mutations.ESSENCE_ITEM]
		assert(item, "Config/Items has Mutation Essence")
		expect.equal(item.name, "Mutation Essence")
	end,
}
