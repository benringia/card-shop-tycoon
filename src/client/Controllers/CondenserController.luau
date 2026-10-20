--!strict
-- Card Condenser panel, marketplace style: cards you can condense on the left; on the right, choose the
-- main copy and see the next star's cost, exactly which duplicates go, and Power and value before ->
-- after. Condense asks the server, which re-checks everything; the binder sync redraws the panel.
-- Opened from your own Condenser's prompt; closes when you walk away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Beasts = require(Config:WaitForChild("Beasts"))
local Cards = require(Config:WaitForChild("Cards"))
local CondenserConfig = require(Config:WaitForChild("Condenser"))
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
-- One copy that can be the main card: a levelled card, or a stack of plain copies (one grade, foil or not)
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
local SUBTITLE_TEXT = "Combine duplicates into one card for +1 star."

local player = Players.LocalPlayer

local CondenserController = {}

local panel: Frame
local subtitle: TextLabel
local list: ScrollingFrame
local pane: ScrollingFrame
local machine: BasePart? = nil
local selectedCardId: string? = nil
local mainKey: string? = nil -- chosen main copy (Candidate.key); nil = the default choice
local inFlight = false -- a Condense request is waiting for the server; the button stays locked
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
	for _, beast in BinderController.GetBeasts() do
		if beast.cardId == card.id then
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

local function getPlan(card: Card, main: Candidate): ({ CondenseRules.Take }?, string?)
	local byGrade = BinderController.GetGradedStacks()[card.id] or {}
	return CondenseRules.plan(Beasts, byGrade, { beast = main.beast ~= nil, foil = main.foil, grade = main.grade, stars = main.stars })
end

-- Whether the default main copy of this card can take a star right now
local function isReady(card: Card): boolean
	local main = getCandidates(card)[1]
	return main ~= nil and (getPlan(card, main)) ~= nil
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

-- Right side ------------------------------------------------------------------------------------------

local function renderPane(card: Card?)
	clear(pane)
	if not card then
		local hint = UIKit.label(pane, "Get two or more copies of a card to condense it. Pick a card on the left.", Enum.Font.GothamBold, 14, UIKit.Colors.Subtext)
		hint.Position = UDim2.fromOffset(10, 10)
		hint.Size = UDim2.new(1, -20, 0, 60)
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

	-- The main copy, large, and its next star
	local faceHolder = Instance.new("Frame")
	faceHolder.Position = UDim2.fromOffset(8, 8)
	faceHolder.Size = UDim2.fromOffset(DETAIL_FACE_SIZE.X, DETAIL_FACE_SIZE.Y)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = pane
	makeFace(faceHolder, card, chosen.foil, true, { level = chosen.level, stars = chosen.stars, grade = chosen.grade })

	local takes, reason = getPlan(card, chosen)
	local nextStars = math.min(chosen.stars + 1, BeastRules.MAX_STARS)
	local powerAfter = BeastRules.getPower(card, chosen.foil, chosen.level, nextStars, chosen.grade)
	local valueNow = BeastRules.getValue(card, chosen.foil, chosen.level, chosen.stars, chosen.grade)
	local valueAfter = BeastRules.getValue(card, chosen.foil, chosen.level, nextStars, chosen.grade)
	local lines = {
		`{card.name}{if chosen.foil then " (FOIL)" else ""}`,
		`{BeastRules.describeGrade(chosen.grade)} · {BeastRules.describeGrowth(chosen.level, chosen.stars)}`,
		`Stars {chosen.stars}/{BeastRules.MAX_STARS} -> {nextStars}/{BeastRules.MAX_STARS}`,
		`Power {chosen.power} -> {powerAfter}`,
		string.format("Value $%.2f -> $%.2f", valueNow, valueAfter),
		if takes then describeTakes(takes) else describeReason(reason),
	}
	local info = UIKit.label(pane, table.concat(lines, "\n"), Enum.Font.GothamBold, 12, UIKit.Colors.Text)
	info.Position = UDim2.fromOffset(DETAIL_FACE_SIZE.X + 16, 8)
	info.Size = UDim2.new(1, -(DETAIL_FACE_SIZE.X + 22), 0, DETAIL_FACE_SIZE.Y)
	info.TextYAlignment = Enum.TextYAlignment.Top

	local y = DETAIL_FACE_SIZE.Y + 16
	local canCondense = takes ~= nil and not inFlight
	local buttonText = if inFlight then "Condensing..." elseif takes then "Condense +1 star" else describeReason(reason)
	local condense = UIKit.button(pane, buttonText, if canCondense then UIKit.Colors.Accent else UIKit.Colors.Locked)
	condense.Position = UDim2.fromOffset(8, y)
	condense.Size = UDim2.new(1, -16, 0, 48)
	condense.TextSize = 16
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
			Remotes.Condense:FireServer(part:GetAttribute("ShelfUid"), card.id, beast.id)
		else
			local before: { [string]: boolean } = {}
			for id in BinderController.GetBeasts() do
				before[id] = true
			end
			awaitingNewCard = { before = before, cardId = card.id, foil = chosen.foil, grade = chosen.grade }
			Remotes.Condense:FireServer(part:GetAttribute("ShelfUid"), card.id, nil, chosen.foil, chosen.grade)
		end
		render()
	end)
	y += 58

	-- Choose the main copy
	local heading = UIKit.label(pane, "Main copy (keeps its grade and level)", Enum.Font.GothamBold, 13, UIKit.Colors.Subtext)
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

