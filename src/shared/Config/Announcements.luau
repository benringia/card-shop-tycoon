--!strict
-- Server-wide chat announcements for big pulls. See DESIGN.md sections 5.7 and 9.
-- Per rarity: "always" announces every copy, "foil" only foil copies. Missing rarities never announce.
return {
	RULES = {
		Legendary = "always",
		Epic = "foil",
	} :: { [string]: "always" | "foil" },

	FOIL_FORMAT = "%s pulled a FOIL %s!",
	NORMAL_FORMAT = "%s pulled %s!",

	-- Announcements wait until the puller flips the card. If they never do, announce after this long.
	REVEAL_TIMEOUT = 30,
}
