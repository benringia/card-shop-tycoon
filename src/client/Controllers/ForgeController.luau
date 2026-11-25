--!strict
-- The Forge window (weapons round 1, Task 7; owner's pick B 2026-11-06: pick on the left, the weapon big on the
-- right; relaid out 2026-11-08, the owner's pick A): tabs Forge / Upgrade / Reforge with a line saying what the tab
-- does (WeaponText.tabLine); the left lists the weapons for that tab as slim rows, the right shows the chosen one as
-- a picture recipe (owner 2026-11-20: "redesign it like the condenser to be easily understood ... do the same with
-- forge"; Util/Recipe, its words in Util/WeaponText): one sentence ("Use 20 Wild Ore and $1,500 to make the Fire
-- Forge Sword!"), a spot for each material with what you have of what it takes and one for the cash (red when short),
-- an arrow, the weapon's card (Util/WeaponFace; tap it for its stats, WeaponDetailController) with the grade or level
-- it comes out with under it, and one big button: what it does over how long it takes, or what's missing over what
-- you have. The Forge Sword is one row with its five elements as buttons. The server re-checks everything
-- (ForgeService); its result plays the reveal (WeaponRevealController) with this window out of the way. Opened from
-- your own Forge's prompt (BuildController); closes when you walk away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Early = require(Config:WaitForChild("Early"))
local EarlyRules = require(Shared:WaitForChild("Util"):WaitForChild("EarlyRules"))
local CondenseRules = require(Shared:WaitForChild("Util"):WaitForChild("CondenseRules"))
local BabyColors = require(Config:WaitForChild("BabyColors"))
local Bosses = require(Config:WaitForChild("Bosses"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local Combat = require(Config:WaitForChild("Combat"))
local ForgeLayout = require(Config:WaitForChild("ForgeLayout"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Weapons = require(Config:WaitForChild("Weapons"))
local Upgrades = require(Config:WaitForChild("Upgrades"))
local UpgradeRules = require(Shared:WaitForChild("Util"):WaitForChild("UpgradeRules"))
local WeaponLooks = require(Config:WaitForChild("WeaponLooks"))
local WeaponRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponRules"))
local WeaponText = require(Shared:WaitForChild("Util"):WaitForChild("WeaponText"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local JobPanel = require(ClientUtil:WaitForChild("JobPanel"))
local Recipe = require(ClientUtil:WaitForChild("Recipe"))
local WeaponFace = require(ClientUtil:WaitForChild("WeaponFace"))
local UIController = require(Controllers:WaitForChild("UIController"))
local WeaponRevealController = require(Controllers:WaitForChild("WeaponRevealController"))
local WeaponDetailController = require(Controllers:WaitForChild("WeaponDetailController"))

type Owned = WeaponRules.Owned
-- A row in the list: one weapon, or the Forge Sword's five (ids in element order)
type Entry = { key: string, name: string, rarity: string, ids: { string } }

local FORGE, UPGRADE, REFORGE = "Forge", "Upgrade", "Reforge"
local PANEL_MAX_SIZE = Vector2.new(820, 540)
local LIST_WIDTH_SCALE = 0.42
local ROW_HEIGHT = 66
local THUMBNAIL_SIZE = Vector2.new(40, 56)
-- the pane's card on desktops (phones: Config/ForgeLayout CARD): with it a Forge weapon's sentence, element buttons
-- and recipe fit the pane with nothing cut (292 px before the window's own scale; owner 2026-11-20: "fix upgrading
-- stations cutoff borders")
local CARD_SIZE = Vector2.new(84, 120)
local RECIPE = Recipe.LOOK -- the recipe on the right: its arrow and the row under it (Util/Recipe, shared with the other stations)
local ELEMENT_BUTTON = 48 -- tap targets are 48 px or more
local ACTION_HEIGHT = 52
local EDGE = 12
local TOOLBAR_TOP = UIKit.HEADER_HEIGHT + 8
local TAB_LINE_HEIGHT = 34 -- under the tabs (desktops): what the tab does, two lines at most
local TAB_LINE_TOP = TOOLBAR_TOP + BabyColors.SEGMENTED.hit + 6
local LIST_TOP = TAB_LINE_TOP + TAB_LINE_HEIGHT + 4
-- Phones: the tabs sit up in the header band, between the title and the close button
local PHONE_TITLE_ROOM = 150
local PHONE_CLOSE_ROOM = 66
local PHONE_LIST_TOP = UIKit.HEADER_HEIGHT + 8
local USE_DISTANCE = Weapons.FORGE_DISTANCE
local DISTANCE_CHECK_SECONDS = 0.5
local IN_FLIGHT_TIMEOUT = 3 -- a request with no answer (the server said no in a toast) unlocks the button again

local player = Players.LocalPlayer

local ForgeController = {}

local panel: Frame
local palette: UIKit.Palette
local switchHolder: Frame
local tabLine: TextLabel -- what the tab does, under the tabs on desktops (phones: the pane's first line)
local list: ScrollingFrame
local pane: ScrollingFrame
local actionBar: Frame -- under the pane: the one button stays in view on short screens
local setTab: (string) -> () = function() end
local machine: BasePart? = nil
local tab = FORGE
local selectedKey: string? = nil
local selectedElement = "Ember" -- the Forge Sword's element picked
local owned: { [string]: Owned } = {}
local items: { [string]: number } = {}
local inFlight = false
local inFlightToken = 0
local reopenAfterReveal = false
local shown: { weaponId: string, view: string }? = nil -- the pane's weapon and what it drew from the cash
local render: () -> ()
local listToTop = false -- the next render starts the list at its top (a new tab, the window opening)

local ELEMENTS = { "Ember", "Tide", "Bloom", "Volt", "Shade" }

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function cash(): number
	local value = player:GetAttribute("Cash")
	return if typeof(value) == "number" then value else 0
end

local function shopLevel(): number
	local value = player:GetAttribute("Level")
	return if typeof(value) == "number" then value else 1
end

local function rarityOrder(rarity: string): number
	local tier = (Rarities.Tiers :: any)[rarity]
	return if tier then tier.order else 0
end

-- The rows a tab lists: Forge, every built weapon you don't have yet that can be made (each Forge weapon, the Forge
-- Sword and the Forge Spear, as one row while any element is missing; its key `forge<Family>`, its ids' prefix);
-- Upgrade and Reforge, the ones you have (not the Steel Sword)
local function entries(): { Entry }
	local found: { Entry } = {}
	local forgeIds: { [string]: { string } } = {} -- by family
	for _, weapon in Weapons.WEAPONS do
		if not weapon.ready or weapon.id == Weapons.STARTER then
			continue
		end
		local have = owned[weapon.id] ~= nil
		if weapon.source.kind == "forge" then
			if (tab == FORGE) ~= have then
				local ids = forgeIds[weapon.family] or {}
				forgeIds[weapon.family] = ids
				table.insert(ids, weapon.id)
			end
		elseif tab == FORGE and not have and WeaponRules.makeCost(Weapons, weapon.id) then
			table.insert(found, { key = weapon.id, name = weapon.name, rarity = weapon.rarity, ids = { weapon.id } })
		elseif tab ~= FORGE and have then
			table.insert(found, { key = weapon.id, name = weapon.name, rarity = weapon.rarity, ids = { weapon.id } })
		end
	end
	for family, ids in forgeIds do
		if tab == FORGE then
			local title = string.upper(string.sub(family, 1, 1)) .. string.sub(family, 2)
			table.insert(found, { key = `forge{title}`, name = `Forge {title}`, rarity = "Common", ids = ids })
		else
			for _, id in ids do
				local weapon = Weapons.ById[id]
				table.insert(found, { key = id, name = weapon.name, rarity = weapon.rarity, ids = { id } })
			end
		end
	end
	table.sort(found, function(a, b)
		if rarityOrder(a.rarity) ~= rarityOrder(b.rarity) then
			return rarityOrder(a.rarity) < rarityOrder(b.rarity)
		end
		return a.name < b.name
	end)
	return found
end

-- The weapon an entry stands for now (a Forge weapon's row: the element picked, if it's one still listed)
local function weaponOf(entry: Entry): string
	if #entry.ids == 1 then
		return entry.ids[1]
	end
	local wanted = `{entry.key}_{selectedElement}`
	return if table.find(entry.ids, wanted) then wanted else entry.ids[1]
end

local function costFor(weaponId: string): WeaponRules.Cost?
	if tab == FORGE then
		return WeaponRules.makeCost(Weapons, weaponId, owned) -- a first Forge weapon is cheap (Weapons.FIRST_FORGE)
	elseif tab == REFORGE then
		return WeaponRules.reforgeCost(Weapons, weaponId)
	end
	local record = owned[weaponId]
	return if record then WeaponRules.upgradeCost(Weapons, weaponId, record.level + 1) else nil
end

local function actionOf(): "forge" | "upgrade" | "reforge"
	return if tab == FORGE then "forge" elseif tab == UPGRADE then "upgrade" else "reforge"
end

-- What the recipe's words need to know about this weapon (WeaponText.say, recipeButton)
local function optsFor(weapon: Weapons.Weapon, record: Owned?): WeaponText.RecipeOpts
	-- how long the job takes, on the button (owner 2026-11-20: the waits run to an hour and were only seen after)
	local seconds = if tab == FORGE then UpgradeRules.seconds(Upgrades, "craft", nil, weapon.rarity)
		elseif tab == REFORGE then UpgradeRules.seconds(Upgrades, "reforge", nil, weapon.rarity)
		else UpgradeRules.seconds(Upgrades, "level", if record then record.level + 1 else 1, weapon.rarity)
	return {
		name = weapon.name,
		wait = CondenseRules.waitWords(EarlyRules.stationWait(seconds, shopLevel(), Early)),
		level = if record then record.level + 1 else nil,
		unlockLevel = if weapon.source.cost then weapon.source.cost.unlockLevel else nil,
		shopLevel = shopLevel(),
		done = tab == REFORGE and record ~= nil and not WeaponRules.canReforge(record),
	}
end

-- The one button for this tab: what it does over how long it takes, else what's missing over what you have
local function buttonFor(weapon: Weapons.Weapon, record: Owned?, cost: WeaponRules.Cost?): (string, string?, boolean)
	return WeaponText.recipeButton(actionOf(), cost, items, cash(), Items, optsFor(weapon, record))
end

-- What a weapon's pane draws from the cash (its spots' colours, its sentence and its button): a cash change redraws
-- the window only when this changes (in a staffed shop sales land every few seconds; a redraw then could swallow a tap)
local function cashView(weaponId: string): string
	local weapon = Weapons.ById[weaponId]
	local cost = costFor(weaponId)
	if not weapon then
		return ""
	end
	local parts = {}
	if cost then
		for _, spot in WeaponText.spots(cost, items, cash(), Items) do
			table.insert(parts, if spot.enough then "1" else "0")
		end
	end
	local text, sub, ready = buttonFor(weapon, owned[weaponId], cost)
	table.insert(parts, text)
	table.insert(parts, sub or "")
	table.insert(parts, tostring(ready))
	return table.concat(parts, "|")
end

local function addLabel(parent: Instance, text: string, font: Enum.Font, size: number, color: Color3, order: number?): TextLabel
	local label = UIKit.label(parent, text, font, size, color)
	label.TextWrapped = true
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.new(1, 0, 0, size + 4)
	if order then
		label.LayoutOrder = order
	end
	return label
end

local function buildRow(entry: Entry, order: number)
	local weaponId = weaponOf(entry)
	local record = owned[weaponId]
	local row = Instance.new("TextButton")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = palette.row
	row.Text = ""
	row.Parent = list
	UIKit.corner(row, 12)
	local selected = entry.key == selectedKey
	UIKit.outline(row, if selected then UIKit.Colors.Accent else palette.rowEdge, if selected then 3 else 2)
	local thumbnail = Instance.new("Frame")
	thumbnail.Position = UDim2.fromOffset(8, 5)
	thumbnail.Size = UDim2.fromOffset(THUMBNAIL_SIZE.X, THUMBNAIL_SIZE.Y)
	thumbnail.BackgroundTransparency = 1
	thumbnail.Parent = row
	-- The Forge tab shows what it will look like (Grade C, +0); the others, yours
	WeaponFace.render(thumbnail, nil, weaponId, record or { grade = "C", level = 0 }, nil)
	local textX = THUMBNAIL_SIZE.X + 18
	local name = UIKit.label(row, entry.name, Enum.Font.FredokaOne, 16, palette.ink)
	name.Position = UDim2.fromOffset(textX, 8)
	name.Size = UDim2.new(1, -(textX + 10), 0, 20)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local sub = if tab == FORGE then `{entry.rarity} · {WeaponText.source(Weapons, Bosses, weaponId)}`
		elseif record then `{entry.rarity} · Grade {record.grade} · +{record.level}`
		else entry.rarity
	local line = UIKit.label(row, sub, Enum.Font.GothamBold, 12, palette.inkSoft)
	line.Position = UDim2.fromOffset(textX, 30)
	line.Size = UDim2.new(1, -(textX + 10), 0, 30)
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.TextWrapped = true
	row.Activated:Connect(function()
		selectedKey = entry.key
		render()
	end)
end

-- A Forge weapon's element buttons: an emoji each, the picked one ringed, the ones you have greyed out
local function elementButtons(parent: Instance, entry: Entry, order: number)
	local holder = Instance.new("Frame")
	holder.Name = "Elements"
	holder.LayoutOrder = order
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, ELEMENT_BUTTON + 4)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Wraps = true -- a second row on a narrow phone
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	for index, element in ELEMENTS do
		local id = `{entry.key}_{element}`
		local open = table.find(entry.ids, id) ~= nil
		local look = WeaponLooks.BY_ELEMENT[element]
		local button = UIKit.button(holder, CardDesign.EMOJI[element] or element, if open then Color3.fromRGB(look.glow[1], look.glow[2], look.glow[3]) else UIKit.Colors.Locked)
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(ELEMENT_BUTTON, ELEMENT_BUTTON)
		button.TextSize = 22
		button.AutoButtonColor = open
		-- The picked one stands out bigger; the others keep the 48 px tap size
		local scale = Instance.new("UIScale")
		scale.Scale = if weaponOf(entry) == id then 1.12 else 1
		scale.Parent = button
		button.Activated:Connect(function()
			if open then
				selectedElement = element
				render()
			end
		end)
	end
end

-- The recipe: a spot for each thing it takes (what you have of what it takes; red when short), an arrow, the weapon's
-- card (tap it for its stats) and under it the grade or level it comes out with (`pill`; nil on a short phone pane
-- with element buttons). Returns the spots and the card, for the fly-in
local function recipeRow(order: number, weaponId: string, record: Owned?, cost: WeaponRules.Cost?, cardSize: Vector2, phone: boolean, pill: string?, beats: boolean): ({ GuiObject }, Frame)
	local data = if cost then WeaponText.spots(cost, items, cash(), Items) else {}
	local need = #data
	local look = ForgeLayout.SLOTS
	local slots = Vector2.zero
	if need > 0 then
		-- as wide as the pane leaves beside the arrow and the card (the window's own scale taken out)
		local scaler = panel:FindFirstChildOfClass("UIScale")
		local scale = if scaler and scaler.Scale > 0 then scaler.Scale else 1
		local room = pane.AbsoluteSize.X / scale - 2 * EDGE - 8 - RECIPE.arrow - cardSize.X
		slots = Vector2.new(math.clamp(room, look.min, if phone then look.phoneMax else look.max), cardSize.Y)
	end
	local under = if not pill then 0 elseif phone then ForgeLayout.UNDER else RECIPE.under
	local row = Instance.new("Frame")
	row.Name = "Recipe"
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(slots.X + (if need > 0 then RECIPE.arrow else 0) + cardSize.X, cardSize.Y + under)
	row.Parent = pane
	local card = Instance.new("Frame")
	card.Name = "Keeps"
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.fromScale(1, 0)
	card.Size = UDim2.fromOffset(cardSize.X, cardSize.Y)
	card.BackgroundTransparency = 1
	card.Parent = row
	-- The Forge tab shows what it will look like (Grade C, +0); the others, yours
	WeaponFace.render(card, nil, weaponId, record or (if tab == FORGE then { grade = "C", level = 0 } else nil), nil)
	local openCard = Instance.new("TextButton")
	openCard.Name = "OpenCard"
	openCard.Text = ""
	openCard.BackgroundTransparency = 1
	openCard.Size = UDim2.fromScale(1, 1)
	openCard.ZIndex = card.ZIndex + 10
	openCard.Parent = card
	openCard.Activated:Connect(function()
		WeaponDetailController.Open(weaponId)
	end)
	if pill then
		local tag = UIKit.pill(row, pill, UIKit.Colors.Accent, UIKit.Colors.Ink)
		tag.Name = "Becomes"
		tag.AnchorPoint = Vector2.new(0.5, 0)
		tag.Position = UDim2.new(1, -cardSize.X / 2, 0, cardSize.Y + 4)
		if beats then
			Recipe.beat(tag)
		end
	end
	local spots: { GuiObject } = {}
	if need > 0 then
		local grid = Recipe.grid(row, need, if phone then need else WeaponText.spotColumns(need), slots, if phone then cardSize.Y else look.tall)
		for index, spot in data do
			table.insert(spots, Recipe.spot(grid, "copy", { order = index, palette = palette, icon = if spot.icon ~= "" then spot.icon else nil, count = spot.count, short = not spot.enough }))
		end
		Recipe.arrow(row, slots.X + RECIPE.arrow / 2, cardSize.Y / 2)
	end
	return spots, card
end

local function renderPane(entry: Entry?)
	clear(pane)
	clear(actionBar)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = pane
	local phone = UIKit.isPhone()
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, EDGE)
	padding.PaddingRight = UDim.new(0, EDGE)
	padding.Parent = pane
	if not entry then
		shown = nil
		local message = if tab == FORGE then "You have every weapon you can make. Upgrade them!"
			else "No weapons yet. Forge one, or win one from a boss."
		addLabel(pane, message, Enum.Font.GothamBold, 15, palette.inkSoft, 1)
		return
	end
	local weaponId = weaponOf(entry)
	local weapon = Weapons.ById[weaponId]
	local record = owned[weaponId]
	local cost = costFor(weaponId)
	local action = actionOf()
	local opts = optsFor(weapon, record)

	local hasElements = tab == FORGE and (#entry.ids > 1 or weapon.source.kind == "forge")
	local done = opts.done == true -- a reforge with nothing to pay for
	local maxed = tab == UPGRADE and cost == nil
	local cardSize = if phone then Vector2.new(ForgeLayout.CARD.w, ForgeLayout.CARD.h) else CARD_SIZE
	local text, sub, ready = buttonFor(weapon, record, cost)

	-- One sentence: what goes in and what comes out, or what to get first. A Forge weapon on a phone: under its
	-- element buttons and its recipe (a short pane: Config/ForgeLayout)
	local say = addLabel(pane, WeaponText.say(action, cost, items, cash(), Items, opts), Enum.Font.FredokaOne, if phone then 13 else 16, palette.ink, if phone and hasElements then 6 else 1)
	say.Name = "Say"
	say.TextXAlignment = Enum.TextXAlignment.Center
	if tab == FORGE and weapon.source.kind == "forge" and WeaponRules.firstForge(Weapons, owned) then
		-- the first Forge weapon's one-time price, said out loud (Weapons.FIRST_FORGE)
		local special = addLabel(pane, Weapons.FIRST_FORGE.line, Enum.Font.FredokaOne, if phone then 12 else 14, palette.good, if phone and hasElements then 7 else 2)
		special.TextXAlignment = Enum.TextXAlignment.Center
	end
	-- a Forge weapon's element first
	if hasElements then
		elementButtons(pane, entry, 3)
		if not phone then
			local pick = addLabel(pane, "Pick its element: it bonds with creatures of that element.", Enum.Font.GothamBold, 12, palette.hint, 4)
			pick.TextXAlignment = Enum.TextXAlignment.Center
		end
	end

	-- The recipe, and under the weapon what it comes out with
	local pill, line = WeaponText.outcome(action, {
		level = if maxed and record then record.level elseif record then record.level + 1 else nil,
		step = if record and not maxed then WeaponText.ladderStep(WeaponLooks, record.level + 1, weapon.rarity) else nil,
		max = maxed,
		grade = if record then record.grade else nil,
		done = done,
	})
	local spots, card = recipeRow(5, weaponId, record, if done then nil else cost, cardSize, phone, if phone and hasElements then nil else pill, action == "upgrade" and not maxed)
	if action == "upgrade" and record then
		-- how much stronger it gets (fully upgraded: its Attack)
		local now = WeaponRules.shownPower(Weapons, Combat, weaponId, record.grade, record.level)
		local words = if maxed then WeaponText.attackLine(now) else WeaponText.powerGain(now, WeaponRules.shownPower(Weapons, Combat, weaponId, record.grade, record.level + 1))
		local chip = UIKit.pill(pane, words, palette.good, Color3.new(1, 1, 1))
		chip.Name = "Power"
		chip.LayoutOrder = 8
	end
	if line and not hasElements then -- a Forge weapon's element line says its piece; the pill says the grade
		local outcome = addLabel(pane, line, Enum.Font.GothamBold, 12, palette.hint, 9)
		outcome.Name = "Outcome"
		outcome.TextXAlignment = Enum.TextXAlignment.Center
	end
	-- Phones: what the tab does last, under the fold if need be
	if phone then
		addLabel(pane, WeaponText.tabLine(tab), Enum.Font.GothamBold, 12, palette.hint, 20)
	end

	-- The one button
	shown = { weaponId = weaponId, view = cashView(weaponId) }
	local canPress = ready and not inFlight
	local button = UIKit.button(actionBar, text, if canPress then UIKit.Colors.Accent else UIKit.Colors.Locked)
	button.Name = "Go"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.5)
	button.Size = UDim2.new(1, -2 * EDGE, 0, ACTION_HEIGHT)
	button.AutoButtonColor = canPress
	if inFlight then
		Recipe.words(button, "Working...", nil)
	else
		Recipe.words(button, text, sub)
	end
	button.Activated:Connect(function()
		local part = machine
		if not canPress or inFlight or not part then
			return
		end
		Recipe.flyIn(panel, spots, card)
		inFlight = true
		inFlightToken += 1
		local token = inFlightToken
		task.delay(IN_FLIGHT_TIMEOUT, function()
			if token == inFlightToken and inFlight then
				inFlight = false
				render()
			end
		end)
		local remote = if tab == FORGE then Remotes.ForgeWeapon elseif tab == UPGRADE then Remotes.UpgradeWeapon else Remotes.ReforgeWeapon
		remote:FireServer(part:GetAttribute("ShelfUid"), weaponId)
		render()
	end)
end

render = function()
	if not panel.Visible then
		return
	end
	-- the list stays where the player scrolled it (the Condenser's fix, owner 2026-11-20: a tap on a row rebuilt the
	-- rows and the list snapped to its top)
	local listAt = if listToTop then Vector2.zero else list.CanvasPosition
	listToTop = false
	clear(list)
	setTab(tab)
	tabLine.Text = WeaponText.tabLine(tab)
	local found = entries()
	local selected: Entry? = nil
	for _, entry in found do
		if entry.key == selectedKey then
			selected = entry
		end
	end
	selected = selected or found[1]
	selectedKey = if selected then selected.key else nil
	for order, entry in found do
		buildRow(entry, order)
	end
	list.CanvasPosition = listAt
	game:GetService("RunService").Heartbeat:Once(function() -- and once the rebuilt rows are laid out
		if list.Parent then
			list.CanvasPosition = listAt
		end
	end)
	if #found == 0 then
		local empty = UIKit.label(list, if tab == FORGE then "Nothing left to forge." else "No weapons yet.", Enum.Font.GothamBold, 15, palette.inkSoft)
		empty.Size = UDim2.new(1, -10, 0, 40)
	end
	renderPane(selected)
end

local function close()
	panel.Visible = false
	machine = nil
end

-- Finished Forge jobs whose reveal waits for the Forge to be open (owner 2026-11-12: "the cinematic should only appear
-- when I open forge")
local pending: { any } = {}

-- The waiting reveals now: the window steps aside, they play, it comes back
local function playReveals()
	if #pending == 0 or not panel.Visible then
		return
	end
	local queue = pending
	pending = {}
	player:SetAttribute("ForgeDone", nil) -- the "Ready!" over the Forge goes (StationTimerController)
	reopenAfterReveal = true -- before hiding: the Visible handler keeps the machine for the reopen
	panel.Visible = false
	for _, result in queue do
		WeaponRevealController.Forge(result)
	end
	task.spawn(function()
		task.wait(0.5)
		while WeaponRevealController.IsPlaying() do
			task.wait(0.25)
		end
		local part = machine
		if reopenAfterReveal and part and part:IsDescendantOf(workspace) then
			reopenAfterReveal = false
			panel.Visible = true
			render()
		end
	end)
end

-- Opens the window for your own Forge
-- Desktops: the tabs under the header. Phones (short screens): nearly the whole screen, the tabs up in the header
-- band, so the weapon, its cost and its button keep the room.
local function layout()
	local phone = UIKit.isPhone()
	panel.Size = if phone then UDim2.fromScale(0.97, 0.96) else UDim2.fromScale(0.94, 0.86)
	local listTop = if phone then PHONE_LIST_TOP else LIST_TOP
	if phone then
		switchHolder.Position = UDim2.fromOffset(PHONE_TITLE_ROOM, (UIKit.HEADER_HEIGHT - BabyColors.SEGMENTED.hit) / 2)
		switchHolder.Size = UDim2.new(1, -(PHONE_TITLE_ROOM + PHONE_CLOSE_ROOM), 0, BabyColors.SEGMENTED.hit)
	else
		switchHolder.Position = UDim2.fromOffset(16, TOOLBAR_TOP)
		switchHolder.Size = UDim2.new(1, -32, 0, BabyColors.SEGMENTED.hit)
	end
	tabLine.Visible = not phone -- phones: the pane's first line
	tabLine.Position = UDim2.fromOffset(16, TAB_LINE_TOP)
	tabLine.Size = UDim2.new(1, -32, 0, TAB_LINE_HEIGHT)
	list.Position = UDim2.fromOffset(12, listTop)
	list.Size = UDim2.new(LIST_WIDTH_SCALE, -18, 1, -(listTop + 12))
	pane.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 0, listTop)
	pane.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 1, -(listTop + 12 + ACTION_HEIGHT + 16))
end

function ForgeController.Open(part: BasePart)
	machine = part
	inFlight = false
	listToTop = true
	layout()
	panel.Visible = true
	Remotes.WeaponsChanged:FireServer() -- the latest weapons (rate-limited on the server)
	render()
	task.defer(playReveals) -- a job that finished while the Forge was closed
end

-- Closes once the owner walks away or the machine is moved or sold
local function watchDistance()
	while true do
		task.wait(DISTANCE_CHECK_SECONDS)
		local part = machine
		if part and panel.Visible then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not part:IsDescendantOf(workspace) or not root or (root.Position - part.Position).Magnitude > USE_DISTANCE then
				close()
			end
		end
	end
end

-- A result: the window steps aside for the reveal and comes back after it while you're still at the Forge
local function onResult(result: any)
	inFlight = false
	if typeof(result) ~= "table" then
		return
	end
	-- a job started (spec 2026-11-12-timed-upgrades-revive-design): the window stays, its job card shows (Util/JobPanel)
	if typeof(result.waiting) == "number" then
		render()
		return
	end
	if result.finished ~= true then
		return
	end
	-- a job done: its reveal now if the Forge is open, else a toast and the reveal when it opens
	table.insert(pending, result)
	if panel.Visible then
		playReveals()
		return
	end
	player:SetAttribute("ForgeDone", true) -- "Ready!" over the Forge until it's opened (a local attribute: this client's)
	local weapon = Weapons.ById[result.weaponId]
	local name = if weapon then weapon.name else "weapon"
	UIController.Notify((string.gsub(Upgrades.FORGE_READY, "{name}", name)), false)
end

function ForgeController.Start()
	local screenGui = UIController.GetScreenGui()
	panel, list = UIKit.panel(screenGui, "Forge", "⚒️ Forge")
	JobPanel.attach(panel, "forge") -- a job inside: its card over the actions (spec 2026-11-12-timed-upgrades-revive-design)
	palette = UIKit.colorsFor(panel)
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = PANEL_MAX_SIZE
	end
	switchHolder = Instance.new("Frame")
	switchHolder.Name = "Tabs"
	switchHolder.BackgroundTransparency = 1
	switchHolder.ZIndex = panel.ZIndex + 3 -- over the header band and its title on phones
	switchHolder.Parent = panel
	local _, pick = UIKit.segmented(switchHolder, { FORGE, UPGRADE, REFORGE }, function(value)
		tab = value
		selectedKey = nil
		listToTop = true
		render()
	end)
	setTab = pick
	tabLine = UIKit.label(panel, "", Enum.Font.GothamBold, 13, palette.hint)
	tabLine.Name = "TabLine"
	tabLine.TextWrapped = true
	tabLine.TextYAlignment = Enum.TextYAlignment.Top

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingLeft = UDim.new(0, 6)
	listPadding.PaddingRight = UDim.new(0, EDGE + 6)
	listPadding.PaddingTop = UDim.new(0, 6)
	listPadding.PaddingBottom = UDim.new(0, 6)
	listPadding.Parent = list

	pane = Instance.new("ScrollingFrame")
	pane.Name = "Details"
	pane.BackgroundColor3 = palette.slotEmpty
	pane.BorderSizePixel = 0
	pane.ScrollBarThickness = 4
	pane.CanvasSize = UDim2.new()
	pane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pane.Parent = panel
	UIKit.corner(pane, 12)
	actionBar = Instance.new("Frame")
	actionBar.Name = "Action"
	actionBar.BackgroundTransparency = 1
	actionBar.AnchorPoint = Vector2.new(0, 1)
	actionBar.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 1, -8)
	actionBar.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 0, ACTION_HEIGHT + 8)
	actionBar.Parent = panel

	Remotes.WeaponsChanged.OnClientEvent:Connect(function(state: unknown)
		if typeof(state) == "table" and typeof((state :: any).owned) == "table" then
			owned = (state :: any).owned
			render()
		end
	end)
	Remotes.ItemsChanged.OnClientEvent:Connect(function(newItems: unknown)
		if typeof(newItems) == "table" then
			items = newItems :: any
			render()
		end
	end)
	Remotes.RequestItems:FireServer() -- our own copy of the Bag's counts, whatever order the controllers start in
	Remotes.ForgeResult.OnClientEvent:Connect(onResult)
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		local current = shown
		if panel.Visible and current and cashView(current.weaponId) ~= current.view then
			render()
		end
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible and not reopenAfterReveal then
			machine = nil
		end
	end)
	task.spawn(watchDistance)
end

return ForgeController
