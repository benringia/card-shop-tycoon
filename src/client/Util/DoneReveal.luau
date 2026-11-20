--!strict
-- A station's finished job waiting to be taken out (owner 2026-11-20, on the Card Condenser: "after the timer than
-- condenser just do nothing. I just got a toast notification. I need a better notification inside the condenser after
-- the timer is done, that is waiting for me to reopen the condenser"; then "also check the other machines"). The card
-- is back in the binder the moment its time is up; what's left is a player attribute naming it (CondenserDone,
-- GradingDone: Util/CondenseRules.encodeDone). While it's set this draws a reveal over everything in the station's
-- window, at once when the window is open, else each time it opens: a heading, the card, its new star popping in (or
-- its new grade) to a soft bell, a line of plain words, its Power with how much it grew, and Take it out, which tells
-- the server (the attribute clears). Numbers in Config/Upgrades REVEAL.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Upgrades = require(Config:WaitForChild("Upgrades"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CondenseRules = require(Shared:WaitForChild("Util"):WaitForChild("CondenseRules"))

local ClientUtil = script.Parent :: Instance
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))

local DoneReveal = {}

export type Options = {
	attribute: string, -- the player attribute holding the waiting result
	seen: RemoteEvent, -- fired by Take it out
	kind: "star" | "grade", -- what the job added
	heading: string,
}

local LOOK = Upgrades.REVEAL
local STAR_SIZE = 22
local player = Players.LocalPlayer

