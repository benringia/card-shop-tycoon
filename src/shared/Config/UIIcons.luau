--!strict
-- The game's UI icons (glossy cartoon style), by name. Made as two sheets with Figma's image generator and cut up
-- by tools/ui-icons/slice_icons.py; the PNGs are in assets/ui/icons. HUD tiles, the top bar and customer bubbles
-- use these names; anything not listed here is drawn as text (an emoji). See DESIGN.md 10.6.
return {
	Cash = "rbxassetid://116750244422885",
	Shard = "rbxassetid://122664780125158",
	Level = "rbxassetid://125329144164489",
	Manage = "rbxassetid://110633075550609",
	Cards = "rbxassetid://121767879661951",
	Bag = "rbxassetid://79888737133829",
	Build = "rbxassetid://79914528871070",
	Prices = "rbxassetid://93124614398604",
	Jobs = "rbxassetid://98703496868727",
	Party = "rbxassetid://120351621762495",
	Pack = "rbxassetid://116595282690759",
	Box = "rbxassetid://116113182691700",
	Info = "rbxassetid://119465681061277",
	Angry = "rbxassetid://131956774419815",
	Happy = "rbxassetid://93527923815109",
	Thinking = "rbxassetid://79705134472751",
	-- Sheet 2
	Shop = "rbxassetid://85054024315305",
	Shelves = "rbxassetid://96926634644875",
	Cases = "rbxassetid://89466168308655",
	Fixtures = "rbxassetid://136391368270947",
	Decor = "rbxassetid://136547921851159",
	Close = "rbxassetid://88925855175878",
	Search = "rbxassetid://101037140246390",
	Odds = "rbxassetid://89837811977131",
	Flip = "rbxassetid://89031795062188",
	Hourglass = "rbxassetid://71035908218047",
	Ember = "rbxassetid://131976712188563",
	Tide = "rbxassetid://91863732626503",
	Bloom = "rbxassetid://133234131972996",
	Volt = "rbxassetid://90302026496319",
	Shade = "rbxassetid://97634629126115",
	Coin = "rbxassetid://127231658719284",
} :: { [string]: string }
