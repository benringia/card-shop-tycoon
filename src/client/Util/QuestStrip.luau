--!strict
-- The daily quests' strip at the top right (owner 2026-11-17: "add design/immersive animations on the quest strip";
-- look A "Candy tracker" of artifact XyGHP2ku71fRaYeuEkGZ6D; numbers in Config/Quests STRIP): a cotton candy card under a
-- gold band (the Quests window's header colours) with a shine passing over it and its scroll wiggling. Each quest shows
-- its icon in a floating bubble of its kind's colour, its words and count, and a glossy bar with its own shine. What
-- changed since the last state animates (QuestRules.stripChanges): the bar fills and "+1" rises over it with a twinkle at
-- its end, a finished quest flashes mint and its check stamps in with confetti, the done count bumps, Claim! pops in and
-- pulses with a ring while the card's outline glows mint. Quests done turns it gold: a hopping trophy, twinkles, the time
-- to new quests. On a phone it's a small chip beside the cash pill (owner 2026-11-17: "mobile version screen now too
-- crowded", "go A" of artifact GtT4bM87otu1aayFVANr7z; QuestRules.bandParts): its scroll and one chip (the count, a
-- pulsing Claim! or the hours left), as wide as they are, no title and no chevron. On a computer a chevron on the band
-- folds it to the band (owner 2026-11-17: "minimizable/hideable"); it opens again on a tap, or by itself on a new day's
-- quests.
-- Once today's Quest Chest is opened the week's quests take the rows (owner 2026-11-17: "what players do after daily
-- quests?", look A; QuestRules.stripMode): a "Weekly" line with the time left, the three rows animating the same way and
-- the Weekly Chest line under them (ready: it says so and wiggles); a phone's chip shows a star and their count. Both
-- chests opened: the gold done box (a phone's chip: a trophy and the hours left). Each part pops in as it arrives.
-- The main quest (owner 2026-11-18, look A; Util/MainQuestRow) rides at its bottom on a computer, under the day's quests,
-- the week's and "Quests done!"; a phone's chip shows it once both chests are opened (its icon and "54%", "Build!" or
-- "Lv 10" instead of the hours left).
-- QuestController places it, shows or hides it and opens the window on a tap.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Quests = require(Config:WaitForChild("Quests"))
local Items = require(Config:WaitForChild("Items"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local PackFx = require(Config:WaitForChild("PackFx"))
local QuestRules = require(Shared:WaitForChild("Util"):WaitForChild("QuestRules"))
local MainQuestRules = require(Shared:WaitForChild("Util"):WaitForChild("MainQuestRules"))
local HudGrow = require(Shared:WaitForChild("Util"):WaitForChild("HudGrow"))
local HudGrowConfig = require(Config:WaitForChild("HudGrow"))

local ClientUtil = script.Parent :: Instance
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local MainQuestRow = require(ClientUtil:WaitForChild("MainQuestRow"))

local QuestStrip = {}

type View = QuestRules.View
type QuestView = QuestRules.QuestView
type Row = { frame: Frame, bubble: Frame, words: TextLabel, count: TextLabel, fill: Frame, gradient: UIGradient, sweep: Frame, check: TextLabel, id: string }

local STRIP = Quests.STRIP
local CREAM = UIStyle.CREAM
local BABY = UIStyle.BABY
local GOLD = CREAM.HEADERS.Quests or { top = BABY.butter.light, bottom = BABY.butter.fill }
local GOLD_DEEP = BABY.butter.deep
local DONE_BODY = { top = Color3.fromRGB(255, 246, 214), bottom = BABY.butter.light }
local GLINT = PackFx.SHEETS.Glint
local GLINT_SHEET_PX = 1024 -- the glint sheet's size (assets/ui/fx/Glint.png)
local GLINT_FRAME = 4 -- its brightest frame of the 16
local CORNER = 14
local TICK = 0.25 -- seconds between the idle loop's checks
local WEEK_INK = BABY.lilac.deep
local CHEST_PRIZE = (Items.ITEMS[Quests.WEEKLY.CHEST[1].item] or { name = "a prize" }).name

local root: TextButton
local outline: UIStroke
local bodyGradient: UIGradient
local band: Frame
local bandFiller: Frame
local bandSweep: Frame
local bandIcon: Frame
local title: TextLabel
local claimChip: TextLabel
local claimPing: Frame
local countChip: TextLabel
local rowsFrame: Frame
local doneBox: Frame
local trophy: Frame
local doneTime: TextLabel
local doneGlints: { ImageLabel } = {}
local rows: { Row } = {}
local weekHead: Frame
local weekLeft: TextLabel
local chestLine: Frame
local chestIcon: Frame
local chestWords: TextLabel
local chestReady = false
local last: View? = nil -- the newest state
local lastShown: View? = nil -- the part of it the rows show: the day's or the week's
local lastMode: QuestRules.StripMode? = nil
local popPending: QuestRules.StripMode? = nil -- the week's rows or the done box arrived: they pop in once seen
local seen: View? = nil -- the part the player last saw (what changed since plays when they can see it)
local lastCompact: boolean? = nil
local lastReset = ""
local lastWeekText = ""
local folded = false
local fold: TextButton
local foldArrow: Frame
local claimTweens: { Tween } = {}
local claimLook: string? = nil -- "computer" (pulsing), "phone" (still) or nil: what Claim! shows now
local trophyTween: Tween? = nil
local lastMain: MainQuestRules.Goal? = nil -- the main quest's goal (QuestStrip.setMain)
local fighting = false -- a fight is on: the main row steps aside (the fight's buttons sit under the strip)
local inPhone = false -- the quests are a Phone app on this screen (QuestStrip.setInPhone): no strip, no main row

local function tween(object: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local playing = TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	playing:Play()
	return playing
end

local function scaleOf(object: GuiObject): UIScale
	local scale = object:FindFirstChildOfClass("UIScale")
	if scale then
		return scale
	end
	local made = Instance.new("UIScale")
	made.Parent = object
	return made
end

local function gradient(parent: GuiObject, top: Color3, bottom: Color3): UIGradient
	local made = Instance.new("UIGradient")
	made.Color = ColorSequence.new(top, bottom)
	made.Rotation = 90
	made.Parent = parent
	return made
end

-- A soft white band that passes over its holder now and then (hidden between passes; never past the holder's rounded
-- ends: it travels between `from` and `to`, fading in and out)
local function makeSweep(parent: GuiObject, z: number): Frame
	local sweep = Instance.new("Frame")
	sweep.Name = "Shine"
	sweep.BackgroundColor3 = Color3.new(1, 1, 1)
	sweep.BackgroundTransparency = 1
	sweep.BorderSizePixel = 0
	sweep.Size = UDim2.fromScale(0.34, 1)
	sweep.ZIndex = z
	sweep.Parent = parent
	local soft = Instance.new("UIGradient")
	soft.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 1) })
	soft.Rotation = 15
	soft.Parent = sweep
	return sweep
end

local function shine(sweep: Frame, from: number, to: number, seconds: number)
	sweep.Position = UDim2.fromScale(from, 0)
	sweep.BackgroundTransparency = 1
	tween(sweep, seconds, { Position = UDim2.fromScale(to, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	tween(sweep, seconds * 0.35, { BackgroundTransparency = 0.25 })
	task.delay(seconds * 0.6, function()
		if sweep.Parent then
			tween(sweep, seconds * 0.4, { BackgroundTransparency = 1 })
		end
	end)
end

-- The pack opening's four-point glint, hidden, `size` px at `position`
local function glint(parent: Instance, size: number, position: UDim2, z: number): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = "Glint"
	image.BackgroundTransparency = 1
	image.Image = GLINT.image
	local frame = GLINT_SHEET_PX / GLINT.grid
	image.ImageRectSize = Vector2.new(frame, frame)
	image.ImageRectOffset = Vector2.new((GLINT_FRAME % GLINT.grid) * frame, (GLINT_FRAME // GLINT.grid) * frame)
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = position
	image.Size = UDim2.fromOffset(size, size)
	image.ImageTransparency = 1
	image.ZIndex = z
	image.Parent = parent
	return image
end

-- A twinkle: the glint grows, turns and fades
local function twinkle(image: ImageLabel, seconds: number)
	image.ImageTransparency = 0
	image.Rotation = 0
	local scale = scaleOf(image)
	scale.Scale = 0.2
	tween(scale, seconds * 0.4, { Scale = 1.1 }, Enum.EasingStyle.Back)
	tween(image, seconds, { Rotation = 90 })
	task.delay(seconds * 0.45, function()
		if image.Parent then
			tween(image, seconds * 0.55, { ImageTransparency = 1 })
		end
	end)
end

-- The scroll's wiggle: a quick shake and back
local function wiggle(object: GuiObject)
	task.spawn(function()
		for _, angle in { -14, 12, -6, 0 } do
			if not object.Parent then
				return
			end
			tween(object, 0.1, { Rotation = angle }, Enum.EasingStyle.Sine)
			task.wait(0.1)
		end
	end)
end

-- A quick swell and back. On a piece the HUD scales (the strip itself, grown on a desktop: Hud.scaleWith) it starts
-- and ends at that size, read when each step plays (owner 2026-11-21: folding the strip left it small)
local function bump(object: GuiObject, size: number)
	local scale = scaleOf(object)
	local function steps(): (number, number, number)
		return HudGrow.bump(HudGrow.rest(object:GetAttribute(HudGrowConfig.ATTRIBUTE)), size)
	end
	local from, peak = steps()
	scale.Scale = from
	tween(scale, 0.12, { Scale = peak }, Enum.EasingStyle.Quad)
	task.delay(0.12, function()
		local _, _, back = steps()
		tween(scale, 0.35, { Scale = back }, Enum.EasingStyle.Back)
	end)
end

local function chip(parent: Instance, name: string, fill: Color3, ink: Color3, edge: Color3): TextLabel
	local label = UIKit.label(parent, "", Enum.Font.FredokaOne, 13, ink)
	label.Name = name
	label.BackgroundColor3 = fill
	label.BackgroundTransparency = 0
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 20)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextWrapped = false
	label.ZIndex = 4
	UIKit.corner(label, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = label
	local rim = Instance.new("UIStroke")
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Color = edge
	rim.Thickness = 2
	rim.Parent = label
	return label
end

-- The gold band: the scroll, the title, Claim! and the count (or, when all is done, the hours left)
local function buildBand()
	band = Instance.new("Frame")
	band.Name = "Band"
	band.LayoutOrder = 0
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	band.BorderSizePixel = 0
	band.Size = UDim2.new(1, 0, 0, STRIP.band)
	band.ZIndex = 2
	band.Parent = root
	UIKit.corner(band, CORNER)
	gradient(band, GOLD.top, GOLD.bottom)
	-- squares the band's bottom corners when the rows hang under it
	bandFiller = Instance.new("Frame")
	bandFiller.Name = "Filler"
	bandFiller.BackgroundColor3 = Color3.new(1, 1, 1)
	bandFiller.BorderSizePixel = 0
	bandFiller.AnchorPoint = Vector2.new(0, 1)
	bandFiller.Position = UDim2.fromScale(0, 1)
	bandFiller.Size = UDim2.new(1, 0, 0, CORNER)
	bandFiller.ZIndex = 2
	bandFiller.Parent = band
	local fillerGradient = gradient(bandFiller, GOLD.top:Lerp(GOLD.bottom, 0.5), GOLD.bottom)
	fillerGradient.Name = "Gradient"
	bandSweep = makeSweep(band, 3)
	bandIcon = Icon.make(band, "📜", UDim2.fromOffset(18, 18))
	bandIcon.AnchorPoint = Vector2.new(0, 0.5)
	bandIcon.Position = UDim2.new(0, 8, 0.5, 0)
	bandIcon.ZIndex = 4
	Icon.layer(bandIcon, 4)
	title = UIKit.label(band, "Daily Quests", Enum.Font.FredokaOne, 15, Color3.new(1, 1, 1))
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0, 0.5)
	title.Position = UDim2.new(0, 31, 0.5, 0)
	title.Size = UDim2.new(1, -31, 0, 20)
	title.TextWrapped = false
	title.ZIndex = 4
	local titleEdge = Instance.new("UIStroke")
	titleEdge.Color = GOLD_DEEP
	titleEdge.Thickness = 1.5
	titleEdge.Parent = title
	local right = Instance.new("Frame")
	right.Name = "Chips"
	right.BackgroundTransparency = 1
	right.AnchorPoint = Vector2.new(1, 0.5)
	right.Position = UDim2.new(1, -6, 0.5, 0)
	right.Size = UDim2.new(0.7, 0, 0, 22)
	right.ZIndex = 4
	right.Parent = band
	local line = Instance.new("UIListLayout")
	line.FillDirection = Enum.FillDirection.Horizontal
	line.HorizontalAlignment = Enum.HorizontalAlignment.Right
	line.VerticalAlignment = Enum.VerticalAlignment.Center
	line.Padding = UDim.new(0, 5)
	line.SortOrder = Enum.SortOrder.LayoutOrder
	line.Parent = right
	claimChip = chip(right, "Claim", BABY.mint.fill, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	claimChip.Text = "Claim!"
	claimChip.LayoutOrder = 1
	claimChip.Visible = false
	local claimEdge = Instance.new("UIStroke")
	claimEdge.Color = BABY.mint.deep
	claimEdge.Thickness = 1.5
	claimEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	claimEdge.Parent = claimChip
	-- the ring that pings out of Claim!
	claimPing = Instance.new("Frame")
	claimPing.Name = "Ping"
	claimPing.BackgroundTransparency = 1
	claimPing.AnchorPoint = Vector2.new(0.5, 0.5)
	claimPing.Position = UDim2.fromScale(0.5, 0.5)
	claimPing.Size = UDim2.new(1, 16, 1, 0)
	claimPing.ZIndex = 4
	claimPing.Parent = claimChip
	UIKit.corner(claimPing, 12)
	local pingRim = Instance.new("UIStroke")
	pingRim.Name = "Rim"
	pingRim.Color = BABY.mint.fill
	pingRim.Thickness = 2
	pingRim.Parent = claimPing
	countChip = chip(right, "Count", Color3.new(1, 1, 1), GOLD_DEEP, GOLD_DEEP)
	countChip.LayoutOrder = 2
	-- the chevron that folds the strip: a white button, its arrow two short bars (no arrow glyph in the fonts)
	fold = Instance.new("TextButton")
	fold.Name = "Fold"
	fold.Text = ""
	fold.AutoButtonColor = false
	fold.BackgroundColor3 = Color3.new(1, 1, 1)
	fold.LayoutOrder = 3
	fold.Size = UDim2.fromOffset(22, 22)
	fold.ZIndex = 5
	fold.Parent = right
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = fold
	local foldRim = Instance.new("UIStroke")
	foldRim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	foldRim.Color = GOLD_DEEP
	foldRim.Thickness = 2
	foldRim.Parent = fold
	foldArrow = Instance.new("Frame")
	foldArrow.Name = "Arrow"
	foldArrow.BackgroundTransparency = 1
	foldArrow.AnchorPoint = Vector2.new(0.5, 0.5)
	foldArrow.Position = UDim2.fromScale(0.5, 0.5)
	foldArrow.Size = UDim2.fromOffset(12, 12)
	foldArrow.ZIndex = 6
	foldArrow.Parent = fold
	for _, side in { -1, 1 } do
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.BackgroundColor3 = GOLD_DEEP
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.new(0.5, side * 2.5, 0.5, 0)
		bar.Size = UDim2.fromOffset(2.5, 8)
		bar.Rotation = -side * 45 -- the two bars make a "^": roll it up (turned over once folded)
		bar.ZIndex = 6
		bar.Parent = foldArrow
		UIKit.corner(bar, 1)
	end
end

local function bubbleColor(kind: string): { fill: Color3, light: Color3, deep: Color3 }
	return BABY[STRIP.bubbles[kind] or "sky"] or BABY.sky
end

-- One quest's row: its bubble, words, count, bar (fill, gloss, shine) and the check that stamps in when it's done
local function buildRow(index: number, quest: QuestView): Row
	local frame = Instance.new("Frame")
	frame.Name = `Quest{index}`
	frame.LayoutOrder = index
	frame.BackgroundColor3 = BABY.mint.light
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, STRIP.rowHeight)
	frame.ZIndex = 2
	frame.Parent = rowsFrame
	UIKit.corner(frame, 9)
	local colors = bubbleColor(quest.kind)
	local bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.BackgroundColor3 = colors.light
	bubble.AnchorPoint = Vector2.new(0, 0.5)
	bubble.Position = UDim2.new(0, 2, 0.5, 0)
	bubble.Size = UDim2.fromOffset(26, 26)
	bubble.ZIndex = 3
	bubble.Parent = frame
	UIKit.corner(bubble, 13)
	local bubbleRim = Instance.new("UIStroke")
	bubbleRim.Color = Color3.new(1, 1, 1)
	bubbleRim.Thickness = 2
	bubbleRim.Parent = bubble
	local picture = Icon.make(bubble, quest.icon, UDim2.fromOffset(18, 18))
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.5)
	picture.ZIndex = 4
	Icon.layer(picture, 4)
	-- the icons sway in their bubbles, each a little after the one above (a turn is smooth; a 2 px float moved in
	-- whole pixels and looked jerky)
	picture.Rotation = -STRIP.sway
	local sway = TweenService:Create(picture, TweenInfo.new(STRIP.swaySeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, (index - 1) * 0.4), { Rotation = STRIP.sway })
	sway:Play()
	local check = UIKit.label(bubble, "✅", Enum.Font.GothamBold, 12, Color3.new(1, 1, 1))
	check.Name = "Check"
	check.AnchorPoint = Vector2.new(0.5, 0.5)
	check.Position = UDim2.new(1, -1, 1, -3)
	check.Size = UDim2.fromOffset(14, 14)
	check.TextXAlignment = Enum.TextXAlignment.Center
	check.ZIndex = 6
	check.Visible = false
	-- the words and the count on one line: the count as wide as its numbers (a week's "1750/1750" ran out of a fixed
	-- 40 px), the words filling the rest
	local line = Instance.new("Frame")
	line.Name = "Line"
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromOffset(34, 1)
	line.Size = UDim2.new(1, -36, 0, 15)
	line.ZIndex = 3
	line.Parent = frame
	local lineLayout = Instance.new("UIListLayout")
	lineLayout.FillDirection = Enum.FillDirection.Horizontal
	lineLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	lineLayout.SortOrder = Enum.SortOrder.LayoutOrder
	lineLayout.Padding = UDim.new(0, 4)
	lineLayout.Parent = line
	local words = UIKit.label(line, quest.text, Enum.Font.GothamBold, 12, CREAM.INK)
	words.Name = "Words"
	words.LayoutOrder = 1
	words.Size = UDim2.new(0, 0, 1, 0)
	words.TextTruncate = Enum.TextTruncate.AtEnd
	words.TextWrapped = false
	words.ZIndex = 3
	local grow = Instance.new("UIFlexItem")
	grow.FlexMode = Enum.UIFlexMode.Fill
	grow.Parent = words
	local count = UIKit.label(line, "", Enum.Font.FredokaOne, 12, CREAM.INK_SOFT)
	count.Name = "Count"
	count.LayoutOrder = 2
	count.AutomaticSize = Enum.AutomaticSize.X
	count.Size = UDim2.new(0, 0, 1, 0)
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.TextWrapped = false
	count.ZIndex = 3
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = CREAM.TRACK
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(34, 19)
	track.Size = UDim2.new(1, -36, 0, 9)
	track.ZIndex = 3
	track.Parent = frame
	UIKit.corner(track, 5)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 4
	fill.Parent = track
	UIKit.corner(fill, 5)
	local fillGradient = gradient(fill, BABY.sky.light, BABY.sky.fill)
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.5
	gloss.BorderSizePixel = 0
	gloss.Position = UDim2.new(0, 3, 0, 1)
	gloss.Size = UDim2.new(1, -6, 0, 2)
	gloss.ZIndex = 5
	gloss.Parent = fill
	UIKit.corner(gloss, 1)
	local sweep = makeSweep(fill, 5)
	return { frame = frame, bubble = bubble, words = words, count = count, fill = fill, gradient = fillGradient, sweep = sweep, check = check, id = quest.id }
end

-- A row as its quest is now (no animation)
local function showRow(row: Row, quest: QuestView)
	local share = math.clamp(quest.progress / math.max(1, quest.goal), 0, 1)
	row.fill.Size = UDim2.fromScale(share, 1)
	row.count.Text = `{math.min(quest.progress, quest.goal)}/{quest.goal}`
	row.words.Text = quest.text
	local muted = quest.claimed
	row.words.TextColor3 = if muted then CREAM.HINT else CREAM.INK
	row.count.TextColor3 = if muted then CREAM.HINT elseif quest.done then CREAM.GOOD else CREAM.INK_SOFT
	local colors = if quest.done then BABY.mint else BABY.sky
	row.gradient.Color = ColorSequence.new(colors.light, colors.fill)
	row.fill.BackgroundTransparency = if muted then 0.45 else 0
	row.check.Visible = quest.done
	scaleOf(row.check).Scale = 1
	row.check.Rotation = 0
end

-- Confetti out of a finished quest's check: small candy squares flying out and fading
local function confetti(row: Row)
	local from = row.check.AbsolutePosition + row.check.AbsoluteSize / 2 - row.frame.AbsolutePosition
	local palette = { BABY.butter.fill, BABY.pink.fill, BABY.mint.fill, BABY.sky.fill, BABY.lilac.fill, BABY.peach.fill }
	for index = 1, STRIP.confetti do
		local bit = Instance.new("Frame")
		bit.Name = "Confetti"
		bit.BackgroundColor3 = palette[(index - 1) % #palette + 1]
		bit.BorderSizePixel = 0
		bit.AnchorPoint = Vector2.new(0.5, 0.5)
		bit.Position = UDim2.fromOffset(from.X, from.Y)
		bit.Size = UDim2.fromOffset(5, 5)
		bit.ZIndex = 7
		bit.Parent = row.frame
		UIKit.corner(bit, 2)
		local angle = (index / STRIP.confetti) * math.pi * 2 + math.random() * 0.5
		local reach = 16 + math.random() * 12
		tween(bit, 0.7, { Position = UDim2.fromOffset(from.X + math.cos(angle) * reach, from.Y + math.sin(angle) * reach), Rotation = 180, BackgroundTransparency = 1 })
		task.delay(0.75, bit.Destroy, bit)
	end
end

-- A quest moved on: the bar fills, "+N" rises over it and its end twinkles
local function progressed(row: Row, quest: QuestView, gained: number)
	local share = math.clamp(quest.progress / math.max(1, quest.goal), 0, 1)
	row.fill.Size = UDim2.fromScale(math.max(0, share - gained / math.max(1, quest.goal)), 1)
	tween(row.fill, STRIP.fillSeconds, { Size = UDim2.fromScale(share, 1) }, Enum.EasingStyle.Quint) -- no overshoot past the track
	local plus = UIKit.label(row.frame, `+{gained}`, Enum.Font.FredokaOne, 14, BABY.sky.deep)
	plus.Name = "Plus"
	plus.AnchorPoint = Vector2.new(0.5, 1)
	local x = math.clamp(share, 0.18, 0.72) -- clear of the count at the right
	plus.Position = UDim2.new(x, 0, 0, 22)
	plus.Size = UDim2.fromOffset(40, 16)
	plus.TextXAlignment = Enum.TextXAlignment.Center
	plus.ZIndex = 8
	local plusEdge = Instance.new("UIStroke")
	plusEdge.Color = Color3.new(1, 1, 1)
	plusEdge.Thickness = 2
	plusEdge.Parent = plus
	scaleOf(plus).Scale = 0.5
	tween(scaleOf(plus), 0.25, { Scale = 1.15 }, Enum.EasingStyle.Back)
	tween(plus, 0.9, { Position = UDim2.new(x, 0, 0, 6) })
	task.delay(0.45, function()
		if plus.Parent then
			tween(plus, 0.45, { TextTransparency = 1 })
			tween(plusEdge, 0.45, { Transparency = 1 })
		end
	end)
	task.delay(1, plus.Destroy, plus)
	local spark = glint(row.fill.Parent :: Instance, 18, UDim2.fromScale(share, 0.5), 7)
	task.delay(STRIP.fillSeconds * 0.6, function()
		if spark.Parent then
			twinkle(spark, 0.7)
		end
	end)
	task.delay(STRIP.fillSeconds + 0.8, spark.Destroy, spark)
end

-- A quest done: the row flashes mint, its check stamps in, confetti
local function finished(row: Row)
	row.frame.BackgroundTransparency = 0.1
	tween(row.frame, 0.9, { BackgroundTransparency = 1 })
	row.check.Visible = true
	local scale = scaleOf(row.check)
	scale.Scale = 2.4
	row.check.Rotation = -25
	tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(row.check, 0.45, { Rotation = 0 }, Enum.EasingStyle.Back)
	confetti(row)
end

local function stopClaim()
	for _, playing in claimTweens do
		playing:Cancel()
	end
	table.clear(claimTweens)
	scaleOf(claimChip).Scale = 1
	outline.Color = Color3.new(1, 1, 1)
	outline.Thickness = 3
end

-- Claim! pulses with a ring pinging out of it, and the card's outline glows mint. A phone's chip keeps still (owner
-- 2026-11-17: "on mobile. remove this claim pulsating animation"): Claim! pops in once and the outline turns mint
local function startClaim(popIn: boolean)
	stopClaim()
	local scale = scaleOf(claimChip)
	if popIn then
		scale.Scale = 0
		tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	if lastCompact then
		local rim = claimPing:FindFirstChild("Rim") :: UIStroke
		rim.Transparency = 1
		outline.Color = BABY.mint.fill
		return
	end
	task.delay(if popIn then 0.4 else 0, function()
		if not claimChip.Visible then
			return
		end
		local pulse = TweenService:Create(scale, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.1 })
		pulse:Play()
		table.insert(claimTweens, pulse)
	end)
	local ping = scaleOf(claimPing)
	ping.Scale = 1
	local rim = claimPing:FindFirstChild("Rim") :: UIStroke
	rim.Transparency = 0
	local grow = TweenService:Create(ping, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), { Scale = 1.5 })
	local fade = TweenService:Create(rim, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), { Transparency = 1 })
	grow:Play()
	fade:Play()
	outline.Color = BABY.mint.fill
	local glow = TweenService:Create(outline, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 4.5 })
	glow:Play()
	table.insert(claimTweens, grow)
	table.insert(claimTweens, fade)
	table.insert(claimTweens, glow)
end

local function buildDone()
	doneBox = Instance.new("Frame")
	doneBox.Name = "Done"
	doneBox.LayoutOrder = 2
	doneBox.BackgroundTransparency = 1
	doneBox.Size = UDim2.new(1, 0, 0, 48)
	doneBox.Visible = false
	doneBox.ZIndex = 2
	doneBox.Parent = root
	trophy = Icon.make(doneBox, "Trophy", UDim2.fromOffset(30, 30))
	trophy.AnchorPoint = Vector2.new(0, 0.5)
	trophy.Position = UDim2.new(0, 12, 0.5, 0)
	trophy.ZIndex = 4
	Icon.layer(trophy, 4)
	local words = UIKit.label(doneBox, "Quests done!", Enum.Font.FredokaOne, 15, GOLD_DEEP)
	words.Name = "Words"
	words.Position = UDim2.fromOffset(52, 6)
	words.Size = UDim2.new(1, -56, 0, 18)
	words.ZIndex = 4
	doneTime = UIKit.label(doneBox, "", Enum.Font.GothamBold, 11, CREAM.HINT)
	doneTime.Name = "Time"
	doneTime.Position = UDim2.fromOffset(52, 25)
	doneTime.Size = UDim2.new(1, -56, 0, 15)
	doneTime.ZIndex = 4
	for _, spot in { UDim2.fromScale(0.12, 0.18), UDim2.fromScale(0.9, 0.3), UDim2.fromScale(0.55, 0.85), UDim2.fromScale(0.78, 0.75) } do
		table.insert(doneGlints, glint(doneBox, 14, spot, 5))
	end
end

-- The week's "Weekly" line over its rows (the time left on its right) and the Weekly Chest line under them
local function buildWeekly()
	weekHead = Instance.new("Frame")
	weekHead.Name = "WeekHead"
	weekHead.LayoutOrder = 0
	weekHead.BackgroundTransparency = 1
	weekHead.Size = UDim2.new(1, 0, 0, 18)
	weekHead.Visible = false
	weekHead.ZIndex = 2
	weekHead.Parent = rowsFrame
	local star = Icon.make(weekHead, "⭐", UDim2.fromOffset(16, 16))
	star.AnchorPoint = Vector2.new(0, 0.5)
	star.Position = UDim2.new(0, 4, 0.5, 0)
	star.ZIndex = 3
	Icon.layer(star, 3)
	local words = UIKit.label(weekHead, "Weekly", Enum.Font.FredokaOne, 14, WEEK_INK)
	words.Name = "Words"
	words.Position = UDim2.fromOffset(24, 0)
	words.Size = UDim2.new(0.5, -24, 1, 0)
	words.TextWrapped = false
	words.ZIndex = 3
	weekLeft = UIKit.label(weekHead, "", Enum.Font.GothamBold, 11, CREAM.INK_SOFT)
	weekLeft.Name = "Left"
	weekLeft.AnchorPoint = Vector2.new(1, 0)
	weekLeft.Position = UDim2.new(1, -2, 0, 0)
	weekLeft.Size = UDim2.new(0.5, 0, 1, 0)
	weekLeft.TextXAlignment = Enum.TextXAlignment.Right
	weekLeft.TextWrapped = false
	weekLeft.ZIndex = 3
	chestLine = Instance.new("Frame")
	chestLine.Name = "WeekChest"
	chestLine.LayoutOrder = 10
	chestLine.BackgroundTransparency = 1
	chestLine.Size = UDim2.new(1, 0, 0, 24)
	chestLine.Visible = false
	chestLine.ZIndex = 2
	chestLine.Parent = rowsFrame
	chestIcon = Icon.make(chestLine, "Gift", UDim2.fromOffset(22, 22))
	chestIcon.AnchorPoint = Vector2.new(0, 0.5)
	chestIcon.Position = UDim2.new(0, 3, 0.5, 0)
	chestIcon.ZIndex = 3
	Icon.layer(chestIcon, 3)
	chestWords = UIKit.label(chestLine, "", Enum.Font.GothamBold, 11, CREAM.INK_SOFT)
	chestWords.Name = "Words"
	chestWords.AnchorPoint = Vector2.new(0, 0.5)
	chestWords.Position = UDim2.new(0, 31, 0.5, 0)
	chestWords.Size = UDim2.new(1, -33, 1, 0)
	chestWords.TextTruncate = Enum.TextTruncate.AtEnd
	chestWords.TextWrapped = false
	chestWords.ZIndex = 3
end

-- The Weekly Chest line: what all three open, or that it's ready (it wiggles then)
local function showChest(ready: boolean)
	chestReady = ready
	chestWords.Text = if ready then "Weekly Chest ready! Tap to open" else `All 3: Weekly Chest ({CHEST_PRIZE}!)`
	chestWords.TextColor3 = if ready then BABY.mint.deep else CREAM.INK_SOFT
end

local function rebuildRows(current: View)
	for _, row in rows do
		row.frame:Destroy()
	end
	table.clear(rows)
	for index, quest in current.quests do
		local row = buildRow(index, quest)
		showRow(row, quest)
		rows[index] = row
	end
end

-- The gold "Quests done!" box in place of the rows (a hopping trophy), or the rows back
local function setDone(on: boolean)
	doneBox.Visible = on
	rowsFrame.Visible = not on and not lastCompact and not folded
	local body = if on then DONE_BODY else { top = CREAM.BODY_TOP, bottom = CREAM.BODY_BOTTOM }
	bodyGradient.Color = ColorSequence.new(body.top, body.bottom)
	if on and not trophyTween then
		local hop = TweenService:Create(trophy, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.new(0, 12, 0.5, -5), Rotation = -6 })
		hop:Play()
		trophyTween = hop
	elseif not on and trophyTween then
		trophyTween:Cancel()
		trophyTween = nil
	end
end

-- Whether the player can see the strip now (the HUD hides its holder in fights and full-screen views)
local function shown(): boolean
	local holder = root.Parent
	return root.Visible and (holder == nil or not holder:IsA("GuiObject") or holder.Visible)
end

-- The week's rows or the gold done box popping in once the player can see the strip
local function playPop()
	local mode = popPending
	if not mode or not shown() then
		return
	end
	popPending = nil
	local target: GuiObject = if mode == "done" then doneBox else rowsFrame
	if not target.Visible then
		return
	end
	local scale = scaleOf(target)
	scale.Scale = 0.6
	tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- What changed since the player last saw the strip, played now: bars filling with +N, checks stamping in, the count
-- bumping, Claim! popping in. Held while the strip is hidden: back from a fight, the quest finished there stamps in as
-- you watch. `current`: the part the rows show (the day's or the week's).
local function animate(current: View)
	local from = seen
	seen = current
	if not from or #rows ~= #current.quests then
		return
	end
	local changes = QuestRules.stripChanges(from, current)
	if changes.doneChanged then
		bump(countChip, 1.35)
	end
	if changes.claimAppeared and claimChip.Visible then
		startClaim(true)
	end
	for _, index in changes.progressed do
		progressed(rows[index], current.quests[index], current.quests[index].progress - from.quests[index].progress)
	end
	for _, index in changes.finished do
		finished(rows[index])
	end
end

-- A phone's chip as wide as what it shows: its scroll, then the count, Claim! or the hours left (their own scale taken
-- out: Claim! pulses, the count bumps)
local function fitPhone()
	if not lastCompact then
		return
	end
	local shownChip = if claimChip.Visible then claimChip else countChip
	local scale = shownChip:FindFirstChildOfClass("UIScale")
	local width = shownChip.AbsoluteSize.X / (if scale and scale.Scale > 0 then scale.Scale else 1)
	root.Size = UDim2.fromOffset(math.ceil(STRIP.phoneChip.left + width + STRIP.phoneChip.right), 0)
end

-- The main quest: its row under the strip on a computer (not folded); a phone's chip shows it once both chests are
-- opened (its icon and "54%", "Build!" or "Lv 10" instead of the hours left)
local function refreshMain()
	MainQuestRow.setWanted(lastCompact == false and not folded and not fighting and not inPhone)
	local current = last
	local goal = lastMain
	if not lastCompact or not current or #current.quests == 0 or QuestRules.stripMode(current) ~= "done" then
		return
	end
	Icon.set(bandIcon, if goal then goal.icon else "Trophy")
	Icon.layer(bandIcon, 4)
	countChip.Text = if goal then MainQuestRules.chipText(goal) else string.match(lastReset, "%d+h") or "Soon"
	fitPhone()
end

local function onShown()
	playPop()
	local current = lastShown
	if current and current ~= seen and #current.quests > 0 and shown() then
		animate(current)
	end
end

-- Builds the strip in `parent` (hidden until the first render) and starts its idle loop: the band's shine, the scroll's
-- wiggle, each bar's shine, the done box's twinkles
function QuestStrip.build(parent: Instance): TextButton
	root = Instance.new("TextButton")
	root.Name = "QuestTracker"
	root.Text = ""
	root.AutoButtonColor = false
	root.AnchorPoint = Vector2.new(1, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.BackgroundColor3 = Color3.new(1, 1, 1)
	root.Size = UDim2.fromOffset(STRIP.width, 0)
	root.Visible = false
	root.Parent = parent
	UIKit.corner(root, CORNER)
	bodyGradient = gradient(root, CREAM.BODY_TOP, CREAM.BODY_BOTTOM)
	outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Color = Color3.new(1, 1, 1)
	outline.Thickness = 3
	outline.Parent = root
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = root
	buildBand()
	countChip:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPhone)
	claimChip:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPhone)
	rowsFrame = Instance.new("Frame")
	rowsFrame.Name = "Rows"
	rowsFrame.LayoutOrder = 1
	rowsFrame.BackgroundTransparency = 1
	rowsFrame.AutomaticSize = Enum.AutomaticSize.Y
	rowsFrame.Size = UDim2.new(1, 0, 0, 0)
	rowsFrame.ZIndex = 2
	rowsFrame.Parent = root
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, STRIP.pad)
	pad.PaddingRight = UDim.new(0, STRIP.pad)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, STRIP.pad)
	pad.Parent = rowsFrame
	local rowsLayout = Instance.new("UIListLayout")
	rowsLayout.Padding = UDim.new(0, STRIP.rowGap)
	rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowsLayout.Parent = rowsFrame
	buildDone()
	buildWeekly()
	MainQuestRow.build(root, 3) -- under the rows (1) and the done box (2)
	task.spawn(function()
		local clock = 0
		local glintIndex = 0
		while root.Parent do
			task.wait(TICK)
			clock += TICK
			if root.Visible and not lastCompact then -- a phone's chip keeps still (no shine or wiggle passing over it)
				if clock % STRIP.shineEvery < TICK then
					shine(bandSweep, 0.12, 0.54, 1)
				end
				if clock % STRIP.wiggleEvery < TICK then
					wiggle(bandIcon)
				end
				for index, row in rows do
					if row.frame.Parent and row.fill.Size.X.Scale > 0.15 and (clock + index * 0.9) % STRIP.barShineEvery < TICK then
						shine(row.sweep, 0.05, 0.6, 0.9)
					end
				end
				if chestReady and chestLine.Visible and clock % STRIP.wiggleEvery < TICK then
					wiggle(chestIcon)
				end
				if doneBox.Visible and clock % 0.75 < TICK and #doneGlints > 0 then
					glintIndex = glintIndex % #doneGlints + 1
					twinkle(doneGlints[glintIndex], 1.1)
				end
			end
		end
	end)
	fold.Activated:Connect(function()
		folded = not folded
		tween(foldArrow, 0.25, { Rotation = if folded then 180 else 0 }, Enum.EasingStyle.Back)
		bump(root, 1.04)
		QuestStrip.render(last, lastCompact == true, lastReset, lastWeekText)
	end)
	root:GetPropertyChangedSignal("Visible"):Connect(onShown)
	if parent:IsA("GuiObject") then
		parent:GetPropertyChangedSignal("Visible"):Connect(onShown)
	end
	return root
