--!strict
-- Codes (owner 2026-11-19: "yes do code box"): a box at the bottom of the phone's Store where a player types a code we
-- posted (the game page, our Discord) for a small gift. Everyone can redeem a code, once each; nothing is tied to
-- joining anything off Roblox (most players are under 13 and can't), and the game never shows a link. CodeService
-- checks and pays on the server (Util/CodeRules); saved as `codes` (the ones used). Plain data: tests/CodeRules.
--   CODES[<CODE>]: capitals and digits only, as CodeRules.normalize makes what's typed. `reward`: cash, items
--     (Config/Items ids) and luck like a gift's (GiftRules.Reward); `ends`: a Unix time it stops working at (none:
--     never). Keep a code here after it ends, so it says "ended" instead of "not one of ours".
--   A small gift, never an economy skip: at most $1,000 and 5 of an item (tested).
-- Adding one: a new entry here, publish, then post it. Removing one never lets it be used twice (the save keeps it).
type Reward = { cash: number?, items: { { item: string, count: number } }?, luck: { strength: string, seconds: number }? }
type Code = { reward: Reward, ends: number? }

local CODES: { [string]: Code } = {
	-- the launch code, on the game page
	ONEMOREPACK = { reward = { cash = 250, items = { { item = "sparkPack", count = 2 } } } },
	-- the community's (our Discord)
	PISHANDCHIKIN = { reward = { items = { { item = "xpTonic", count = 2 } }, luck = { strength = "x2", seconds = 15 * 60 } } },
}

return {
	CODES = CODES,
	MAX_LENGTH = 20, -- of a code; what's typed may be twice that before it's cleaned (spaces, dashes)
	COOLDOWN = 1.5, -- seconds between tries (server)
	-- The box's answers (the result line under it)
	TEXT = {
		ok = "Code redeemed!",
		unknown = "That code isn't one of ours. Check the spelling!",
		used = "You already used that code.",
		expired = "That code has ended.",
		empty = "Type a code first.",
		busy = "Finish your fight first.",
	},
	-- The box (client Util/CodeBox): pixels
	BOX = { height = 132, field = 44, button = 48, hint = "Find codes on our game page and community!" },
}