-- Left side -------------------------------------------------------------------------------------------

local function buildCardRow(card: Card, order: number)
	local candidates = getCandidates(card)
	local strongest = candidates[1]
	local owned = 0
	for _, candidate in candidates do
		owned += candidate.count
	end
	local takes: { CondenseRules.Take }?, reason: string? = nil, nil
	if strongest then
		takes, reason = getPlan(card, strongest)
	end
	local ready = takes ~= nil
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
	makeFace(thumbnail, card, strongest ~= nil and strongest.foil, false)

	local textX = THUMBNAIL_SIZE.X + 14
	local nameRoom = if ready then 84 else 8 -- leave room for the READY chip
	addLabel(row, card.name, UDim2.fromOffset(textX, 8), UDim2.new(1, -(textX + nameRoom), 0, 20), Enum.Font.GothamBold, 15, UIKit.Colors.Text)
	local status = `Owned {owned}`
	if strongest then
		local cost = BeastRules.getCondenseCost(strongest.stars)
		status ..= if takes and cost then ` · next star: {cost} duplicates` elseif reason == "max" then " · max stars" else ` · {describeReason(reason)}`
	end
	addLabel(row, status, UDim2.fromOffset(textX, 32), UDim2.new(1, -(textX + 8), 0, 18), Enum.Font.Gotham, 12, if ready then READY_COLOR else UIKit.Colors.Subtext)

	-- Can take a star right now: green chip on the row
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
	-- Ready cards first (keeping rarest-first order inside each group)
	local cards = getCondensableCards()
	local readyCount = 0
	local ready: { [string]: boolean } = {}
	for _, card in cards do
		if isReady(card) then
			ready[card.id] = true
			readyCount += 1
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
		then `{readyCount} {if readyCount == 1 then "card" else "cards"} ready to condense · {SUBTITLE_TEXT}`
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
		buildCardRow(card, order)
	end
	if #cards == 0 then
		local empty = UIKit.label(list, "No duplicates yet. Rip more packs!", Enum.Font.GothamBold, 15, UIKit.Colors.Subtext)
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
	panel.Size = UDim2.fromScale(0.94, 0.86)
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = PANEL_MAX_SIZE
	end
	subtitle = UIKit.label(panel, SUBTITLE_TEXT, Enum.Font.Gotham, 14, UIKit.Colors.Subtext)
	subtitle.Position = UDim2.fromOffset(16, 56)
	subtitle.Size = UDim2.new(1, -32, 0, 22)
	list.Position = UDim2.fromOffset(12, 84)
	list.Size = UDim2.new(LIST_WIDTH_SCALE, -18, 1, -96)

	pane = Instance.new("ScrollingFrame")
	pane.Name = "Details"
	pane.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 0, 84)
	pane.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 1, -96)
	pane.BackgroundColor3 = UIKit.Colors.Row
	pane.BackgroundTransparency = 0.4
	pane.BorderSizePixel = 0
	pane.ScrollBarThickness = 4
	pane.CanvasSize = UDim2.new()
	pane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pane.Parent = panel
	UIKit.corner(pane, 10)

	-- Condensing changes the binder; redraw with the new counts and stars
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
