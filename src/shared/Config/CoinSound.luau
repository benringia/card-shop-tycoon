--!strict
-- The coin sound whenever your cash goes up (owner 2026-11-19: "Add a coin sound effect everytime you earn coin for
-- everything"; client Util/CoinSound, Util/CoinSoundRules): one of OPTIONS, Roblox-licensed Pro Sound Effects (pick by
-- ear with /coinsound <n>, the admin panel's buttons; DEFAULT until then), at VOLUME with its pitch within PITCH, at
-- most once every GAP seconds (a burst of earnings sounds once), DEFER seconds after the rise so a reward that comes
-- with its own moment can hold it first (a monster's knockout poof plays its coins). Plain data (tests/CoinSoundRules).
return {
	OPTIONS = {
		{ id = "rbxassetid://9113849651", name = "Coin Throws 3 (Pro Sound Effects)" },
		{ id = "rbxassetid://9113728756", name = "Cash Register 5 (Pro Sound Effects)" },
		{ id = "rbxassetid://9113850472", name = "Coin Toss Large Metal Flipped 5 (Pro Sound Effects)" },
	},
	DEFAULT = 1, -- the owner's pick by ear (2026-11-19: "coin sound 1")
	VOLUME = 0.4,
	PITCH = { 0.96, 1.08 },
	GAP = 0.18,
	DEFER = 0.12,
	KO_HOLD = 3.4, -- seconds a monster's knockout holds it (its poof's coins jingle instead; Config/MonsterKO)
}
