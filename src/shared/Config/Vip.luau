--!strict
-- VIP's looks (spec 2026-11-28-robux-round-design; the VIP game pass, Config/Monetization PASSES.VIP): looks only, no
-- gameplay. Read by Util/VipRules, VipChatController and TitleController. Plain data.
return {
	-- the gold [VIP] in front of a VIP's chat lines (rich text, TextChatService)
	CHAT = { tag = "[VIP]", color = "#FFD23F" },
	-- the name over a VIP's head: a crown just left of it and the name in a gold gradient (top to bottom); the title row
	-- above stays the player's own (owner pick B)
	NAME = {
		crown = "👑",
		gradient = { { 255, 243, 176 }, { 255, 210, 63 }, { 240, 160, 32 } },
		stroke = { 74, 42, 0 }, -- the name's outline in gold
	},
}
