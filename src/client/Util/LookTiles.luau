--!strict
-- Shop decor's look tiles (spec 2026-11-14-shop-decor-design): the first six tiles of the Shop menu's Decor tab, one per
-- shop look (Config/Decor LOOKS), the size of the Build tiles beside them. Each shows a swatch of the look (its wall
-- and wallpaper above the band, trim and floor), its name and a button: "Using" on the look in use, "Use" on one
-- you own, its price (green, pink when you're short) or the level it unlocks at. Pressing asks the server
-- (Remotes.ShopLook); DecorService says no through the Blocked card. Reads the attributes ShopLook, ShopLooksOwned,
-- Level and Cash. After them the perk looks (Config/Decor PERK_LOOKS; Robux round, spec 2026-11-28-robux-round-design):
-- the VIP Lounge and Sunny Shop, their chip under the name and, until their perk is held (HasVIP, HasStarterPack), a
-- gold "Get VIP" / "Get it" with the live price that opens the pass or the Starter Pack; Sunny Shop is hidden where
-- Roblox restricts paid random items (the Starter Pack holds luck) unless it's already yours.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Decor = require(Shared:WaitForChild("Config"):WaitForChild("Decor"))
local Monetization = require(Shared:WaitForChild("Config"):WaitForChild("Monetization"))
local DecorRules = require(Shared:WaitForChild("Util"):WaitForChild("DecorRules"))
local PaidRandomRules = require(Shared:WaitForChild("Util"):WaitForChild("PaidRandomRules"))
local UnlockRules = require(Shared:WaitForChild("Util"):WaitForChild("UnlockRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UIKit = require((script.Parent :: Instance):WaitForChild("UIKit"))
local Tooltip = require((script.Parent :: Instance):WaitForChild("Tooltip"))
local ProductPrice = require((script.Parent :: Instance):WaitForChild("ProductPrice"))
local RobuxPrice = require((script.Parent :: Instance):WaitForChild("RobuxPrice"))
local ScreenClear = require((script.Parent :: Instance):WaitForChild("ScreenClear"))
local ShopTips = require(Shared:WaitForChild("Util"):WaitForChild("ShopTips"))

local LookTiles = {}

local PICTURE = require(Shared:WaitForChild("Config"):WaitForChild("ShopTiles")).FULL.picture -- like the Build tiles' 3D pictures
local WALLPAPER_TILE = 44 -- pixels a wallpaper repeat on the swatch

type Tile = { look: DecorRules.Look, frame: Frame, button: TextButton }

local player = Players.LocalPlayer

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function attribute(name: string): any
	return player:GetAttribute(name)
end

-- The perks this player holds for the perk looks (MonetizationService's Has<Key> attributes)
local function perks(): DecorRules.Perks
	local held: DecorRules.Perks = {}
	for key in Decor.PERKS do
		held[key] = player:GetAttribute(`Has{key}`) == true
	end
	return held
end

-- A perk look's live price: the pass's, or the one-time product's (UNLOCKS: the Starter Pack); nil while unknown or not
-- made yet
local function perkPrice(perk: string): number?
	if table.find(Monetization.UNLOCKS, perk) then
		local id = Monetization.PRODUCTS[perk] or 0
		return if id ~= 0 then ProductPrice.of(id) else nil
	end
	local id = Monetization.PASSES[perk] or 0
	return if id ~= 0 then ProductPrice.ofPass(id) else nil
end

-- Whether a perk's pass or one-time product is made on Creator Hub (its id isn't 0): until then its button says
-- "Coming soon" (never a buy button that does nothing)
local function perkMade(perk: string): boolean
	if table.find(Monetization.UNLOCKS, perk) then
		return (Monetization.PRODUCTS[perk] or 0) ~= 0
	end
	return (Monetization.PASSES[perk] or 0) ~= 0
end

-- Opens a perk's purchase: the pass, or the one-time product through the server (it checks it's for sale here)
local function buyPerk(perk: string)
	if table.find(Monetization.UNLOCKS, perk) then
		ScreenClear.prompt()
		Remotes.BuyUnlock:FireServer(perk)
		return
	end
	local id = Monetization.PASSES[perk] or 0
	if id ~= 0 then
		ScreenClear.prompt()
		MarketplaceService:PromptGamePassPurchase(player, id)
	end
end

-- The player's decor as the server last told it
local function state(): DecorRules.State
	local look = attribute("ShopLook")
	local owned = attribute("ShopLooksOwned")
	local list = {}
	if typeof(owned) == "string" then
		for id in string.gmatch(owned, "[^,]+") do
			table.insert(list, id)
		end
	end
	return { look = if typeof(look) == "string" then look else Decor.DEFAULT_LOOK, owned = list }
end

local function swatch(parent: GuiObject, look: DecorRules.Look, background: Color3)
	local frame = Instance.new("Frame")
	frame.Name = "Swatch"
	frame.Position = UDim2.fromOffset(8, 8)
	frame.Size = UDim2.new(1, -16, 0, PICTURE)
	frame.BackgroundColor3 = background
	frame.ClipsDescendants = true
	frame.Parent = parent
	UIKit.corner(frame, 10)
	local wall = Instance.new("Frame")
	wall.Name = "Wall"
	wall.Size = UDim2.fromScale(1, 0.62)
	wall.BackgroundColor3 = rgb(look.wall)
	wall.BorderSizePixel = 0
	wall.Parent = frame
	if look.wallpaper ~= "" then
		local paper = Instance.new("ImageLabel")
		paper.Name = "Wallpaper"
		paper.Size = UDim2.fromScale(1, 1)
		paper.BackgroundTransparency = 1
		paper.Image = look.wallpaper
		paper.ScaleType = Enum.ScaleType.Tile
		paper.TileSize = UDim2.fromOffset(WALLPAPER_TILE, WALLPAPER_TILE)
		paper.Parent = wall
	end
	for _, strip in { { "Band", 0.62, 0.12, look.band }, { "Trim", 0.6, 0.03, look.trim }, { "Floor", 0.74, 0.26, look.floor } } do
		local piece = Instance.new("Frame")
		piece.Name = strip[1] :: string
		piece.Position = UDim2.fromScale(0, strip[2] :: number)
		piece.Size = UDim2.fromScale(1, strip[3] :: number)
		piece.BackgroundColor3 = rgb(strip[4] :: { number })
		piece.BorderSizePixel = 0
		piece.Parent = frame
	end
end

local function refresh(tiles: { Tile })
	local current = state()
	local level = attribute("Level")
	local cash = attribute("Cash")
	level = if typeof(level) == "number" then level else 1
	cash = if typeof(cash) == "number" then cash else 0
	local held = perks()
	for _, tile in tiles do
		local look, button = tile.look, tile.button
		local using = current.look == look.id
		local owned = DecorRules.owns(Decor, current, look.id, held)
		if look.perk then
			-- a perk look: "Using" / "Use" while held, else its gold buy button with the live price
			local made = perkMade(look.perk)
			if using or owned then
				RobuxPrice.set(button, if using then "Using" else "Use", nil)
				button.BackgroundColor3 = if using then UIKit.Colors.Accent else UIKit.Colors.Secondary
			elseif not made then
				RobuxPrice.set(button, "Coming soon", nil)
				button.BackgroundColor3 = UIKit.Colors.Locked
			else
				RobuxPrice.set(button, Decor.PERKS[look.perk].buy, perkPrice(look.perk))
				button.BackgroundColor3 = UIKit.Colors.Accent
			end
			button.AutoButtonColor = not using and (owned or made)
			continue
		end
		local locked = not owned and level < look.level
		button.Text = if using then "Using"
			elseif owned then "Use"
			elseif locked then `🔒 Lv {look.level}`
			else string.format("$%d", look.price)
		-- Soft buttons (UIKit): butter on the look in use, sky to switch, mint to buy, pink when short, grey while locked
		button.BackgroundColor3 = if using then UIKit.Colors.Accent
			elseif owned then UIKit.Colors.Secondary
			elseif locked then UIKit.Colors.Locked
			elseif cash < look.price then UIKit.Colors.Danger
			else UIKit.Colors.Success
		button.AutoButtonColor = not using
	end
end

-- The look tiles in `list` (LayoutOrder 1-8: the six cash looks, then the perk looks, before the windows and the
-- Build tiles), kept up to date
function LookTiles.build(list: ScrollingFrame, palette: any): { GuiObject }
	local tiles: { Tile } = {}
	local frames: { GuiObject } = {}
	local looks: { DecorRules.Look } = table.clone(Decor.LOOKS)
	for _, look in Decor.PERK_LOOKS do
		table.insert(looks, look)
	end
	for index, look in looks do
		local frame = Instance.new("Frame")
		frame.Name = "Look" .. look.id
		frame.LayoutOrder = index
		frame.BackgroundColor3 = palette.row
		frame.Parent = list
		UIKit.corner(frame, 14)
		UIKit.outline(frame)
		Tooltip.rich(frame, look.name, ShopTips.look()) -- what a look is (owner 2026-11-17: tooltips in the shop)
		swatch(frame, look, palette.slotEmpty)
		local name = UIKit.label(frame, look.name, Enum.Font.FredokaOne, 17, UIKit.Colors.Text)
		name.Position = UDim2.fromOffset(10, PICTURE + 12)
		name.Size = UDim2.new(1, -20, 0, 22)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextWrapped = false
		local detail = UIKit.label(frame, if look.perk then Decor.PERKS[look.perk].chip else "Shop look", Enum.Font.GothamBold, 13, UIKit.Colors.Subtext)
		detail.Position = UDim2.fromOffset(10, PICTURE + 34)
		detail.Size = UDim2.new(1, -20, 0, 18)
		local button = UIKit.button(frame, "", UIKit.Colors.Success)
		button.AnchorPoint = Vector2.new(0.5, 1)
		button.Position = UDim2.new(0.5, 0, 1, -8)
		button.Size = UDim2.new(1, -16, 0, 48)
		button.Font = Enum.Font.FredokaOne
		button.TextSize = 20
		button.Activated:Connect(function()
			local current = state()
			if current.look == look.id then
				return -- already in use
			end
			if look.perk and not DecorRules.owns(Decor, current, look.id, perks()) then
				buyPerk(look.perk)
				return
			end
			Remotes.ShopLook:FireServer(if DecorRules.owns(Decor, current, look.id, perks()) then "use" else "buy", look.id)
		end)
		-- a chance-based perk's look (Sunny Shop: the Starter Pack holds luck) stays out of the Decor tab (its "Hidden"
		-- attribute, which BuildController's tab switch reads) until Roblox's policy says it's sold here, or it's yours
		if look.perk and UnlockRules.chanceBased(look.perk, Monetization) then
			local perk = look.perk
			local key = `Has{perk}`
			frame:SetAttribute("Hidden", player:GetAttribute(key) ~= true)
			player:GetAttributeChangedSignal(key):Connect(function()
				if player:GetAttribute(key) == true then
					frame:SetAttribute("Hidden", false)
				end
			end)
			task.spawn(function()
				local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
				if not PaidRandomRules.restricted(ok, info) then
					frame:SetAttribute("Hidden", false)
				end
			end)
		end
		table.insert(tiles, { look = look, frame = frame, button = button })
		table.insert(frames, frame)
	end
	local function update()
		refresh(tiles)
	end
	for _, name in { "ShopLook", "ShopLooksOwned", "Level", "Cash", "HasVIP", "HasStarterPack" } do
		player:GetAttributeChangedSignal(name):Connect(update)
	end
	update()
	-- the perk looks' live prices come in a moment after the first draw
	task.delay(2, update)
	task.delay(6, update)
	return frames
end

return LookTiles
