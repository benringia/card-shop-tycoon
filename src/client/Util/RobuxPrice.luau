--!strict
-- A Robux price on a button or label: "Unlock · [Robux] 49", or "[Robux] 49" alone (owner 2026-11-17: "can the R$ be
-- replaced with an actual robux icon"). Roblox's own Robux glyph, tinted like the text and outlined like it; the
-- words, glyph and number shrink together when the button is too narrow. Without a price the button shows `words` as
-- its plain Text. Code that sets the button's Text itself later takes the price row away (tests/RobuxIcon).
local TextService = game:GetService("TextService")

local RobuxPrice = {}

local ICON = "rbxasset://textures/ui/common/robux@3x.png"
local ROW = "RobuxPrice"
local GAP = 4 -- px between the words, the glyph and the number
local ICON_SCALE = 1.1 -- the glyph's size against the text size (its picture has a margin: smaller read as a ring)
local HEIGHT_SHARE = 0.62 -- a TextScaled button's text size against its height
local MIN_SIZE = 9
local WIDTH_MARGIN = 0.92 -- room for fonts measured a little narrow

type Text = TextButton | TextLabel

local function textWidth(text: string, size: number, font: Enum.Font): number
	if text == "" then
		return 0
	end
	return TextService:GetTextSize(text, size, font, Vector2.new(4000, 4000)).X
end

-- The text size the button would use: its own, or for a TextScaled one its height's share, capped by its constraint
local function baseSize(button: Text, height: number): number
	if not button.TextScaled then
		return button.TextSize
	end
	local size = math.floor(height * HEIGHT_SHARE)
	local cap = button:FindFirstChildOfClass("UITextSizeConstraint")
	if cap then
		size = math.min(size, cap.MaxTextSize)
	end
	return math.max(size, MIN_SIZE)
end

local function label(row: Frame, name: string, order: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.LayoutOrder = order
	text.BackgroundTransparency = 1
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromScale(0, 1)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextYAlignment = Enum.TextYAlignment.Center
	text.Parent = row
	return text
end

local function build(button: Text): Frame
	local row = Instance.new("Frame")
	row.Name = ROW
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.ZIndex = button.ZIndex
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, GAP)
	layout.Parent = row
	local words = label(row, "Words", 1)
	local icon = Instance.new("ImageLabel")
	icon.Name = "Robux"
	icon.LayoutOrder = 2
	icon.BackgroundTransparency = 1
	icon.Image = ICON
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = row
	local amount = label(row, "Amount", 3)

	local connections: { RBXScriptConnection } = {}
	-- The button's look: its font, colour, transparency and text outline, kept in step as the button changes
	local function look()
		for _, text in { words, amount } do
			text.FontFace = button.FontFace
			text.TextColor3 = button.TextColor3
			text.TextTransparency = button.TextTransparency
			text.ZIndex = button.ZIndex
			local edge = button:FindFirstChild("TextOutline")
			local mine = text:FindFirstChild("TextOutline")
			if edge and edge:IsA("UIStroke") then
				if not mine then
					mine = edge:Clone()
					mine.Parent = text
				end
				local stroke = mine :: UIStroke
				stroke.Enabled = edge.Enabled
				stroke.Color = edge.Color
				stroke.Thickness = edge.Thickness
				stroke.Transparency = edge.Transparency
			elseif mine then
				mine:Destroy()
			end
		end
		icon.ImageColor3 = button.TextColor3
		icon.ImageTransparency = button.TextTransparency
		icon.ZIndex = button.ZIndex
	end
	-- One text size for the words, glyph and number: the button's own, smaller when the row is too wide for it
	local function fit()
		local room = row.AbsoluteSize
		if room.X <= 0 or room.Y <= 0 then
			return
		end
		local size = baseSize(button, room.Y)
		local font = button.Font
		local function width(at: number): number
			local wordsWidth = textWidth(words.Text, at, font)
			return wordsWidth + (if wordsWidth > 0 then GAP else 0) + at * ICON_SCALE + GAP + textWidth(amount.Text, at, font)
		end
		local wide = width(size)
		local most = room.X * WIDTH_MARGIN
		if wide > most then
			size = math.max(MIN_SIZE, math.floor(size * most / wide))
		end
		words.TextSize = size
		amount.TextSize = size
		local glyph = math.floor(size * ICON_SCALE)
		icon.Size = UDim2.fromOffset(glyph, glyph)
	end
	table.insert(connections, button:GetPropertyChangedSignal("TextColor3"):Connect(function()
		task.defer(look) -- after the button's own outline listener
	end))
	table.insert(connections, button:GetPropertyChangedSignal("TextTransparency"):Connect(look))
	table.insert(connections, button:GetPropertyChangedSignal("FontFace"):Connect(look))
	table.insert(connections, row:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
	-- Someone wrote the button's Text again (a "Soon" or "Restricted" state): the plain text wins
	table.insert(connections, button:GetPropertyChangedSignal("Text"):Connect(function()
		if button.Text ~= "" then
			row:Destroy()
		end
	end))
	row.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
	row:GetAttributeChangedSignal("Refit"):Connect(fit)
	look()
	row.Parent = button
	fit()
	return row
end

-- `words` with the Robux glyph and `price` after them ("" for the glyph and number alone); `price` nil shows `words`
-- as the button's plain Text
function RobuxPrice.set(button: Text, words: string, price: number?)
	local row = button:FindFirstChild(ROW)
	if not price then
		if row then
			row:Destroy()
		end
		button.Text = words
		return
	end
	local amount = tostring(math.floor(price))
	if row and row:GetAttribute("Words") == words and row:GetAttribute("Amount") == amount then
		return -- drawn already (JobPanel draws four times a second)
	end
	button.Text = ""
	if not row or not row:IsA("Frame") then
		row = build(button)
	end
	local frame = row :: Frame
	local wordsLabel = frame:FindFirstChild("Words") :: TextLabel
	local amountLabel = frame:FindFirstChild("Amount") :: TextLabel
	wordsLabel.Text = if words ~= "" then `{words} ·` else ""
	wordsLabel.Visible = words ~= ""
	amountLabel.Text = amount
	frame:SetAttribute("Words", words)
	frame:SetAttribute("Amount", amount)
	frame:SetAttribute("Refit", (tonumber(frame:GetAttribute("Refit")) or 0) + 1)
end

return RobuxPrice