end

-- Shows `current` as it is (nil or no quests: nothing), and plays what changed when the player can see it; `compact`:
-- the phone's one-line band; `resetText`: "New quests in 9h 12m"; `weekText`: "4 days left"
function QuestStrip.render(current: View?, compact: boolean, resetText: string, weekText: string)
	last = current
	if not current or #current.quests == 0 then
		return
	end
	local mode = QuestRules.stripMode(current)
	local week = current.week
	local showing: View = if mode == "weekly" and week then week else current
	local fresh = lastCompact ~= compact
	lastCompact = compact
	lastReset = resetText
	lastWeekText = weekText
	band.Size = UDim2.new(1, 0, 0, if compact then STRIP.phoneBand else STRIP.band)
	bandFiller.Visible = not compact and not folded
	foldArrow.Rotation = if folded then 180 else 0
	local sameQuests = #rows == #showing.quests and mode == lastMode
	for index, quest in showing.quests do
		if not rows[index] or rows[index].id ~= quest.id then
			sameQuests = false
		end
	end
	if not sameQuests and #rows > 0 then
		folded = false -- a new day's quests, or the week's coming in: shown open again
	end
	if lastMode and mode ~= lastMode and mode ~= "daily" then
		popPending = mode
	end
	lastMode = mode
	lastShown = showing
	if fresh or not sameQuests then
		rebuildRows(showing) -- a new day's quests, the week's, or the phone's band: shown as they are
		seen = showing
	end
	local done = 0
	for _, quest in showing.quests do
		done += if quest.done then 1 else 0
	end
	-- the band: on a phone a chip by the cash that says it all (its scroll, then the count, Claim! or the hours left)
	local allDone = mode == "done"
	local weekly = mode == "weekly"
	Icon.set(bandIcon, if allDone and compact then "Trophy" elseif weekly and compact then "⭐" else "📜")
	Icon.layer(bandIcon, 4)
	local claimable = showing.claimable > 0 and not allDone
	local parts = QuestRules.bandParts(compact, claimable, weekly)
	title.Visible = parts.title
	claimChip.Visible = parts.claim
	countChip.Visible = parts.count
	fold.Visible = parts.fold
	countChip.Text = if allDone then (if compact then string.match(resetText, "%d+h") or "Soon" else "Done")
		elseif weekly and not compact then "Done"
		else `{done}/{#showing.quests}`
	-- Claim!'s look: a computer's pulse, a phone's still mint outline, or none; set again when either changes
	local look = if claimable then (if compact then "phone" else "computer") else nil
	if look ~= claimLook then
		claimLook = look
		if look then
			startClaim(false)
		else
			stopClaim()
		end
	end
	for index, quest in showing.quests do
		showRow(rows[index], quest)
	end
	weekHead.Visible = weekly
	chestLine.Visible = weekly
	weekLeft.Text = weekText
	showChest(weekly and showing.bonusReady)
	rowsFrame.Visible = not compact and not allDone and not folded
	setDone(allDone and not compact and not folded)
	doneTime.Text = resetText
	refreshMain()
	if compact then
		fitPhone()
		task.defer(fitPhone) -- the chip's new words are measured on the next frame
	else
		root.Size = UDim2.fromOffset(STRIP.width, 0)
	end
	playPop()
	if shown() then
		animate(showing)
	end
