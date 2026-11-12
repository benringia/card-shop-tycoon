--!strict
-- The character window (owner 2026-11-12: "add character info window, for players to check their stats / elementals",
-- layout A, a Titles tab; spec 2026-11-12-wild-danger-character-window-design): your character holding your weapon on
-- the left (Util/CharacterStage), Stats / Elements / Titles tabs on the right (Config/CharacterWindow), your weapon
-- along the bottom. Opened from your face on the party bar (owner 2026-11-12, pick B) or the P key.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Combat = require(Config:WaitForChild("Combat"))
local Look = require(Config:WaitForChild("CharacterWindow"))
local Party = require(Config:WaitForChild("Party"))
local Titles = require(Config:WaitForChild("Titles"))
local Weapons = require(Config:WaitForChild("Weapons"))
local WeaponLooks = require(Config:WaitForChild("WeaponLooks"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CharacterStats = require(Shared:WaitForChild("Util"):WaitForChild("CharacterStats"))
local WeaponRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Motion = require(ClientUtil:WaitForChild("Motion"))
local ElementWheelView = require(ClientUtil:WaitForChild("ElementWheelView"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local ElementBadge = require(ClientUtil:WaitForChild("ElementBadge"))
local CharacterStage = require(ClientUtil:WaitForChild("CharacterStage"))
local StageAura = require(ClientUtil:WaitForChild("StageAura"))
local Tooltip = require(ClientUtil:WaitForChild("Tooltip"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))
local PartyController = require(Controllers:WaitForChild("PartyController"))
local PartyBarController = require(Controllers:WaitForChild("PartyBarController"))
local WeaponSwitchController = require(Controllers:WaitForChild("WeaponSwitchController"))

local CharacterController = {}

local player = Players.LocalPlayer
local panel: Frame
local palette: UIKit.Palette
local stage: CharacterStage.Stage
local page: ScrollingFrame -- the open tab's contents (scrolls: Titles grows)
local stageHolder: Frame -- the stage's frame: the weapon box, the title and the aura sit on it
local weaponBox: Frame? = nil
local stageTitle: Frame? = nil
local aura: StageAura.Aura? = nil
local chooseTab: (string) -> () = function() end -- the tabs' switch shows this one chosen
local openTab = "Stats"
-- the server's titles (TitleService): earned, worn, new ones, and how far each locked one is
local titleState = {
	earned = {} :: { string },
	equipped = "",
	fresh = {} :: { string },
	progress = {} :: { [string]: { have: number, need: number } },
}
local newShown: { [string]: boolean } = {} -- tagged NEW while this window stays open (the server forgets them once seen)
local faceDot: Frame? = nil
local TITLES = Look.TITLES

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- A white row card in the window's look, `height` tall, in a vertical list at `order`
local function card(parent: Instance, order: number, height: number): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -10, 0, height) -- room for the page's scroll bar
	frame.BackgroundColor3 = palette.row
	frame.Parent = parent
	UIKit.corner(frame, 14)
	local edge = Instance.new("UIStroke")
	edge.Color = palette.rowEdge
	edge.Thickness = 2
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = frame
	return frame
end

local function list(parent: Instance, gap: number)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = parent
end

-- The party's cards: { name, element, power } in slot order
local function partyCards(): { { name: string, element: string, power: number } }
	local beasts = BinderController.GetBeasts()
	local cards = {}
	for slot = 1, 3 do
		local beastId = PartyController.GetSlots()[slot]
		local beast = if beastId then beasts[beastId] else nil
		local cardInfo = if beast then Cards.ById[beast.cardId] else nil
		if beast and cardInfo then
			table.insert(cards, {
				name = cardInfo.name,
				element = cardInfo.element,
				power = BeastRules.getPower(cardInfo, beast.foil, beast.level, beast.stars, beast.grade),
			})
		end
	end
	return cards
end

-- The equipped weapon: its id, grade, level and Power (nil: none)
local function weaponNow(): (string?, string, number, number)
	local state = WeaponSwitchController.GetState()
	local id = state.equipped
	local owned = if id then state.owned[id] else nil
	if not id or not Weapons.ById[id] then
		return nil, "C", 0, 0
	end
	local grade = if owned then owned.grade else "C"
	local level = if owned then owned.level else 0
	return id, grade, level, WeaponRules.shownPower(Weapons, Combat, id, grade, level)
end

local function showStats()
	local powers = {}
	for _, each in partyCards() do
		table.insert(powers, each.power)
	end
	local _, _, _, weaponPower = weaponNow()
	local stats = CharacterStats.compute(powers, weaponPower) :: any
	for index, stat in Look.STATS do
		local row = card(page, index, Look.STAT_ROW)
		Icon.make(row, stat.icon, UDim2.fromOffset(34, 34)).Position = UDim2.new(0, 0, 0.5, -17)
		local name = UIKit.label(row, stat.name, Enum.Font.FredokaOne, 14, palette.hint)
		name.Position = UDim2.fromOffset(44, 0)
		name.Size = UDim2.new(0.5, -44, 0, 18)
		-- a weapon's Power is a multiplier, shown as the Armory shows it ("x1.62")
		local value = if stat.key == "attack" then string.format("x%.2f", stats.attack) else string.format("%d", math.round(stats[stat.key]))
		local number = UIKit.label(row, value, Enum.Font.FredokaOne, 28, palette.ink)
		number.AnchorPoint = Vector2.new(1, 0)
		number.Position = UDim2.new(1, 0, 0, -2)
		number.Size = UDim2.new(0.5, 0, 0, 32)
		number.TextXAlignment = Enum.TextXAlignment.Right
		local line = UIKit.label(row, stat.line, Enum.Font.GothamBold, 11, palette.inkSoft)
		line.Position = UDim2.fromOffset(44, 30)
		line.Size = UDim2.new(1, -44, 0, 28)
		line.TextWrapped = true
		line.TextYAlignment = Enum.TextYAlignment.Top
	end
end

-- The element wheel (owner 2026-11-12, pick A: a picture, not lines of text): who beats who, your party's elements
-- glowing, a short legend beside it (below it when the tab is narrow)
local function showElements()
	local mine: { [string]: boolean } = {}
	for _, each in partyCards() do
		mine[each.element] = true
	end
	local wheelLook = Look.WHEEL
	local width = page.AbsoluteSize.X - 30 -- the card's padding and the scroll bar
	local beside = width <= 0 or width >= wheelLook.size.x + Look.LEGEND_WIDTH
	local legendHeight = #Look.LEGEND * 30 -- a line may wrap to two
	-- the tab's height too (the card fits without scrolling); 0 before the window is laid out
	local tall = page.AbsoluteSize.Y - 26 - 14 - (if beside then 0 else legendHeight + 6)
	local scale = math.min(1, if beside then 1 else width / wheelLook.size.x, if tall > 0 then tall / wheelLook.size.y else 1)
	local holder = card(page, 1, 26 + wheelLook.size.y * scale + (if beside then 0 else legendHeight + 6))
	local title = UIKit.label(holder, Look.WHEEL_TITLE, Enum.Font.FredokaOne, 14, palette.hint)
	title.Size = UDim2.new(1, 0, 0, 18)
	local wheel = ElementWheelView.new(holder, mine, palette, scale)
	wheel.Position = UDim2.fromOffset(0, 24)
	local legend = Instance.new("Frame")
	legend.BackgroundTransparency = 1
	legend.Position = if beside then UDim2.fromOffset(wheelLook.size.x * scale + 10, 24 + (wheelLook.size.y * scale - legendHeight) / 2)
		else UDim2.fromOffset(0, 30 + wheelLook.size.y * scale)
	legend.Size = if beside then UDim2.new(1, -(wheelLook.size.x * scale + 10), 0, legendHeight) else UDim2.new(1, 0, 0, legendHeight)
	legend.Parent = holder
	list(legend, 2)
	for index, line in Look.LEGEND do
		local text = string.gsub(string.gsub(line, "{strong}", tostring(Combat.STRONG)), "{weak}", tostring(Combat.WEAK))
		local label = UIKit.label(legend, text, Enum.Font.GothamBold, 12, palette.inkSoft)
		label.LayoutOrder = index
		label.Size = UDim2.new(1, 0, 0, 28)
		label.TextWrapped = true
		label.TextYAlignment = Enum.TextYAlignment.Top
	end
end

-- 1234567 -> "1,234,567"
local function commas(value: number): string
	local text = tostring(math.floor(value))
	local done = text
	repeat
		text = done
		done = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
	until done == text
	return done
end

-- A title's row: its icon and name in its gradient (Config/Titles), how to earn it; earned: NEW while new and Wear /
-- Wearing; to earn: greyed, a lock and a bar of how far they are ("12 / 100")
local function titleRow(order: number, id: string, earned: boolean)
	local title = Titles.ById[id]
	local auto = id == ""
	local row = card(page, order, if earned then 64 else 72)
	local left = if auto then 0 else 30
	if not auto then
		local icon = UIKit.label(row, title.icon, Enum.Font.FredokaOne, 22, palette.ink)
		icon.Size = UDim2.fromOffset(26, 26)
		icon.TextXAlignment = Enum.TextXAlignment.Center
		if not earned then
			icon.TextTransparency = 0.5
		end
	end
	local tagged = earned and newShown[id] == true
	local name = UIKit.label(row, if auto then Look.TITLES_AUTO.name else title.name, Enum.Font.FredokaOne, 17, if auto then palette.ink else Color3.new(1, 1, 1))
	name.Position = UDim2.fromOffset(left, 0)
	name.Size = UDim2.new(1, -(left + 96 + (if tagged then 50 else 0)), 0, 22) -- room for NEW after it
	name.TextScaled = true
	local most = Instance.new("UITextSizeConstraint")
	most.MaxTextSize = 17
	most.Parent = name
	if not auto then
		name.TextStrokeTransparency = 0.6
		local gradient = Instance.new("UIGradient")
		gradient.Color = if earned
			then ColorSequence.new(rgb(title.gradient[1]), rgb(title.gradient[2]))
			else ColorSequence.new(palette.inkSoft)
		gradient.Parent = name
	end
	if tagged then
		local tag = UIKit.pill(row, TITLES.new, UIKit.Colors.Danger, Color3.new(1, 1, 1))
		tag.AnchorPoint = Vector2.new(1, 0)
		tag.Position = UDim2.new(1, -96, 0, 0)
	end
	local how = UIKit.label(row, if auto then Look.TITLES_AUTO.how else title.how, Enum.Font.GothamBold, 11, palette.inkSoft)
	how.Position = UDim2.fromOffset(left, 22)
	how.Size = UDim2.new(1, -(left + 96), 0, 16)
	how.TextScaled = true -- one line, smaller if it must
	local howMost = Instance.new("UITextSizeConstraint")
	howMost.MaxTextSize = 11
	howMost.Parent = how
	if earned then
		local worn = titleState.equipped == id
		local button = UIKit.button(row, if worn then TITLES.worn else TITLES.wear, if worn then UIKit.Colors.Secondary else UIKit.Colors.Accent)
		button.Name = "Wear"
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, 0, 0.5, 0)
		button.Size = UDim2.fromOffset(88, 40)
		button.Activated:Connect(function()
			if not worn then
				Remotes.EquipTitle:FireServer(id)
			end
		end)
		return
	end
	row.BackgroundTransparency = 0.35
	Icon.make(row, "Lock", UDim2.fromOffset(26, 26)).Position = UDim2.new(1, -40, 0.5, -13)
	local far = titleState.progress[id]
	if far and far.need > 0 then
		local money = title.check.kind == "stat" and title.check.stat == "totalEarned"
		local track = UIKit.bar(row, far.have / far.need, UIKit.Colors.Accent)
		track.Position = UDim2.fromOffset(left, 42)
		track.Size = UDim2.new(1, -(left + 48), 0, 16)
		local shown = math.min(far.have, far.need)
		local count = UIKit.label(track, if money then `${commas(shown)} / ${commas(far.need)}` else `{commas(shown)} / {commas(far.need)}`, Enum.Font.GothamBold, 11, palette.ink)
		count.Size = UDim2.fromScale(1, 1) -- over the bar
		count.TextXAlignment = Enum.TextXAlignment.Center
		count.ZIndex = track.ZIndex + 2
	end
end

-- The Titles tab: how to wear one, Automatic, the earned ones (new ones tagged), then the ones still to earn. Seeing it
-- tells the server nothing's new any more (the tags stay till the window closes)
local function showTitles()
	if #titleState.fresh > 0 then
		for _, id in titleState.fresh do
			newShown[id] = true
		end
		Remotes.TitlesSeen:FireServer()
	end
	local hint = UIKit.label(page, TITLES.hint, Enum.Font.GothamBold, 13, palette.inkSoft)
	hint.LayoutOrder = 0
	hint.Size = UDim2.new(1, -10, 0, 18)
	titleRow(1, "", true)
	local order = 1
	local function rows(keep: (id: string, earned: boolean) -> boolean)
		for _, id in Titles.ORDER do
			local earned = table.find(titleState.earned, id) ~= nil
			if keep(id, earned) then
				order += 1
				titleRow(order, id, earned)
			end
		end
	end
	rows(function(id, earned)
		return earned and newShown[id] == true -- new ones first
	end)
	rows(function(id, earned)
		return earned and not newShown[id]
	end)
	rows(function(_, earned)
		return not earned
	end)
end

-- The dot on your face while a title is new
local function updateDot()
	if faceDot then
		faceDot.Visible = #titleState.fresh > 0
	end
end

-- The weapon in hand: its picture in a small box at the stage's top right; its name, grade, level and element in a tip
-- (hover, or hold on touch). Made again each time (a tip hooks its box once)
local function showWeapon()
	if weaponBox then
		weaponBox:Destroy()
	end
	local look = Look.WEAPON_BOX
	local box = Instance.new("Frame")
	box.Name = "WeaponBox"
	box.AnchorPoint = Vector2.new(1, 0)
	box.Position = UDim2.new(1, -look.inset, 0, look.inset)
	box.Size = UDim2.fromOffset(look.box, look.box)
	box.BackgroundColor3 = Color3.new(1, 1, 1)
	box.BackgroundTransparency = 0.1
	box.ZIndex = 5
	box.Parent = stageHolder
	UIKit.corner(box, 14)
	UIKit.outline(box, palette.rowEdge, 2)
	weaponBox = box
	local id, grade, level = weaponNow()
	local weapon = if id then Weapons.ById[id] else nil
	local looks = if id then WeaponLooks.WEAPONS[id] else nil
	if weapon and looks then
		local picture = Instance.new("ImageLabel")
		picture.BackgroundTransparency = 1
		picture.AnchorPoint = Vector2.new(0.5, 0.5)
		picture.Position = UDim2.fromScale(0.5, 0.5)
		picture.Size = UDim2.fromScale(0.86, 0.86)
		picture.ScaleType = Enum.ScaleType.Fit
		picture.Image = looks.portrait
		picture.ZIndex = 6
		picture.Parent = box
		local chip = UIKit.label(box, grade, Enum.Font.FredokaOne, 13, Color3.new(1, 1, 1))
		chip.AnchorPoint = Vector2.new(1, 1)
		chip.Position = UDim2.new(1, -4, 1, -1)
		chip.Size = UDim2.fromOffset(18, 16)
		chip.TextXAlignment = Enum.TextXAlignment.Right
		chip.TextStrokeTransparency = 0.3
		chip.ZIndex = 7
		local detail = `Grade {grade} · Lv {level}`
		Tooltip.rich(box, weapon.name, if weapon.element then { detail, ElementBadge.name(weapon.element) } else { detail })
	else
		local icon = Icon.make(box, "Sword", UDim2.fromScale(0.6, 0.6))
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		Tooltip.attach(box, Look.NO_WEAPON)
	end
end

-- The title worn, at the top of the stage: its icon, then the name in its gradient (Config/Titles); nothing when none
local function showStageTitle()
	if stageTitle then
		stageTitle:Destroy()
		stageTitle = nil
	end
	local id = player:GetAttribute("TitleId")
	local title = if typeof(id) == "string" then Titles.ById[id] else nil
	if not title then
		return
	end
	local look = Look.STAGE_TITLE
	local room = Look.WEAPON_BOX.box + Look.WEAPON_BOX.inset + 4 -- clear of the weapon box, and as far in from the left
	local row = Instance.new("Frame")
	row.Name = "StageTitle"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(room, look.inset + (Look.WEAPON_BOX.box - look.height) / 2)
	row.Size = UDim2.new(1, -room * 2, 0, look.height)
	row.ZIndex = 5
	row.Parent = stageHolder
	stageTitle = row
	local name = UIKit.label(row, title.name, Enum.Font.FredokaOne, look.maxText, Color3.new(1, 1, 1))
	name.Size = UDim2.fromScale(1, 1)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextScaled = true
	name.TextStrokeColor3 = Color3.fromRGB(55, 30, 20)
	name.TextStrokeTransparency = 0.25
	name.ZIndex = 6
	local most = Instance.new("UITextSizeConstraint")
	most.MaxTextSize = look.maxText
	most.Parent = name
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(rgb(title.gradient[1]), rgb(title.gradient[2]))
	gradient.Parent = name
	local icon = UIKit.label(row, title.icon, Enum.Font.FredokaOne, look.maxText, Color3.new(1, 1, 1))
	icon.AnchorPoint = Vector2.new(1, 0.5)
	icon.Size = UDim2.fromOffset(look.height, look.height)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.ZIndex = 6
	local function place()
		icon.Position = UDim2.new(0.5, -name.TextBounds.X / 2 - 2, 0.5, 0) -- just left of the centred name
	end
	name:GetPropertyChangedSignal("TextBounds"):Connect(place)
	place()
end

local function show(tab: string)
	openTab = tab
	clear(page)
	chooseTab(tab)
	if tab == "Stats" then
		showStats()
	elseif tab == "Elements" then
		showElements()
	else
		showTitles()
	end
end

local function refresh()
	local title = panel:FindFirstChild("Title", true)
	if title and title:IsA("TextLabel") then
		title.Text = `{player.DisplayName} · Lv {player:GetAttribute("Level") or 1}`
	end
	stage.refresh()
	show(openTab)
	showWeapon()
	showStageTitle()
	if aura then
		aura.set(tonumber(player:GetAttribute("SupporterTier")) or 0)
	end
end

local function toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		if #titleState.fresh > 0 then
			openTab = "Titles" -- the dot led them here
		end
		Remotes.Titles:FireServer() -- the titles now
		refresh()
	else
		newShown = {}
	end
end

-- The window open on its Titles tab (the "New title!" card's button)
function CharacterController.OpenTitles()
	openTab = "Titles"
	if panel.Visible then
		show("Titles")
	else
		toggle()
	end
end

-- "New title!": a card pops in at the top with the title in its gradient and how it was earned, a bright chime, and
-- "Equip it" (the Titles tab); one at a time, after any cinematic holding the screen (a boss win's)
local unlockQueue: { string } = {}
local unlockShowing = false
local function showUnlocks()
	if unlockShowing then
		return
	end
	unlockShowing = true
	task.spawn(function()
		while #unlockQueue > 0 do
			local waited = 0
			while workspace.CurrentCamera and workspace.CurrentCamera.CameraType ~= Enum.CameraType.Custom and waited < 30 do
				waited += task.wait(0.5)
			end
			local id = table.remove(unlockQueue, 1) :: string
			local title = Titles.ById[id]
			if not title or panel.Visible then
				continue -- the window's open: its Titles tab tags it NEW already
			end
			local holder = Instance.new("Frame")
			holder.Name = "TitleUnlocked"
			holder.AnchorPoint = Vector2.new(0.5, 0)
			holder.Position = UDim2.new(0.5, 0, 0, TITLES.top) -- under Pish's talk card (his titles lesson comes now too)
			holder.Size = UDim2.fromOffset(TITLES.width, 112)
			holder.ZIndex = 30
			holder.Parent = UIController.GetScreenGui()
			UIKit.creamWindow(holder)
			local colors = UIKit.colorsFor(holder)
			local head = UIKit.label(holder, `{title.icon} {TITLES.unlocked}`, Enum.Font.FredokaOne, 16, colors.hint) -- the emoji here: a gradient would tint it
			head.Position = UDim2.fromOffset(16, 8)
			head.Size = UDim2.new(1, -32, 0, 20)
			head.TextXAlignment = Enum.TextXAlignment.Center
			local name = UIKit.label(holder, title.name, Enum.Font.FredokaOne, 26, Color3.new(1, 1, 1))
			name.Position = UDim2.fromOffset(16, 28)
			name.Size = UDim2.new(1, -32, 0, 32)
			name.TextXAlignment = Enum.TextXAlignment.Center
			name.TextStrokeColor3 = Color3.fromRGB(70, 40, 80)
			name.TextStrokeTransparency = 0.2 -- a pastel gradient still reads on the cream card
			local gradient = Instance.new("UIGradient")
			gradient.Color = ColorSequence.new(rgb(title.gradient[1]), rgb(title.gradient[2]))
			gradient.Parent = name
			local how = UIKit.label(holder, title.how, Enum.Font.GothamBold, 12, colors.inkSoft)
			how.Position = UDim2.fromOffset(16, 60)
			how.Size = UDim2.new(1, -150, 0, 40)
			how.TextWrapped = true
			local wear = UIKit.button(holder, TITLES.show, UIKit.Colors.Accent)
			wear.Name = "WearIt"
			wear.AnchorPoint = Vector2.new(1, 1)
			wear.Position = UDim2.new(1, -14, 1, -12)
			wear.Size = UDim2.fromOffset(112, 40)
			local closed = false
			wear.Activated:Connect(function()
				closed = true
				holder:Destroy()
				CharacterController.OpenTitles()
			end)
			local scale = Instance.new("UIScale")
			scale.Scale = 0.4
			scale.Parent = holder
			TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			local chime = Instance.new("Sound")
			chime.SoundId = TITLES.sound.id
			chime.Volume = TITLES.sound.volume
			chime.PlaybackSpeed = TITLES.sound.pitch
			chime.Parent = SoundService
			chime.Ended:Once(function()
				chime:Destroy()
			end)
			chime:Play()
			local shown = 0
			while not closed and shown < TITLES.seconds and not panel.Visible do
				shown += task.wait(0.25)
			end
			if not closed then
				TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 0 }):Play()
				task.wait(0.3)
				holder:Destroy()
			end
		end
		unlockShowing = false
	end)
end

local function build()
	local screenGui = UIController.GetScreenGui()
	local scroll
	panel, scroll = UIKit.panel(screenGui, "CharacterWindow", player.DisplayName, "Party")
	palette = UIKit.colorsFor(panel)
	panel.Size = UDim2.fromScale(0.94, 0.9)
	-- UIKit.panel's own cap (460 x 520), raised: a second constraint would keep the smaller one
	local limit = panel:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(Look.MAX_SIZE[1], Look.MAX_SIZE[2])
	limit.Parent = panel
	-- side by side on every landscape screen (phones play landscape); stacked only on a tall one
	local camera = workspace.CurrentCamera
	local phone = camera ~= nil and camera.ViewportSize.Y > camera.ViewportSize.X
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, -8, 0, if phone then Look.PHONE_BODY_HEIGHT else Look.BODY_HEIGHT)
	body.Parent = scroll
	if not phone then
		-- side by side: as tall as the window has room for (BODY_HEIGHT at most), never cut off on a short screen
		local function fit()
			local room = scroll.AbsoluteSize.Y - 4
			if room > 0 then
				body.Size = UDim2.new(1, -8, 0, math.clamp(room, Look.MIN_BODY_HEIGHT, Look.BODY_HEIGHT))
			end
		end
		scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		fit()
	end
	-- the stage: left (above on a phone)
	stageHolder = Instance.new("Frame")
	stageHolder.Name = "StageHolder"
	stageHolder.BackgroundColor3 = Color3.fromRGB(214, 196, 250)
	stageHolder.Size = if phone then UDim2.new(1, 0, 0, 240) else UDim2.new(Look.STAGE_SHARE, -6, 1, 0)
	stageHolder.ClipsDescendants = true -- the aura's sparkles stay on the stage
	stageHolder.Parent = body
	UIKit.corner(stageHolder, 16)
	stage = CharacterStage.new(stageHolder)
	stage.frame.ZIndex = 3 -- the supporter glow (2) behind the character, its sparkles (4) and the boxes (5) in front
	aura = StageAura.attach(stageHolder, 2, 4, function(): boolean
		return panel.Visible
	end)
	-- the tabs and their page: right (below on a phone)
	local right = Instance.new("Frame")
	right.BackgroundTransparency = 1
	right.Position = if phone then UDim2.fromOffset(0, 248) else UDim2.new(Look.STAGE_SHARE, 6, 0, 0)
	right.Size = if phone then UDim2.new(1, 0, 0, 320) else UDim2.new(1 - Look.STAGE_SHARE, -6, 1, 0)
	right.Parent = body
	-- the tabs: the binder Filters' segmented switch (owner 2026-11-12: three big buttons looked cramped)
	local tabs, choose = UIKit.segmented(right, Look.TABS, show)
	tabs.Name = "Tabs"
	chooseTab = choose
	local tabsHeight = tabs.Size.Y.Offset
	page = Instance.new("ScrollingFrame")
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 6
	page.ScrollingDirection = Enum.ScrollingDirection.Y
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new()
	page.Position = UDim2.fromOffset(0, tabsHeight + 6)
	page.Size = UDim2.new(1, 0, 1, -(tabsHeight + 6))
	page.Parent = right
	list(page, 8)
	-- the title worn and the supporter aura change while the window is open
	for _, name in { "TitleId", "SupporterTier" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if panel.Visible then
				showStageTitle()
				if aura then
					aura.set(tonumber(player:GetAttribute("SupporterTier")) or 0)
				end
			end
		end)
	end
end

-- Your face first on the party bar (owner 2026-11-12, pick B: you and your team in one place): your avatar's headshot
-- in a white ring; tapping it opens the window, and so does Look.FACE.key (a key chip on it with a keyboard)
local function addFace()
	local cushion = PartyBarController.GetCushion()
	if not cushion then
		return
	end
	local bar = Party.BAR
	local hit = Instance.new("TextButton")
	hit.Name = "Me"
	hit.LayoutOrder = -1 -- before the Party pill
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromOffset(bar.HIT, bar.HIT)
	hit.Parent = cushion
	local face = Instance.new("ImageLabel")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromOffset(bar.PORTRAIT, bar.PORTRAIT)
	face.BackgroundColor3 = rgb(bar.EMPTY)
	face.Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=150&h=150`
	face.Parent = hit
	UIKit.corner(face, bar.PORTRAIT / 2)
	UIKit.outline(face, rgb(Look.FACE.ring), 3)
	local grow = Instance.new("UIScale")
	grow.Parent = face
	local hover = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	hit.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled then
			TweenService:Create(grow, hover, { Scale = Look.FACE.hover }):Play()
		end
	end)
	hit.MouseLeave:Connect(function()
		TweenService:Create(grow, hover, { Scale = 1 }):Play()
	end)
	Motion.press(hit, true)
	hit.Activated:Connect(toggle)
	-- a red dot while a title is new (its tap opens the Titles tab)
	local dot = Instance.new("Frame")
	dot.Name = "NewDot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(0.5, bar.PORTRAIT * 0.36, 0.5, -bar.PORTRAIT * 0.36)
	dot.Size = UDim2.fromOffset(TITLES.dot.size, TITLES.dot.size)
	dot.BackgroundColor3 = rgb(TITLES.dot.color)
	dot.ZIndex = face.ZIndex + 2
	dot.Visible = false
	dot.Parent = hit
	UIKit.corner(dot, TITLES.dot.size / 2)
	UIKit.outline(dot, Color3.new(1, 1, 1), 2)
	faceDot = dot
	updateDot()
	if UserInputService.KeyboardEnabled then
		local chip = UIKit.label(face, Look.FACE.key, Enum.Font.FredokaOne, 12, Color3.fromRGB(20, 28, 60))
		chip.Name = "Key"
		chip.AnchorPoint = Vector2.new(0.5, 0.5)
		chip.Position = UDim2.new(0, 1, 1, -1)
		chip.Size = UDim2.fromOffset(17, 17)
		chip.TextXAlignment = Enum.TextXAlignment.Center
		chip.BackgroundColor3 = Color3.new(1, 1, 1)
		chip.BackgroundTransparency = 0
		UIKit.corner(chip, 9)
		UIKit.outline(chip, rgb(bar.TEXT), 1.5)
	end
	-- the key works while the party bar shows (never while typing, never through a calm HUD)
	local key = (Enum.KeyCode :: any)[Look.FACE.key]
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= key or UserInputService:GetFocusedTextBox() then
			return
		end
		local barFrame = cushion.Parent :: GuiObject?
		local row = if barFrame then barFrame.Parent :: GuiObject? else nil
		if barFrame and barFrame.Visible and (not row or row.Visible) then
			toggle()
		end
	end)
end

function CharacterController.Start()
	build()
	addFace()
	Remotes.Titles.OnClientEvent:Connect(function(state: unknown)
		if typeof(state) ~= "table" then
			return
		end
		local data = state :: any
		titleState.earned = if typeof(data.earned) == "table" then data.earned else {}
		titleState.equipped = if typeof(data.equipped) == "string" then data.equipped else ""
		titleState.fresh = if typeof(data.fresh) == "table" then data.fresh else {}
		titleState.progress = if typeof(data.progress) == "table" then data.progress else {}
		updateDot()
		if panel.Visible and openTab == "Titles" then
			show("Titles")
		end
	end)
	Remotes.TitleUnlocked.OnClientEvent:Connect(function(id: unknown)
		if typeof(id) == "string" and Titles.ById[id] then
			table.insert(unlockQueue, id)
			showUnlocks()
		end
	end)
end

return CharacterController
