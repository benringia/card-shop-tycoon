--!strict
-- The weekly event's chip (owner 2026-11-19: "build the weekend events"; Config/Events, Util/EventRules,
-- Util/EventNow): a small pill riding under the quest strip (QuestController.Below, under Turts' chip). Gold while an
-- event is on ("Boss Rush · 5h left"), plain while it counts down to the next ("Next: Boss Rush in 2h"); its tooltip
-- says what the event does. A computer only (CompactHud.phonePieces eventChip): a phone gets the day's toast and the
-- Boss Ladder's line. Hidden through a new player's first visit (the strip's holder hides with fights and the calm HUD).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Events = require(Config:WaitForChild("Events"))
local UIIcons = require(Config:WaitForChild("UIIcons"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local CompactHud = require(Shared:WaitForChild("Util"):WaitForChild("CompactHud"))
local EventNow = require(Shared:WaitForChild("Util"):WaitForChild("EventNow"))
local EventRules = require(Shared:WaitForChild("Util"):WaitForChild("EventRules"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local Icon = require(ClientUtil:WaitForChild("Icon"))
local Tooltip = require(ClientUtil:WaitForChild("Tooltip"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local QuestController = require(Controllers:WaitForChild("QuestController"))
local UIController = require(Controllers:WaitForChild("UIController"))

local EventController = {}

local RENDER_SECONDS = 5 -- the countdown is in minutes at its finest

local holder: Frame
local words: TextLabel? = nil
local shownKey = "" -- the event and whether it's on, as the pill was last built

-- The event the chip is about: today's, or the next one coming
local function subject(): (Events.Event?, boolean)
	local today = EventNow.today()
	if today then
		return today, true
	end
	local coming = EventRules.next(Events, EventNow.unix())
	return coming, false
end

-- The pill for this event: its icon and the words, gold while it's on
local function build(event: Events.Event, live: boolean)
	holder:ClearAllChildren()
	local look = Events.CHIP
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, look.height)
	pill.Parent = holder
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = pill
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = if live
		then ColorSequence.new(UIStyle.BABY.butter.light, UIStyle.BABY.butter.fill)
		else ColorSequence.new(UIStyle.CREAM.BODY_TOP, UIStyle.CREAM.BODY_BOTTOM)
	shade.Parent = pill
	local rim = Instance.new("UIStroke")
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Color = Color3.new(1, 1, 1)
	rim.Thickness = 3
	rim.Parent = pill
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = pill
	local line = Instance.new("UIListLayout")
	line.FillDirection = Enum.FillDirection.Horizontal
	line.VerticalAlignment = Enum.VerticalAlignment.Center
	line.SortOrder = Enum.SortOrder.LayoutOrder
	line.Padding = UDim.new(0, look.gap)
	line.Parent = pill
	if (UIIcons :: { [string]: string })[event.icon] then
		Icon.make(pill, event.icon, UDim2.fromOffset(look.icon, look.icon)).LayoutOrder = 1
	else
		local emoji = UIKit.label(pill, event.icon, Enum.Font.GothamBold, look.textSize + 2, UIStyle.CREAM.INK)
		emoji.LayoutOrder = 1
		emoji.Size = UDim2.fromOffset(look.icon, look.height)
	end
	local text = UIKit.label(pill, "", Enum.Font.FredokaOne, look.textSize, UIStyle.CREAM.INK)
	text.Name = "Words"
	text.LayoutOrder = 2
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromOffset(0, look.height)
	text.TextWrapped = false
	words = text
	Tooltip.rich(pill, if live then `{event.name} · today` else `Next event: {event.name}`, { event.line, Events.CHIP.tip })
end

local function render()
	local allowed = CompactHud.phonePieces(UIController.IsCompact(), true, false, false).eventChip
	local event, live = subject()
	local text = EventNow.chip()
	-- TutorialDone is only set in the main game (false through Pish's tour); elsewhere the tour is long over
	local roomy = UIController.GetScreenGui().AbsoluteSize.Y >= Events.CHIP.minScreen
	local visible = allowed and roomy and event ~= nil and text ~= nil and Players.LocalPlayer:GetAttribute("TutorialDone") ~= false
	holder.Visible = visible
	if not visible or not event or not text then
		return
	end
	local key = `{event.id}:{live}`
	if key ~= shownKey then
		shownKey = key
		build(event, live)
	end
	local label = words
	if label then
		label.Text = text
	end
end

function EventController.Start()
	holder = Instance.new("Frame")
	holder.Name = "EventChip"
	holder.BackgroundTransparency = 1
	holder.AutomaticSize = Enum.AutomaticSize.X
	holder.Size = UDim2.fromOffset(0, Events.CHIP.height)
	holder.LayoutOrder = 5 -- under Turts' chip
	holder.Visible = false
	QuestController.Below(holder)
	UIController.OnCompact(render)
	UIController.GetScreenGui():GetPropertyChangedSignal("AbsoluteSize"):Connect(render)
	Players.LocalPlayer:GetAttributeChangedSignal("TutorialDone"):Connect(render)
	workspace:GetAttributeChangedSignal(EventNow.OVERRIDE):Connect(render) -- Studio's /event
	task.spawn(function()
		while true do
			render()
			task.wait(RENDER_SECONDS)
		end
	end)
end

return EventController
