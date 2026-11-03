--!strict
-- Card Condenser panel, "tidy two panes" (owner's pick A, spec 2026-11-04-round4-design section 3): a toolbar (search
-- and All / Ready / Raising), the cards you can condense on the left as slim rows (a Ready tag, copies toward the next
-- star), and on the right the chosen card: its stars, Power and Value before -> after, which copy it keeps (Change
-- picks another), one big Condense and a small Star Shards toggle. Condense asks the server, which re-checks
-- everything; the binder sync redraws the panel. Opened from your own Condenser's prompt; closes when you walk away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Beasts = require(Config:WaitForChild("Beasts"))
local Cards = require(Config:WaitForChild("Cards"))
local BabyColors = require(Config:WaitForChild("BabyColors"))
local CondenserConfig = require(Config:WaitForChild("Condenser"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CondenseRules = require(Shared:WaitForChild("Util"):WaitForChild("CondenseRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type Card = typeof(Cards.List[1])
type Beast = { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number, grade: string }
-- One copy that can be the main card: a levelled card, or a stack of plain copies (one grade, foil or not)
type Candidate = { key: string, beast: Beast?, foil: boolean, grade: string, level: number, stars: number, count: number, power: number }

local PANEL_MAX_SIZE = Vector2.new(820, 540)
local LIST_WIDTH_SCALE = 0.5
local ROW_HEIGHT = 66
local MAIN_ROW_HEIGHT = 48 -- tap target minimum
local THUMBNAIL_SIZE = Vector2.new(40, 56)
local DETAIL_FACE_SIZE = Vector2.new(96, 137)
local DISTANCE_CHECK_SECONDS = 0.5
local ALL_FILTER, READY_FILTER, RAISING_FILTER = "All", "Ready", "Raising"
local TOOLBAR_TOP = UIKit.HEADER_HEIGHT + 8
local SEARCH_WIDTH = 200
local SEARCH_HEIGHT = 40
local LIST_TOP = TOOLBAR_TOP + BabyColors.SEGMENTED.hit + 8
local EDGE = 12 -- px either side of the pane's buttons: room for their hover grow, so nothing is cut off
local CONDENSE_HEIGHT = 52
local SHARDS_WIDTH = 250
local STAR_SIZE = 20
local BAR_HEIGHT = 6

local player = Players.LocalPlayer

local CondenserController = {}

local panel: Frame
local palette: UIKit.Palette -- the cream window's colours (UIKit.colorsFor), set in Start
local readyBadge: TextLabel -- "2 ready" in the band
local list: ScrollingFrame
local pane: ScrollingFrame
local setFilter: (string) -> () = function() end
local machine: BasePart? = nil
local selectedCardId: string? = nil
local searchText = ""
local activeFilter = ALL_FILTER -- All, Ready (can take a star now) or Raising (in the list, not ready yet)
local mainKey: string? = nil -- chosen main copy (Candidate.key); nil = the default choice
local choosingMain = false -- Change: the copies to keep show in place of the buttons
local inFlight = false -- a Condense request is waiting for the server; the button stays locked
local useShards = false -- Star Shards fill missing duplicates (up to half a star's cost)
local shardCount = 0 -- from ItemsChanged
local inFlightToken = 0
-- A plain main being condensed: the levelled card it becomes is selected once it arrives
local awaitingNewCard: { before: { [string]: boolean }, cardId: string, foil: boolean, grade: string }? = nil

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function makeFace(parent: Instance, card: Card, foil: boolean, showValue: boolean, growth: CardFace.Growth?)
	local face = Instance.new("Frame")
	face.Size = UDim2.fromScale(1, 1)
	face.Parent = parent
	UIKit.corner(face, 8)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = face
	CardFace.render(face, stroke, card, foil, showValue, growth)
end

local function addLabel(parent: GuiObject, text: string, position: UDim2, size: UDim2, font: Enum.Font, textSize: number, color: Color3): TextLabel
	local label = UIKit.label(parent, text, font, textSize, color)
	label.Position = position
	label.Size = size
	label.TextTruncate = Enum.TextTruncate.AtEnd
	return label
end

-- Every copy of this card that could be the main card, strongest first
local function getCandidates(card: Card): { Candidate }
	local candidates: { Candidate } = {}
	local working = BinderController.GetWorking()
	for id, beast in BinderController.GetBeasts() do
		if beast.cardId == card.id and not working[id] then -- working cards can't be condensed
			table.insert(candidates, {
				key = beast.id,
				beast = beast,
				foil = beast.foil,
				grade = beast.grade,
				level = beast.level,
				stars = beast.stars,
				count = 1,
				power = BeastRules.getPower(card, beast.foil, beast.level, beast.stars, beast.grade),
			})
		end
	end
	for grade, owned in BinderController.GetGradedStacks()[card.id] or {} do
		for _, foil in { true, false } do
			local count = if foil then owned.foil else owned.normal
			if count > 0 then
				table.insert(candidates, {
					key = `stack:{grade}:{foil}`,
					foil = foil,
					grade = grade,
					level = 1,
					stars = BeastRules.START_STARS,
					count = count,
					power = BeastRules.getPower(card, foil, 1, BeastRules.START_STARS, grade),
				})
			end
		end
	end
	CondenseRules.sortMainChoices(candidates)
	return candidates
end

local function asMain(main: Candidate): CondenseRules.Main
	return { beast = main.beast ~= nil, foil = main.foil, grade = main.grade, stars = main.stars }
end

local function getPlan(card: Card, main: Candidate): ({ CondenseRules.Take }?, string?, number)
	local byGrade = BinderController.GetGradedStacks()[card.id] or {}
	local shards = if useShards then shardCount else nil
	return CondenseRules.plan(Beasts, byGrade, asMain(main), shards)
end

-- Whether the default main copy of this card can take a star right now (Star Shards count only while the toggle is on)
local function isReady(card: Card): boolean
	local main = getCandidates(card)[1]
	return main ~= nil and (getPlan(card, main)) ~= nil
end

-- Search by name or number, then the switch: All, Ready (can take a star now) or Raising (the rest)
local function passesFilter(card: Card): boolean
	if searchText ~= "" then
		local query = string.lower(searchText)
		local number = tonumber((string.gsub(query, "#", "")))
		if not string.find(string.lower(card.name), query, 1, true) and number ~= card.number then
			return false
		end
	end
	if activeFilter == READY_FILTER then
		return isReady(card)
	elseif activeFilter == RAISING_FILTER then
		return not isReady(card)
	end
	return true
end

-- Cards you're raising (any levelled or starred copy, even with no duplicates yet, so you can see what
-- the next star needs) and cards with two or more plain copies. Rarest first.
local function getCondensableCards(): { Card }
	local result: { Card } = {}
	for _, card in Cards.RarestFirst do
		local plain, levelled = 0, 0
		for _, candidate in getCandidates(card) do
			if candidate.beast then
				levelled += 1
			else
				plain += candidate.count
			end
		end
		if plain >= 2 or levelled > 0 then
			table.insert(result, card)
		end
	end
	return result
end

local function describeTakes(takes: { CondenseRules.Take }): string
	local parts = {}
	for _, take in takes do
		table.insert(parts, `{take.count} {if take.foil then "FOIL " else ""}{BeastRules.describeGrade(take.grade)}`)
	end
	return "Uses " .. table.concat(parts, " + ")
end

local function describeReason(reason: string?): string
	if reason == "max" then
		return "Max stars reached"
	end
	local have, need = string.match(reason or "", "^short:(%d+):(%d+)$")
	return if have then `Need {need} duplicates, you have {have}` else "Can't condense this copy"
end

local render: () -> ()

-- 1100 -> "1,100"
local function commas(value: number): string
	local text = tostring(math.floor(math.max(0, value)))
	return (string.gsub(string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,"))), "^,", ""))
end

-- 2277 -> "$2,277.00"
local function money(value: number): string
	local total = math.round(math.max(0, value) * 100) -- in cents, so 2.999 is $3.00
	return string.format("$%s.%02d", commas(total // 100), total % 100)
end

-- Right side ------------------------------------------------------------------------------------------

-- A row of stars: the ones it has, the one Condense adds (faint) and the rest (fainter)
local function starRow(parent: Instance, position: UDim2, stars: number, adding: boolean)
	local row = Instance.new("Frame")
	row.Name = "Stars"
	row.BackgroundTransparency = 1
	row.Position = position
	row.Size = UDim2.fromOffset(BeastRules.MAX_STARS * (STAR_SIZE + 3), STAR_SIZE)
	row.Parent = parent
	for index = 1, BeastRules.MAX_STARS do
		local star = Icon.make(row, "Star", UDim2.fromOffset(STAR_SIZE, STAR_SIZE))
		star.Position = UDim2.fromOffset((index - 1) * (STAR_SIZE + 3), 0)
		Icon.set(star, "Star")
		local glyph = star:FindFirstChild("Glyph")
		if glyph and glyph:IsA("ImageLabel") then
			glyph.ImageTransparency = if index <= stars then 0 elseif adding and index == stars + 1 then 0.45 else 0.8
		end
	end
end

-- "Power  957 > 1,100" with the after value in green (the Next icon as the arrow; arrows don't draw in these fonts)
local function compareRow(parent: Instance, position: UDim2, name: string, before: string, after: string)
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundTransparency = 1
	row.Position = position
	row.Size = UDim2.new(1, -(position.X.Offset + EDGE), 0, 22)
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local function piece(order: number, text: string, font: Enum.Font, color: Color3)
		local label = UIKit.label(row, text, font, 14, color)
		label.LayoutOrder = order
		label.TextWrapped = false
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, 22)
	end
	piece(1, name, Enum.Font.GothamBold, palette.inkSoft)
	piece(2, before, Enum.Font.FredokaOne, palette.ink)
	local arrow = Icon.make(row, "Next", UDim2.fromOffset(14, 14))
	arrow.LayoutOrder = 3
	Icon.set(arrow, "Next")
	piece(4, after, Enum.Font.FredokaOne, palette.good)
end

-- The copies that could be kept (Change): today's rows, the chosen one ringed
local function mainChoices(candidates: { Candidate }, chosen: Candidate, y: number): number
	for _, candidate in candidates do
		local row = Instance.new("TextButton")
		row.AnchorPoint = Vector2.new(0.5, 0) -- grows evenly under the mouse (the grow follows the anchor)
		row.Position = UDim2.new(0.5, 0, 0, y)
		row.Size = UDim2.new(1, -2 * EDGE, 0, MAIN_ROW_HEIGHT)
		row.BackgroundColor3 = palette.row
		row.Text = ""
		row.Parent = pane
		UIKit.corner(row, 10)
		UIKit.outline(row, if candidate.key == chosen.key then UIKit.Colors.Accent else palette.rowEdge, 2)
		local title = `{if candidate.foil then "FOIL · " else ""}{BeastRules.describeGrade(candidate.grade)} · {BeastRules.describeGrowth(candidate.level, candidate.stars)}`
		if not candidate.beast then
			title ..= ` · x{candidate.count}`
		end
		addLabel(row, title, UDim2.fromOffset(10, 0), UDim2.new(1, -100, 1, 0), Enum.Font.GothamBold, 13, palette.ink)
		local power = addLabel(row, `Power {candidate.power}`, UDim2.new(1, -94, 0, 0), UDim2.new(0, 86, 1, 0), Enum.Font.GothamBold, 12, palette.power)
		power.TextXAlignment = Enum.TextXAlignment.Right
		row.Activated:Connect(function()
			mainKey = candidate.key
			choosingMain = false
			render()
		end)
		y += MAIN_ROW_HEIGHT + 6
	end
	return y
end

local function renderPane(card: Card?)
	clear(pane)
	if not card then
		local hint = UIKit.label(pane, "Get two or more copies of a card to condense it. Pick a card on the left.", Enum.Font.GothamBold, 14, palette.inkSoft)
		hint.Position = UDim2.fromOffset(EDGE, 10)
		hint.Size = UDim2.new(1, -2 * EDGE, 0, 60)
		return
	end
	local candidates = getCandidates(card)
	-- A plain main just became a levelled card: keep condensing that card
	local waiting = awaitingNewCard
	if waiting and waiting.cardId == card.id then
		local newId = CondenseRules.findNewCard(waiting.before, BinderController.GetBeasts(), card.id, waiting.foil, waiting.grade)
		if newId then
			mainKey = newId
			awaitingNewCard = nil
		end
	end
	local main: Candidate? = nil
	for _, candidate in candidates do
		if candidate.key == mainKey then
			main = candidate
		end
	end
	main = main or candidates[1]
	if not main then
		return
	end
	local chosen = main :: Candidate

	-- The main copy, large, beside its name, its stars before and after and what a star does
	local faceHolder = Instance.new("Frame")
	faceHolder.Position = UDim2.fromOffset(EDGE, 10)
	faceHolder.Size = UDim2.fromOffset(DETAIL_FACE_SIZE.X, DETAIL_FACE_SIZE.Y)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = pane
	makeFace(faceHolder, card, chosen.foil, true, { level = chosen.level, stars = chosen.stars, grade = chosen.grade })

	local takes, reason, shardsUsed = getPlan(card, chosen)
	local atMax = chosen.stars >= BeastRules.MAX_STARS
	local nextStars = math.min(chosen.stars + 1, BeastRules.MAX_STARS)
	local powerAfter = BeastRules.getPower(card, chosen.foil, chosen.level, nextStars, chosen.grade)
	local valueNow = BeastRules.getValue(card, chosen.foil, chosen.level, chosen.stars, chosen.grade)
	local valueAfter = BeastRules.getValue(card, chosen.foil, chosen.level, nextStars, chosen.grade)
	local x = EDGE + DETAIL_FACE_SIZE.X + 12
	addLabel(pane, `{card.name}{if chosen.foil then " (FOIL)" else ""}`, UDim2.fromOffset(x, 10), UDim2.new(1, -(x + EDGE), 0, 24), Enum.Font.FredokaOne, 18, palette.ink)
	starRow(pane, UDim2.fromOffset(x, 40), chosen.stars, not atMax)
	local starWords = if atMax then "Max stars" else `{chosen.stars} -> {nextStars} star{if nextStars == 1 then "" else "s"}`
	addLabel(pane, starWords, UDim2.fromOffset(x, 64), UDim2.new(1, -(x + EDGE), 0, 18), Enum.Font.GothamBold, 12, palette.inkSoft)
	if not atMax then
		compareRow(pane, UDim2.fromOffset(x, 88), "Power", commas(chosen.power), commas(powerAfter))
		compareRow(pane, UDim2.fromOffset(x, 114), "Value", money(valueNow), money(valueAfter))
	end

	-- Which copy it keeps and what it uses, with Change when there's another copy to keep
	local y = 10 + DETAIL_FACE_SIZE.Y + 10
	local keeps = Instance.new("Frame")
	keeps.Name = "Keeps"
	keeps.Position = UDim2.fromOffset(EDGE, y)
	keeps.Size = UDim2.new(1, -2 * EDGE, 0, 48)
	keeps.BackgroundColor3 = palette.row
	keeps.Parent = pane
	UIKit.corner(keeps, 10)
	UIKit.outline(keeps, palette.rowEdge, 2)
	local uses = if takes
		then string.gsub(describeTakes(takes), "^Uses", "uses") .. (if shardsUsed > 0 then ` + {shardsUsed} Star Shard{if shardsUsed == 1 then "" else "s"}` else "")
		else nil
	local keepText = `Keeps {BeastRules.describeGrade(chosen.grade)} · Lv {chosen.level}{if uses then " · " .. uses else ""}`
	local canChange = #candidates > 1
	local keepLabel = addLabel(keeps, keepText, UDim2.fromOffset(10, 0), UDim2.new(1, if canChange then -92 else -20, 1, 0), Enum.Font.GothamBold, 13, palette.ink)
	keepLabel.TextWrapped = true
	if canChange then
		local change = Instance.new("TextButton")
		change.Name = "Change"
		change.AnchorPoint = Vector2.new(1, 0.5)
		change.Position = UDim2.new(1, -4, 0.5, 0)
		change.Size = UDim2.fromOffset(80, 48)
		change.BackgroundTransparency = 1
		change.Font = Enum.Font.FredokaOne
		change.TextSize = 15
		change.Text = if choosingMain then "Done" else "Change"
		change.TextColor3 = palette.hint
		change.Parent = keeps
		change.Activated:Connect(function()
			choosingMain = not choosingMain
			render()
		end)
	end
	y += 48 + 10

	if choosingMain then
		mainChoices(candidates, chosen, y)
		return
	end

	local canCondense = takes ~= nil and not inFlight
	local buttonText = if inFlight then "Condensing..." elseif takes then "Condense +1 star" else describeReason(reason)
	local condense = UIKit.button(pane, buttonText, if canCondense then UIKit.Colors.Accent else UIKit.Colors.Locked)
	condense.AnchorPoint = Vector2.new(0.5, 0) -- grows evenly under the mouse, inside the pane's EDGE
	condense.Position = UDim2.new(0.5, 0, 0, y)
	condense.Size = UDim2.new(1, -2 * EDGE, 0, CONDENSE_HEIGHT)
	condense.TextSize = 17
	condense.AutoButtonColor = canCondense
	condense.Activated:Connect(function()
		local part = machine
		if not canCondense or inFlight or not part then
			return
		end
		-- Locked until the binder sync arrives (or a timeout if the server refused), so a second tap
		-- can't send the same stale request
		inFlight = true
		inFlightToken += 1
		local token = inFlightToken
		task.delay(CondenserConfig.IN_FLIGHT_TIMEOUT, function()
			if token == inFlightToken and inFlight then
				inFlight = false
				render()
			end
		end)
		local beast = chosen.beast
		if beast then
			Remotes.Condense:FireServer(part:GetAttribute("ShelfUid"), card.id, beast.id, nil, nil, useShards)
		else
			local before: { [string]: boolean } = {}
			for id in BinderController.GetBeasts() do
				before[id] = true
			end
			awaitingNewCard = { before = before, cardId = card.id, foil = chosen.foil, grade = chosen.grade }
			Remotes.Condense:FireServer(part:GetAttribute("ShelfUid"), card.id, nil, chosen.foil, chosen.grade, useShards)
		end
		render()
	end)
	y += CONDENSE_HEIGHT + 10

	-- Star Shards toggle: they fill in for missing duplicates (never more than half a star); off, Condense never
	-- spends them and Ready counts copies only
	local hasShards = shardCount > 0
	local shardText = if not hasShards then "No Star Shards yet"
		elseif useShards then `Using Star Shards ({shardCount})`
		else `Use Star Shards ({shardCount})`
	local shards = UIKit.button(pane, shardText, if not hasShards then UIKit.Colors.Locked elseif useShards then UIKit.Colors.Success else UIKit.Colors.Secondary)
	shards.AnchorPoint = Vector2.new(0.5, 0)
	shards.Position = UDim2.new(0.5, 0, 0, y)
	shards.Size = UDim2.fromOffset(SHARDS_WIDTH, 48)
	shards.TextSize = 14
	shards.AutoButtonColor = hasShards
	shards.Activated:Connect(function()
		if hasShards then
			useShards = not useShards
			render()
		end
	end)
	y += 48 + EDGE
	local bottom = Instance.new("Frame") -- keeps room under the last button for its hover grow
	bottom.BackgroundTransparency = 1
	bottom.Position = UDim2.fromOffset(0, y)
	bottom.Size = UDim2.fromOffset(1, 1)
	bottom.Parent = pane
end

-- Left side -------------------------------------------------------------------------------------------

local function buildCardRow(card: Card, order: number)
	local candidates = getCandidates(card)
	local strongest = candidates[1]
	local plain = 0
	for _, candidate in candidates do
		if not candidate.beast then
			plain += candidate.count
		end
	end
	local ready = isReady(card)
	local need = if strongest then BeastRules.getCondenseCost(strongest.stars) or 0 else 0
	local have = if strongest then CondenseRules.countDuplicates(BinderController.GetGradedStacks()[card.id] or {}, asMain(strongest), Beasts) else 0
	local line, share = CondenseRules.rowLine(plain, have, need, ready)
	local row = Instance.new("TextButton")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = palette.row
	row.Text = ""
	row.Parent = list
	UIKit.corner(row, 12)
	local selected = card.id == selectedCardId
	UIKit.outline(row, if selected then UIKit.Colors.Accent else palette.rowEdge, if selected then 3 else 2)
	local thumbnail = Instance.new("Frame")
	thumbnail.Position = UDim2.fromOffset(8, 5)
	thumbnail.Size = UDim2.fromOffset(THUMBNAIL_SIZE.X, THUMBNAIL_SIZE.Y)
	thumbnail.BackgroundTransparency = 1
	thumbnail.Parent = row
	makeFace(thumbnail, card, strongest ~= nil and strongest.foil, false)

	local textX = THUMBNAIL_SIZE.X + 18
	local nameRoom = if ready then 74 else 10 -- room for the Ready tag
	addLabel(row, card.name, UDim2.fromOffset(textX, 8), UDim2.new(1, -(textX + nameRoom), 0, 20), Enum.Font.FredokaOne, 16, palette.ink)
	if ready then
		local tag = UIKit.pill(row, "Ready", palette.good, Color3.new(1, 1, 1))
		tag.AnchorPoint = Vector2.new(1, 0)
		tag.Position = UDim2.new(1, -10, 0, 8)
		tag.Size = UDim2.fromOffset(58, 22)
		tag.TextSize = 12
	end
	addLabel(row, line, UDim2.fromOffset(textX, 30), UDim2.new(1, -(textX + 10), 0, 16), Enum.Font.GothamBold, 12, palette.inkSoft)
	local track = Instance.new("Frame")
	track.Name = "Copies"
	track.Position = UDim2.fromOffset(textX, 50)
	track.Size = UDim2.new(1, -(textX + 12), 0, BAR_HEIGHT)
	track.BackgroundColor3 = palette.track
	track.Parent = row
	UIKit.corner(track, BAR_HEIGHT / 2)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(share, 1)
	fill.BackgroundColor3 = palette.good
	fill.Parent = track
	UIKit.corner(fill, BAR_HEIGHT / 2)

	row.Activated:Connect(function()
		if selectedCardId ~= card.id then
			selectedCardId = card.id
			mainKey = nil
			choosingMain = false
			awaitingNewCard = nil
		end
		render()
	end)
end

render = function()
	if not panel.Visible then
		return
	end
	clear(list)
	setFilter(activeFilter) -- the switch shows the current choice (UIKit.segmented leaves that to us)
	local all = getCondensableCards()
	local readyCount = 0
	local ready: { [string]: boolean } = {}
	for _, card in all do
		if isReady(card) then
			ready[card.id] = true
			readyCount += 1
		end
	end
	-- Ready cards first (keeping rarest-first order inside each group)
	local cards: { Card } = {}
	for _, card in all do
		if passesFilter(card) then
			table.insert(cards, card)
		end
	end
	local position: { [string]: number } = {}
	for index, card in cards do
		position[card.id] = index
	end
	table.sort(cards, function(a, b)
		if (ready[a.id] == true) ~= (ready[b.id] == true) then
			return ready[a.id] == true
		end
		return position[a.id] < position[b.id]
	end)
	readyBadge.Text = `{readyCount} ready`
	readyBadge.Visible = readyCount > 0
	local selected: Card? = nil
	for _, card in cards do
		if card.id == selectedCardId then
			selected = card
		end
	end
	selected = selected or cards[1]
	selectedCardId = if selected then selected.id else nil
	for order, card in cards do
		buildCardRow(card, order)
	end
	if #cards == 0 then
		local filtering = searchText ~= "" or activeFilter ~= ALL_FILTER
		local message = if filtering then "No cards match." else "No duplicates yet. Rip more packs!"
		local empty = UIKit.label(list, message, Enum.Font.GothamBold, 15, palette.inkSoft)
		empty.Size = UDim2.new(1, -10, 0, 40)
	end
	renderPane(selected)
end

local function close()
	panel.Visible = false
	machine = nil
end

-- Opens the panel for your own Condenser
function CondenserController.Open(part: BasePart)
	machine = part
	selectedCardId = nil
	mainKey = nil
	choosingMain = false
	awaitingNewCard = nil
	inFlight = false
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
			if not part:IsDescendantOf(workspace) or not root or (root.Position - part.Position).Magnitude > CondenserConfig.USE_DISTANCE then
				close()
			end
		end
	end
end

function CondenserController.Start()
	local screenGui = UIController.GetScreenGui()
	panel, list = UIKit.panel(screenGui, "Condenser", "Card Condenser")
	palette = UIKit.colorsFor(panel)
	panel.Size = UDim2.fromScale(0.94, 0.86)
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = PANEL_MAX_SIZE
	end
	Icon.header(panel, "Condenser", UIKit.HEADER_HEIGHT)
	local header = panel:FindFirstChild("Header", true) :: Frame
	readyBadge = UIKit.label(header, "", Enum.Font.FredokaOne, 16, Color3.new(1, 1, 1))
	readyBadge.AnchorPoint = Vector2.new(1, 0.5)
	readyBadge.Position = UDim2.new(1, -64, 0.5, 0) -- clear of the round close button
	readyBadge.Size = UDim2.fromOffset(110, 24)
	readyBadge.TextXAlignment = Enum.TextXAlignment.Right
	readyBadge.ZIndex = header.ZIndex + 2

	-- The toolbar: search by name or #number, then All / Ready / Raising
	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.Position = UDim2.fromOffset(16, TOOLBAR_TOP + (BabyColors.SEGMENTED.hit - SEARCH_HEIGHT) / 2)
	search.Size = UDim2.fromOffset(SEARCH_WIDTH, SEARCH_HEIGHT)
	search.BackgroundColor3 = palette.row
	search.ClearTextOnFocus = false
	search.PlaceholderText = "Search name or #"
	search.Text = ""
	search.Font = Enum.Font.Gotham
	search.TextSize = 14
	search.TextColor3 = palette.ink
	search.PlaceholderColor3 = palette.inkSoft
	search.Parent = panel
	UIKit.corner(search, SEARCH_HEIGHT / 2)
	UIKit.outline(search, palette.rowEdge, 2)
	local searchPadding = Instance.new("UIPadding")
	searchPadding.PaddingLeft = UDim.new(0, 14)
	searchPadding.PaddingRight = UDim.new(0, 14)
	searchPadding.Parent = search
	search:GetPropertyChangedSignal("Text"):Connect(function()
		searchText = search.Text
		render()
	end)
	local switchHolder = Instance.new("Frame")
	switchHolder.Name = "Show"
	switchHolder.BackgroundTransparency = 1
	switchHolder.Position = UDim2.fromOffset(16 + SEARCH_WIDTH + 10, TOOLBAR_TOP)
	switchHolder.Size = UDim2.new(1, -(16 + SEARCH_WIDTH + 10 + 16), 0, BabyColors.SEGMENTED.hit)
	switchHolder.Parent = panel
	local _, pick = UIKit.segmented(switchHolder, { ALL_FILTER, READY_FILTER, RAISING_FILTER }, function(value)
		activeFilter = value
		render()
	end)
	setFilter = pick
	setFilter(activeFilter)

	list.Position = UDim2.fromOffset(12, LIST_TOP)
	list.Size = UDim2.new(LIST_WIDTH_SCALE, -18, 1, -(LIST_TOP + 12))
	-- Room round the rows for the chosen row's ring and a row growing under the mouse (nothing cut off)
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingLeft = UDim.new(0, 6)
	listPadding.PaddingRight = UDim.new(0, EDGE + 6) -- a row grows to the right (its anchor is top-left in the list)
	listPadding.PaddingTop = UDim.new(0, 6)
	listPadding.PaddingBottom = UDim.new(0, 6)
	listPadding.Parent = list

	pane = Instance.new("ScrollingFrame")
	pane.Name = "Details"
	pane.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 0, LIST_TOP)
	pane.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 1, -(LIST_TOP + 12))
	pane.BackgroundColor3 = palette.slotEmpty -- a deeper cream; its rows are white
	pane.BackgroundTransparency = 0
	pane.BorderSizePixel = 0
	pane.ScrollBarThickness = 4
	pane.CanvasSize = UDim2.new()
	pane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pane.Parent = panel
	UIKit.corner(pane, 12)

	-- Condensing changes the binder; redraw with the new counts and stars
	Remotes.ItemsChanged.OnClientEvent:Connect(function(items)
		local count = if typeof(items) == "table" then items.starShard else nil
		shardCount = if typeof(count) == "number" then count else 0
		if shardCount == 0 then
			useShards = false
		end
		if panel.Visible then
			render()
		end
	end)
	Remotes.RequestItems:FireServer() -- our own copy of the shard count, whatever order the controllers start in
	Remotes.CollectionChanged.OnClientEvent:Connect(function()
		task.defer(function() -- after BinderController has stored the new binder
			inFlight = false
			render()
		end)
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then
			machine = nil
		end
	end)
	task.spawn(watchDistance)
end

return CondenserController
