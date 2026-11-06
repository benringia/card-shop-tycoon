--!strict
-- The Forge window (weapons round 1, Task 7; owner's pick B 2026-11-06: pick on the left, the weapon big on the
-- right): tabs Forge / Upgrade / Reforge; the left lists the weapons for that tab as slim rows, the right shows the
-- chosen one: its card (Util/WeaponFace), its stats in words (WeaponText), its cost with have / need, and one big
-- button that says what it does or what's missing (WeaponText.button). The Forge Sword is one row with its five
-- elements as buttons. The server re-checks everything (ForgeService); its result plays the reveal
-- (WeaponRevealController) with this window out of the way. Opened from your own Forge's prompt (BuildController);
-- closes when you walk away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BabyColors = require(Config:WaitForChild("BabyColors"))
local Bosses = require(Config:WaitForChild("Bosses"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local Combat = require(Config:WaitForChild("Combat"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Weapons = require(Config:WaitForChild("Weapons"))
local WeaponLooks = require(Config:WaitForChild("WeaponLooks"))
local WeaponRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponRules"))
local WeaponText = require(Shared:WaitForChild("Util"):WaitForChild("WeaponText"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local WeaponFace = require(ClientUtil:WaitForChild("WeaponFace"))
local UIController = require(Controllers:WaitForChild("UIController"))
local WeaponRevealController = require(Controllers:WaitForChild("WeaponRevealController"))

type Owned = WeaponRules.Owned
-- A row in the list: one weapon, or the Forge Sword's five (ids in element order)
type Entry = { key: string, name: string, rarity: string, ids: { string } }

local FORGE, UPGRADE, REFORGE = "Forge", "Upgrade", "Reforge"
local PANEL_MAX_SIZE = Vector2.new(820, 540)
local LIST_WIDTH_SCALE = 0.42
local ROW_HEIGHT = 66
local THUMBNAIL_SIZE = Vector2.new(40, 56)
local CARD_SIZE = Vector2.new(84, 120) -- small enough that what the tab does and costs sits beside it on a phone
local ELEMENT_BUTTON = 48 -- tap targets are 48 px or more
local ACTION_HEIGHT = 52
local EDGE = 12
local TOOLBAR_TOP = UIKit.HEADER_HEIGHT + 8
local LIST_TOP = TOOLBAR_TOP + BabyColors.SEGMENTED.hit + 8
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
local render: () -> ()

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

-- The rows a tab lists: Forge, every built weapon you don't have yet that can be made (the Forge Sword as one row
-- while any element is missing); Upgrade and Reforge, the ones you have (not the Steel Sword)
local function entries(): { Entry }
	local found: { Entry } = {}
	local forgeIds = {}
	for _, weapon in Weapons.WEAPONS do
		if not weapon.ready or weapon.id == Weapons.STARTER then
			continue
		end
		local have = owned[weapon.id] ~= nil
		if weapon.source.kind == "forge" and weapon.family == "sword" then
			if (tab == FORGE) ~= have then
				table.insert(forgeIds, weapon.id)
			end
		elseif tab == FORGE and not have and WeaponRules.makeCost(Weapons, weapon.id) then
			table.insert(found, { key = weapon.id, name = weapon.name, rarity = weapon.rarity, ids = { weapon.id } })
		elseif tab ~= FORGE and have then
			table.insert(found, { key = weapon.id, name = weapon.name, rarity = weapon.rarity, ids = { weapon.id } })
		end
	end
	if #forgeIds > 0 then
		if tab == FORGE then
			table.insert(found, { key = "forgeSword", name = "Forge Sword", rarity = "Common", ids = forgeIds })
		else
			for _, id in forgeIds do
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

-- The weapon an entry stands for now (the Forge Sword: the element picked, if it's one still listed)
local function weaponOf(entry: Entry): string
	if #entry.ids == 1 then
		return entry.ids[1]
	end
	local wanted = `forgeSword_{selectedElement}`
	return if table.find(entry.ids, wanted) then wanted else entry.ids[1]
end

local function costFor(weaponId: string): WeaponRules.Cost?
	if tab == FORGE then
		return WeaponRules.makeCost(Weapons, weaponId)
	elseif tab == REFORGE then
		return WeaponRules.reforgeCost(Weapons, weaponId)
	end
	local record = owned[weaponId]
	return if record then WeaponRules.upgradeCost(Weapons, weaponId, record.level + 1) else nil
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

-- The Forge Sword's element buttons: an emoji each, the picked one ringed, the ones you have greyed out
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
	layout.Wraps = true -- a second row on a narrow phone
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	for index, element in ELEMENTS do
		local id = `forgeSword_{element}`
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

local function renderPane(entry: Entry?)
	clear(pane)
	clear(actionBar)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = pane
	local phone = UIKit.isPhone()
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, if phone then 6 else 10)
	padding.PaddingBottom = UDim.new(0, if phone then 6 else 10)
	padding.PaddingLeft = UDim.new(0, EDGE)
	padding.PaddingRight = UDim.new(0, EDGE)
	padding.Parent = pane
	if not entry then
		local message = if tab == FORGE then "You have every weapon you can make. Upgrade them!"
			else "No weapons yet. Forge one, or win one from a boss."
		addLabel(pane, message, Enum.Font.GothamBold, 15, palette.inkSoft, 1)
		return
	end
	local weaponId = weaponOf(entry)
	local weapon = Weapons.ById[weaponId]
	local record = owned[weaponId]
	local cost = costFor(weaponId)

	-- The card, and beside it what matters on a short phone screen: its name, what this tab does to it, its cost
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.LayoutOrder = 1
	top.BackgroundTransparency = 1
	top.Size = UDim2.new(1, 0, 0, CARD_SIZE.Y)
	top.AutomaticSize = Enum.AutomaticSize.Y
	top.Parent = pane
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	card.BackgroundTransparency = 1
	card.Parent = top
	WeaponFace.render(card, nil, weaponId, record or (if tab == FORGE then { grade = "C", level = 0 } else nil), nil)
	local words = Instance.new("Frame")
	words.BackgroundTransparency = 1
	words.Position = UDim2.fromOffset(CARD_SIZE.X + 12, 0)
	words.Size = UDim2.new(1, -(CARD_SIZE.X + 12), 0, 0)
	words.AutomaticSize = Enum.AutomaticSize.Y
	words.Parent = top
	local wordsLayout = Instance.new("UIListLayout")
	wordsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	wordsLayout.Padding = UDim.new(0, 4)
	wordsLayout.Parent = words
	addLabel(words, weapon.name, Enum.Font.FredokaOne, 20, palette.ink, 1)
	if not phone then -- phones: the list's row already says it
		addLabel(words, `{weapon.rarity} · {WeaponText.source(Weapons, Bosses, weaponId)}`, Enum.Font.GothamBold, 13, palette.inkSoft, 2)
	end
	local hint: string? = nil
	if tab == FORGE and (#entry.ids > 1 or weapon.source.kind == "forge") then
		elementButtons(words, entry, 3)
		hint = "Pick its element: it bonds with creatures of that element."
	elseif tab == FORGE then
		hint = "Forged at a random grade, C to S, like a card."
	elseif tab == UPGRADE and record then
		if record.level < Weapons.MAX_LEVEL then
			local now = WeaponRules.shownPower(Weapons, Combat, weaponId, record.grade, record.level)
			local after = WeaponRules.shownPower(Weapons, Combat, weaponId, record.grade, record.level + 1)
			addLabel(words, string.format("+%d -> +%d: Power x%.2f -> x%.2f", record.level, record.level + 1, now, after), Enum.Font.FredokaOne, 16, palette.good, 3)
			addLabel(words, WeaponText.ladderStep(WeaponLooks, record.level + 1), Enum.Font.GothamBold, 13, palette.hint, 4)
		else
			addLabel(words, "Fully upgraded: Awakened!", Enum.Font.FredokaOne, 16, palette.good, 3)
		end
	elseif tab == REFORGE and record then
		addLabel(words, `Now Grade {record.grade}`, Enum.Font.FredokaOne, 16, palette.ink, 3)
		hint = "A reforge rolls a new grade; you keep the better one."
	end
	if cost then
		local lines = WeaponText.cost(cost, items, cash(), Items)
		if phone then
			-- One line on a phone, each part in its own colour
			local parts = {}
			for _, line in lines do
				local color = if line.enough then palette.good else palette.bad
				table.insert(parts, `<font color="#{color:ToHex()}">{line.text}</font>`)
			end
			local label = addLabel(words, table.concat(parts, "  ·  "), Enum.Font.GothamBold, 14, palette.ink, 10)
			label.RichText = true
		else
			for index, line in lines do
				addLabel(words, line.text, Enum.Font.GothamBold, 14, if line.enough then palette.good else palette.bad, 10 + index)
			end
		end
	end

	-- Under it, to scroll to: the tab's hint and the weapon's stats in words
	if hint then
		addLabel(pane, hint, Enum.Font.GothamBold, 13, palette.hint, 2)
	end
	local stats = WeaponText.stats(Weapons, weaponId, if tab == FORGE then nil else record, Combat)
	for index, stat in stats do
		if stat.label ~= "Grade" and stat.label ~= "Level" then
			addLabel(pane, `{stat.label}: {stat.value}`, Enum.Font.GothamBold, 13, palette.ink, 2 + index)
		end
	end

	-- The one button
	local action = if tab == FORGE then "forge" elseif tab == UPGRADE then "upgrade" else "reforge"
	local text, ready = WeaponText.button(action, cost, items, cash(), Items, {
		level = if record then record.level + 1 else nil,
		unlockLevel = if weapon.source.cost then weapon.source.cost.unlockLevel else nil,
		shopLevel = shopLevel(),
	})
	if tab == REFORGE and record and record.grade == "S" then
		text, ready = "Already Grade S", false
	end
	local canPress = ready and not inFlight
	local button = UIKit.button(actionBar, if inFlight then "Working..." else text, if canPress then UIKit.Colors.Accent else UIKit.Colors.Locked)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.5)
	button.Size = UDim2.new(1, -2 * EDGE, 0, ACTION_HEIGHT)
	button.TextSize = 17
	button.AutoButtonColor = canPress
	button.Activated:Connect(function()
		local part = machine
		if not canPress or inFlight or not part then
			return
		end
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
	clear(list)
	setTab(tab)
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
	list.Position = UDim2.fromOffset(12, listTop)
	list.Size = UDim2.new(LIST_WIDTH_SCALE, -18, 1, -(listTop + 12))
	pane.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 0, listTop)
	pane.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 1, -(listTop + 12 + ACTION_HEIGHT + 16))
end

function ForgeController.Open(part: BasePart)
	machine = part
	inFlight = false
	layout()
	panel.Visible = true
	Remotes.WeaponsChanged:FireServer() -- the latest weapons (rate-limited on the server)
	render()
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
local function onResult()
	inFlight = false
	if not panel.Visible then
		return
	end
	reopenAfterReveal = true -- before hiding: the Visible handler keeps the machine for the reopen
	panel.Visible = false
	task.spawn(function()
		task.wait(0.5) -- the reveal queues on the same event
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

function ForgeController.Start()
	local screenGui = UIController.GetScreenGui()
	panel, list = UIKit.panel(screenGui, "Forge", "⚒️ Forge")
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
		render()
	end)
	setTab = pick

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
	player:GetAttributeChangedSignal("Cash"):Connect(render)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible and not reopenAfterReveal then
			machine = nil
		end
	end)
	task.spawn(watchDistance)
end

return ForgeController
