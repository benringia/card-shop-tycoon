--!strict
-- The Recycler's window (Config/Recycler, Util/RecycleRules; owner 2026-11-21: "can we have add a recycler. that can
-- make extra cards turn into upgrade materials", layout A of artifact UjbnCvUyswFQ7d1vQSrW7R; then "on recycler add.
-- convert to coins. for players who just need coins. then add timers for every conversion"): a switch between Upgrade
-- stuff and Coins, one row for each rarity (its pile of extras, what it makes and how long that takes, a Recycle
-- button or how many more it needs) and one big Recycle everything. In Upgrade stuff each rarity always makes the same
-- material; in Coins every extra card pays its rarity's price. The rows show what the server will do (the same rules);
-- it works the extras out again itself. A conversion is a timed job in the machine like the other stations': while it
-- runs the window shows its card with the countdown and Finish now (Util/JobPanel), and what it made arrives when the
-- time is up (a toast, and the window's sentence when it's open). Opened from your own Recycler's prompt; closes when
-- you walk away. Nothing goes on one tap (owner 2026-11-21: "make sure players cant accidentally recycle their most
-- powerful creatures. or the creatures they've been using"): a press shows the cards that would go, a picture each with
-- how many, and only Yes, recycle sends them, with that list (the server takes nothing that wasn't in it). Creatures are
-- never plain copies, so they never go, and every creature this client knows of (the binder's, and the ones in a
-- station) keeps the copies it can still use.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Recycler = require(Config:WaitForChild("Recycler"))
local Beasts = require(Config:WaitForChild("Beasts"))
local Grading = require(Config:WaitForChild("Grading"))
local Cards = require(Config:WaitForChild("Cards"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local BabyColors = require(Config:WaitForChild("BabyColors"))
local Early = require(Config:WaitForChild("Early"))
local EarlyRules = require(Shared:WaitForChild("Util"):WaitForChild("EarlyRules"))
local RecycleRules = require(Shared:WaitForChild("Util"):WaitForChild("RecycleRules"))
local UpgradeRules = require(Shared:WaitForChild("Util"):WaitForChild("UpgradeRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local Recipe = require(ClientUtil:WaitForChild("Recipe"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local JobPanel = require(ClientUtil:WaitForChild("JobPanel"))
local StationJobs = require(ClientUtil:WaitForChild("StationJobs"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

local PANEL_MAX_SIZE = Vector2.new(520, 560)
local SWITCH_TOP = UIKit.HEADER_HEIGHT + 8 -- the Upgrade stuff / Coins switch, over the list
local LIST_TOP = SWITCH_TOP + BabyColors.SEGMENTED.hit + 4
local SAY_HEIGHT = 24
local ROW_HEIGHT = 60 -- four rows, the sentence, the big button and the small line fit the window with no scroll
local PILE = Vector2.new(30, 40) -- a pile's front card
local MINI = Vector2.new(96, 44) -- a row's button
local BAR_HEIGHT = 6
local SAFE_HEIGHT = 18
local DONE_SECONDS = 4 -- what was made stays in the sentence this long
local DISTANCE_CHECK_SECONDS = 0.5

local player = Players.LocalPlayer

local RecyclerController = {}

local panel: Frame
local list: ScrollingFrame
local palette: UIKit.Palette -- the cream window's colours (UIKit.colorsFor), set in Start
local setMode: (string) -> () = function() end
local machine: BasePart? = nil
local mode = Recycler.MODES[1] -- "materials" or "coins"
local inFlight = false -- a request is waiting for the server; the buttons stay locked
local inFlightToken = 0
local doneText: string? = nil -- what the last conversion made, shown in the sentence
local doneToken = 0
local review: { rarity: string? }? = nil -- a press waiting for Yes: one rarity's pile (nil: everything)

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function rarityOf(cardId: string): string?
	local card = Cards.ById[cardId]
	return if card then card.rarity else nil
end

-- How long a conversion takes, as the server will count it (a new shop's wait is shorter), on a clock: "1:40"
local function clockFor(gains: { RecycleRules.Gain }, cash: number): string
	local seconds = EarlyRules.stationWait(RecycleRules.seconds(Recycler, gains, cash), tonumber(player:GetAttribute("Level")) or 1, Early)
	return UpgradeRules.clock(seconds)
end

-- Every creature this client knows of: the binder's (the party's and the workers' with them) and the ones held in a
-- station; the server also counts the ones on display, so it only ever keeps more
local function creatures(): { StationJobs.Held }
	local list: { StationJobs.Held } = {}
	for _, beast in BinderController.GetBeasts() do
		table.insert(list, { cardId = beast.cardId, stars = beast.stars, grade = beast.grade })
	end
	for _, station in { "condenser", "grading" } do
		local job = StationJobs.get(station)
		local held = if job then job.card else nil
		if held then
			table.insert(list, held)
		end
	end
	return list
end

local function currentPiles(): { [string]: RecycleRules.Pile }
	return RecycleRules.piles(Recycler, Beasts, Grading, BinderController.GetGradedStacks() :: any, creatures(), rarityOf)
end

-- What a press does now: the copies that go, the materials it makes and the cash
local function planFor(piles: { [string]: RecycleRules.Pile }, rarity: string?): ({ RecycleRules.Take }, { RecycleRules.Gain }, number)
	if mode == "coins" then
		local takes, cash = RecycleRules.coinPlan(Recycler, piles, rarity)
		return takes, {}, cash
	end
	local takes, gains = RecycleRules.plan(Recycler, piles, rarity)
	return takes, gains, 0
end

local function makeFace(parent: Instance, card: any)
	local face = Instance.new("Frame")
	face.Size = UDim2.fromScale(1, 1)
	face.Parent = parent
	UIKit.corner(face, 6)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = face
	CardFace.render(face, stroke, card, false, false)
end

local render: () -> ()

-- Yes, recycle: the press with the list the player saw (`takes`)
local function send(rarity: string?, takes: { RecycleRules.Take })
	local part = machine
	if inFlight or not part then
		return
	end
	review = nil
	-- Locked until the server answers (the job starts, or a timeout if it refused), so a second tap can't send the
	-- same request
	inFlight = true
	inFlightToken += 1
	local token = inFlightToken
	task.delay(Recycler.IN_FLIGHT_TIMEOUT, function()
		if token == inFlightToken and inFlight then
			inFlight = false
			render()
		end
	end)
	Remotes.Recycle:FireServer(part:GetAttribute("ShelfUid"), rarity, mode, RecycleRules.shownMap(takes))
	render()
end

-- A press: the window shows what would go before anything does
local function ask(rarity: string?)
	if inFlight then
		return
	end
	review = { rarity = rarity }
	render()
end

-- A pile of cards in the rarity's colour: three cards fanned up and to the right, faint when the pile is empty
local function buildPile(parent: Instance, color: Color3, empty: boolean)
	local holder = Instance.new("Frame")
	holder.Name = "Pile"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.new(0, 10, 0.5, 0)
	holder.Size = UDim2.fromOffset(PILE.X + 10, PILE.Y + 10)
	holder.Parent = parent
	for index = 3, 1, -1 do
		local card = Instance.new("Frame")
		card.Position = UDim2.fromOffset((index - 1) * 5, 10 - (index - 1) * 5)
		card.Size = UDim2.fromOffset(PILE.X, PILE.Y)
		card.BackgroundColor3 = color:Lerp(palette.row, if index == 1 then 0.55 else 0.75)
		card.BackgroundTransparency = if empty then 0.5 else 0
		card.ZIndex = 4 - index
		card.Parent = holder
		UIKit.corner(card, 6)
		UIKit.outline(card, if empty then palette.rowEdge else color, 2)
	end
end

local function buildRow(order: number, rarity: string, pile: RecycleRules.Pile)
	local coins = mode == "coins"
	local recipe = Recycler.RECIPES[rarity]
	local per = if coins then 1 else recipe.per
	local made, _, more = RecycleRules.make(pile.count, per)
	-- what this row's press makes, and how long the machine takes over it
	local gains: { RecycleRules.Gain } = if coins or made <= 0 then {} else { { item = recipe.item, count = made } }
	local cash = if coins then math.round(pile.count * (Recycler.COINS[rarity] or 0) * 100) / 100 else 0
	local tier = Rarities.Tiers[rarity]
	local color = if tier then tier.color else palette.inkSoft
	local row = Instance.new("Frame")
	row.Name = "Row_" .. string.gsub(rarity, " ", "")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	row.BackgroundColor3 = palette.row
	row.Parent = list
	UIKit.corner(row, 12)
	UIKit.outline(row, palette.rowEdge, 2)
	buildPile(row, color, pile.count <= 0)

	local textX = PILE.X + 30
	local rightRoom = MINI.X + 20
	local title = UIKit.label(row, RecycleRules.rowTitle(Recycler, rarity, pile.count), Enum.Font.FredokaOne, 15, palette.ink)
	title.Name = "Title"
	title.Position = UDim2.fromOffset(textX, 4)
	title.Size = UDim2.new(1, -(textX + rightRoom), 0, 20)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local sub = UIKit.label(row, if coins then RecycleRules.coinSub(Recycler, rarity) else RecycleRules.rowSub(Recycler, rarity), Enum.Font.GothamBold, 12, palette.inkSoft)
	sub.Name = "Recipe"
	sub.Position = UDim2.fromOffset(textX, 23)
	sub.Size = UDim2.new(1, -(textX + rightRoom), 0, 16)
	sub.TextTruncate = Enum.TextTruncate.AtEnd
	-- under them: what the pile makes and how long it takes, or a bar toward its first one
	if made > 0 then
		local makes = if coins then RecycleRules.money(cash) else RecycleRules.outWords(Recycler, recipe.item, made)
		local out = UIKit.label(row, `Makes {makes} · takes {clockFor(gains, cash)}`, Enum.Font.FredokaOne, 13, palette.good)
		out.Name = "Makes"
		out.Position = UDim2.fromOffset(textX, 40)
		out.Size = UDim2.new(1, -(textX + rightRoom), 0, 16)
		out.TextTruncate = Enum.TextTruncate.AtEnd
	elseif pile.count > 0 then
		local track = Instance.new("Frame")
		track.Name = "Toward"
		track.Position = UDim2.fromOffset(textX, 45)
		track.Size = UDim2.new(1, -(textX + rightRoom + 4), 0, BAR_HEIGHT)
		track.BackgroundColor3 = palette.track
		track.Parent = row
		UIKit.corner(track, BAR_HEIGHT / 2)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(math.clamp(1 - more / per, 0, 1), 1)
		fill.BackgroundColor3 = palette.good
		fill.Parent = track
		UIKit.corner(fill, BAR_HEIGHT / 2)
	end

	-- what comes out (the material's picture, or a coin) and the row's button
	local item = Items.ITEMS[recipe.item]
	local picture = Icon.make(row, if coins then "Cash" elseif item then item.icon else "Copies", UDim2.fromOffset(20, 20))
	picture.AnchorPoint = Vector2.new(1, 0)
	picture.Position = UDim2.new(1, -(MINI.X + 14), 0, 4)
	local buttonText, on = RecycleRules.rowButton(pile.count, per)
	local can = on and not inFlight
	local button = UIKit.button(row, buttonText, if can then UIKit.Colors.Accent else UIKit.Colors.Locked)
	button.Name = "Recycle"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.fromOffset(MINI.X, MINI.Y)
	button.TextSize = 15
	button.AutoButtonColor = can
	button.Activated:Connect(function()
		if can then
			ask(rarity)
		end
	end)
end

-- The review: "Recycle these 52 cards?", that creatures are safe, the cards going (a picture each, how many), Yes,
-- recycle with what it makes and how long, and Back
local function renderReview(piles: { [string]: RecycleRules.Pile }, rarity: string?)
	local takes, gains, cash = planFor(piles, rarity)
	local total = 0
	for _, take in takes do
		total += take.count
	end
	local say = UIKit.label(list, RecycleRules.reviewSay(total), Enum.Font.FredokaOne, 16, palette.ink)
	say.Name = "Say"
	say.LayoutOrder = 0
	say.Size = UDim2.new(1, -8, 0, SAY_HEIGHT)
	say.TextXAlignment = Enum.TextXAlignment.Center
	local safe = UIKit.label(list, Recycler.REVIEW_SAFE, Enum.Font.GothamBold, 12, palette.good)
	safe.Name = "ReviewSafe"
	safe.LayoutOrder = 1
	safe.Size = UDim2.new(1, -8, 0, SAFE_HEIGHT)
	safe.TextXAlignment = Enum.TextXAlignment.Center
	safe.TextTruncate = Enum.TextTruncate.AtEnd

	local tile = Recycler.REVIEW_TILE
	local going = Instance.new("Frame")
	going.Name = "Going"
	going.LayoutOrder = 2
	going.BackgroundTransparency = 1
	going.Size = UDim2.new(1, -8, 0, 0)
	going.AutomaticSize = Enum.AutomaticSize.Y
	going.Parent = list
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(tile[1], tile[2] + 20)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = going
	for order, line in RecycleRules.byCard(takes) do
		local card = Cards.ById[line.cardId]
		if card then
			local cell = Instance.new("Frame")
			cell.Name = "Card_" .. line.cardId
			cell.LayoutOrder = order
			cell.BackgroundTransparency = 1
			cell.Parent = going
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromOffset(tile[1], tile[2])
			holder.Parent = cell
			makeFace(holder, card)
			local count = UIKit.label(cell, `x{RecycleRules.count(line.count)}`, Enum.Font.FredokaOne, 14, palette.ink)
			count.Name = "Count"
			count.Position = UDim2.fromOffset(0, tile[2] + 2)
			count.Size = UDim2.new(1, 0, 0, 18)
			count.TextXAlignment = Enum.TextXAlignment.Center
		end
	end

	local can = total > 0 and not inFlight
	local yes = UIKit.button(list, Recycler.REVIEW_YES, if can then UIKit.Colors.Accent else UIKit.Colors.Locked)
	yes.Name = "Yes"
	yes.LayoutOrder = 3
	yes.Size = UDim2.new(1, -8, 0, Recipe.LOOK.button)
	yes.AutoButtonColor = can
	Recipe.words(yes, Recycler.REVIEW_YES, if total > 0 then `Makes {RecycleRules.makes(Recycler, gains, cash)} · takes {clockFor(gains, cash)}` else nil)
	yes.Activated:Connect(function()
		if can then
			send(rarity, takes)
		end
	end)
	local back = UIKit.button(list, "Back", UIKit.Colors.Secondary)
	back.Name = "Back"
	back.LayoutOrder = 4
	back.Size = UDim2.new(1, -8, 0, 44)
	back.Activated:Connect(function()
		review = nil
		render()
	end)
end

render = function()
	if not panel.Visible then
		return
	end
	clear(list)
	setMode(Recycler.MODE_WORDS[mode]) -- the switch shows the current choice (UIKit.segmented leaves that to us)
	local coins = mode == "coins"
	local piles = currentPiles()
	local asking = review
	if asking then
		renderReview(piles, asking.rarity)
		return
	end
	local _, gains, cash = planFor(piles, nil)

	local said = doneText
	local say = UIKit.label(list, said or (if coins then Recycler.EXPLAIN_COINS else Recycler.EXPLAIN), Enum.Font.FredokaOne, 16, if said then palette.good else palette.ink)
	say.Name = "Say"
	say.LayoutOrder = 0
	say.Size = UDim2.new(1, -8, 0, SAY_HEIGHT)
	say.TextXAlignment = Enum.TextXAlignment.Center
	say.TextTruncate = Enum.TextTruncate.AtEnd

	for order, rarity in Recycler.ORDER do
		buildRow(order, rarity, piles[rarity])
	end

	local title, sub = RecycleRules.allWords(Recycler, gains, cash)
	local some = #gains > 0 or cash > 0
	local can = some and not inFlight
	local all = UIKit.button(list, title, if can then UIKit.Colors.Accent else UIKit.Colors.Locked)
	all.Name = "RecycleAll"
	all.LayoutOrder = 10
	all.Size = UDim2.new(1, -8, 0, Recipe.LOOK.button)
	all.AutoButtonColor = can
	Recipe.words(all, title, if sub and some then `{sub} · takes {clockFor(gains, cash)}` else sub)
	all.Activated:Connect(function()
		if can then
			ask(nil)
		end
	end)

	local safe = UIKit.label(list, Recycler.SAFE, Enum.Font.GothamBold, 12, palette.inkSoft)
	safe.Name = "Safe"
	safe.LayoutOrder = 11
	safe.Size = UDim2.new(1, -8, 0, SAFE_HEIGHT)
	safe.TextXAlignment = Enum.TextXAlignment.Center
	safe.TextTruncate = Enum.TextTruncate.AtEnd
end

local function close()
	panel.Visible = false
	machine = nil
end

-- Opens the window for your own Recycler
function RecyclerController.Open(part: BasePart)
	machine = part
	inFlight = false
	doneText = nil
	review = nil
	panel.Size = if UIKit.isShort() then UDim2.fromScale(0.97, 0.96) else UDim2.fromScale(0.92, 0.9)
	panel.Visible = true
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
			if not part:IsDescendantOf(workspace) or not root or (root.Position - part.Position).Magnitude > Recycler.USE_DISTANCE then
				close()
			end
		end
	end
end

function RecyclerController.Start()
	local screenGui = UIController.GetScreenGui()
	panel, list = UIKit.panel(screenGui, "Recycler", "Recycler")
	JobPanel.attach(panel, "recycler") -- a conversion inside: its card with the countdown and Finish now over the rows
	palette = UIKit.colorsFor(panel)
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = PANEL_MAX_SIZE
	end
	Icon.header(panel, "Copies", UIKit.HEADER_HEIGHT)

	-- The switch over the list: what the extras become
	local switchHolder = Instance.new("Frame")
	switchHolder.Name = "Mode"
	switchHolder.BackgroundTransparency = 1
	switchHolder.Position = UDim2.fromOffset(16, SWITCH_TOP)
	switchHolder.Size = UDim2.new(1, -32, 0, BabyColors.SEGMENTED.hit)
	switchHolder.Parent = panel
	local words: { string } = {}
	local modeOf: { [string]: string } = {}
	for _, name in Recycler.MODES do
		table.insert(words, Recycler.MODE_WORDS[name])
		modeOf[Recycler.MODE_WORDS[name]] = name
	end
	local _, pick = UIKit.segmented(switchHolder, words, function(value)
		mode = modeOf[value] or Recycler.MODES[1]
		doneText = nil
		review = nil -- the list was for the other mode
		render()
	end)
	setMode = pick
	setMode(Recycler.MODE_WORDS[mode])

	list.Position = UDim2.fromOffset(12, LIST_TOP)
	list.Size = UDim2.new(1, -24, 1, -(LIST_TOP + 12))
	-- room round the rows for their outlines and the buttons growing under the mouse
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = list

	-- A conversion's time is up: what it made, said in the window for a few seconds (the toast says it too)
	Remotes.Recycled.OnClientEvent:Connect(function(gains: unknown, cash: unknown)
		inFlight = false
		local clean: { RecycleRules.Gain } = {}
		if typeof(gains) == "table" then
			for _, gain in gains :: { any } do
				if typeof(gain) == "table" and typeof(gain.item) == "string" and typeof(gain.count) == "number" then
					table.insert(clean, { item = gain.item, count = gain.count })
				end
			end
		end
		local paid = if typeof(cash) == "number" then cash else 0
		if #clean > 0 or paid > 0 then
			doneText = RecycleRules.doneWords(Recycler, clean, paid)
			doneToken += 1
			local token = doneToken
			task.delay(DONE_SECONDS, function()
				if token == doneToken then
					doneText = nil
					render()
				end
			end)
		end
		render()
	end)
	-- a job starting or ending: the buttons unlock, the piles follow
	StationJobs.onChanged(function()
		inFlight = false
		render()
	end)
	-- the binder changed (the copies left, or a pack was opened meanwhile): redraw with the new piles
	Remotes.CollectionChanged.OnClientEvent:Connect(function()
		task.defer(function() -- after BinderController has stored the new binder
			if panel.Visible then
				render()
			end
		end)
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then
			machine = nil
		end
	end)
	task.spawn(watchDistance)
end

return RecyclerController
