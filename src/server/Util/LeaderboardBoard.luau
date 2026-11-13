--!strict
-- The plaza leaderboard's faces (Config/Leaderboard FACE; LeaderboardService fills them): each list drawn on the front
-- of one of the plaza's giant cards (Server/Util/PlazaBuild marks them with a LeaderboardList attribute). A panel in
-- the card's rarity colour: a sky window with the list's title and the top three on a podium, then a cream text box of
-- rows for the rest. Built on the server, so every player sees the same cards (their text takes the game's fonts on
-- each client: Util/FontStyle restyles Gotham in the workspace).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Leaderboard = require(Shared:WaitForChild("Config"):WaitForChild("Leaderboard"))
local Rarities = require(Shared:WaitForChild("Config"):WaitForChild("Rarities"))
local LeaderboardRules = require(Shared:WaitForChild("Util"):WaitForChild("LeaderboardRules"))

local LeaderboardBoard = {}

type Spot = { root: Frame, avatar: ImageLabel, name: TextLabel, count: TextLabel }
type Row = { band: Frame, avatar: ImageLabel, name: TextLabel, count: TextLabel }
export type List = { podium: { Spot }, rows: { Row }, note: TextLabel }

local FACE = Leaderboard.FACE
local SIZES = FACE.sizes

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function corner(item: GuiObject, radius: UDim)
	local made = Instance.new("UICorner")
	made.CornerRadius = radius
	made.Parent = item
end

-- White text on the sky window, outlined in plum so it reads on the light sky
local function outlined(item: TextLabel): TextLabel
	item.TextStrokeColor3 = rgb(FACE.outline)
	item.TextStrokeTransparency = FACE.outlineFade
	return item
end

local function label(parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number, color: { number }): TextLabel
	local made = Instance.new("TextLabel")
	made.BackgroundTransparency = 1
	made.Size = size
	made.Position = position
	made.Text = text
	made.TextSize = textSize
	made.Font = Enum.Font.GothamBold
	made.TextColor3 = rgb(color)
	made.TextTruncate = Enum.TextTruncate.AtEnd
	made.Parent = parent
	return made
end

-- A round avatar picture `size` pixels across, in a white ring
local function avatar(parent: Instance, size: number, position: UDim2): ImageLabel
	local picture = Instance.new("ImageLabel")
	picture.Size = UDim2.fromOffset(size, size)
	picture.Position = position
	picture.BackgroundColor3 = rgb(FACE.rowAlt)
	picture.Parent = parent
	corner(picture, UDim.new(0.5, 0))
	local ring = Instance.new("UIStroke")
	ring.Color = rgb(FACE.white)
	ring.Thickness = 3
	ring.Parent = picture
	return picture
end

-- One podium place in its column: avatar, name and count over a step showing the place
local function podiumSpot(parent: Instance, place: number, x: number, width: number, bottom: number): Spot
	local step = FACE.steps[place]
	local size = FACE.avatar[place]
	local total = size + SIZES.podiumName + SIZES.podiumCount + 6 + step.height
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(width, total)
	root.Position = UDim2.fromOffset(x, bottom - total)
	root.Visible = false
	root.Parent = parent
	local picture = avatar(root, size, UDim2.fromOffset((width - size) / 2, 0))
	local name = outlined(label(root, "", UDim2.fromOffset(width, SIZES.podiumName), UDim2.fromOffset(0, size + 2), SIZES.podiumName, FACE.white))
	local count = outlined(label(root, "", UDim2.fromOffset(width, SIZES.podiumCount), UDim2.fromOffset(0, size + 2 + SIZES.podiumName), SIZES.podiumCount, FACE.white))
	local block = Instance.new("Frame")
	block.BackgroundColor3 = rgb(step.color)
	block.BorderSizePixel = 0
	block.Size = UDim2.fromOffset(width - 8, step.height)
	block.Position = UDim2.fromOffset(4, total - step.height)
	block.Parent = root
	corner(block, UDim.new(0, 10))
	label(block, tostring(place), UDim2.new(1, 0, 0, SIZES.place + 6), UDim2.new(), SIZES.place, FACE.ink)
	return { root = root, avatar = picture, name = name, count = count }
end

