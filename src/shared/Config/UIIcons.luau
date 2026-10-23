--!strict
-- The game's UI icons (glossy cartoon style), by name. Made as one sheet with Figma's image generator and cut up by
-- tools/ui-icons/slice_icons.py; the PNGs are in assets/ui/icons. HUD tiles, the top bar and customer bubbles
-- use these names; anything not listed here is drawn as text (an emoji). See DESIGN.md 10.6.
return {
	Cash = "rbxassetid://116750244422885",
	Shard = "rbxassetid://122664780125158",
	Level = "rbxassetid://125329144164489",
	Manage = "rbxassetid://110633075550609",
	Cards = "rbxassetid://121767879661951",
	Bag = "rbxassetid://79888737133829",
	Build = "rbxassetid://79914528871070",
	Prices = "rbxassetid://109729489033023",
	Jobs = "rbxassetid://98703496868727",
	Party = "rbxassetid://120351621762495",
	Pack = "rbxassetid://116595282690759",
	Box = "rbxassetid://116113182691700",
	Info = "rbxassetid://119465681061277",
	Angry = "rbxassetid://131956774419815",
	Happy = "rbxassetid://93527923815109",
	Thinking = "rbxassetid://79705134472751",
} :: { [string]: string }
