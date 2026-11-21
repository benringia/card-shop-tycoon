--!strict
-- Grading Station panel, laid out like the Condenser's: cards you can grade on the left, the chosen card's recipe on
-- the right. A picture recipe since 2026-11-20 (owner: "in grading station window. redesign it like the condenser to
-- be easily understood. it's currently so confusing"; Util/Recipe, words and spots in Util/CondenseRules): one
-- sentence ("Use 2 extra Voidmaw and $2,500 to make it Grade A!"), the copies that go in as little cards with the
-- cash under them, an arrow, the card with its new grade beating under it, how much Power it adds, and one big
-- "Make it Grade A!" with how long it takes. Grading Seals are tapped into empty spots; a Gold Seal, the grade swap
-- (Config/Grading SWAP) and "Keep a different copy" are small buttons under it. A row shows the card's grade and a
-- gold Ready!, "2 more" with a bar, "Need cash" or Top grade. A finished grade waits here like the Condenser's star
-- (Util/DoneReveal, the GradingDone attribute). Grade Up asks the server, which re-checks everything and takes the
-- cash; the binder sync redraws the panel. Opened from your own Grading Station's prompt; closes when you walk away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Early = require(Config:WaitForChild("Early"))
local EarlyRules = require(Shared:WaitForChild("Util"):WaitForChild("EarlyRules"))
local Beasts = require(Config:WaitForChild("Beasts"))
local Cards = require(Config:WaitForChild("Cards"))
local GradingConfig = require(Config:WaitForChild("Grading"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CondenseRules = require(Shared:WaitForChild("Util"):WaitForChild("CondenseRules"))
local Upgrades = require(Config:WaitForChild("Upgrades"))
local UpgradeRules = require(Shared:WaitForChild("Util"):WaitForChild("UpgradeRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local JobPanel = require(ClientUtil:WaitForChild("JobPanel"))
local DoneReveal = require(ClientUtil:WaitForChild("DoneReveal"))
local Recipe = require(ClientUtil:WaitForChild("Recipe"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
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
local SUBTITLE_TEXT = GradingConfig.EXPLAIN
local RECIPE = Recipe.LOOK -- the recipe on the right (Util/Recipe, shared with the Condenser)
local BAR_HEIGHT = 6
local SIDE = 10 -- the pane's things keep this far from its edges, so no outline or lifted button is cut
-- The pane fits its window with nothing cut (owner 2026-11-20: "fix upgrading stations cutoff borders"; the window is
-- 520 px tall before its own scale, the pane 384): the sentence, the recipe, the helper chips, the button, the link
local SAY_HEIGHT = 46
local HELPER = 46 -- the Grading Seals' and Gold Seals' chips (a tap target with the gap under them)
-- A phone (owner 2026-11-21, the night's device check: on a 705 x 338 phone the window was 241 px tall with 105 for
-- its list and its recipe, the big button far under the fold): the window takes nearly the whole screen, the rows over
-- the list go, the recipe is smaller and the big button sits pinned under the pane (`actionBar`), as in the Forge
local PHONE_FACE = Vector2.new(66, 94)
local PHONE_SAY = 38 -- the sentence's room (two lines of smaller words)
local LIST_TOP = 124 -- below the subtitle and the search row

local player = Players.LocalPlayer

local GradingController = {}

local panel: Frame
local palette: UIKit.Palette -- the cream window's colours (UIKit.colorsFor), set in Start
local subtitle: TextLabel
local list: ScrollingFrame
local pane: ScrollingFrame
local actionBar: Frame -- a phone: the big button, pinned under the pane
local search: TextBox
local machine: BasePart? = nil
local selectedCardId: string? = nil
local searchText = ""
local mainKey: string? = nil -- chosen main copy (Candidate.key); nil = the default choice
local inFlight = false -- a Grade Up request is waiting for the server; the button stays locked
local inFlightToken = 0
local useSeals = false -- Grading Seals fill missing duplicates (up to half a step)
local sealCount = 0 -- from ItemsChanged
local useGold = false -- a Gold Seal pays the step's cash (not a Legendary's A to S)
local choosingMain = false -- Keep a different copy: the copies show in place of the recipe
local goldCount = 0

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

-- A finished grade waiting in the Grading Station: its reveal over the window (Util/DoneReveal), set up in Start
local refreshDone: (opened: boolean?) -> () = function() end

local render: () -> ()

-- Right side ------------------------------------------------------------------------------------------------------

local function renderPane(card: Card?)
	clear(pane)
	clear(actionBar)
	local phone = UIKit.isShort()
	local face = if phone then PHONE_FACE else DETAIL_FACE_SIZE
	local sayTop = if phone then PHONE_SAY else SAY_HEIGHT
	if not card then
		local hint = UIKit.label(pane, "Get two or more copies of a card to grade it up. Pick a card on the left.", Enum.Font.GothamBold, 14, palette.inkSoft)
		hint.Position = UDim2.fromOffset(10, 10)
		hint.Size = UDim2.new(1, -20, 0, 60)
		hint.TextWrapped = true
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

	-- What goes in: the plan's copies and seals when the grade can be raised, else the copies there are (and, with the
	-- seals in, as many as may stand in)
	local byGrade = BinderController.GetGradedStacks()[card.id] or {}
	local asMain = { beast = chosen.beast ~= nil, foil = chosen.foil, grade = chosen.grade, stars = chosen.stars }
	local plan = getPlan(card, chosen)
	local nextGrade = CondenseRules.nextGrade(Beasts.GRADES, chosen.grade)
	local step = if nextGrade then CondenseRules.gradeStepCost(GradingConfig, card.rarity, nextGrade) else nil
	local need = if step then step.copies else 0
	local have = math.min(need, CondenseRules.gradeHave(Beasts, byGrade, asMain))
	local share = GradingConfig.MAX_SEAL_SHARE or 0
	local sealsIn = if plan then plan.seals elseif useSeals then math.max(0, math.min(sealCount, math.floor(need * share), need - have)) else 0
	local copiesIn = if plan then need - plan.seals else have
	local offers = CondenseRules.shardOffers(need, have, sealCount, share, useSeals)
	local missing = if plan or not nextGrade then 0 else need - copiesIn - sealsIn
	local could = not useSeals and plan == nil and nextGrade ~= nil and (CondenseRules.gradePlan(GradingConfig, Beasts, card.rarity, byGrade, asMain, sealCount)) ~= nil
	local cash = getCash()
	local price = if step then step.cash else 0
	local goldAllowed = nextGrade ~= nil and CondenseRules.goldSealAllowed(card.rarity, nextGrade)
	local goldPays = useGold and goldCount > 0 and goldAllowed
	local affordable = goldPays or cash >= price
	local canGrade = plan ~= nil and affordable and not inFlight

	-- one sentence: what will happen
	local sentence = if choosingMain then "Which copy do you want to grade? Tap it." else CondenseRules.gradeSay({ name = card.name, grade = nextGrade, copies = copiesIn, seals = sealsIn, cash = formatCash(price), missing = missing, gold = goldPays })
	local say = UIKit.label(pane, sentence, Enum.Font.FredokaOne, if phone then 13 else 16, palette.ink)
	say.Name = "Say"
	say.Position = UDim2.fromOffset(10, 6)
	say.Size = UDim2.new(1, -20, 0, sayTop - 8)
	say.TextWrapped = true
	say.TextXAlignment = Enum.TextXAlignment.Center

	local y = sayTop
	-- Keep a different copy: the copies that could be graded, in place of the recipe
	if choosingMain then
		for _, candidate in candidates do
			local row = Instance.new("TextButton")
			row.Position = UDim2.fromOffset(8, y)
			row.Size = UDim2.new(1, -16, 0, MAIN_ROW_HEIGHT)
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
		local back = UIKit.button(pane, "Back", UIKit.Colors.Secondary)
		back.AnchorPoint = Vector2.new(0.5, 0)
		back.Position = UDim2.new(0.5, 0, 0, y + 4)
		back.Size = UDim2.fromOffset(160, 48)
		back.Activated:Connect(function()
			choosingMain = false
			render()
		end)
		return
	end

	-- The recipe: the spots, an arrow, the card that gets the grade (alone once it is Grade S)
	local wide = if nextGrade then RECIPE.slots.X + RECIPE.arrow + face.X else face.X
	local recipe = Instance.new("Frame")
	recipe.Name = "Recipe"
	recipe.BackgroundTransparency = 1
	recipe.AnchorPoint = Vector2.new(0.5, 0)
	recipe.Position = UDim2.new(0.5, 0, 0, y)
	recipe.Size = UDim2.fromOffset(wide, face.Y + RECIPE.under)
	recipe.Parent = pane
	local faceHolder = Instance.new("Frame")
	faceHolder.Name = "Keeps"
	faceHolder.AnchorPoint = Vector2.new(1, 0)
	faceHolder.Position = UDim2.fromScale(1, 0)
	faceHolder.Size = UDim2.fromOffset(face.X, face.Y)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = recipe
	makeFace(faceHolder, card, chosen.foil, false, { level = chosen.level, stars = chosen.stars, grade = chosen.grade })
	-- under the card: the grade it becomes, beating (or the one it has, at the top)
	local gradePill = UIKit.pill(recipe, BeastRules.describeGrade(nextGrade or chosen.grade), UIKit.Colors.Accent, UIKit.Colors.Ink)
	gradePill.Name = "Grade"
	gradePill.AnchorPoint = Vector2.new(0.5, 0.5) -- it beats about its middle, clear of the card and the chips under it
	gradePill.Position = UDim2.new(1, -face.X / 2, 0, face.Y + 18)
	if nextGrade then
		Recipe.beat(gradePill)
	end

	local spots: { GuiObject } = {}
	if nextGrade then
		local grid = Recipe.grid(recipe, need, CondenseRules.slotColumns(need), Vector2.new(RECIPE.slots.X, face.Y))
		local copies: { CondenseRules.Take } = {}
		for _, take in if plan then plan.takes else {} do
			for _ = 1, take.count do
				table.insert(copies, take)
			end
		end
		for index, kind in CondenseRules.slots(need, copiesIn, sealsIn, offers) do
			local take = copies[index]
			local spot = Recipe.spot(grid, if kind == "shard" then "item" else kind, {
				order = index,
				palette = palette,
				image = if kind == "copy" then CardFace.artImage(card) else nil,
				foil = take ~= nil and take.foil,
				icon = "GradingSeal",
				onTap = function()
					useSeals = kind == "offer"
					render()
				end,
			})
			if kind == "copy" or kind == "shard" then
				table.insert(spots, spot)
			end
		end
		Recipe.arrow(recipe, RECIPE.slots.X + RECIPE.arrow / 2, face.Y / 2)
		-- under the spots: the cash it takes (red when you don't have it), or the Gold Seal paying it
		-- ...and beside it how much stronger the card gets
		local under = Instance.new("Frame")
		under.Name = "Under"
		under.BackgroundTransparency = 1
		under.Position = UDim2.fromOffset(0, face.Y + 6)
		under.Size = UDim2.fromOffset(RECIPE.slots.X + RECIPE.arrow, 24)
		under.Parent = recipe
		local underLayout = Instance.new("UIListLayout")
		underLayout.FillDirection = Enum.FillDirection.Horizontal
		underLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		underLayout.SortOrder = Enum.SortOrder.LayoutOrder
		underLayout.Padding = UDim.new(0, 6)
		underLayout.Parent = under
		local cashPill = UIKit.pill(under, if goldPays then "Gold Seal" else formatCash(price), if affordable then palette.row else palette.bad, if affordable then palette.ink else Color3.new(1, 1, 1))
		cashPill.Name = "Cash"
		cashPill.LayoutOrder = 1
		local powerAfter = BeastRules.getPower(card, chosen.foil, chosen.level, chosen.stars, nextGrade)
		local chip = UIKit.pill(under, `+{math.max(0, powerAfter - chosen.power)} Power`, palette.good, Color3.new(1, 1, 1))
		chip.Name = "Power"
		chip.LayoutOrder = 2
	end
	y += face.Y + RECIPE.under + 6

	-- The helpers, over the button so they're seen (owner 2026-11-20: "whats the use of grading seals? I cant see it
	-- inside the grading station", "also the golden seall or something"): a chip each for Grading Seals (a tap puts
	-- them in the empty spots, or takes them out) and Gold Seals (a tap pays the cash with one), with their picture,
	-- how many you have and what the tap does
	local goldAllowedHere = goldAllowed
	local sealTitle, sealSub = CondenseRules.sealChip({ have = sealCount, on = useSeals, used = sealsIn, offers = offers, could = could, missing = missing, max = nextGrade == nil })
	local goldTitle, goldSub = CondenseRules.goldChip(goldCount, goldPays, goldAllowedHere, nextGrade == nil)
	local helpers: { { name: string, icon: string, title: string, sub: string, lit: boolean, tap: (() -> ())? } } = {}
	if sealTitle then
		table.insert(helpers, {
			name = "Seals",
			icon = "GradingSeal",
			title = sealTitle,
			sub = sealSub or "",
			lit = sealsIn > 0,
			tap = if useSeals or offers > 0 then function()
				useSeals = not useSeals
				render()
			end else nil,
		})
	end
	if goldTitle then
		table.insert(helpers, {
			name = "Gold",
			icon = "GoldSeal",
			title = goldTitle,
			sub = goldSub or "",
			lit = goldPays,
			tap = if goldAllowedHere then function()
				useGold = not useGold
				render()
			end else nil,
		})
	end
	for index, helper in helpers do
		local chip = Instance.new("TextButton")
		chip.Name = helper.name
		chip.Text = ""
		chip.AutoButtonColor = helper.tap ~= nil
		chip.BackgroundColor3 = if helper.lit then Color3.fromRGB(255, 240, 196) else palette.row
		-- one fills the row; two share it
		chip.Position = UDim2.new(if index == 1 then 0 else 0.5, if index == 1 then SIDE else 3, 0, y)
		chip.Size = UDim2.new(if #helpers == 1 then 1 else 0.5, if #helpers == 1 then -2 * SIDE else -(SIDE + 3), 0, HELPER)
		chip.Parent = pane
		UIKit.corner(chip, 10)
		UIKit.outline(chip, if helper.lit then UIKit.Colors.Accent else palette.rowEdge, 2)
		local picture = Icon.make(chip, helper.icon, UDim2.fromOffset(28, 28))
		picture.AnchorPoint = Vector2.new(0, 0.5)
		picture.Position = UDim2.new(0, 7, 0.5, 0)
		local title = UIKit.label(chip, helper.title, Enum.Font.FredokaOne, 13, palette.ink)
		title.Position = UDim2.fromOffset(41, 6)
		title.Size = UDim2.new(1, -45, 0, 16)
		title.TextWrapped = false
		title.TextTruncate = Enum.TextTruncate.AtEnd
		local sub = UIKit.label(chip, helper.sub, Enum.Font.GothamBold, 11, palette.inkSoft)
		sub.Position = UDim2.fromOffset(41, 23)
		sub.Size = UDim2.new(1, -45, 0, 16)
		sub.TextWrapped = false
		sub.TextTruncate = Enum.TextTruncate.AtEnd
		if helper.tap then
			chip.Activated:Connect(helper.tap)
		end
	end
	if #helpers > 0 then
		y += HELPER + 6
	end

	-- The big button: Make it Grade A! and how long it takes, or what's missing
	local seconds = if nextGrade then EarlyRules.stationWait(UpgradeRules.seconds(Upgrades, "grade", nextGrade, card.rarity), tonumber(player:GetAttribute("Level")) or 1, Early) else 0
	local buttonText, buttonSub = CondenseRules.gradeButton({ inFlight = inFlight, grade = nextGrade, cash = formatCash(price), have = formatCash(cash), affordable = affordable, missing = missing, seconds = seconds })
	local gradeButton = UIKit.button(if phone then actionBar else pane, buttonText, if canGrade then UIKit.Colors.Accent else UIKit.Colors.Locked)
	gradeButton.Name = "GradeUp"
	gradeButton.Position = UDim2.fromOffset(8, if phone then 4 else y)
	gradeButton.Size = UDim2.new(1, -16, 0, RECIPE.button)
	gradeButton.AutoButtonColor = canGrade
	Recipe.words(gradeButton, buttonText, buttonSub)
	-- Locked until the binder sync arrives (or a timeout if the server refused), so a second tap can't send the same
	-- stale request
	local function lock()
		inFlight = true
		inFlightToken += 1
		local token = inFlightToken
		task.delay(GradingConfig.IN_FLIGHT_TIMEOUT, function()
			if token == inFlightToken and inFlight then
				inFlight = false
				render()
			end
		end)
	end
	gradeButton.Activated:Connect(function()
		local part = machine
		if not canGrade or inFlight or not part then
			return
		end
		Recipe.flyIn(panel, spots, faceHolder)
		lock()
		local beast = chosen.beast
		if beast then
			Remotes.GradeUp:FireServer(part:GetAttribute("ShelfUid"), card.id, beast.id, nil, nil, useSeals, goldPays)
		else
			-- A plain copy moves up to the next grade's stack: keep following it there
			mainKey = `stack:{plan and plan.grade or chosen.grade}:{chosen.foil}`
			Remotes.GradeUp:FireServer(part:GetAttribute("ShelfUid"), card.id, nil, chosen.foil, chosen.grade, useSeals, goldPays)
		end
		render()
	end)
	if not phone then
		y += RECIPE.button + 8
	end

	-- The grade swap (Config/Grading SWAP; owner 2026-11-20): a levelled or starred card takes the grade of a better
	-- spare copy. Offered only when there is one
	local swapPlan = CondenseRules.swapPlan(GradingConfig, Beasts, card.rarity, byGrade, asMain)
	if swapPlan then
		local swapGrade = swapPlan.grade
		local swapAffordable = cash >= swapPlan.cash
		local canSwap = swapAffordable and not inFlight
		local line = addLabel(pane, CondenseRules.swapLine(swapGrade), UDim2.fromOffset(10, y), UDim2.new(1, -20, 0, 34), Enum.Font.GothamBold, 12, palette.inkSoft)
		line.TextWrapped = true
		line.TextTruncate = Enum.TextTruncate.None
		line.TextXAlignment = Enum.TextXAlignment.Center
		y += 36
		local swapSeconds = EarlyRules.stationWait(UpgradeRules.seconds(Upgrades, "grade", swapGrade, card.rarity), tonumber(player:GetAttribute("Level")) or 1, Early)
		local swapText, swapSub = CondenseRules.swapWords({ grade = swapGrade, cash = formatCash(swapPlan.cash), seconds = swapSeconds, affordable = swapAffordable, inFlight = inFlight })
		local swapButton = UIKit.button(pane, swapText, if canSwap then UIKit.Colors.Secondary else UIKit.Colors.Locked)
		swapButton.Name = "Swap"
		swapButton.Position = UDim2.fromOffset(8, y)
		swapButton.Size = UDim2.new(1, -16, 0, RECIPE.button)
		swapButton.AutoButtonColor = canSwap
		Recipe.words(swapButton, swapText, swapSub)
		swapButton.Activated:Connect(function()
			local part = machine
			local beast = chosen.beast
			if not canSwap or inFlight or not part or not beast then
				return
			end
			lock()
			Remotes.GradeUp:FireServer(part:GetAttribute("ShelfUid"), card.id, beast.id, nil, nil, false, false, true)
			render()
		end)
		y += RECIPE.button + 8
	end

	-- for players who mind which copy is graded (its level, its stars): a small link
	if #candidates > 1 then
		local change = Instance.new("TextButton")
		change.Name = "Change"
		change.AnchorPoint = Vector2.new(0.5, 0)
		change.Position = UDim2.new(0.5, 0, 0, y)
		change.Size = UDim2.fromOffset(220, 44)
		change.BackgroundTransparency = 1
		change.Font = Enum.Font.GothamBold
		change.TextSize = 13
		change.RichText = true
		change.Text = "<u>Keep a different copy</u>"
		change.TextColor3 = palette.hint
		change.Parent = pane
		change.Activated:Connect(function()
			choosingMain = true
			render()
		end)
		y += 44
	end
	local bottom = Instance.new("Frame") -- keeps room under the last button for its hover grow
	bottom.BackgroundTransparency = 1
	bottom.Position = UDim2.fromOffset(0, y + 1)
	bottom.Size = UDim2.fromOffset(1, 1)
	bottom.Parent = pane
end

-- Left side -------------------------------------------------------------------------------------------------------

local function buildCardRow(card: Card, order: number, ready: boolean)
	local candidates = getCandidates(card)
	local main = defaultMain(candidates)
	local row = Instance.new("TextButton")
	row.Name = "Card_" .. card.id
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = palette.row
	row.Text = ""
	row.Parent = list
	UIKit.corner(row, 12)
	local selected = card.id == selectedCardId
	UIKit.outline(row, if selected then UIKit.Colors.Accent else palette.rowEdge, if selected then 3 else 2)
	local thumbnail = Instance.new("Frame")
	thumbnail.Position = UDim2.fromOffset(6, 4)
	thumbnail.Size = UDim2.fromOffset(THUMBNAIL_SIZE.X, THUMBNAIL_SIZE.Y)
	thumbnail.BackgroundTransparency = 1
	thumbnail.Parent = row
	makeFace(thumbnail, card, main ~= nil and main.foil, false)

	-- its grade under its name, and on the right a gold Ready!, how many more copies, Need cash, or Top grade
	local nextGrade = if main then CondenseRules.nextGrade(Beasts.GRADES, main.grade) else nil
	local step = if nextGrade then CondenseRules.gradeStepCost(GradingConfig, card.rarity, nextGrade) else nil
	local need = if step then step.copies else 0
	local have = 0
	if main then
		have = math.min(need, CondenseRules.gradeHave(Beasts, BinderController.GetGradedStacks()[card.id] or {}, { beast = main.beast ~= nil, foil = main.foil, grade = main.grade, stars = main.stars }))
	end
	local cashOk = step == nil or getCash() >= step.cash
	local tagText, tagKind, share = CondenseRules.gradeRowTag(have, need, nextGrade, ready, cashOk)
	local textX = THUMBNAIL_SIZE.X + 14
	addLabel(row, card.name, UDim2.fromOffset(textX, 8), UDim2.new(1, -(textX + 96), 0, 20), Enum.Font.FredokaOne, 16, palette.ink)
	local words = if main and nextGrade then `{BeastRules.describeGrade(main.grade)} · next: {BeastRules.describeGrade(nextGrade)}` elseif main then BeastRules.describeGrade(main.grade) else ""
	addLabel(row, words, UDim2.fromOffset(textX, 30), UDim2.new(1, -(textX + 10), 0, 16), Enum.Font.GothamBold, 12, palette.inkSoft)
	local gold = tagKind == "ready"
	local tag = UIKit.pill(row, tagText, if gold then UIKit.Colors.Accent else palette.track, if gold then UIKit.Colors.Ink else palette.inkSoft)
	tag.Name = "Tag"
	tag.AnchorPoint = Vector2.new(1, 0)
	tag.Position = UDim2.new(1, -10, 0, 8)
	tag.TextSize = 12
	if tagKind == "wait" then
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
	end

	row.Activated:Connect(function()
		if selectedCardId ~= card.id then
			selectedCardId = card.id
			mainKey = nil
			choosingMain = false
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

local listToTop = false -- the next render starts the list at its top

render = function()
	if not panel.Visible then
		return
	end
	-- the list stays where the player scrolled it (the Condenser's fix, owner 2026-11-20: a tap on a card rebuilt the
	-- rows and the list snapped to its top); a search or the window opening starts at the top
	local listAt = if listToTop then Vector2.zero else list.CanvasPosition
	listToTop = false
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
	subtitle.TextColor3 = if readyCount > 0 then palette.good else palette.inkSoft
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
	list.CanvasPosition = listAt
	game:GetService("RunService").Heartbeat:Once(function() -- and once the rebuilt rows are laid out
		if list.Parent then
			list.CanvasPosition = listAt
		end
	end)
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
-- The window's pieces for this screen: a computer's line and search over the list, or a phone's bigger window
-- without them and the big button's bar under the pane
local function layout()
	local phone = UIKit.isShort()
	panel.Size = if phone then UDim2.fromScale(0.97, 0.96) else UDim2.fromScale(0.94, 0.86)
	local top = if phone then UIKit.HEADER_HEIGHT + 8 else LIST_TOP
	subtitle.Visible = not phone
	search.Visible = not phone
	local bar = if phone then RECIPE.button + 12 else 0
	list.Position = UDim2.fromOffset(12, top)
	list.Size = UDim2.new(LIST_WIDTH_SCALE, -18, 1, -(top + 12))
	pane.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 0, top)
	pane.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 1, -(top + 12 + bar))
	actionBar.Visible = phone
	actionBar.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 1, -12)
	actionBar.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 0, bar)
end

function GradingController.Open(part: BasePart)
	machine = part
	layout()
	selectedCardId = nil
	mainKey = nil
	choosingMain = false
	inFlight = false
	listToTop = true
	panel.Visible = true
	render()
	refreshDone(true) -- a grade still waiting shows again each time the window opens, until it's taken out
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
	JobPanel.attach(panel, "grading") -- a job inside: its card over the actions (spec 2026-11-12-timed-upgrades-revive-design)
	-- a finished grade's reveal: over everything in the window (above the job veil), until Take it out
	refreshDone = DoneReveal.attach(panel, { attribute = "GradingDone", station = "grading", seen = Remotes.GradingSeen, kind = "grade", heading = GradingConfig.DONE_HEADING })
	palette = UIKit.colorsFor(panel)
	panel.Size = UDim2.fromScale(0.94, 0.86)
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = PANEL_MAX_SIZE
	end
	subtitle = UIKit.label(panel, SUBTITLE_TEXT, Enum.Font.Gotham, 14, UIKit.Colors.Subtext)
	subtitle.Position = UDim2.fromOffset(16, 56)
	subtitle.Size = UDim2.new(1, -32, 0, 22)
	search = Instance.new("TextBox")
	search.Name = "Search"
	search.Position = UDim2.fromOffset(16, 82)
	search.Size = UDim2.fromOffset(220, 34)
	search.BackgroundColor3 = palette.row
	search.ClearTextOnFocus = false
	search.PlaceholderText = "Search name or #"
	search.Text = ""
	search.Font = Enum.Font.Gotham
	search.TextSize = 14
	search.TextColor3 = palette.ink
	search.PlaceholderColor3 = palette.inkSoft
	search.Parent = panel
	UIKit.corner(search, 8)
	UIKit.outline(search, palette.rowEdge, 2)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		searchText = search.Text
		listToTop = true
		render()
	end)

	list.Position = UDim2.fromOffset(12, LIST_TOP)
	list.Size = UDim2.new(LIST_WIDTH_SCALE, -18, 1, -(LIST_TOP + 12))
	-- room round the rows, so the list's edge cuts no row's outline (owner 2026-11-20: "fix upgrading stations cutoff
	-- borders"; the Condenser's and the Forge's lists have it)
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingLeft = UDim.new(0, 6)
	listPadding.PaddingRight = UDim.new(0, 12)
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
	UIKit.corner(pane, 10)
	actionBar = Instance.new("Frame")
	actionBar.Name = "Action"
	actionBar.BackgroundTransparency = 1
	actionBar.AnchorPoint = Vector2.new(0, 1)
	actionBar.Visible = false
	actionBar.Parent = panel

	-- Seals come and go with the item inventory
	Remotes.ItemsChanged.OnClientEvent:Connect(function(items)
		local count = if typeof(items) == "table" then items.gradingSeal else nil
		sealCount = if typeof(count) == "number" then count else 0
		if sealCount == 0 then
			useSeals = false
		end
		local gold = if typeof(items) == "table" then items.goldSeal else nil
		goldCount = if typeof(gold) == "number" then gold else 0
		if goldCount == 0 then
			useGold = false
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
