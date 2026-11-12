--!strict
-- A town dog's hello (Town Chikin, the owner 2026-11-11; Town Pish, 2026-11-12: "npc pish should also greet people like
-- chikin"): when its marker's GreetId changes (Server/Util/TownDog.greet) it barks and a white speech bubble over it says
-- one of `lines` with the greeted player's name, popping in and fading after SECONDS, for everyone who can see it.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ClientUtil = script.Parent :: Instance
local PishVisual = require(ClientUtil:WaitForChild("PishVisual"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))

local GreetBubble = {}

local SECONDS = 3
local INK = Color3.fromRGB(80, 60, 90)

-- `up`: studs over the marker (above its name tag); `edge`: the bubble's outline colour
function GreetBubble.show(marker: BasePart, visual: PishVisual.Visual, lines: { string }, up: number, edge: Color3)
	local userId = marker:GetAttribute("GreetUserId")
	local line = lines[tonumber(marker:GetAttribute("GreetLine")) or 1]
	local greeted = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	if not greeted or not line then
		return
	end
	PishVisual.sound(visual, "bark")
	local old = marker:FindFirstChild("GreetBubble")
	if old then
		old:Destroy()
	end
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "GreetBubble"
	bubble.Size = UDim2.fromOffset(260, 44)
	bubble.StudsOffsetWorldSpace = Vector3.new(0, up, 0)
	bubble.MaxDistance = 80
	bubble.LightInfluence = 0
	bubble.Adornee = marker
	bubble.Parent = marker
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Parent = bubble
	UIKit.corner(frame, 20)
	local stroke = Instance.new("UIStroke")
	stroke.Color = edge
	stroke.Thickness = 2.5
	stroke.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = frame
	local text = UIKit.label(frame, string.format(line, greeted.DisplayName), Enum.Font.FredokaOne, 20, INK)
	text.Size = UDim2.new(1, -16, 1, 0)
	text.Position = UDim2.fromOffset(8, 0)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextScaled = true
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(SECONDS, function()
		local fade = TweenInfo.new(0.35)
		TweenService:Create(frame, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		TweenService:Create(text, fade, { TextTransparency = 1 }):Play()
	end)
	Debris:AddItem(bubble, SECONDS + 0.5)
end

return GreetBubble
