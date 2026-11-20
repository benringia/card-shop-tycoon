--!strict
-- A shop can always restock (owner 2026-11-20: "my friend accidentaly spend all his money for packs and could not
-- progress. fix/prevent this kind of scenarios"; Util/BrokeRules, server BrokeService). A shop earns from a rack with
-- packs on it, so until it has a rack it keeps that rack's cost, and while its stock is worth less than a box of
-- packs it keeps the rest of a box's cost: orders, builds, every other spend and opening your own stock are refused
-- when they would eat that. A shop that is stuck anyway (an older save, a path nobody thought of) gets what it lacks
-- from Pish. Plain data, Lune-tested.
return {
	SHELF = "SmallPackRack", -- what a shop sells from (Config/Shelves; the tour's rack)
	PRODUCT = "FirstSparkPack", -- what it sells (Config/Products; the tour's packs)
	-- Pish's help: the shop is looked at every CHECK_SECONDS and helped once it has been stuck CHECKS looks in a row
	-- (cash and stock change hands in steps: a customer carries packs to the register before paying)
	CHECK_SECONDS = 5,
	CHECKS = 2,
	TOP_UP = { title = "Pish helps out!", icon = "🐾", seconds = 7 }, -- his card (Blocked's "info" tone)
	-- %s: dollars (BrokeRules.words)
	WORDS = {
		order = "Build a Pack Rack first! Keep $%s for it.",
		spendNoShelf = "Your shop needs a Pack Rack and packs first. Keep $%s for them!",
		spend = "Your shelves are almost empty! Keep $%s for your next box of packs.",
		take = "Sell these packs first! They pay for your next box ($%s).",
		takeNoShelf = "Keep these packs to sell! Build a Pack Rack for them ($%s).",
		sellShelf = "Your shop needs a rack to sell from. Keep this one!",
		topUp = "You ran out of packs and cash, so Pish gave you $%s. Order a box of packs and sell them!",
		topUpNoShelf = "You were stuck, so Pish gave you $%s. Build a Pack Rack, then sell your packs!",
	},
}
