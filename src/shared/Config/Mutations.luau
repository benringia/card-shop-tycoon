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
	-- A mutation's number by its rarity, a share (kept by the part 3 boss pass, 2026-11-26: a Legendary Sharp or
	-- Critical adds about 10 points to a 0.8x boss fight); `half` entries (Treasure, Scholar: fights only, owner's
	-- guardrail) take HALF_SIZE, an entry's own `sizes` (Lifesteal, Pet Boost: the sims) take those
	SIZE = { Common = 0.03, Rare = 0.05, ["Very Rare"] = 0.08, Epic = 0.12, Legendary = 0.16 },
	HALF_SIZE = { Common = 0.02, Rare = 0.03, ["Very Rare"] = 0.04, Epic = 0.06, Legendary = 0.08 },
	-- The mutation you don't keep turns into this much Mutation Essence (a Config/Items item)
	ESSENCE_ITEM = "mutationEssence",
	ESSENCE = { Common = 2, Rare = 4, ["Very Rare"] = 8, Epic = 12, Legendary = 20 },
	-- The Forge's Mutate: a new roll on any weapon you have (quest weapons too), for this much Essence
	MUTATE = { essence = 30 },
	CRIT = 2, -- a Critical sword hit's damage x this
	-- A choice left waiting (they left before answering) is asked again this long after the weapons arrive on a join
	ASK_AFTER_JOIN = 8,
	-- The reveal's choice panel (WeaponRevealController, R1 of the owner's mockups 2026-11-26: a CURRENT and a NEW!
	-- card, each with its button in its rarity colour, "You get [Essence] +N" on a drop's): its width (at most, and of
	-- the screen), the gap between the cards, the buttons' height (a phone's keeps the 48 px tap size), text sizes, the
	-- effect line's box (it shrinks to fit), the icons, the tag colours (closeAfter: the stage closes this long after
	-- the pick). A phone drops the top line and puts the tag in the name row.
	CHOICE = {
		width = 520,
		widthShare = 0.92,
		gap = 14,
		button = 52,
		phoneButton = 48,
		text = { top = 15, tag = 11, name = 18, pill = 11, effect = 13, button = 20, gets = 13 },
		phoneText = { tag = 11, name = 15, pill = 11, effect = 12, button = 17, gets = 12 },
		effectHeight = 34,
		phoneEffectHeight = 28,
		icon = 22,
		phoneIcon = 18,
		getsIcon = 20,
		phoneGetsIcon = 16,
		tagColor = { 215, 205, 230 },
		newColor = { 255, 213, 74 },
		effectColor = { 241, 234, 250 },
		closeAfter = 0.4,
	},
	-- Each group's icon (Config/UIIcons white glyphs, so the window tints them in the mutation's rarity colour: the
	-- spec's heart is the Heal glyph, the glossy Heart can't take a tint)
	GROUPS = {
		offense = { name = "Offense", icon = "Sword" },
		defense = { name = "Defense", icon = "Shield" },
		support = { name = "Support", icon = "Heal" },
	},
	-- stat: what it changes (Util/MutationRules Stats; "pet" is the creatures' ATK and HP); how: "more" (x 1 + size),
	-- "less" (x 1 - size), "add" (the size itself: a chance or a share); words: one short line saying exactly what it
	-- changes (owner 2026-11-26: "make this description more specific": damage, max HP, cash...), {n} the size in %;
	-- twist: a Legendary's extra (its stat set to `value`). None copies a weapon's own perk (heal, burn, chill...).
	LIST = {
		{ id = "sharp", name = "Sharp", group = "offense", stat = "sword", how = "more", words = "Your sword deals +{n}% damage" },
		{ id = "critical", name = "Critical", group = "offense", stat = "crit", how = "add", words = "{n}% chance your sword deals double damage" },
		{ id = "elementEdge", name = "Element Edge", group = "offense", stat = "strong", how = "more", words = "Super effective sword hits deal +{n}% damage" },
		{ id = "bossHunter", name = "Boss Hunter", group = "offense", stat = "boss", how = "more", words = "Your sword deals +{n}% damage to bosses" },
		-- The defensive ones protect your creatures too (owner 2026-11-26, option C: on the player alone a Legendary
		-- Thorns added nothing to a boss fight, players who fight well are rarely hit): Tough their HP (BattleService),
		-- Guard and Thorns on their hits, Quick Step a chance to dodge each (BattleSim); Tough's Second Wind stays the
		-- player's. Their own sizes from the part 3 sims (each Legendary about a Legendary Sharp's 4-16 points at 0.8x:
		-- on creatures too, 16% Guard or Tough was about twice that; Thorns needs big shares, the damage creatures take
		-- is small beside a boss's HP)
		{
			id = "tough",
			name = "Tough",
			group = "defense",
			stat = "hp",
			how = "more",
			sizes = { Common = 0.02, Rare = 0.04, ["Very Rare"] = 0.06, Epic = 0.09, Legendary = 0.12 },
			words = "You and your creatures get +{n}% max HP",
			twist = { stat = "secondWind", value = 0.3, words = "Second Wind: below 30% HP, heal 30% once" },
		},
		{
			id = "guard",
			name = "Guard",
			group = "defense",
			stat = "taken",
			how = "less",
			sizes = { Common = 0.02, Rare = 0.04, ["Very Rare"] = 0.06, Epic = 0.09, Legendary = 0.12 },
			words = "You and your creatures take {n}% less damage",
		},
		{
			id = "quickStep",
			name = "Quick Step",
			group = "defense",
			stat = "dodge",
			how = "less",
			sizes = { Common = 0.02, Rare = 0.04, ["Very Rare"] = 0.06, Epic = 0.09, Legendary = 0.12 },
			words = "Your dodge recharges {n}% faster; your creatures dodge {n}% of hits",
		},
		{
			id = "thorns",
			name = "Thorns",
			group = "defense",
			stat = "thorns",
			how = "add",
			sizes = { Common = 0.2, Rare = 0.3, ["Very Rare"] = 0.5, Epic = 0.75, Legendary = 1.0 },
			-- (it reflects: the foe that hit takes this share of the damage it dealt; owner 2026-11-26: "does this mean
			-- REFLECTS back? if yes change the wordings")
			words = "Reflects {n}% of the damage you and your creatures take back at the foe",
		},
		{
			-- a share of the player's own HP for every sword hit that lands (the part 3 boss pass, 2026-11-26: a share of the
			-- hit's damage made a 100 HP player unkillable on late bosses, whose hits are hundreds); a Legendary's 1.6% adds
			-- about what a Legendary Sharp does to a 0.8x fight
			id = "lifesteal",
			name = "Lifesteal",
			group = "support",
			stat = "lifesteal",
			how = "add",
			sizes = { Common = 0.003, Rare = 0.005, ["Very Rare"] = 0.008, Epic = 0.012, Legendary = 0.016 },
			words = "Each sword hit heals you {n}% of your max HP",
		},
		{
			-- its own sizes (the boss sims 2026-11-26: +16% on every creature took the Prism Hydra at 0.8x from 59% to 95%,
			-- half of that added about 17 points to a 0.8x fight against a Legendary Sharp's 10; the creatures do most of a
			-- fight's damage)
			id = "petBoost",
			name = "Pet Boost",
			group = "support",
			stat = "pet",
			how = "more",
			sizes = { Common = 0.01, Rare = 0.02, ["Very Rare"] = 0.03, Epic = 0.04, Legendary = 0.06 },
			words = "Your creatures get +{n}% ATK and max HP",
			twist = { stat = "rally", value = 0.05, words = "Rally: your teammates' creatures get +5% ATK" },
		},
		{ id = "ultimateCharge", name = "Ultimate Charge", group = "support", stat = "meter", how = "more", words = "Your creatures' ultimates charge {n}% faster" },
		{ id = "treasure", name = "Treasure", group = "support", stat = "cash", how = "more", half = true, words = "+{n}% cash from fights you win" },
		{ id = "scholar", name = "Scholar", group = "support", stat = "xp", how = "more", half = true, words = "Your creatures get +{n}% XP from fights" },
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
