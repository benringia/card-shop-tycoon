--!strict
-- A gift's win moment (spec 2026-11-15-daily-gifts-design; owner: "design must feel like a WIN"; Config/Gifts WIN):
-- the screen dims and light rays turn as the gift drops in (a daily gift: Pish's present picture; a chest: the boss
-- chest tinted purple or gold, in a viewport), it rattles three times, harder each time, over a rising whoosh, then
-- bursts in a flash and confetti (a chest's lid flies open on its glow) with its big title, and its gifts flip in one
-- by one as cards. A pack among them offers OPEN IT NOW! (rips it from the Bag); Nice! closes. `play` waits until it's
-- closed and says which pack to open, if any.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gifts = require(Shared:WaitForChild("Config"):WaitForChild("Gifts"))
local BossChests = require(Shared:WaitForChild("Config"):WaitForChild("BossChests"))

local Util = script.Parent :: Instance
local ChestModel = require(Util:WaitForChild("ChestModel"))
local Icon = require(Util:WaitForChild("Icon"))
local ScreenClear = require(Util:WaitForChild("ScreenClear"))
local ScreenCover = require(Util:WaitForChild("ScreenCover"))
local SoundBank = require(Util:WaitForChild("SoundBank"))
local UIKit = require(Util:WaitForChild("UIKit"))

local GiftWin = {}

export type Line = { icon: string, text: string, item: string?, pack: boolean }

local WIN = Gifts.WIN
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 111, 168)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 179, 64)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(95, 220, 140)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(79, 183, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(167, 123, 255)),
})
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 210, 63),
	Color3.fromRGB(255, 127, 184),
	Color3.fromRGB(122, 240, 168),
	Color3.fromRGB(130, 202, 255),
	Color3.fromRGB(191, 160, 255),
}
local PICTURE = 210 -- px: the gift's size on screen
local CARD = Vector2.new(132, 156)

local player = Players.LocalPlayer

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function sound(gui: Instance, key: string, pitch: number?)
	local id = (WIN.SOUNDS :: any)[key]
	if not id then
		return
	end
	local made = SoundBank.make(id)
	made.Volume = (WIN.VOLUMES :: any)[key] or 0.2
	made.PlaybackSpeed = pitch or 1
	made.Parent = gui
	made:Play()
	made.Ended:Once(function()
		made:Destroy()
	end)
end

local function tween(object: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local made = TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	made:Play()
	return made
end

-- The boss chest in a viewport, tinted `tint`: the whole render through the viewport's ImageColor3 (the model's
-- texture can't be recoloured from a script), the stand-in's parts too
local function chestView(parent: GuiObject, tint: Color3): (ViewportFrame, ChestModel.Chest)
	local view = Instance.new("ViewportFrame")
	view.Name = "Chest"
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(200, 190, 210)
	view.LightColor = Color3.fromRGB(255, 245, 230)
	view.LightDirection = Vector3.new(-0.4, -1, 0.6)
	view.Size = UDim2.fromScale(1, 1)
	view.Parent = parent
	local look = BossChests.LOOK.colors
	local chest = ChestModel.new(view, 4, { wood = rgb(look.wood), woodDark = rgb(look.woodDark), trim = rgb(look.trim) })
	view.ImageColor3 = Color3.new(1, 1, 1):Lerp(tint, 0.75)
	for _, entry in chest.parts do
		if entry.part ~= chest.glow then
			entry.part.Color = entry.color:Lerp(tint, 0.65)
		end
	end
	ChestModel.light(chest, tint:Lerp(Color3.new(1, 1, 1), 0.5), 0)
	ChestModel.place(chest, CFrame.new(0, 0, 0))
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 4.2, -10.5), Vector3.new(0, 1.9, 0)) -- room above for the lid flying open
	camera.Parent = view
	view.CurrentCamera = camera
	return view, chest
end

