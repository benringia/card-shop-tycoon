--!strict
-- Grading Station panel, laid out like the Condenser's: cards you can grade on the left; on the right, choose the main
-- copy and see the next grade, what it costs (duplicates and cash), exactly which copies go, and Power and value before
-- -> after, plus the whole way to Grade S. Grade Up asks the server, which re-checks everything and takes the cash;
-- the binder sync redraws the panel. Opened from your own Grading Station's prompt; closes when you walk away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Beasts = require(Config:WaitForChild("Beasts"))
local Cards = require(Config:WaitForChild("Cards"))
local GradingConfig = require(Config:WaitForChild("Grading"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CondenseRules = require(Shared:WaitForChild("Util"):WaitForChild("CondenseRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type Card = typeof(Cards.List[1])
type Beast = { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number, grade: string }
-- One copy that can be graded: a levelled card, or a stack of plain copies (one grade, foil or not)
type Candidate = { key: string, beast: Beast?, foil: boolean, grade: string, level: number, stars: number, count: number, power: number }

local PANEL_MAX_SIZE = Vector2.new(820, 520)
local LIST_WIDTH_SCALE = 0.5
local ROW_HEIGHT = 64
local MAIN_ROW_HEIGHT = 48 -- tap target minimum
local THUMBNAIL_SIZE = Vector2.new(40, 56)
local DETAIL_FACE_SIZE = Vector2.new(96, 137)
local DISTANCE_CHECK_SECONDS = 0.5
local VALUE_COLOR = Color3.fromRGB(120, 230, 120)
local READY_COLOR = Color3.fromRGB(60, 200, 110)
local GOLD = Color3.fromRGB(255, 205, 90)
local SUBTITLE_TEXT = "Raise a card's grade with duplicates and cash. Grade S is the best."
local LIST_TOP = 124 -- below the subtitle and the search row

local player = Players.LocalPlayer

local GradingController = {}

local panel: Frame
local subtitle: TextLabel
local list: ScrollingFrame
local pane: ScrollingFrame
local machine: BasePart? = nil
local selectedCardId: string? = nil
local searchText = ""
local mainKey: string? = nil -- chosen main copy (Candidate.key); nil = the default choice
local inFlight = false -- a Grade Up request is waiting for the server; the button stays locked
local inFlightToken = 0
local useSeals = false -- Grading Seals fill missing duplicates (up to half a step)
local sealCount = 0 -- from ItemsChanged

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

local function getCash(): number
	local cash = player:GetAttribute("Cash")
	return if typeof(cash) == "number" then cash else 0
end

local function formatCash(amount: number): string
	local whole = tostring(math.floor(amount))
	local withCommas = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. (withCommas:gsub("^,", ""))
end

-- Every copy of this card that could be graded, highest grade first (the copy you'd most want at S), then strongest
local function getCandidates(card: Card): { Candidate }
	local candidates: { Candidate } = {}
	local working = BinderController.GetWorking()
	for id, beast in BinderController.GetBeasts() do
		if beast.cardId == card.id and not working[id] then -- working cards can't be graded
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

local function getPlan(card: Card, main: Candidate): (CondenseRules.GradePlan?, string?)
	local byGrade = BinderController.GetGradedStacks()[card.id] or {}
	return CondenseRules.gradePlan(GradingConfig, Beasts, card.rarity, byGrade, { beast = main.beast ~= nil, foil = main.foil, grade = main.grade, stars = main.stars }, if useSeals then sealCount else nil)
end

-- The default main copy: the first one that can still go up a grade
local function defaultMain(candidates: { Candidate }): Candidate?
	for _, candidate in candidates do
		if CondenseRules.nextGrade(Beasts.GRADES, candidate.grade) then
			return candidate
		end
	end
	return candidates[1]
end

local function isReady(card: Card): boolean
	local main = defaultMain(getCandidates(card))
	if not main then
		return false
	end
	local plan = getPlan(card, main)
	return plan ~= nil and getCash() >= plan.cash
end

-- Cards you own two or more copies of, or any levelled copy below Grade S. Rarest first.
local function getGradableCards(): { Card }
	local result: { Card } = {}
	for _, card in Cards.RarestFirst do
		local copies, belowTop = 0, false
		for _, candidate in getCandidates(card) do
			copies += candidate.count
			if CondenseRules.nextGrade(Beasts.GRADES, candidate.grade) then
				belowTop = true
			end
		end
		if belowTop and copies >= 2 then
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
		return "Already Grade S"
	end
	local have, need = string.match(reason or "", "^short:(%d+):(%d+)$")
	return if have then `Need {need} duplicates, you have {have}` else "Can't grade this copy"
end

local render: () -> ()

-- Right side ------------------------------------------------------------------------------------------------------

local function renderPane(card: Card?)
	clear(pane)
	if not card then
		local hint = UIKit.label(pane, "Get two or more copies of a card to grade it up. Pick a card on the left.", Enum.Font.GothamBold, 14, UIKit.Colors.Subtext)
		hint.Position = UDim2.fromOffset(10, 10)
		hint.Size = UDim2.new(1, -20, 0, 60)
		return
	end
	local candidates = getCandidates(card)
	local main: Candidate? = nil
	for _, candidate in candidates do
		if candidate.key == mainKey then
			main = candidate
		end
	end
	main = main or defaultMain(candidates)
	if not main then
		return
	end
	local chosen = main :: Candidate

	local faceHolder = Instance.new("Frame")
	faceHolder.Position = UDim2.fromOffset(8, 8)
	faceHolder.Size = UDim2.fromOffset(DETAIL_FACE_SIZE.X, DETAIL_FACE_SIZE.Y)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = pane
	makeFace(faceHolder, card, chosen.foil, true, { level = chosen.level, stars = chosen.stars, grade = chosen.grade })

	local plan, reason = getPlan(card, chosen)
	local nextGrade = CondenseRules.nextGrade(Beasts.GRADES, chosen.grade)
	local cash = getCash()
	local lines = {
		`{card.name}{if chosen.foil then " (FOIL)" else ""}`,
		`{BeastRules.describeGrowth(chosen.level, chosen.stars)}`,
	}
	if nextGrade then
		local powerAfter = BeastRules.getPower(card, chosen.foil, chosen.level, chosen.stars, nextGrade)
		local valueNow = BeastRules.getValue(card, chosen.foil, chosen.level, chosen.stars, chosen.grade)
		local valueAfter = BeastRules.getValue(card, chosen.foil, chosen.level, chosen.stars, nextGrade)
		local step = CondenseRules.gradeStepCost(GradingConfig, card.rarity, nextGrade)
		table.insert(lines, `Grade {chosen.grade} -> {nextGrade}`)
		table.insert(lines, `Power {chosen.power} -> {powerAfter}`)
		table.insert(lines, string.format("Value $%.2f -> $%.2f", valueNow, valueAfter))
		if step then
			table.insert(lines, `Costs {step.copies} {if step.copies == 1 then "copy" else "copies"} + {formatCash(step.cash)}`)
		end
		table.insert(lines, if plan
			then describeTakes(plan.takes) .. (if plan.seals > 0 then ` + {plan.seals} Grading Seal{if plan.seals == 1 then "" else "s"}` else "")
			else describeReason(reason))
	else
		table.insert(lines, "Grade S: the best it can be")
	end
	local info = UIKit.label(pane, table.concat(lines, "\n"), Enum.Font.GothamBold, 12, UIKit.Colors.Text)
	info.Position = UDim2.fromOffset(DETAIL_FACE_SIZE.X + 16, 8)
	info.Size = UDim2.new(1, -(DETAIL_FACE_SIZE.X + 22), 0, DETAIL_FACE_SIZE.Y)
	info.TextYAlignment = Enum.TextYAlignment.Top

	local y = DETAIL_FACE_SIZE.Y + 16
	local affordable = plan ~= nil and cash >= plan.cash
	local canGrade = affordable and not inFlight
	local buttonText = if inFlight then "Grading..."
		elseif plan and not affordable then `Need {formatCash(plan.cash)} (you have {formatCash(cash)})`
		elseif plan then `Grade up to {plan.grade} · {formatCash(plan.cash)}`
		else describeReason(reason)
	local gradeButton = UIKit.button(pane, buttonText, if canGrade then UIKit.Colors.Accent else UIKit.Colors.Locked)
	gradeButton.Position = UDim2.fromOffset(8, y)
	gradeButton.Size = UDim2.new(1, -16, 0, 48)
	gradeButton.TextSize = 16
	gradeButton.AutoButtonColor = canGrade
	gradeButton.Activated:Connect(function()
		local part = machine
		if not canGrade or inFlight or not part then
			return
		end
		-- Locked until the binder sync arrives (or a timeout if the server refused), so a second tap can't send the
		-- same stale request
		inFlight = true
		inFlightToken += 1
		local token = inFlightToken
		task.delay(GradingConfig.IN_FLIGHT_TIMEOUT, function()
			if token == inFlightToken and inFlight then
				inFlight = false
				render()
			end
		end)
		local beast = chosen.beast
		if beast then
			Remotes.GradeUp:FireServer(part:GetAttribute("ShelfUid"), card.id, beast.id, nil, nil, useSeals)
		else
			-- A plain copy moves up to the next grade's stack: keep following it there
			mainKey = `stack:{plan and plan.grade or chosen.grade}:{chosen.foil}`
			Remotes.GradeUp:FireServer(part:GetAttribute("ShelfUid"), card.id, nil, chosen.foil, chosen.grade, useSeals)
		end
		render()
	end)
	y += 58

	-- Grading Seals toggle: they fill in for missing duplicates (never more than half a step)
	local hasSeals = sealCount > 0
	local sealText = if not hasSeals then "🏅 No Grading Seals (bosses drop them)"
		elseif useSeals and plan and plan.seals == 0 then `🏅 Seals not needed here (you have {sealCount})`
		elseif useSeals and not plan and reason and string.sub(reason, 1, 5) == "short" then `🏅 Too few duplicates even with seals (max half a step)`
		elseif useSeals then `🏅 Using Grading Seals (you have {sealCount})`
		else `🏅 Use Grading Seals (you have {sealCount})`
	local sealButton = UIKit.button(pane, sealText, if useSeals and hasSeals then UIKit.Colors.Accent else UIKit.Colors.Row)
	sealButton.Position = UDim2.fromOffset(8, y)
	sealButton.Size = UDim2.new(1, -16, 0, 48)
	sealButton.TextSize = 14
	sealButton.AutoButtonColor = hasSeals
	sealButton.Activated:Connect(function()
		if hasSeals then
			useSeals = not useSeals
			render()
		end
	end)
	y += 58

	-- The whole way to Grade S from here
	if nextGrade then
		local top = CondenseRules.gradeCostToTop(GradingConfig, Beasts.GRADES, card.rarity, chosen.grade)
		local path = addLabel(pane, `To Grade S: {top.copies} {if top.copies == 1 then "copy" else "copies"} + {formatCash(top.cash)} in all`, UDim2.fromOffset(10, y), UDim2.new(1, -20, 0, 20), Enum.Font.GothamBold, 13, GOLD)
		path.TextXAlignment = Enum.TextXAlignment.Left
		y += 26
	end

	-- Choose the main copy
	local heading = UIKit.label(pane, "Copy to grade (keeps its level and stars)", Enum.Font.GothamBold, 13, UIKit.Colors.Subtext)
	heading.Position = UDim2.fromOffset(10, y)
	heading.Size = UDim2.new(1, -20, 0, 18)
	y += 22
	for _, candidate in candidates do
		local row = Instance.new("TextButton")
		row.Position = UDim2.fromOffset(8, y)
		row.Size = UDim2.new(1, -16, 0, MAIN_ROW_HEIGHT)
		row.BackgroundColor3 = UIKit.Colors.Row
		row.Text = ""
		row.Parent = pane
		UIKit.corner(row, 8)
		if candidate.key == chosen.key then
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = UIKit.Colors.Accent
			stroke.Thickness = 2
			stroke.Parent = row
		end
		local title = `{if candidate.foil then "FOIL · " else ""}{BeastRules.describeGrade(candidate.grade)} · {BeastRules.describeGrowth(candidate.level, candidate.stars)}`
		if not candidate.beast then
			title ..= ` · x{candidate.count}`
		end
		addLabel(row, title, UDim2.fromOffset(10, 0), UDim2.new(1, -100, 1, 0), Enum.Font.GothamBold, 13, UIKit.Colors.Text)
		local power = addLabel(row, `Power {candidate.power}`, UDim2.new(1, -94, 0, 0), UDim2.new(0, 86, 1, 0), Enum.Font.GothamBold, 12, VALUE_COLOR)
		power.TextXAlignment = Enum.TextXAlignment.Right
		row.Activated:Connect(function()
			mainKey = candidate.key
			render()
		end)
		y += MAIN_ROW_HEIGHT + 6
	end
end

-- Left side -------------------------------------------------------------------------------------------------------

local function buildCardRow(card: Card, order: number, ready: boolean)
	local candidates = getCandidates(card)
	local main = defaultMain(candidates)
	local owned = 0
	for _, candidate in candidates do
		owned += candidate.count
	end
	local row = Instance.new("TextButton")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
	row.BackgroundColor3 = UIKit.Colors.Row
	row.Text = ""
	row.Parent = list
	UIKit.corner(row, 8)
	if card.id == selectedCardId then
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = UIKit.Colors.Accent
		stroke.Thickness = 2
		stroke.Parent = row
	end
	local thumbnail = Instance.new("Frame")
	thumbnail.Position = UDim2.fromOffset(6, 4)
	thumbnail.Size = UDim2.fromOffset(THUMBNAIL_SIZE.X, THUMBNAIL_SIZE.Y)
	thumbnail.BackgroundTransparency = 1
	thumbnail.Parent = row
	makeFace(thumbnail, card, main ~= nil and main.foil, false)

	local textX = THUMBNAIL_SIZE.X + 14
	local nameRoom = if ready then 84 else 8 -- leave room for the READY chip
	addLabel(row, card.name, UDim2.fromOffset(textX, 8), UDim2.new(1, -(textX + nameRoom), 0, 20), Enum.Font.GothamBold, 15, UIKit.Colors.Text)
	local status = `Owned {owned}`
	if main then
		local nextGrade = CondenseRules.nextGrade(Beasts.GRADES, main.grade)
		local step = if nextGrade then CondenseRules.gradeStepCost(GradingConfig, card.rarity, nextGrade) else nil
		if nextGrade and step then
			status ..= ` · {main.grade} -> {nextGrade}: {step.copies} + {formatCash(step.cash)}`
		end
	end
	addLabel(row, status, UDim2.fromOffset(textX, 32), UDim2.new(1, -(textX + 8), 0, 18), Enum.Font.Gotham, 12, if ready then READY_COLOR else UIKit.Colors.Subtext)

	if ready then
		local chip = UIKit.label(row, "READY", Enum.Font.GothamBold, 12, UIKit.Colors.Text)
		chip.AnchorPoint = Vector2.new(1, 0)
		chip.Position = UDim2.new(1, -8, 0, 8)
		chip.Size = UDim2.fromOffset(68, 20)
		chip.TextXAlignment = Enum.TextXAlignment.Center
		chip.BackgroundColor3 = READY_COLOR
		chip.BackgroundTransparency = 0
		UIKit.corner(chip, 6)
	end

	row.Activated:Connect(function()
		if selectedCardId ~= card.id then
			selectedCardId = card.id
			mainKey = nil
		end
		render()
	end)
end

local function passesSearch(card: Card): boolean
	if searchText == "" then
		return true
	end
	local query = string.lower(searchText)
	local number = tonumber((string.gsub(query, "#", "")))
	return string.find(string.lower(card.name), query, 1, true) ~= nil or number == card.number
end

render = function()
	if not panel.Visible then
		return
	end
	clear(list)
	-- Ready cards first, keeping rarest-first order inside each group
	local cards: { Card } = {}
	local ready: { [string]: boolean } = {}
	local readyCount = 0
	for _, card in getGradableCards() do
		if passesSearch(card) then
			table.insert(cards, card)
			if isReady(card) then
				ready[card.id] = true
				readyCount += 1
			end
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
	subtitle.Text = if readyCount > 0
		then `{readyCount} {if readyCount == 1 then "card" else "cards"} ready to grade · {SUBTITLE_TEXT}`
		else SUBTITLE_TEXT
	subtitle.TextColor3 = if readyCount > 0 then READY_COLOR else UIKit.Colors.Subtext
	local selected: Card? = nil
	for _, card in cards do
		if card.id == selectedCardId then
			selected = card
		end
	end
	selected = selected or cards[1]
	selectedCardId = if selected then selected.id else nil
	for order, card in cards do
		buildCardRow(card, order, ready[card.id] == true)
	end
	if #cards == 0 then
		local message = if searchText ~= "" then "No cards match." else "No duplicates yet. Rip more packs!"
		local empty = UIKit.label(list, message, Enum.Font.GothamBold, 15, UIKit.Colors.Subtext)
		empty.Size = UDim2.new(1, -10, 0, 40)
	end
	renderPane(selected)
end

local function close()
	panel.Visible = false
	machine = nil
end

-- Opens the panel for your own Grading Station
function GradingController.Open(part: BasePart)
	machine = part
	selectedCardId = nil
	mainKey = nil
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
			if not part:IsDescendantOf(workspace) or not root or (root.Position - part.Position).Magnitude > GradingConfig.USE_DISTANCE then
				close()
			end
		end
	end
end

function GradingController.Start()
	local screenGui = UIController.GetScreenGui()
	panel, list = UIKit.panel(screenGui, "GradingStation", "🏅 Grading Station")
	panel.Size = UDim2.fromScale(0.94, 0.86)
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = PANEL_MAX_SIZE
	end
	subtitle = UIKit.label(panel, SUBTITLE_TEXT, Enum.Font.Gotham, 14, UIKit.Colors.Subtext)
	subtitle.Position = UDim2.fromOffset(16, 56)
	subtitle.Size = UDim2.new(1, -32, 0, 22)
	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.Position = UDim2.fromOffset(16, 82)
	search.Size = UDim2.fromOffset(220, 34)
	search.BackgroundColor3 = UIKit.Colors.Row
	search.ClearTextOnFocus = false
	search.PlaceholderText = "Search name or #"
	search.Text = ""
	search.Font = Enum.Font.Gotham
	search.TextSize = 14
	search.TextColor3 = UIKit.Colors.Text
	search.PlaceholderColor3 = UIKit.Colors.Subtext
	search.Parent = panel
	UIKit.corner(search, 8)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		searchText = search.Text
		render()
	end)

	list.Position = UDim2.fromOffset(12, LIST_TOP)
	list.Size = UDim2.new(LIST_WIDTH_SCALE, -18, 1, -(LIST_TOP + 12))

	pane = Instance.new("ScrollingFrame")
	pane.Name = "Details"
	pane.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 0, LIST_TOP)
	pane.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 1, -(LIST_TOP + 12))
	pane.BackgroundColor3 = UIKit.Colors.Row
	pane.BackgroundTransparency = 0.4
	pane.BorderSizePixel = 0
	pane.ScrollBarThickness = 4
	pane.CanvasSize = UDim2.new()
	pane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pane.Parent = panel
	UIKit.corner(pane, 10)

	-- Seals come and go with the item inventory
	Remotes.ItemsChanged.OnClientEvent:Connect(function(items)
		local count = if typeof(items) == "table" then items.gradingSeal else nil
		sealCount = if typeof(count) == "number" then count else 0
		if sealCount == 0 then
			useSeals = false
		end
		if panel.Visible then
			render()
		end
	end)
	Remotes.RequestItems:FireServer() -- our own copy of the seal count, whatever order the controllers start in
	-- Grading changes the binder (and the cash): redraw
	Remotes.CollectionChanged.OnClientEvent:Connect(function()
		task.defer(function() -- after BinderController has stored the new binder
			inFlight = false
			render()
		end)
	end)
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		if panel.Visible then
			render()
		end
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then
			machine = nil
		end
	end)
	task.spawn(watchDistance)
end

return GradingController
