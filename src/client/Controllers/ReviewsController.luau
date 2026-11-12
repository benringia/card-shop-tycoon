--!strict
-- The phone's Reviews app (owner 2026-11-13: "yes ratings app show customer feedbacks", the small version for the
-- testers; Config/Reviews, Server/Services/ReviewService): a page inside the phone (Util/Hud.phonePage) with your shop
-- rating, its two weakest parts as tips (RatingService's RatingUpdate, Config/Customers RATING_TIPS), then customers'
-- posts newest first (a coloured face, a name, stars, a line, how long ago). A red count on the app for posts since you
-- last looked. The rating also shows on the phone's status bar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Reviews = require(Config:WaitForChild("Reviews"))
local Customers = require(Config:WaitForChild("Customers"))
local ReviewRules = require(Shared:WaitForChild("Util"):WaitForChild("ReviewRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))

local ReviewsController = {}

local INK = Color3.fromRGB(91, 61, 110)
local SOFT = Color3.fromRGB(140, 115, 160)
local STAR = Color3.fromRGB(255, 180, 0)

local posts: { ReviewRules.Post } = {}
local seenAt = 0
local rating = 0
local tips: { string } = {}
local content: Frame
local feed: ScrollingFrame
local header: Frame

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- Stars as emoji (the fonts draw a plain star symbol as an empty box)
local function stars(count: number): string
	return string.rep("⭐", math.clamp(math.floor(count + 0.5), 1, 5))
end

local function ago(at: number): string
	local seconds = math.max(0, workspace:GetServerTimeNow() - at)
	if seconds < 60 then
		return Reviews.SECONDS.now
	elseif seconds < 3600 then
		return string.format(Reviews.SECONDS.minute, math.floor(seconds / 60))
	end
	return string.format(Reviews.SECONDS.hour, math.floor(seconds / 3600))
end

local function card(parent: Instance, order: number, height: number): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -8, 0, height)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.ZIndex = 35
	frame.Parent = parent
	UIKit.corner(frame, 14)
	return frame
end

local function label(parent: Instance, text: string, font: Enum.Font, size: number, color: Color3): TextLabel
	local made = UIKit.label(parent, text, font, size, color)
	made.ZIndex = 36
	return made
end

local function drawHeader()
	header:ClearAllChildren()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = header
	local starLine = label(header, stars(rating), Enum.Font.FredokaOne, 22, STAR)
	starLine.Position = UDim2.fromOffset(12, 6)
	starLine.Size = UDim2.new(1, -80, 0, 26)
	local number = label(header, string.format("%.1f", rating), Enum.Font.FredokaOne, 26, INK)
	number.AnchorPoint = Vector2.new(1, 0)
	number.Position = UDim2.new(1, -12, 0, 4)
	number.Size = UDim2.fromOffset(60, 30)
	number.TextXAlignment = Enum.TextXAlignment.Right
	local helps = label(header, Reviews.TIPS_TITLE, Enum.Font.GothamBold, 11, SOFT)
	helps.Position = UDim2.fromOffset(12, 34)
	helps.Size = UDim2.new(1, -24, 0, 14)
	helps.Visible = #tips > 0
	for index, tip in tips do
		local line = label(header, `• {tip}`, Enum.Font.GothamBold, 12, INK)
		line.Position = UDim2.fromOffset(12, 32 + index * 16)
		line.Size = UDim2.new(1, -24, 0, 16)
		line.TextScaled = true
		local most = Instance.new("UITextSizeConstraint")
		most.MaxTextSize = 12
		most.Parent = line
	end
end

local function drawFeed()
	for _, child in feed:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if #posts == 0 then
		local empty = label(feed, Reviews.EMPTY, Enum.Font.GothamBold, 13, SOFT)
		empty.Size = UDim2.new(1, -8, 0, 60)
		empty.TextWrapped = true
		empty.TextXAlignment = Enum.TextXAlignment.Center
		return
	end
	for index, post in posts do
		local row = card(feed, index, 64)
		local face = Instance.new("Frame")
		face.Position = UDim2.fromOffset(10, 10)
		face.Size = UDim2.fromOffset(26, 26)
		face.BackgroundColor3 = rgb(Reviews.COLORS[post.color] or Reviews.COLORS[1])
		face.ZIndex = 36
		face.Parent = row
		UIKit.corner(face, 13)
		UIKit.outline(face, Color3.new(1, 1, 1), 2)
		local initial = label(face, string.sub(post.name, 1, 1), Enum.Font.FredokaOne, 14, Color3.new(1, 1, 1))
		initial.Size = UDim2.fromScale(1, 1)
		initial.TextXAlignment = Enum.TextXAlignment.Center
		local name = label(row, post.name, Enum.Font.FredokaOne, 15, INK)
		name.Position = UDim2.fromOffset(44, 6)
		name.Size = UDim2.new(1, -110, 0, 18)
		local when = label(row, ago(post.at), Enum.Font.GothamBold, 11, SOFT)
		when.AnchorPoint = Vector2.new(1, 0)
		when.Position = UDim2.new(1, -10, 0, 8)
		when.Size = UDim2.fromOffset(40, 14)
		when.TextXAlignment = Enum.TextXAlignment.Right
		local rated = label(row, stars(post.stars), Enum.Font.FredokaOne, 13, STAR)
		rated.Position = UDim2.fromOffset(44, 24)
		rated.Size = UDim2.new(1, -54, 0, 14)
		local line = label(row, post.line, Enum.Font.GothamBold, 13, INK)
		line.Position = UDim2.fromOffset(44, 40)
		line.Size = UDim2.new(1, -54, 0, 18)
		line.TextScaled = true
		local most = Instance.new("UITextSizeConstraint")
		most.MaxTextSize = 13
		most.Parent = line
	end
end

local function updateBadge()
	Hud.setBadge("Reviews", ReviewRules.unseen(posts, seenAt))
end

local function open()
	seenAt = workspace:GetServerTimeNow()
	updateBadge()
	drawHeader()
	drawFeed()
	feed.CanvasPosition = Vector2.zero
	Hud.showPhonePage("Reviews")
	Remotes.Reviews:FireServer() -- the whole feed now (it may have started before this listened)
end

local function build()
	content = Hud.phonePage("Reviews", Reviews.TITLE)
	header = card(content, 0, 96)
	header.Position = UDim2.fromOffset(0, 0)
	header.Size = UDim2.new(1, 0, 0, 96)
	feed = Instance.new("ScrollingFrame")
	feed.Name = "Feed"
	feed.BackgroundTransparency = 1
	feed.BorderSizePixel = 0
	feed.Position = UDim2.fromOffset(0, 104)
	feed.Size = UDim2.new(1, 0, 1, -104)
	feed.ScrollBarThickness = 4
	feed.AutomaticCanvasSize = Enum.AutomaticSize.Y
	feed.CanvasSize = UDim2.new()
	feed.ZIndex = 34
	feed.Parent = content
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = feed
end

function ReviewsController.Start()
	build()
	Hud.fanButton({ id = "Reviews", icon = "💬", label = "Reviews", order = 5, stay = true, onClick = open })
	Remotes.Reviews.OnClientEvent:Connect(function(message: unknown)
		if typeof(message) ~= "table" then
			return
		end
		local data = message :: any
		if typeof(data.posts) == "table" then
			posts = data.posts
		elseif typeof(data.post) == "table" then
			posts = ReviewRules.push(posts, data.post, Reviews.MAX)
		end
		updateBadge()
		if (content.Parent :: GuiObject).Visible then -- reading the feed now
			seenAt = workspace:GetServerTimeNow()
			updateBadge()
			drawFeed()
		end
	end)
	-- the rating: on the status bar, and the header's two weakest parts as tips
	Remotes.RatingUpdate.OnClientEvent:Connect(function(update: unknown)
		if typeof(update) ~= "table" or typeof((update :: any).rating) ~= "number" then
			return
		end
		local data = update :: any
		rating = data.rating
		Hud.setPhoneStatus(`⭐ {string.format("%.1f", rating)}`)
		local weak = {}
		for _, part in (if typeof(data.parts) == "table" then data.parts else {}) do
			local words = Customers.RATING_TIPS[part.name]
			if words and part.known ~= false and typeof(part.score) == "number" and part.score < Customers.RATING.goodFrom then
				table.insert(weak, { score = part.score, text = words.fix })
			end
		end
		table.sort(weak, function(a, b)
			return a.score < b.score
		end)
		tips = {}
		for index = 1, math.min(2, #weak) do
			table.insert(tips, weak[index].text)
		end
		if (content.Parent :: GuiObject).Visible then
			drawHeader()
		end
	end)
	Remotes.Reviews:FireServer()
end

return ReviewsController