-- Confetti bursting out from the middle and falling
local function confetti(layer: GuiObject, count: number)
	local random = Random.new()
	for _ = 1, count do
		local bit = Instance.new("Frame")
		bit.AnchorPoint = Vector2.new(0.5, 0.5)
		bit.Position = UDim2.fromScale(0.5, 0.42)
		bit.Size = UDim2.fromOffset(random:NextInteger(8, 14), random:NextInteger(5, 9))
		bit.BackgroundColor3 = CONFETTI_COLORS[random:NextInteger(1, #CONFETTI_COLORS)]
		bit.BorderSizePixel = 0
		bit.Rotation = random:NextNumber(0, 360)
		bit.Parent = layer
		UIKit.corner(bit, 2)
		local angle = random:NextNumber(0, math.pi * 2)
		local reach = random:NextNumber(0.18, 0.5)
		local out = UDim2.fromScale(0.5 + math.cos(angle) * reach, 0.42 + math.sin(angle) * reach * 0.8)
		local life = random:NextNumber(1.4, 2.2)
		tween(bit, 0.5, { Position = out, Rotation = bit.Rotation + random:NextNumber(-200, 200) }, Enum.EasingStyle.Quart)
		task.delay(0.5, function()
			tween(bit, life, {
				Position = out + UDim2.fromScale(random:NextNumber(-0.04, 0.04), 0.35),
				Rotation = bit.Rotation + random:NextNumber(-300, 300),
				BackgroundTransparency = 1,
			}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
			task.delay(life, bit.Destroy, bit)
		end)
	end
end

-- One gift card: its picture and words, flipping in (a squeeze on X, as a card turning)
local function card(row: Frame, line: Line, order: number, gold: boolean)
	local face = Instance.new("Frame")
	face.Name = `Gift{order}`
	face.LayoutOrder = order
	face.Size = UDim2.fromOffset(CARD.X, CARD.Y)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.Parent = row
	UIKit.corner(face, 16)
	UIKit.outline(face, if gold then Color3.fromRGB(255, 200, 60) else Color3.fromRGB(240, 222, 245), 4)
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Color = if gold
		then ColorSequence.new(Color3.fromRGB(255, 250, 225), Color3.fromRGB(255, 226, 140))
		else ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(246, 236, 255))
	fill.Parent = face
	local picture = Icon.make(face, line.icon, UDim2.fromOffset(84, 84))
	picture.AnchorPoint = Vector2.new(0.5, 0)
	picture.Position = UDim2.new(0.5, 0, 0, 12)
	local words = UIKit.label(face, line.text, Enum.Font.FredokaOne, 17, Color3.fromRGB(91, 61, 110))
	words.AnchorPoint = Vector2.new(0.5, 1)
	words.Position = UDim2.new(0.5, 0, 1, -8)
	words.Size = UDim2.new(1, -12, 0, 44)
	words.TextWrapped = true
	words.TextXAlignment = Enum.TextXAlignment.Center
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = face
	face.Rotation = -12
	tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(face, 0.4, { Rotation = 0 }, Enum.EasingStyle.Back)
	UIKit.glow(face, if gold then Color3.fromRGB(255, 210, 80) else Color3.fromRGB(220, 180, 255), 16, 0, 0.4)
end

local function button(parent: Instance, name: string, text: string, color: Color3, order: number): TextButton
	local made = UIKit.button(parent, text, color)
	made.Name = name
	made.LayoutOrder = order
	made.Size = UDim2.fromOffset(if #text > 6 then 230 else 150, 56)
	return made
end

-- Plays the win moment for `kind` ("daily" | "weekly" | "monthly"; `index`: the daily gift's day, 7 the big one) and
-- its gift `lines`; returns the pack item to open now, or nil
function GiftWin.play(kind: string, index: number, lines: { Line }): string?
	local look = if kind == "daily" then (if index >= #Gifts.DAILY then WIN.big else WIN.daily) else (WIN :: any)[kind]
	if typeof(look) ~= "table" then
		return nil
	end
	local chest = kind ~= "daily"
	ScreenClear.wait()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GiftWin"
	gui.DisplayOrder = 60
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local dim = Instance.new("TextButton") -- swallows taps on the world behind
	dim.Name = "Dim"
	dim.AutoButtonColor = false
	dim.Text = ""
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(30, 14, 50)
	dim.BackgroundTransparency = 1
	dim.Parent = ScreenCover.layer(gui) -- the dim, its confetti and the flash: the whole screen, past a phone's safe area
	tween(dim, 0.35, { BackgroundTransparency = 1 - WIN.DIM })

	local rays = Instance.new("ImageLabel")
	rays.Name = "Rays"
	rays.BackgroundTransparency = 1
	rays.Image = WIN.RAYS
	rays.ImageColor3 = rgb(look.colors[1])
	rays.ImageTransparency = 1
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.42)
	rays.Size = UDim2.fromOffset(PICTURE * 3.4, PICTURE * 3.4)
	rays.Parent = gui
	tween(rays, 0.6, { ImageTransparency = 0.3 })
	local spin = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation = (rays.Rotation + dt * 14) % 360
	end)

	-- The gift: it drops in from above the screen
	local holder = Instance.new("Frame")
	holder.Name = "Gift"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 0, -PICTURE)
	holder.Size = UDim2.fromOffset(PICTURE, PICTURE)
	holder.Parent = gui
	local chestModel: ChestModel.Chest? = nil
	if chest then
		local _, made = chestView(holder, rgb(look.chest))
		chestModel = made
	else
		Icon.make(holder, look.picture, UDim2.fromScale(1, 1))
	end
	sound(gui, "rise")
	tween(holder, WIN.DROP, { Position = UDim2.fromScale(0.5, 0.42) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.wait(WIN.DROP)
	sound(gui, "drop")

	-- Three rattles, each harder (and higher)
	for step, wait in WIN.RATTLES do
		task.wait(wait)
		local angle = WIN.RATTLE_ANGLE[step]
		sound(gui, "rattle", 1 + step * 0.15)
		for _, side in { angle, -angle, angle * 0.5, 0 } do
			tween(holder, 0.06, { Rotation = side }, Enum.EasingStyle.Sine)
			task.wait(0.06)
		end
		holder.Size = UDim2.fromOffset(PICTURE * (1 + step * 0.05), PICTURE * (1 + step * 0.05))
	end
	task.wait(0.25)

	-- The burst
	sound(gui, "burst")
	if chest or index >= #Gifts.DAILY then
		sound(gui, "sting")
	end
	if kind == "monthly" then
		sound(gui, "fanfare")
	end
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0.15
	flash.ZIndex = 5
	flash.Parent = ScreenCover.layer(gui, 5)
	tween(flash, WIN.BURST, { BackgroundTransparency = 1 })
	confetti(dim, WIN.CONFETTI)
	if chestModel then
		local opened = chestModel
		local started = os.clock()
		local open: RBXScriptConnection
		open = RunService.RenderStepped:Connect(function()
			local share = math.clamp((os.clock() - started) / 0.45, 0, 1)
			opened.lid = math.rad(BossChests.LOOK.lidOpen) * TweenService:GetValue(share, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			ChestModel.light(opened, opened.glow.Color, share)
			ChestModel.place(opened, CFrame.new())
			if share >= 1 then
				open:Disconnect()
			end
		end)
		tween(holder, 0.5, { Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(PICTURE * 0.85, PICTURE * 0.85) })
	else
		-- the present pops: up big and gone, the cards take its place
		tween(holder, 0.3, { Size = UDim2.fromOffset(PICTURE * 1.6, PICTURE * 1.6), Rotation = 0 })
		for _, item in holder:GetDescendants() do
			if item:IsA("ImageLabel") then
				tween(item, 0.3, { ImageTransparency = 1 })
			end
		end
	end
	sound(gui, "shimmer")

	-- The title
	local words = string.gsub(look.title, "{day}", tostring(index))
	local title = UIKit.label(gui, words, Enum.Font.FredokaOne, 64, Color3.new(1, 1, 1))
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, if chest then 0.1 else 0.2)
	title.Size = UDim2.new(0.9, 0, 0, 80)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 6
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(70, 30, 90)
	edge.Thickness = 4
	edge.Parent = title
	local fill = Instance.new("UIGradient")
	fill.Color = if look.rainbow then RAINBOW else ColorSequence.new(Color3.new(1, 1, 1), rgb(look.colors[1]))
	fill.Rotation = if look.rainbow then 0 else 90
	fill.Parent = title
	local titleScale = Instance.new("UIScale")
	titleScale.Scale = 0.2
	titleScale.Parent = title
	tween(titleScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	-- The cards, one by one
	local row = Instance.new("Frame")
	row.Name = "Cards"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, if chest then 0.64 else 0.5)
	row.Size = UDim2.new(1, -32, 0, CARD.Y + 20)
	row.ZIndex = 6
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 14)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local fit = Instance.new("UIScale") -- narrow phones: the row shrinks to fit
	fit.Parent = row
	local function fitRow()
		local wide = #lines * (CARD.X + 14)
		fit.Scale = math.min(1, row.AbsoluteSize.X / math.max(wide, 1))
	end
	fitRow()
	row:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitRow)
	local pack: string? = nil
	for order, line in lines do
		task.wait(WIN.CARD_EVERY)
		sound(gui, if line.icon == "Cash" then "coins" else "card")
		card(row, line, order, look.rainbow == true)
		if line.pack and line.item and not pack then
			pack = line.item
		end
	end

	-- The buttons
	task.wait(0.3)
	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(0.5, 0)
	buttons.Position = UDim2.new(0.5, 0, if chest then 0.64 else 0.5, CARD.Y / 2 + 22)
	buttons.Size = UDim2.new(1, -32, 0, 60)
	buttons.ZIndex = 6
	buttons.Parent = gui
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonLayout.Padding = UDim.new(0, 12)
	buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
	buttonLayout.Parent = buttons
	local picked: string? = nil
	local done = false
	if pack then
		local openNow = button(buttons, "OpenNow", "OPEN IT NOW!", UIKit.Colors.Success, 1)
		openNow.Activated:Connect(function()
			picked = pack
			done = true
		end)
	end
	local nice = button(buttons, "Nice", "Nice!", UIKit.Colors.Accent, 2)
	nice.Activated:Connect(function()
		done = true
	end)
	while not done do
		task.wait()
	end

	spin:Disconnect()
	local fade = TweenInfo.new(0.3)
	for _, item in gui:GetDescendants() do
		if item:IsA("TextLabel") or item:IsA("TextButton") then
			TweenService:Create(item, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif item:IsA("ImageLabel") then
			TweenService:Create(item, fade, { ImageTransparency = 1 }):Play()
		elseif item:IsA("Frame") then
			TweenService:Create(item, fade, { BackgroundTransparency = 1 }):Play()
		elseif item:IsA("ViewportFrame") then
			TweenService:Create(item, fade, { ImageTransparency = 1 }):Play()
		elseif item:IsA("UIStroke") then
			TweenService:Create(item, fade, { Transparency = 1 }):Play()
		end
	end
	task.wait(0.32)
	gui:Destroy()
	return picked
end

return GiftWin
