--!strict
-- The fight's end screen, design B "banner and loot strip" (owner, 2026-11-03; Config/Victory): a warm flash, a big
-- glowing title popping in over the arena with a line under it, a row of reward tiles popping in one by one (rare ones
-- glowing gold, Util/VictoryRules picks them), notes under them, and the party under those with XP bars filling
-- and LEVEL UP badges. Losses and runs use the same layout in red or grey with no tiles. It closes by itself or on a
-- tap. One screen, rebuilt for each fight.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Victory = require(Shared:WaitForChild("Config"):WaitForChild("Victory"))
local VictoryRules = require(Shared:WaitForChild("Util"):WaitForChild("VictoryRules"))
local Icon = require((script.Parent :: Instance):WaitForChild("Icon"))

local VictoryScreen = {}

export type PartyEntry = { name: string, art: string?, from: number, to: number, levelUp: boolean, level: number? }
export type Show = {
	kind: string, -- "win" | "conquered" | "lose" | "run"
	title: string,
	subtitle: string?,
	tiles: { VictoryRules.Tile }?,
	notes: { string }?,
	party: { PartyEntry }?,
	seconds: number?, -- how long it stays (Config/Victory SECONDS when nil)
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local gui: ScreenGui? = nil
local current = 0 -- bumped per show, so an old show's timers leave a new one alone
local notesLabel: TextLabel? = nil

-- One loaded Sound per id, made when this module loads (the loading screen fetched them too: Util/CombatAssets), so
-- the fanfare plays the moment the screen opens; each play is a copy, so quick tile pops can overlap
local templates: { [string]: Sound } = {}
for key, id in Victory.SOUNDS do
	if id ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = `Victory_{key}`
		sound.SoundId = id
		sound.Volume = Victory.VOLUME
		sound:SetAttribute("StartAt", Victory.START_AT[key] or 0)
		sound.Parent = SoundService
		templates[id] = sound
	end
end

local function play(id: string)
	local template = templates[id]
	if not template then
		return
	end
	local sound = template:Clone()
	sound.Parent = SoundService
	sound.TimePosition = tonumber(template:GetAttribute("StartAt")) or 0
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

local function pop(target: GuiObject, from: number, seconds: number)
	local scale = Instance.new("UIScale")
	scale.Scale = from
	scale.Parent = target
	TweenService:Create(scale, TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function text(parent: Instance, value: string, font: Enum.Font, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = size
	label.TextColor3 = color
	label.Text = value
	label.Parent = parent
	return label
end

local function corner(target: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = target
end

function VictoryScreen.hide()
	current += 1
	if gui then
		gui:Destroy()
		gui = nil
	end
	notesLabel = nil
end

-- Swaps the notes line (the PvP countdown)
function VictoryScreen.setNotes(lines: { string })
	if notesLabel then
		notesLabel.Text = table.concat(lines, "\n")
	end
end

function VictoryScreen.show(data: Show)
	VictoryScreen.hide()
	local token = current
	local colors = Victory.COLORS[data.kind] or Victory.COLORS.run
	local screen = Instance.new("ScreenGui")
	screen.Name = "Victory"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 30
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = screen
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 600
	local fit = Instance.new("UIScale")
	fit.Scale = math.clamp(height / 560, 0.62, 1.1) -- landscape phones get a smaller layout
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = screen

	-- A warm flash, then a soft dark veil so the words read over any arena
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BorderSizePixel = 0
	flash.BackgroundColor3 = if data.kind == "lose" then Color3.fromRGB(120, 20, 20) else Color3.fromRGB(255, 240, 190)
	flash.BackgroundTransparency = if data.kind == "run" then 1 else 0.35
	flash.Parent = root
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	local veil = Instance.new("Frame")
	veil.Size = UDim2.fromScale(1, 1)
	veil.BorderSizePixel = 0
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 1
	veil.Parent = root
	TweenService:Create(veil, TweenInfo.new(0.4), { BackgroundTransparency = 0.6 }):Play()

	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0.5, 0)
	column.Position = UDim2.fromScale(0.5, 0.1)
	column.Size = UDim2.fromOffset(620, 480)
	column.Parent = root
	fit.Parent = column

	-- The title: white shading into gold, a dark outline, popping in from big
	local title = text(column, data.title, Enum.Font.FredokaOne, Victory.TITLE_SIZE, Color3.new(1, 1, 1))
	title.Size = UDim2.new(1, 0, 0, Victory.TITLE_SIZE + 10)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(rgb(colors.title), rgb(colors.shade))
	gradient.Rotation = 90
	gradient.Parent = title
	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(colors.stroke)
	stroke.Thickness = 4
	stroke.Parent = title
	pop(title, 2.2, Victory.TITLE_POP)
	local subtitle = text(column, data.subtitle or "", Enum.Font.FredokaOne, 18, Color3.new(1, 1, 1))
	subtitle.Position = UDim2.fromOffset(0, Victory.TITLE_SIZE + 6)
	subtitle.Size = UDim2.new(1, 0, 0, 24)
	local subStroke = Instance.new("UIStroke")
	subStroke.Thickness = 2
	subStroke.Transparency = 0.3
	subStroke.Parent = subtitle

	-- The reward tiles, popping in one by one
	local tiles = data.tiles or {}
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Position = UDim2.fromOffset(0, Victory.TITLE_SIZE + 44)
	local rows = math.max(1, math.ceil(#tiles / Victory.TILE.perRow))
	strip.Size = UDim2.new(1, 0, 0, if #tiles > 0 then rows * (Victory.TILE.height + Victory.TILE.gap) else 0)
	strip.Parent = column
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(Victory.TILE.width, Victory.TILE.height)
	grid.CellPadding = UDim2.fromOffset(Victory.TILE.gap, Victory.TILE.gap)
	grid.FillDirectionMaxCells = Victory.TILE.perRow
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = strip
	for index, tile in tiles do
		local card = Instance.new("Frame")
		card.LayoutOrder = index
		card.BackgroundColor3 = rgb(Victory.TILE_BACK)
		card.BackgroundTransparency = 0.12
		card.Visible = false
		card.Parent = strip
		corner(card, 12)
		local edge = Instance.new("UIStroke")
		edge.Color = if tile.rare then rgb(Victory.RARE) else Color3.new(1, 1, 1)
		edge.Transparency = if tile.rare then 0 else 0.85
		edge.Thickness = if tile.rare then 2 else 1.5
		edge.Parent = card
		local icon = Icon.make(card, tile.icon, UDim2.fromOffset(40, 40))
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 8)
		local amount = text(card, tile.amount, Enum.Font.FredokaOne, 17, Color3.new(1, 1, 1))
		amount.Position = UDim2.fromOffset(2, 50)
		amount.Size = UDim2.new(1, -4, 0, 20)
		amount.TextScaled = true
		local label = text(card, tile.label, Enum.Font.GothamBold, 11, Color3.fromRGB(185, 176, 201))
		label.Position = UDim2.fromOffset(4, 72)
		label.Size = UDim2.new(1, -8, 0, 18)
		label.TextScaled = true
		task.delay(Victory.TILES_FROM + (index - 1) * Victory.TILE_GAP, function()
			if token ~= current then
				return
			end
			card.Visible = true
			pop(card, 0.5, 0.3)
			play(if tile.rare then Victory.SOUNDS.rare else Victory.SOUNDS.tile)
		end)
	end

	-- Notes under the tiles (where the loot is, why it was smaller, the PvP countdown)
	local notes = text(column, table.concat(data.notes or {}, "\n"), Enum.Font.GothamBold, 13, Color3.fromRGB(225, 220, 235))
	local notesTop = strip.Position.Y.Offset + strip.Size.Y.Offset + 4
	local notesHeight = math.max(1, #(data.notes or {})) * 16 + 4
	notes.Position = UDim2.new(0, 0, 0, notesTop)
	notes.Size = UDim2.new(1, 0, 0, notesHeight)
	notes.TextYAlignment = Enum.TextYAlignment.Top
	notes.TextWrapped = true
	local notesStroke = Instance.new("UIStroke")
	notesStroke.Thickness = 1.5
	notesStroke.Transparency = 0.4
	notesStroke.Parent = notes
	notesLabel = notes

	-- The party under the notes (clear of the HUD buttons): portrait, name, XP bar filling (round to 0 again on a level
	-- up), LEVEL UP
	local party = data.party or {}
	if #party > 0 then
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.Position = UDim2.new(0.5, 0, 0, notesTop + notesHeight + 14)
		bar.Size = UDim2.fromOffset(#party * 150 + 20, Victory.PORTRAIT + 20)
		bar.BackgroundColor3 = rgb(Victory.TILE_BACK)
		bar.BackgroundTransparency = 0.2
		bar.Parent = column
		corner(bar, 14)
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Padding = UDim.new(0, 10)
		list.Parent = bar
		for _, entry in party do
			local item = Instance.new("Frame")
			item.BackgroundTransparency = 1
			item.Size = UDim2.fromOffset(140, Victory.PORTRAIT)
			item.Parent = bar
			local pic = Instance.new("ImageLabel")
			pic.Size = UDim2.fromOffset(Victory.PORTRAIT, Victory.PORTRAIT)
			pic.BackgroundColor3 = Color3.fromRGB(42, 29, 51)
			pic.Image = entry.art or ""
			pic.ScaleType = Enum.ScaleType.Crop
			pic.Parent = item
			corner(pic, Victory.PORTRAIT // 2)
			local ring = Instance.new("UIStroke")
			ring.Color = Color3.fromRGB(62, 224, 138)
			ring.Thickness = 2.5
			ring.Parent = pic
			local name = text(item, entry.name, Enum.Font.FredokaOne, 14, Color3.new(1, 1, 1))
			name.Position = UDim2.fromOffset(Victory.PORTRAIT + 8, 2)
			name.Size = UDim2.new(1, -Victory.PORTRAIT - 8, 0, 18)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextTruncate = Enum.TextTruncate.AtEnd
			local track = Instance.new("Frame")
			track.Position = UDim2.fromOffset(Victory.PORTRAIT + 8, 24)
			track.Size = UDim2.new(1, -Victory.PORTRAIT - 8, 0, 8)
			track.BackgroundColor3 = Color3.fromRGB(11, 7, 16)
			track.Parent = item
			corner(track, 4)
			local fill = Instance.new("Frame")
			fill.Size = UDim2.fromScale(math.clamp(entry.from, 0, 1), 1)
			fill.BackgroundColor3 = rgb(Victory.XP_FILL_COLOR)
			fill.Parent = track
			corner(fill, 4)
			local badge = text(pic, "LEVEL UP!", Enum.Font.FredokaOne, 11, Color3.fromRGB(90, 53, 0))
			badge.AnchorPoint = Vector2.new(0.5, 1)
			badge.Position = UDim2.new(0.5, 0, 0, 2)
			badge.Size = UDim2.fromOffset(64, 16)
			badge.BackgroundColor3 = rgb(Victory.RARE)
			badge.BackgroundTransparency = 0
			badge.Visible = false
			corner(badge, 8)
			task.delay(Victory.XP_FROM, function()
				if token ~= current then
					return
				end
				local fillTime = Victory.XP_FILL
				if entry.levelUp then
					TweenService:Create(fill, TweenInfo.new(fillTime * 0.6, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1, 1) }):Play()
					task.delay(fillTime * 0.6, function()
						if token ~= current then
							return
						end
						fill.Size = UDim2.fromScale(0, 1)
						TweenService:Create(fill, TweenInfo.new(fillTime * 0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(entry.to, 1) }):Play()
						badge.Visible = true
						pop(badge, 0.3, 0.3)
						play(Victory.SOUNDS.levelUp)
					end)
				else
					TweenService:Create(fill, TweenInfo.new(fillTime, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(entry.to, 1) }):Play()
				end
			end)
		end
	end

	if data.kind == "win" or data.kind == "conquered" then
		play(Victory.SOUNDS.win)
	end
	-- A tap or click closes it (after a moment, so the tap that won the fight doesn't); it goes by itself too
	task.delay(0.8, function()
		if token ~= current then
			return
		end
		local connection: RBXScriptConnection
		connection = UserInputService.InputBegan:Connect(function(input: InputObject)
			if token ~= current then
				connection:Disconnect()
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				connection:Disconnect()
				VictoryScreen.hide()
			end
		end)
	end)
	task.delay(data.seconds or Victory.SECONDS, function()
		if token == current then
			VictoryScreen.hide()
		end
	end)
end

return VictoryScreen
