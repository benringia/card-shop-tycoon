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
		-- the Frontier Pack (owner 2026-11-23, pick B): its 3D pack in the Frontier look, shot the same way
		-- (assets/ui/product-pictures/FrontierPack.png)
		Frontier = {
			Pack = "rbxassetid://103500260670101",
		},
	},
	-- Products that aren't a pack or deck box, by id (owner 2026-11-20: "also change the Icons and the box icons of the
	-- other products"): the sleeve packets and the sealed booster box, shot in Studio on magenta and cut out the same
	-- way (assets/ui/product-pictures). ProductPictureRules.forProduct picks for menus and the delivery boxes' stickers.
	PRODUCTS = {
		CardSleeves = "rbxassetid://105125617613671", -- assets/ui/product-pictures/CardSleeves.png
		FirstSparkBox = "rbxassetid://133941027127296", -- assets/ui/product-pictures/FirstSparkBox.png
	} :: { [string]: string },
	-- A look with no picture yet shows the drawn icon (Config/UIIcons)
	FALLBACK = { Pack = "BoosterPack", Deck = "DeckBox" },
}