-- 1100 -> "1,100"
local function commas(value: number): string
	local text = tostring(math.floor(math.max(0, value)))
	return (string.gsub(string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,"))), "^,", ""))
end

local function bell()
	local ding = Instance.new("Sound")
	ding.SoundId = LOOK.ding.id
	ding.Volume = LOOK.ding.volume
	ding.PlaybackSpeed = LOOK.ding.pitch
	ding.Parent = SoundService
	ding.Ended:Once(function()
		ding:Destroy()
	end)
	ding:Play()
end

-- Something that pops in a beat after the card shows, with the bell
local function popIn(target: GuiObject)
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = target
	task.delay(LOOK.delay, function()
		if not target.Parent then
			return
		end
		TweenService:Create(scale, TweenInfo.new(LOOK.pop, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		bell()
	end)
end

-- Attaches the reveal to `panel` (a UIKit.panel). Returns `refresh(opened)`: call it when the window opens (`opened`
-- true: a result still waiting shows again) and it also runs whenever the attribute changes.
function DoneReveal.attach(panel: Frame, options: Options): (opened: boolean?) -> ()
	local palette = UIKit.colorsFor(panel)
	local veil = Instance.new("TextButton") -- a button, so taps on the window under it go nowhere
	veil.Name = "DoneVeil"
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Position = UDim2.fromOffset(0, UIKit.HEADER_HEIGHT)
	veil.Size = UDim2.new(1, 0, 1, -UIKit.HEADER_HEIGHT)
	veil.BackgroundColor3 = palette.row
	veil.BackgroundTransparency = 0.15
	veil.ZIndex = 60
	veil.Visible = false
	veil.Parent = panel
	UIKit.corner(veil, 18)
	local card = Instance.new("Frame")
	card.Name = "DoneCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(LOOK.width, LOOK.height)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.ZIndex = 61
	card.Parent = veil
	UIKit.corner(card, 18)
	UIKit.outline(card, UIKit.Colors.Accent, 3)
	local fit = Instance.new("UIScale")
	fit.Parent = card
	local shown = "" -- the attribute's value the reveal last showed (taken out: not shown again)

	local function build(done: CondenseRules.Done, info: typeof(Cards.List[1]))
		for _, child in card:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local function line(text: string, font: Enum.Font, size: number, color: Color3, y: number, height: number): TextLabel
			local label = UIKit.label(card, text, font, size, color)
			label.Position = UDim2.new(0, 14, 0, y)
			label.Size = UDim2.new(1, -28, 0, height)
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.ZIndex = 62
			return label
		end
		line(options.heading, Enum.Font.FredokaOne, 16, palette.hint, 12, 20)
		local faceHolder = Instance.new("Frame")
		faceHolder.AnchorPoint = Vector2.new(0.5, 0)
		faceHolder.Position = UDim2.new(0.5, 0, 0, 38)
		faceHolder.Size = UDim2.fromOffset(LOOK.face[1], LOOK.face[2])
		faceHolder.BackgroundTransparency = 1
		faceHolder.ZIndex = 62
		faceHolder.Parent = card
		local face = Instance.new("Frame")
		face.Size = UDim2.fromScale(1, 1)
		face.Parent = faceHolder
		UIKit.corner(face, 8)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = face
		CardFace.render(face, stroke, info, done.foil, false, { level = done.level, stars = done.stars, grade = done.grade })
		local y = 38 + LOOK.face[2] + 8
		line(`{info.name}{if done.foil then " (FOIL)" else ""}`, Enum.Font.FredokaOne, 20, palette.ink, y, 24)
		y += 28
		local before: number
		local words: string
		if options.kind == "star" then
			-- its stars, the new one popping in
			local rowWidth = BeastRules.MAX_STARS * (STAR_SIZE + 3)
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Position = UDim2.new(0.5, -rowWidth / 2, 0, y)
			row.Size = UDim2.fromOffset(rowWidth, STAR_SIZE)
			row.ZIndex = 62
			row.Parent = card
			for index = 1, BeastRules.MAX_STARS do
				local star = Icon.make(row, "Star", UDim2.fromOffset(STAR_SIZE, STAR_SIZE))
				star.Position = UDim2.fromOffset((index - 1) * (STAR_SIZE + 3), 0)
				star.ZIndex = 62
				Icon.set(star, "Star")
				local glyph = star:FindFirstChild("Glyph")
				if glyph and glyph:IsA("ImageLabel") then
					glyph.ImageTransparency = if index <= done.stars then 0 else 0.8
				end
				if index == done.stars then
					popIn(star)
				end
			end
			y += STAR_SIZE + 6
			words = CondenseRules.doneLine(done.stars)
			before = BeastRules.getPower(info, done.foil, done.level, done.stars - 1, done.grade)
		else
			-- its new grade on a gold pill, popping in
			local pill = Instance.new("Frame")
			pill.AnchorPoint = Vector2.new(0.5, 0)
			pill.Position = UDim2.new(0.5, 0, 0, y)
			pill.Size = UDim2.fromOffset(120, 30)
			pill.BackgroundColor3 = UIKit.Colors.Accent
			pill.ZIndex = 62
			pill.Parent = card
			UIKit.corner(pill, 15)
			local grade = UIKit.label(pill, BeastRules.describeGrade(done.grade), Enum.Font.FredokaOne, 18, Color3.fromRGB(58, 42, 0))
			grade.Size = UDim2.fromScale(1, 1)
			grade.TextXAlignment = Enum.TextXAlignment.Center
			grade.ZIndex = 63
			popIn(pill)
			y += 36
			words = CondenseRules.gradeDoneLine(done.grade)
			local under = CondenseRules.gradeBefore(done.grade) or done.grade
			before = BeastRules.getPower(info, done.foil, done.level, done.stars, under)
		end
		line(words, Enum.Font.GothamBold, 13, palette.inkSoft, y, 18)
		y += 20
		local after = BeastRules.getPower(info, done.foil, done.level, done.stars, done.grade)
		line(`Power {commas(after)}  {CondenseRules.gain(before, after)}`, Enum.Font.FredokaOne, 16, palette.good, y, 20)
		y += 28
		local take = UIKit.button(card, LOOK.button, UIKit.Colors.Accent)
		take.Name = "TakeOut"
		take.AnchorPoint = Vector2.new(0.5, 0)
		take.Position = UDim2.new(0.5, 0, 0, y)
		take.Size = UDim2.new(1, -40, 0, 52)
		take.TextSize = 18
		take.ZIndex = 62
		take.Activated:Connect(function()
			veil.Visible = false
			options.seen:FireServer()
		end)
	end

	local function refresh(opened: boolean?)
		if opened then
			shown = "" -- a result still waiting shows again each time the window opens, until it's taken out
		end
		local value = player:GetAttribute(options.attribute)
		local done = CondenseRules.decodeDone(value, if options.kind == "star" then 1 else 0)
		local info = if done then Cards.ById[done.cardId] else nil
		if not done or not info then
			veil.Visible = false
			shown = ""
			return
		end
		if not panel.Visible or shown == value then
			return
		end
		shown = value :: string
		build(done, info)
		-- a short window (a phone) shrinks the card to fit
		fit.Scale = math.clamp((veil.AbsoluteSize.Y - 16) / LOOK.height, 0.6, 1)
		veil.Visible = true
	end
	player:GetAttributeChangedSignal(options.attribute):Connect(function()
		refresh(false)
	end)
	return refresh
end

return DoneReveal
