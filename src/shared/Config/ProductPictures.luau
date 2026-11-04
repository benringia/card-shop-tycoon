--!strict
-- The pack and deck box pictures in menu rows (Order Stock, Prices; Util/ProductPicture; spec 2026-11-04-round5-design
-- section 6, owner pick A): the real First Spark pack and deck box, rendered big in Studio and cut out
-- (tools/ui-art/cut_product_picture.py; PNGs in assets/ui/product-pictures), uploaded as images. Plain data
-- (Lune-tested: tests/ProductPictureRules).
return {
	AREA = 56, -- px square a picture fits in
	MARGIN = 4, -- px of air on every side inside it
	-- By the product's look (Config/Packs `look`) and kind
	LOOKS = {
		FirstSpark = {
			Pack = "rbxassetid://95761911403820",
			Deck = "rbxassetid://87594315794918",
		},
	},
	-- A look with no picture yet shows the drawn icon (Config/UIIcons)
	FALLBACK = { Pack = "BoosterPack", Deck = "DeckBox" },
}
