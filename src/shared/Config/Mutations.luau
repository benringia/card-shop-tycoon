--!strict
-- Weapon mutations (weapons round 4 part 2, spec docs/superpowers/specs/2026-11-25-weapons-round4-design.md; owner
-- 2026-11-25: "every weapon should have a chance for a mutation (common to legendary) mutations now add glow on top of
-- the upgrades glow", grouped "Offensive (atk/crit etc) / Defensive (hp/defense etc) / supportive (lifesteals, bonus
-- xp/cash, amplify pets stats)"). One per weapon, saved on its record; only the weapon in your hand counts, never in
-- the arena. A boss's drop of a weapon you have rolls one (Take new or Keep mine; the other turns into Mutation
-- Essence), and the Forge's Mutate spends Essence on a roll. Rules in Util/MutationRules. Plain data (Lune reads it).
return {
	RARITIES = { "Common", "Rare", "Very Rare", "Epic", "Legendary" },
	-- A roll's rarity (they add up to 1)
	ODDS = { Common = 0.45, Rare = 0.30, ["Very Rare"] = 0.15, Epic = 0.08, Legendary = 0.02 },
	-- A mutation's number by its rarity, a share (placeholders until the boss pass's sims, part 3); `half` entries
	-- (Treasure, Scholar: fights only, owner's guardrail) take HALF_SIZE
	SIZE = { Common = 0.03, Rare = 0.05, ["Very Rare"] = 0.08, Epic = 0.12, Legendary = 0.16 },
	HALF_SIZE = { Common = 0.02, Rare = 0.03, ["Very Rare"] = 0.04, Epic = 0.06, Legendary = 0.08 },
	-- The mutation you don't keep turns into this much Mutation Essence (a Config/Items item)
	ESSENCE_ITEM = "mutationEssence",
	ESSENCE = { Common = 2, Rare = 4, ["Very Rare"] = 8, Epic = 12, Legendary = 20 },
	-- The Forge's Mutate: a new roll on any weapon you have (quest weapons too), for this much Essence
	MUTATE = { essence = 30 },
	CRIT = 2, -- a Critical sword hit's damage x this
	GROUPS = {
		offense = { name = "Offense", icon = "Sword" },
		defense = { name = "Defense", icon = "Shield" },
		support = { name = "Support", icon = "Heart" },
	},
	-- stat: what it changes (Util/MutationRules Stats; "pet" is the creatures' ATK and HP); how: "more" (x 1 + size),
	-- "less" (x 1 - size), "add" (the size itself: a chance or a share); words: one short line, {n} the size in %;
	-- twist: a Legendary's extra (its stat set to `value`). None copies a weapon's own perk (heal, burn, chill...).
	LIST = {
		{ id = "sharp", name = "Sharp", group = "offense", stat = "sword", how = "more", words = "Sword hits +{n}%" },
		{ id = "critical", name = "Critical", group = "offense", stat = "crit", how = "add", words = "{n}% chance a sword hit deals double" },
		{ id = "elementEdge", name = "Element Edge", group = "offense", stat = "strong", how = "more", words = "Strong sword hits +{n}%" },
		{ id = "bossHunter", name = "Boss Hunter", group = "offense", stat = "boss", how = "more", words = "Sword hits on bosses +{n}%" },
		{
			id = "tough",
			name = "Tough",
			group = "defense",
			stat = "hp",
			how = "more",
			words = "Your HP +{n}%",
			twist = { stat = "secondWind", value = 0.3, words = "Second Wind: once a fight, heal 30% when low" },
		},
		{ id = "guard", name = "Guard", group = "defense", stat = "taken", how = "less", words = "You take {n}% less damage" },
		{ id = "quickStep", name = "Quick Step", group = "defense", stat = "dodge", how = "less", words = "Dodge ready {n}% sooner" },
		{ id = "thorns", name = "Thorns", group = "defense", stat = "thorns", how = "add", words = "{n}% of the damage you take hits back" },
		{ id = "lifesteal", name = "Lifesteal", group = "support", stat = "lifesteal", how = "add", words = "Heal {n}% of your sword damage" },
		{
			id = "petBoost",
			name = "Pet Boost",
			group = "support",
			stat = "pet",
			how = "more",
			words = "Your creatures' ATK and HP +{n}%",
			twist = { stat = "rally", value = 0.05, words = "Rally: teammates' creatures +5% ATK" },
		},
		{ id = "ultimateCharge", name = "Ultimate Charge", group = "support", stat = "meter", how = "more", words = "Ultimates charge {n}% faster" },
		{ id = "treasure", name = "Treasure", group = "support", stat = "cash", how = "more", half = true, words = "Fight cash +{n}%" },
		{ id = "scholar", name = "Scholar", group = "support", stat = "xp", how = "more", half = true, words = "Creature XP from fights +{n}%" },
	},
	-- (Second Wind heals its share once the player drops under that same share of their HP: BattleSim's hurtPlayer)
	-- The blade's look (owner's mockups: "Epic mutation · pink rim", "Legendary mutation · gold rim and sparkles"): a rim
	-- in the card rarity colour on the weapon model only (a Highlight; Roblox draws up to 31 at once), this transparent
	-- by rarity, over its upgrade glow; Legendary also sparkles
	LOOK = {
		rim = { Common = 0.55, Rare = 0.45, ["Very Rare"] = 0.35, Epic = 0.25, Legendary = 0.15 },
		sparkles = { rate = 6, size = 0.18, lifetime = { 0.5, 0.9 }, speed = { 0.2, 0.6 } },
	},
}