-- Draws list `list` (Config/Leaderboard FACE.lists: "allTime" or "server") on the front of a giant card
function LeaderboardBoard.attach(card: BasePart, list: string): List
	local look = FACE.lists[list]
	local tier = (Rarities.Tiers :: any)[card:GetAttribute("Rarity")]
	local rim = if tier then tier.color else rgb(FACE.white)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Leaderboard"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = FACE.width / card.Size.X
	gui.LightInfluence = FACE.light
	gui.MaxDistance = FACE.distance
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = card
	local panelWidth, panelHeight = FACE.width * FACE.inset[1], FACE.height * FACE.inset[2]
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(panelWidth, panelHeight)
	panel.BackgroundColor3 = rgb(FACE.box)
	panel.ClipsDescendants = true
	panel.Parent = gui
	corner(panel, UDim.new(FACE.corner, 0))
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = rim
	stroke.Thickness = FACE.stroke
	stroke.Parent = panel

	-- The sky window: title, subtitle, podium
	local artHeight = panelHeight * FACE.art
	local sky = Instance.new("Frame")
	sky.Size = UDim2.fromOffset(panelWidth, artHeight)
	sky.BackgroundColor3 = rgb(FACE.white)
	sky.BorderSizePixel = 0
	sky.Parent = panel
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(rgb(look.sky[1]), rgb(look.sky[2]))
	gradient.Rotation = 90
	gradient.Parent = sky
	outlined(label(sky, look.title, UDim2.fromOffset(panelWidth, SIZES.title + 4), UDim2.fromOffset(0, 8), SIZES.title, FACE.white))
	outlined(label(sky, FACE.subtitle, UDim2.fromOffset(panelWidth, SIZES.subtitle), UDim2.fromOffset(0, 12 + SIZES.title), SIZES.subtitle, FACE.white))
	local column = (panelWidth - 16) / 3
	local podium: { Spot } = {}
	-- 2nd on the left, 1st in the middle, 3rd on the right
	for slot, place in { 2, 1, 3 } do
		podium[place] = podiumSpot(sky, place, 8 + (slot - 1) * column, column, artHeight)
	end

	-- The text box: the rest of the top
	local rows: { Row } = {}
	local top = artHeight + FACE.boxPad
	local h = FACE.rowHeight
	for index = FACE.podium + 1, Leaderboard.TOP do
		local band = Instance.new("Frame")
		band.Name = `Row{index}`
		band.BackgroundColor3 = rgb(FACE.rowAlt)
		band.BackgroundTransparency = if index % 2 == 0 then 0 else 1
		band.BorderSizePixel = 0
		band.Size = UDim2.fromOffset(panelWidth - 2 * FACE.boxPad, h - 4)
		band.Position = UDim2.fromOffset(FACE.boxPad, top + (index - FACE.podium - 1) * h)
		band.Visible = false
		band.Parent = panel
		corner(band, UDim.new(0, 10))
		label(band, tostring(index), UDim2.fromOffset(34, h - 4), UDim2.fromOffset(4, 0), SIZES.rank, FACE.inkSoft)
		local picture = avatar(band, h - 14, UDim2.fromOffset(42, 5))
		local name = label(band, "", UDim2.new(1, -(h + 150), 1, 0), UDim2.fromOffset(h + 40, 0), SIZES.name, FACE.ink)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local count = label(band, "", UDim2.fromOffset(104, h - 4), UDim2.new(1, -112, 0, 0), SIZES.count, FACE.count)
		count.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(rows, { band = band, avatar = picture, name = name, count = count })
	end
	local note = label(panel, FACE.loading, UDim2.fromOffset(panelWidth - 2 * FACE.boxPad, h * 2), UDim2.fromOffset(FACE.boxPad, top), SIZES.note, FACE.inkSoft)
	note.TextWrapped = true
	return { podium = podium, rows = rows, note = note }
end

local function headshot(userId: number): string
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

-- Shows `entries` (ranked, LeaderboardRules) on a list card; `note` in the text box while it has no rows (nobody yet,
-- still loading, or everyone fits on the podium)
function LeaderboardBoard.fill(list: List, entries: { LeaderboardRules.Entry }, note: string)
	for place, spot in list.podium do
		local entry = entries[place]
		spot.root.Visible = entry ~= nil
		if entry then
			spot.name.Text = entry.name
			spot.count.Text = LeaderboardRules.countText(entry.count)
			spot.avatar.Image = headshot(entry.userId)
		end
	end
	for index, row in list.rows do
		local entry = entries[FACE.podium + index]
		row.band.Visible = entry ~= nil
		if entry then
			row.name.Text = entry.name
			row.count.Text = LeaderboardRules.countText(entry.count)
			row.avatar.Image = headshot(entry.userId)
		end
	end
	list.note.Text = note
	list.note.Visible = #entries <= FACE.podium
end

return LeaderboardBoard
