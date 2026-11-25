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
		expect.equal(sharp.line, "Sword hits +12%.")
		expect.equal(sharp.short, "Epic · Sharp · sword hits +12%")
		expect.equal(sharp.yours, "Epic · Sharp (sword hits +12%)")
		expect.equal(sharp.icon, "Sword")
		expect.equal(sharp.group, "offense")
		expect.equal(sharp.rarity, "Epic")
		expect.equal(MutationRules.words(Mutations, m("tough", "Rare")).yours, "Rare · Tough (your HP +5%)", "the mockup's line")
		expect.equal(MutationRules.words(Mutations, m("tough", "Legendary")).line, "Your HP +16%. Second Wind: once a fight, heal 30% when low.")
		expect.equal(MutationRules.words(Mutations, m("petBoost", "Legendary")).line, "Your creatures' ATK and HP +16%. Rally: teammates' creatures +5% ATK.")
		expect.equal(MutationRules.words(Mutations, m("treasure", "Common")).line, "Fight cash +2%.", "Treasure at half")
		expect.equal(MutationRules.words(Mutations, m("guard", "Very Rare")).line, "You take 8% less damage.")
		expect.equal(MutationRules.words(Mutations, m("critical", "Rare")).line, "5% chance a sword hit deals double.")
		for _, entry in Mutations.LIST do
			for _, rarityName in Mutations.RARITIES do
				local words = MutationRules.words(Mutations, m(entry.id, rarityName))
				for _, text in { words.title, words.line, words.short, words.yours } do
					local plain = string.gsub(text, "·", "")
					assert(not string.find(plain, "[^\32-\126]"), `{entry.id} {rarityName}: plain text: {text}`)
					assert(not string.find(string.lower(text), "%f[%a]supers?%f[%A]"), `{entry.id}: ultimates, never supers: {text}`)
				end
				assert(#words.line <= 80, `{entry.id} {rarityName}: one short line ({#words.line})`)
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
		expect.near(MutationRules.stats(Mutations, m("guard", "Rare")).taken, 0.95, 1e-9)
		expect.near(MutationRules.stats(Mutations, m("quickStep", "Epic")).dodge, 0.88, 1e-9)
		expect.near(MutationRules.stats(Mutations, m("critical", "Rare")).crit, 0.05, 1e-9)
		expect.near(MutationRules.stats(Mutations, m("elementEdge", "Common")).strong, 1.03, 1e-9)
		expect.near(MutationRules.stats(Mutations, m("bossHunter", "Very Rare")).boss, 1.08, 1e-9)
		expect.near(MutationRules.stats(Mutations, m("thorns", "Epic")).thorns, 0.12, 1e-9)
		expect.near(MutationRules.stats(Mutations, m("lifesteal", "Rare")).lifesteal, 0.05, 1e-9)
		expect.near(MutationRules.stats(Mutations, m("ultimateCharge", "Epic")).meter, 1.12, 1e-9)
		local pet = MutationRules.stats(Mutations, m("petBoost", "Legendary"))
		expect.near(pet.petAtk, 1.16, 1e-9)
		expect.near(pet.petHp, 1.16, 1e-9)
		expect.near(pet.rally, 0.05, 1e-9, "Legendary's twist")
		expect.equal(MutationRules.stats(Mutations, m("petBoost", "Epic")).rally, 0, "no twist below Legendary")
		local tough = MutationRules.stats(Mutations, m("tough", "Legendary"))
		expect.near(tough.hp, 1.16, 1e-9)
		expect.near(tough.secondWind, 0.3, 1e-9)
		expect.near(MutationRules.stats(Mutations, m("scholar", "Epic")).xp, 1.06, 1e-9, "Scholar at half")
		expect.near(MutationRules.stats(Mutations, m("treasure", "Legendary")).cash, 1.08, 1e-9, "Treasure at half")
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
