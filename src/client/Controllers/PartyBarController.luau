--!strict
-- The party dock (owner 2026-11-13: "lets make the party UI like this in palworld. pets carousel, then under it is the
-- character menu model then beside it is health. Both mobile and Desktop", no box; Util/PartyDock), where the party bar
-- was: bottom right left of the cash on a PC, under the cash at the top right on a phone. On top your 3 party slots as
-- a carousel: the creature that's out (or the one last in the middle) big in the middle, the other two smaller either
-- side, each a round portrait in its element's rim with its key number; the summoned one has the orange glow and OUT
-- tag; an empty one is a faint ring with a "+" (picks a card in the binder). Tap a side one, or press 1 / 2 / 3, to
-- summon it (it slides to the middle); tap the one out to send it back. Its name, level and element under it. Under
-- that, you: your face (CharacterController: the character window), your health (full outside fights; a fight shows its
-- own) and your level with its XP bar; on a phone everything flush right, your row at the very top over the cash pill,
-- the weapon chip on a row under the name (WeaponSwitchController). Cards resting after a
-- fight dim and show an hourglass and "2:41". Hovering a card (or holding a finger on it) shows its tooltip above it:
-- Power, HP / ATK / SPD bars, perk and rest (Util/CardTips). Numbers: Config/Party BAR (DOCK).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local Party = require(Config:WaitForChild("Party"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local BabyColors = require(Config:WaitForChild("BabyColors"))
local HudLayout = require(Config:WaitForChild("HudLayout"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local PartyRules = require(Shared:WaitForChild("Util"):WaitForChild("PartyRules"))
local UiLayout = require(Shared:WaitForChild("Util"):WaitForChild("UiLayout"))
local PartyDock = require(Shared:WaitForChild("Util"):WaitForChild("PartyDock"))
local LevelRules = require(Shared:WaitForChild("Util"):WaitForChild("LevelRules"))
local SparkPath = require(Shared:WaitForChild("Util"):WaitForChild("SparkPath"))
local XpPill = require(Shared:WaitForChild("Util"):WaitForChild("XpPill"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local RestTimers = require(ClientUtil:WaitForChild("RestTimers"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Motion = require(ClientUtil:WaitForChild("Motion"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local CardTips = require(ClientUtil:WaitForChild("CardTips"))
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local CreatureVisuals = require(ClientUtil:WaitForChild("CreatureVisuals"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))
local PartyController = require(Controllers:WaitForChild("PartyController"))
local BuffController = require(Controllers:WaitForChild("BuffController"))

type SlotView = {
	hit: TextButton, -- the tap area round the portrait (Party.BAR.HIT)
	button: Frame, -- the round portrait
	lift: UIScale,
	rim: Frame, -- the element-coloured rim (light to full colour)
	rimShade: UIGradient,
	base: Frame, -- the rim's deep shade showing under it
	shine: Frame,
	chipEdge: UIStroke, -- the slot number chip's outline, in the element colour
	art: ImageLabel,
	element: Frame,
	level: TextLabel,
	empty: Frame,
	outTag: TextLabel,
	glow: ImageLabel,
	rest: TextLabel,
	shade: Frame,
	veil: Frame, -- the phone's dark veil over a side creature
}

local BAR = Party.BAR
local player = Players.LocalPlayer
local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end
local SLOT_SIZE = UDim2.fromOffset(BAR.PORTRAIT, BAR.PORTRAIT)
local EMPTY = rgb(BAR.EMPTY)
local EMPTY_EDGE = rgb(BAR.EMPTY_EDGE)
local BROWN = rgb(BAR.TEXT)
local OUT_COLOR = rgb(BAR.OUT)
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(20, 28, 60)
local SUMMON_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
local SUMMON_ACTION = "PartySummon"
local TIP_GAP = 10
local TIP_WIDTH = 250


local PartyBarController = {}

local slotViews: { SlotView } = {}
local slots: { [number]: string } = {} -- party slot -> beastId
local heldLevel: { [string]: number } = {} -- beastId -> the level its chip keeps while XP sparks fly to it
local landedHandlers: { (beastId: string) -> () } = {}
local summoned: number? = nil
local tip: Frame -- the hover / long-press tooltip over the bar
local tipSlot: number? = nil -- the slot it describes
local swallowTap: { [number]: boolean } = {} -- a long press shows the tooltip instead of summoning
local partyKnown = false -- the first PartyChanged is the party loading, not a change to announce
local pendingChanges: { PartyRules.Change } = {}
local announcing = false
local dock: Frame -- the whole dock (carousel, name, you)
local carousel: Frame -- the slots' box
local summonedChanged = Instance.new("BindableEvent")

-- Fires when the summoned slot changes (a summon, an unsummon or a swap): the mascot ducks
PartyBarController.Summoned = summonedChanged.Event

-- Above its slot (centred, kept on screen)
local function placeTip()
	local slot = tipSlot
	local view = if slot then slotViews[slot] else nil
	if not view or not tip.Visible then
		return
	end
	local screen = tip.Parent :: GuiObject
	local origin = screen.AbsolutePosition
	local button = view.button
	local spot = UiLayout.above(
		{ x = button.AbsolutePosition.X - origin.X, y = button.AbsolutePosition.Y - origin.Y, w = button.AbsoluteSize.X, h = button.AbsoluteSize.Y },
		{ w = tip.AbsoluteSize.X, h = tip.AbsoluteSize.Y },
		{ w = screen.AbsoluteSize.X, h = screen.AbsoluteSize.Y },
		TIP_GAP
	)
	tip.Position = UDim2.fromOffset(spot.x, spot.y)
end

-- Fills the tooltip with this slot's card (false: the slot is empty)
local function fillTip(slot: number): boolean
	local beastId = slots[slot]
	local beast = if beastId then BinderController.GetBeasts()[beastId] else nil
	local card = if beast then Cards.ById[beast.cardId] else nil
	if not beast or not card or not beastId then
		return false
	end
	local perk = PartyRules.getPerk(Party, card.element, card.rarity, beast.stars)
	local fightPerk = PartyRules.getFightPerk(Party, card.element, card.rarity, beast.stars)
	CardTips.copy(tip, {
		card = card,
		foil = beast.foil,
		grade = beast.grade,
		level = beast.level,
		stars = beast.stars,
		power = BeastRules.getPower(card, beast.foil, beast.level, beast.stars, beast.grade),
		stats = BeastRules.getStats(card, beast.foil, beast.level, beast.stars, beast.grade),
		reference = CardTips.reference(),
		perk = if perk then PartyRules.describe(perk) else nil,
		fightPerk = if fightPerk then PartyRules.describeFight(fightPerk) else nil,
		restSeconds = RestTimers.GetSeconds(beastId),
	})
	return true
end

local function hideTip()
	tip.Visible = false
	tipSlot = nil
end

local function showTip(slot: number)
	if UIKit.anyPanelOpen() or not fillTip(slot) then
		hideTip()
		return
	end
	tipSlot = slot
	tip.Visible = true
	placeTip()
end

local DOCK = BAR.DOCK
-- The carousel (Util/PartyDock.carousel): the slot last in the middle stays there when sent back in
local focus: number? = nil
local centerSlot = 1
-- Under it: the middle creature's name, level and element, and your row
local nameLabel: TextLabel
local nameElement: Frame
local meRow: Frame
local weaponSpot: Frame
local levelBadge: Frame
local levelNumber: TextLabel
local xpFill: Frame
local xpWords: TextLabel
-- Phones (owner 2026-11-13, declutter pick A): the name pill and the middle portrait's element badge
local compact = false
local nameLine: Frame
local nameEdge: UIStroke
local namePad: UIPadding
local elementBadge: Frame
local elementIcon: Frame

-- The name line: the middle creature's name (its level sits on top of its portrait, owner 2026-11-13), on a computer
-- its element after it, on a phone a soft pill with the element on the portrait's corner
local function writeName()
	if not nameLabel then
		return
	end
	local beast = BinderController.GetBeasts()[slots[centerSlot] or ""]
	local card = if beast then Cards.ById[beast.cardId] else nil
	nameLabel.Text = if card then card.name else "Add a creature"
	nameElement.Visible = card ~= nil and not compact
	elementBadge.Visible = card ~= nil and compact
	if card then
		Icon.set(nameElement, card.element)
		Icon.set(elementIcon, card.element)
	end
	nameLine.BackgroundTransparency = if compact then DOCK.pill.transparency else 1
	nameEdge.Enabled = compact
	local pad = UDim.new(0, if compact then DOCK.pill.pad else 0)
	namePad.PaddingLeft, namePad.PaddingRight = pad, pad
end

-- Tap or key: an empty slot asks for a card, a party card summons, the summoned one goes back
local function useSlot(slot: number)
	if not slots[slot] then
		BinderController.Open("Tap a card, then Add to party.")
	elseif summoned == slot then
		Remotes.Summon:FireServer(nil)
	else
		Remotes.Summon:FireServer(slot)
	end
end

local function keyChip(parent: GuiObject, key: string): UIStroke
	local chip = UIKit.label(parent, key, Enum.Font.FredokaOne, 12, WHITE)
	chip.Name = "Key"
	-- Bottom-left corner, clear of the OUT tag on top and the level chip in the middle
	chip.AnchorPoint = Vector2.new(0.5, 0.5)
	chip.Position = UDim2.new(0, 1, 1, -1)
	chip.Size = UDim2.fromOffset(17, 17)
	chip.TextXAlignment = Enum.TextXAlignment.Center
	chip.TextColor3 = INK
	chip.BackgroundColor3 = WHITE
	chip.BackgroundTransparency = 0
	chip.ZIndex = 8
	UIKit.corner(chip, 9)
	return UIKit.outline(chip, BROWN, 1.5)
end

-- A round piece of the portrait, `grow` px bigger than it all round, `z` among the portrait's pieces
local function disc(parent: GuiObject, name: string, grow: number, z: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(1, grow * 2, 1, grow * 2)
	frame.BorderSizePixel = 0
	frame.ZIndex = z
	frame.Parent = parent
	UIKit.corner(frame, (BAR.PORTRAIT + grow * 2) / 2)
	return frame
end

local function makeSlot(parent: Instance, slot: number): SlotView
	-- A tap area big enough for a finger at the smallest HUD scale, the portrait drawn in its middle
	local hit = Instance.new("TextButton")
	hit.Name = `Slot{slot}`
	hit.LayoutOrder = slot
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromOffset(BAR.HIT, BAR.HIT)
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Parent = parent
	local button = Instance.new("Frame")
	button.Name = "Portrait"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.5)
	button.Size = SLOT_SIZE
	button.BackgroundColor3 = EMPTY
	button.ClipsDescendants = false
	button.Parent = hit
	UIKit.corner(button, BAR.PORTRAIT / 2)
	local lift = Instance.new("UIScale")
	lift.Parent = button

	-- The summoned glow behind the card
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(2, 2)
	glow.Image = CardDesign.IMAGES.GLOW
	glow.ImageColor3 = OUT_COLOR
	glow.ImageTransparency = 0.25
	glow.ZIndex = 0
	glow.Visible = false
	glow.Parent = button

	-- The card: its element scene with the element icon on it
	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.ScaleType = Enum.ScaleType.Crop
	art.ZIndex = 2
	art.Parent = button
	UIKit.corner(art, BAR.PORTRAIT / 2)
	local element = Icon.make(button, "Ember", UDim2.fromScale(0.62, 0.62))
	element.AnchorPoint = Vector2.new(0.5, 0.5)
	element.Position = UDim2.fromScale(0.5, 0.46)
	element.SizeConstraint = Enum.SizeConstraint.RelativeXX
	element.ZIndex = 3

	-- The 3D rim (Party.BAR RIM): its deep shade dropped under it, the rim itself, a white ring round the picture, the
	-- picture sunk in (dark at its top) and a shine across the top
	local base = disc(button, "Base", BAR.RIM, 0)
	base.Position = UDim2.new(0.5, 0, 0.5, BAR.RIM_BASE)
	local rim = disc(button, "Rim", BAR.RIM, 1)
	rim.BackgroundColor3 = WHITE
	local rimShade = Instance.new("UIGradient")
	rimShade.Rotation = 90
	rimShade.Parent = rim
	local ring = Instance.new("UIStroke")
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Color = WHITE
	ring.Thickness = BAR.INNER_RING
	ring.Parent = art
	local sink = Instance.new("Frame")
	sink.Name = "Sink"
	sink.Size = UDim2.fromScale(1, 1)
	sink.BackgroundColor3 = Color3.new(0, 0, 0)
	sink.BorderSizePixel = 0
	sink.ZIndex = art.ZIndex
	sink.Parent = art
	UIKit.corner(sink, BAR.PORTRAIT / 2)
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, BAR.SINK.transparency),
		NumberSequenceKeypoint.new(BAR.SINK.depth, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = sink
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.AnchorPoint = Vector2.new(0.5, 0)
	shine.Position = UDim2.fromScale(0.5, BAR.SHINE.top)
	shine.Size = UDim2.fromScale(BAR.SHINE.width, BAR.SHINE.height)
	shine.BackgroundColor3 = WHITE
	shine.BackgroundTransparency = BAR.SHINE.transparency
	shine.BorderSizePixel = 0
	shine.ZIndex = 4
	shine.Parent = button
	UIKit.corner(shine, BAR.PORTRAIT)

	-- The level in a gold chip at the top centre of the portrait (owner 2026-11-13: "Put the level at the center top of
	-- each circle on party"); it rolls up there after a fight (rollLevel)
	local level = UIKit.label(button, "", Enum.Font.FredokaOne, DOCK.levelText, rgb(DOCK.chipText))
	level.Name = "Level"
	level.AnchorPoint = Vector2.new(0.5, 0.5)
	level.Position = UDim2.new(0.5, 0, 0, -1)
	level.Size = UDim2.fromOffset(0, DOCK.levelText + 4)
	level.AutomaticSize = Enum.AutomaticSize.X
	level.TextWrapped = false
	level.TextXAlignment = Enum.TextXAlignment.Center
	level.BackgroundColor3 = rgb(DOCK.chip)
	level.BackgroundTransparency = 0
	level.ZIndex = 8
	UIKit.corner(level, (DOCK.levelText + 4) / 2)
	UIKit.outline(level, WHITE, 1.5)
	local levelPad = Instance.new("UIPadding")
	levelPad.PaddingLeft = UDim.new(0, 5)
	levelPad.PaddingRight = UDim.new(0, 5)
	levelPad.Parent = level

	-- Empty: a faint ring with a "+"
	local empty = Instance.new("Frame")
	empty.Name = "Empty"
	empty.BackgroundTransparency = 1
	empty.Size = UDim2.fromScale(1, 1)
	empty.ZIndex = 2
	empty.Parent = button
	UIKit.corner(empty, BAR.PORTRAIT / 2)
	UIKit.outline(empty, EMPTY_EDGE, 2)
	local plus = UIKit.label(empty, "+", Enum.Font.FredokaOne, 26, EMPTY_EDGE:Lerp(BROWN, 0.4))
	plus.Size = UDim2.fromScale(1, 1)
	plus.TextXAlignment = Enum.TextXAlignment.Center
	plus.ZIndex = 3

	local outTag = UIKit.label(button, "OUT", Enum.Font.FredokaOne, 11, WHITE)
	outTag.Name = "Out"
	outTag.AnchorPoint = Vector2.new(0.5, 0.5)
	outTag.Position = UDim2.new(0.5, 0, 1, 1) -- at the bottom: the level has the top
	outTag.Size = UDim2.fromOffset(32, 15)
	outTag.TextXAlignment = Enum.TextXAlignment.Center
	outTag.BackgroundColor3 = OUT_COLOR
	outTag.BackgroundTransparency = 0
	outTag.ZIndex = 7
	outTag.Visible = false
	UIKit.corner(outTag, 8)

	-- Resting: the card dims and the countdown sits over it
	local shade = Instance.new("Frame")
	shade.Name = "Resting"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.ZIndex = 6
	shade.Visible = false
	shade.Parent = button
	UIKit.corner(shade, BAR.PORTRAIT / 2)
	-- Resting: an hourglass over the time left (icons, not emoji)
	local hourglass = Icon.make(shade, "Hourglass", UDim2.fromScale(0.5, 0.5))
	hourglass.AnchorPoint = Vector2.new(0.5, 0)
	hourglass.Position = UDim2.fromScale(0.5, 0.08)
	hourglass.SizeConstraint = Enum.SizeConstraint.RelativeXX
	hourglass.ZIndex = 7
	local rest = UIKit.label(shade, "", Enum.Font.FredokaOne, 12, WHITE)
	rest.AnchorPoint = Vector2.new(0, 1)
	rest.Position = UDim2.fromScale(0, 0.92)
	rest.Size = UDim2.new(1, 0, 0, 14)
	rest.TextXAlignment = Enum.TextXAlignment.Center
	rest.ZIndex = 7
	UIKit.outlined(rest, 1.5)

	local veil = Instance.new("Frame")
	veil.Name = "Veil"
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = DOCK.sideVeil
	veil.ZIndex = 6
	veil.Visible = false
	veil.Parent = button
	UIKit.corner(veil, BAR.PORTRAIT / 2)

	local chipEdge = keyChip(button, tostring(slot))
	hit.Activated:Connect(function()
		if swallowTap[slot] then
			swallowTap[slot] = nil
			return
		end
		if slots[slot] then
			focus = slot -- it slides to the middle (and stays there when sent back in)
		end
		useSlot(slot)
	end)
	-- Mouse: hover for the tooltip. Touch: hold a finger on the card (the tap then doesn't summon)
	hit.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled then
			showTip(slot)
		end
	end)
	hit.MouseLeave:Connect(function()
		if tipSlot == slot then
			hideTip()
		end
	end)
	local pressed = 0
	hit.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		swallowTap[slot] = nil -- a hold released off the card never fired Activated: don't eat this new tap
		pressed += 1
		local press = pressed
		task.delay(UIStyle.LONG_PRESS, function()
			if pressed == press and slots[slot] then
				swallowTap[slot] = true
				showTip(slot)
			end
		end)
	end)
	hit.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		pressed += 1 -- cancels a hold still counting
		if tipSlot == slot then
			hideTip()
		end
	end)
	return {
		hit = hit,
		button = button,
		lift = lift,
		rim = rim,
		rimShade = rimShade,
		base = base,
		shine = shine,
		chipEdge = chipEdge,
		art = art,
		element = element,
		level = level,
		empty = empty,
		outTag = outTag,
		glow = glow,
		rest = rest,
		shade = shade,
		veil = veil,
	}
end

local preloaded = false

-- Once the party is known: download its pets' models first, then every other creature model
local function preloadModels(beasts: { [string]: any })
	if preloaded then
		return
	end
	local names = {}
	for _, beastId in slots do
		local beast = beasts[beastId]
		local card = if beast then Cards.ById[beast.cardId] else nil
		if card then
			table.insert(names, card.name)
		end
	end
	if #names == 0 then
		return
	end
	preloaded = true
	CreatureVisuals.preload(names)
end

-- The carousel (Util/PartyDock.carousel): each slot slides to its spot, the middle one big and in front, and the name
-- line under it tells who it is
local function placeCarousel()
	local spots = PartyDock.carousel(slots, summoned, focus, Party.PARTY_SIZE)
	focus, centerSlot = spots.center, spots.center
	local slide = TweenInfo.new(DOCK.slide, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local middle = DOCK.width / 2
	for slot, view in slotViews do
		local inMiddle = slot == spots.center
		local x = if inMiddle then middle elseif slot == spots.left then DOCK.sideX else DOCK.width - DOCK.sideX
		local y = DOCK.height / 2 + (if inMiddle then 0 else DOCK.sideY)
		view.hit.ZIndex = if inMiddle then 3 else 2
		view.veil.Visible = compact and not inMiddle
		;(view.chipEdge.Parent :: GuiObject).Visible = not compact -- no key numbers on a phone
		TweenService:Create(view.hit, slide, { Position = UDim2.fromOffset(x, y) }):Play()
		TweenService:Create(view.lift, slide, { Scale = if inMiddle then DOCK.center else DOCK.side }):Play()
	end
	writeName()
end

local function render()
	local beasts = BinderController.GetBeasts()
	preloadModels(beasts)
	for slot, view in slotViews do
		local beast = beasts[slots[slot] or ""]
		local card = if beast then Cards.ById[beast.cardId] else nil
		local isSummoned = card ~= nil and summoned == slot
		view.empty.Visible = card == nil
		view.art.Visible = card ~= nil
		view.element.Visible = card ~= nil
		view.level.Visible = card ~= nil
		view.outTag.Visible = isSummoned
		view.glow.Visible = isSummoned
		if card and beast then
			local own = CardDesign.ART_IMAGES[card.name]
			view.art.Image = CardFace.artImage(card)
			Icon.set(view.element, card.element)
			view.element.Visible = own == nil -- a card's own picture already shows its creature
			view.level.Text = `Lv {heldLevel[beast.id] or beast.level}`
			view.button.BackgroundColor3 = Cards.ELEMENTS[card.element] or EMPTY
		else
			view.button.BackgroundColor3 = EMPTY
		end
		-- The rim in the creature's element colour (Config/BabyColors ELEMENTS); the summoned one bigger and higher
		local shades = if card then UIStyle.BABY[BabyColors.ELEMENTS[card.element] or "white"] else nil
		view.rim.Visible = shades ~= nil
		view.base.Visible = shades ~= nil
		view.shine.Visible = shades ~= nil
		if shades then
			view.rimShade.Color = ColorSequence.new(shades.light, shades.fill)
			view.base.BackgroundColor3 = shades.deep
			view.chipEdge.Color = shades.fill
		else
			view.chipEdge.Color = BROWN
		end
	end
	placeCarousel()
end

local function nameOf(beastId: string?): string?
	local beast = if beastId then BinderController.GetBeasts()[beastId] else nil
	local card = if beast then Cards.ById[beast.cardId] else nil
	return if card then card.name else nil
end

-- A card joining the party: its slot pops up and settles, the rim flashing white
local function celebrate(slot: number)
	local view = slotViews[slot]
	if not view then
		return
	end
	local rest = if slot == centerSlot then DOCK.center else DOCK.side
	local half = BAR.POP_SECONDS / 2
	local up = TweenService:Create(view.lift, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = rest * BAR.POP })
	up.Completed:Once(function()
		TweenService:Create(view.lift, TweenInfo.new(half, Enum.EasingStyle.Back), { Scale = rest }):Play()
	end)
	up:Play()
	view.rimShade.Color = ColorSequence.new(UIKit.Colors.Accent)
	task.delay(BAR.POP_SECONDS, render) -- back to its element rim
end

-- Toasts the party's changes ("Cindercub swapped in for Ashbeak!") once the cards' names are known: a card added
-- from a plain copy is new to the binder until its CollectionChanged arrives, so it waits up to BAR.NAME_WAIT
local function announce()
	if announcing then
		return
	end
	announcing = true
	local waited = 0
	while waited < BAR.NAME_WAIT do
		local missing = false
		for _, change in pendingChanges do
			missing = missing or (change.after ~= nil and nameOf(change.after) == nil) or (change.before ~= nil and nameOf(change.before) == nil)
		end
		if not missing then
			break
		end
		waited += task.wait(0.2)
	end
	local messages = {}
	for _, change in pendingChanges do
		table.insert(messages, PartyRules.changeText(change.kind, nameOf(change.after), nameOf(change.before)))
		if change.after then
			celebrate(change.slot)
		end
	end
	pendingChanges = {}
	announcing = false
	if #messages > 0 then
		UIController.Notify(table.concat(messages, "  "), false, nil, "Party")
	end
end

-- from / to: the creature's level before and after the fight (the chip rolls between them as the sparks land)
export type XpGain = { id: string, levelUp: boolean?, from: number?, to: number? }

-- Called once per gain when its sparks land, or at once when there are no sparks to watch (LevelUpController starts
-- the creature's level-up pillar then, spec 2026-11-04-round4-design section 9)
function PartyBarController.OnLanded(handler: (beastId: string) -> ())
	table.insert(landedHandlers, handler)
end

local function landed(beastId: string)
	for _, handler in landedHandlers do
		task.spawn(handler, beastId)
	end
end

-- The level chip counts up from the held level to the creature's new one (round 4), then shows the real level
local function rollLevel(view: any, beastId: string, toLevel: number)
	local fromLevel = heldLevel[beastId]
	heldLevel[beastId] = nil
	if not fromLevel or fromLevel >= toLevel then
		render()
		return
	end
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - started) / BAR.SPARKS.levelRoll, 1)
		if view.level.Parent then
			view.level.Text = `Lv {XpPill.countUp(fromLevel, toLevel, t)}`
		end
		if t >= 1 then
			connection:Disconnect()
			render()
		end
	end)
end

-- After a won monster fight (spec 2026-11-03-windows-round3-design): glowing sparks fly from `from` (where the
-- monster was, GUI pixels) into each portrait whose creature is in `gains`, then "+xp XP" pops over it and its level
-- chip bumps (bigger on a level up) and, on a level up, counts up from the old level (round 4). Skipped while a window
-- covers the HUD or the bar is hidden.
function PartyBarController.ShowXpGains(from: Vector2, gains: { XpGain }, xp: number)
	local look = BAR.SPARKS
	local screen = UIController.GetScreenGui()
	if not dock or not dock.Visible or UIKit.anyPanelOpen() or xp <= 0 then
		for _, gain in gains do
			landed(gain.id)
		end
		return
	end
	-- Each levelled-up creature's chip keeps its old level while the sparks fly
	for _, gain in gains do
		if gain.levelUp and gain.from then
			heldLevel[gain.id] = gain.from
		end
	end
	render()
	local origin = screen.AbsolutePosition
	local color = rgb(look.color)
	for _, gain in gains do
		local slot: number? = nil
		for index, beastId in slots do
			if beastId == gain.id then
				slot = index
			end
		end
		local view = if slot then slotViews[slot] else nil
		if not view then
			heldLevel[gain.id] = nil
			landed(gain.id)
			continue -- swapped out mid-fight: no portrait to fly to
		end
		local target = view.button.AbsolutePosition + view.button.AbsoluteSize / 2 - origin
		local count = SparkPath.count(xp, look.min, look.max)
		for index = 1, count do
			task.delay((index - 1) * look.stagger, function()
				local spark = Instance.new("ImageLabel")
				spark.Name = "XpSpark"
				spark.BackgroundTransparency = 1
				spark.Image = CardDesign.IMAGES.GLOW
				spark.ImageColor3 = color
				spark.AnchorPoint = Vector2.new(0.5, 0.5)
				spark.Size = UDim2.fromOffset(look.size, look.size)
				spark.ZIndex = 20
				spark.Parent = screen
				local jitter = (index - (count + 1) / 2) * 18
				local started = os.clock()
				local connection: RBXScriptConnection
				connection = RunService.RenderStepped:Connect(function()
					local t = math.min((os.clock() - started) / look.seconds, 1)
					local eased = t * t * (3 - 2 * t)
					local x, y = SparkPath.point(from.X + jitter, from.Y, target.X, target.Y, look.lift + jitter, eased)
					spark.Position = UDim2.fromOffset(x, y)
					spark.ImageTransparency = if t > 0.85 then (t - 0.85) / 0.15 else 0
					if t >= 1 then
						connection:Disconnect()
						spark:Destroy()
					end
				end)
			end)
		end
		-- Landed: "+xp XP" over the portrait and a bump on its level chip
		task.delay((count - 1) * look.stagger + look.seconds, function()
			landed(gain.id)
			if not view.button.Parent then
				heldLevel[gain.id] = nil
				return
			end
			Motion.bump(view.level)
			if gain.levelUp then
				celebrate(slot :: number)
			end
			rollLevel(view, gain.id, gain.to or 0)
			local pop = UIKit.label(screen, `+{xp} XP`, Enum.Font.FredokaOne, look.popText, WHITE)
			pop.AnchorPoint = Vector2.new(0.5, 1)
			pop.Position = UDim2.fromOffset(target.X, target.Y - view.button.AbsoluteSize.Y / 2)
			pop.Size = UDim2.fromOffset(120, look.popText + 4)
			pop.TextXAlignment = Enum.TextXAlignment.Center
			pop.TextWrapped = false
			pop.ZIndex = 21
			local edge = Instance.new("UIStroke")
			edge.Color = UIStyle.BABY.lilac.deep
			edge.Thickness = 2
			edge.Parent = pop
			local info = TweenInfo.new(look.popSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(pop, info, {
				Position = UDim2.fromOffset(target.X, target.Y - view.button.AbsoluteSize.Y / 2 - look.popRise),
				TextTransparency = 1,
			}):Play()
			TweenService:Create(edge, info, { Transparency = 1 }):Play()
			task.delay(look.popSeconds, function()
				pop:Destroy()
			end)
		end)
	end
end

-- Your row under the carousel (CharacterController puts your face first in it)
function PartyBarController.GetMeRow(): Frame
	return meRow
end

-- The weapon chip's spot under your row (WeaponSwitchController shows it and sits the chip on it, phones)
function PartyBarController.GetWeaponSpot(): Frame
	return weaponSpot
end

function PartyBarController.Start()
	-- The dock: no box (owner 2026-11-13), each piece with its own white rim; the carousel, the name line, your row
	local bar = Instance.new("Frame")
	bar.Name = "PartyBar"
	bar.LayoutOrder = 0 -- left of the buff / cash column
	bar.Size = UDim2.new()
	bar.AutomaticSize = Enum.AutomaticSize.XY
	bar.BackgroundTransparency = 1
	bar.Parent = UIController.GetDockHolder() -- a PC's bottom left; a phone's status row (OnCompact below)
	Hud.calmPiece(bar, "party") -- hidden through Pish's first visit (a calm HUD) and Chikin's but his summon step
	dock = bar
	local stack = Instance.new("UIListLayout")
	stack.FillDirection = Enum.FillDirection.Vertical
	stack.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stack.Padding = UDim.new(0, DOCK.gap)
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = bar

	carousel = Instance.new("Frame")
	carousel.Name = "Carousel"
	carousel.LayoutOrder = 1
	carousel.BackgroundTransparency = 1
	carousel.Size = UDim2.fromOffset(DOCK.width, DOCK.height)
	carousel.Parent = bar

	-- The middle one's name, its level in a gold chip, its element; a row as wide as the carousel with the line centred
	-- under the middle creature (on a phone the line is a soft pill)
	local nameRow = Instance.new("Frame")
	nameRow.Name = "NameRow"
	nameRow.LayoutOrder = 2
	nameRow.BackgroundTransparency = 1
	nameRow.Size = UDim2.fromOffset(DOCK.width, DOCK.nameText + 6)
	nameRow.Parent = bar
	local line = Instance.new("Frame")
	line.Name = "NameLine"
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(0.5, 0.5)
	line.BackgroundColor3 = rgb(DOCK.pill.fill)
	line.BackgroundTransparency = 1
	line.Size = UDim2.fromOffset(0, DOCK.nameText + 6)
	line.AutomaticSize = Enum.AutomaticSize.X
	line.Parent = nameRow
	UIKit.corner(line, (DOCK.nameText + 6) / 2)
	nameEdge = UIKit.outline(line, WHITE, 1.5)
	nameEdge.Transparency = 0.3
	nameEdge.Enabled = false
	namePad = Instance.new("UIPadding")
	namePad.Parent = line
	nameLine = line
	local lineList = Instance.new("UIListLayout")
	lineList.FillDirection = Enum.FillDirection.Horizontal
	lineList.VerticalAlignment = Enum.VerticalAlignment.Center
	lineList.Padding = UDim.new(0, 5)
	lineList.SortOrder = Enum.SortOrder.LayoutOrder
	lineList.Parent = line
	nameLabel = UIKit.label(line, "", Enum.Font.FredokaOne, DOCK.nameText, WHITE)
	nameLabel.LayoutOrder = 1
	nameLabel.Size = UDim2.fromOffset(0, DOCK.nameText + 4)
	nameLabel.AutomaticSize = Enum.AutomaticSize.X
	nameLabel.TextWrapped = false
	UIKit.outlined(nameLabel, 1.5)
	nameElement = Icon.make(line, "Ember", UDim2.fromOffset(DOCK.nameText + 2, DOCK.nameText + 2))
	nameElement.LayoutOrder = 3

	-- the phone's element badge on the middle portrait's corner: a white disc with the element on it
	elementBadge = Instance.new("Frame")
	elementBadge.Name = "ElementBadge"
	elementBadge.AnchorPoint = Vector2.new(0.5, 0.5)
	elementBadge.Position = UDim2.fromOffset(DOCK.width / 2 + DOCK.elementAt, DOCK.height / 2 + DOCK.elementAt)
	elementBadge.Size = UDim2.fromOffset(DOCK.elementBadge, DOCK.elementBadge)
	elementBadge.BackgroundColor3 = WHITE
	elementBadge.ZIndex = 5
	elementBadge.Visible = false
	elementBadge.Parent = carousel
	UIKit.corner(elementBadge, DOCK.elementBadge / 2)
	elementIcon = Icon.make(elementBadge, "Ember", UDim2.fromScale(0.78, 0.78))
	elementIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	elementIcon.Position = UDim2.fromScale(0.5, 0.5)
	elementIcon.ZIndex = 6

	-- You: your face (CharacterController), your health and your level with its XP, the phone's weapon chip
	meRow = Instance.new("Frame")
	meRow.Name = "MeRow"
	meRow.LayoutOrder = 3
	meRow.BackgroundTransparency = 1
	meRow.Size = UDim2.fromOffset(0, DOCK.meHeight)
	meRow.AutomaticSize = Enum.AutomaticSize.X
	meRow.Parent = bar
	-- your buffs as round icons by your character info (owner 2026-11-13, buffs pick A; BuffController): left of your
	-- face on a phone, after your bars on a computer (OnCompact below)
	local buffs = BuffController.GetStack()
	if buffs then
		buffs.Parent = meRow
	end
	local meList = Instance.new("UIListLayout")
	meList.FillDirection = Enum.FillDirection.Horizontal
	meList.VerticalAlignment = Enum.VerticalAlignment.Center
	meList.Padding = UDim.new(0, 4)
	meList.SortOrder = Enum.SortOrder.LayoutOrder
	meList.Parent = meRow
	local bars = Instance.new("Frame")
	bars.Name = "Bars"
	bars.LayoutOrder = 1
	bars.BackgroundTransparency = 1
	bars.Size = UDim2.fromOffset(DOCK.barWidth + DOCK.badge + 4, DOCK.badge + 4)
	bars.Parent = meRow
	-- one bar: a white-rimmed track with its fill and its words over it, a badge at its left end
	local function makeBar(name: string, top: number, height: number, fill: { { number } }): (Frame, TextLabel)
		local track = Instance.new("Frame")
		track.Name = name
		track.Position = UDim2.fromOffset(DOCK.badge + 4, top)
		track.Size = UDim2.fromOffset(DOCK.barWidth, height)
		track.BackgroundColor3 = Color3.new(0, 0, 0)
		track.BackgroundTransparency = DOCK.trackTransparency
		track.ClipsDescendants = true
		track.Parent = bars
		UIKit.corner(track, height / 2)
		UIKit.outline(track, WHITE, 2)
		local inner = Instance.new("Frame")
		inner.Name = "Fill"
		inner.Size = UDim2.fromScale(1, 1)
		inner.BackgroundColor3 = WHITE
		inner.BorderSizePixel = 0
		inner.Parent = track
		UIKit.corner(inner, height / 2)
		local shade = Instance.new("UIGradient")
		shade.Rotation = 90
		shade.Color = ColorSequence.new(rgb(fill[1]), rgb(fill[2]))
		shade.Parent = inner
		local words = UIKit.label(track, "", Enum.Font.FredokaOne, DOCK.barText, WHITE)
		words.Size = UDim2.new(1, -8, 1, 0)
		words.Position = UDim2.fromOffset(4, 0)
		words.TextXAlignment = Enum.TextXAlignment.Right
		words.ZIndex = 3
		UIKit.outlined(words, 1.5)
		return inner, words
	end
	-- your XP bar alone (the health bar went, owner 2026-11-13: a fight shows your health), centred on the row
	local xpTop = (DOCK.badge + 4 - DOCK.xpHeight) / 2
	xpFill, xpWords = makeBar("Xp", xpTop, DOCK.xpHeight, DOCK.xpFill)
	levelBadge = Instance.new("Frame")
	levelBadge.Name = "Level"
	levelBadge.AnchorPoint = Vector2.new(0.5, 0.5)
	levelBadge.Position = UDim2.fromOffset(DOCK.badge / 2, xpTop + DOCK.xpHeight / 2)
	levelBadge.Size = UDim2.fromOffset(DOCK.badge, DOCK.badge)
	levelBadge.BackgroundTransparency = 1
	levelBadge.Parent = bars
	local star = Icon.make(levelBadge, "Level", UDim2.fromScale(1, 1))
	star.ZIndex = 2
	levelNumber = UIKit.label(levelBadge, "", Enum.Font.FredokaOne, DOCK.barText, WHITE)
	levelNumber.Size = UDim2.fromScale(1, 0.9)
	levelNumber.Position = UDim2.fromScale(0, 0.08)
	levelNumber.TextXAlignment = Enum.TextXAlignment.Center
	levelNumber.ZIndex = 4
	local levelEdge = Instance.new("UIStroke")
	levelEdge.Color = Color3.fromRGB(120, 70, 0)
	levelEdge.Thickness = 2
	levelEdge.Parent = levelNumber
	-- the phone's weapon chip on its own row under the name (owner 2026-11-13: "weapon should be below the character
	-- menu"), its count on its corner
	local look = HudLayout.WEAPON_SWITCH
	weaponSpot = Instance.new("Frame")
	weaponSpot.Name = "WeaponSpot"
	weaponSpot.LayoutOrder = 4
	weaponSpot.BackgroundTransparency = 1
	weaponSpot.Size = UDim2.fromOffset(look.compactChip, look.compactChip)
	weaponSpot.Visible = false
	weaponSpot.Parent = bar

	-- Phones (owner 2026-11-13: "align them all right"; "I want the character info to be at the very top. leveled with
	-- the roblox icons on the other side. below the exp is the coins"): every row flush right, and your row leaves the
	-- dock for the top of the corner's column, over the cash pill (UIController places the column)
	UIController.OnCompact(function(on: boolean)
		compact = on
		-- a PC (owner 2026-11-13: "on desktop can we move character info and party on the bottom left. align them"):
		-- the dock in the bottom-left corner, every row flush left
		bar.Parent = if on then UIController.GetStatusRow() else UIController.GetDockHolder()
		stack.HorizontalAlignment = if on then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
		meRow.Parent = if on then UIController.GetStatusRow() else bar
		meRow.LayoutOrder = if on then -2 else 3
		if buffs then
			buffs.LayoutOrder = if on then -3 else 10
		end
		placeCarousel() -- the phone's look: no key numbers, veiled sides, the name pill, the element badge
	end)

	-- your level and XP (the XP pill's job before, owner 2026-11-13: "the exp/level looks broken")
	local function updateXp()
		local xp = player:GetAttribute("XP")
		if typeof(xp) ~= "number" then
			levelNumber.Text = ""
			xpWords.Text = "Loading..."
			xpFill.Size = UDim2.fromScale(0, 1)
			return
		end
		local level = tostring(player:GetAttribute("Level") or 1)
		if levelNumber.Text ~= level and levelNumber.Text ~= "" then
			Motion.bump(levelBadge)
		end
		levelNumber.Text = level
		local into, span = LevelRules.getProgress(xp)
		xpFill.Size = UDim2.fromScale(if span > 0 then math.clamp(into / span, 0, 1) else 1, 1)
		xpWords.Text = PartyDock.xpText(into, span)
	end
	updateXp()
	player:GetAttributeChangedSignal("XP"):Connect(updateXp)
	player:GetAttributeChangedSignal("Level"):Connect(updateXp)

	tip = Instance.new("Frame")
	tip.Name = "PartyTip"
	tip.Size = UDim2.fromOffset(if UIKit.isPhone() then TIP_WIDTH - 30 else TIP_WIDTH, 0)
	tip.AutomaticSize = Enum.AutomaticSize.Y
	tip.BackgroundColor3 = UIStyle.PANEL
	tip.ZIndex = 50
	tip.Visible = false
	tip.Parent = UIController.GetScreenGui()
	UIKit.corner(tip, 12)
	UIKit.outline(tip, UIStyle.EDGE, UIStyle.EDGE_THICKNESS)
	local tipPadding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(tipPadding :: any)[side] = UDim.new(0, 10)
	end
	tipPadding.Parent = tip
	tip:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeTip) -- it sizes itself after its content

	for slot = 1, Party.PARTY_SIZE do
		slotViews[slot] = makeSlot(carousel, slot)
	end
	render()

	-- 1 / 2 / 3 summon (bound above Roblox's own hotbar keys; never while typing)
	ContextActionService:BindActionAtPriority(SUMMON_ACTION, function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local slot = table.find(SUMMON_KEYS, input.KeyCode)
		if not slot or not bar.Visible or not (bar.Parent :: GuiObject).Visible then
			return Enum.ContextActionResult.Pass
		end
		if slots[slot] then
			focus = slot
		end
		useSlot(slot)
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, table.unpack(SUMMON_KEYS))

	Remotes.PartyChanged.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.slots) ~= "table" then
			return
		end
		local before = slots
		slots = {}
		for _, entry in payload.slots do
			if typeof(entry) == "table" and typeof(entry.slot) == "number" and typeof(entry.beastId) == "string" then
				slots[entry.slot] = entry.beastId
			end
		end
		local wasSummoned = summoned
		summoned = if typeof(payload.summoned) == "number" then payload.summoned else nil
		render()
		if partyKnown and summoned ~= wasSummoned then
			summonedChanged:Fire()
		end
		if partyKnown then
			for _, change in PartyRules.changes(before, slots, Party.PARTY_SIZE) do
				table.insert(pendingChanges, change)
			end
			if #pendingChanges > 0 then
				task.spawn(announce)
			end
		end
		partyKnown = true
		local open = tipSlot
		if open then
			showTip(open)
		end
	end)
	-- Party cards arrive with the binder; redraw when it changes
	Remotes.CollectionChanged.OnClientEvent:Connect(function()
		task.defer(render)
	end)

	-- Resting countdowns: green with a "+" while you stand at the healing spring (it heals them faster)
	local heal = Party.HEAL_FX.color
	local healGreen = Color3.fromRGB(heal[1], heal[2], heal[3])
	local sinceRest = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceRest += dt
		if sinceRest < 0.5 then
			return
		end
		sinceRest = 0
		local healing = RestTimers.IsNearSpring()
		for slot, view in slotViews do
			local seconds = if slots[slot] then RestTimers.GetSeconds(slots[slot]) else 0
			view.shade.Visible = seconds > 0
			if seconds > 0 then
				view.rest.Text = if healing then `+{RestTimers.Format(seconds)}` else RestTimers.Format(seconds)
				view.rest.TextColor3 = if healing then healGreen else WHITE
			end
		end
		local open = tipSlot
		if open and tip.Visible then
			fillTip(open) -- the resting countdown in the tooltip
		end
	end)
end

return PartyBarController