end

-- The countdowns (to new quests, to the week's end), once a while
function QuestStrip.tick(resetText: string, weekText: string)
	lastWeekText = weekText
	weekLeft.Text = weekText
	doneTime.Text = resetText
	local current = last
	if current and lastCompact and QuestRules.stripMode(current) == "done" then
		local goal = lastMain
		countChip.Text = if goal then MainQuestRules.chipText(goal) else string.match(resetText, "%d+h") or "Soon"
	end
end

-- The main quest's goal now (Util/MainQuest; nil: none): its row, or a phone's chip once all is done
function QuestStrip.setMain(goal: MainQuestRules.Goal?)
	lastMain = goal
	MainQuestRow.show(goal)
	refreshMain()
end

-- A main quest item's first build: its moment on the row (the next goal slides in after it)
function QuestStrip.mainDone(name: string, xp: number)
	MainQuestRow.done(name, xp)
end

-- A fight started or ended: the main row steps aside while it's on (the fight's soft lock button sits under the strip)
-- The quests live in the Phone on this screen (a computer, Config/DesktopHud QUESTS): the main quest's row under the
-- strip goes with it (the Quests window shows it)
function QuestStrip.setInPhone(on: boolean)
	if inPhone ~= on then
		inPhone = on
		refreshMain()
	end
end

function QuestStrip.setFighting(on: boolean)
	fighting = on
	refreshMain()
end

-- What the main quest row's Build! button does
function QuestStrip.onBuild(handler: (MainQuestRules.Goal) -> ())
	MainQuestRow.onBuild(handler)
end

return QuestStrip
