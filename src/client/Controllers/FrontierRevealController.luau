--!strict
-- The big moment when you find a Frontier card: the screen dims, the card spins in with a glow and sparkles,
-- and a "FRONTIER CARD!" banner names it. Driven by the server's Frontier announcement (PullAnnouncement with
-- kind "frontier") when the finder is this player. Tap anywhere to close, or it closes itself.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CardEffects = require(Config:WaitForChild("CardEffects"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local FrontierRevealController = {}

local CARD_SIZE = Vector2.new(210, 300)
local SPIN_IN = TweenInfo.new(0.9, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.35)
local SPARKLE_COUNT = 14

local overlay: TextButton
local revealToken = 0

local function close()
	revealToken += 1
	overlay.Visible = false
end

local function sparkleBurst(parent: GuiObject)
	local aurora = CardEffects.FRONTIER.AURORA
	for index = 1, SPARKLE_COUNT do
		local angle = (index / SPARKLE_COUNT) * math.pi * 2
		local sparkle = UIKit.label(parent, "✨", Enum.Font.GothamBold, 28, aurora[(index % #aurora) + 1])
		sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
		sparkle.Position = UDim2.fromScale(0.5, 0.5)
		sparkle.Size = UDim2.fromOffset(40, 40)
		sparkle.TextXAlignment = Enum.TextXAlignment.Center
		sparkle.ZIndex = 52
		local distance = 220 + (index % 3) * 40
		TweenService:Create(sparkle, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance),
			TextTransparency = 1,
		}):Play()
		task.delay(1.2, function()
			sparkle:Destroy()
		end)
	end
end

local function reveal(card: typeof(Cards.List[1]), foil: boolean)
	for _, child in overlay:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	revealToken += 1
	local token = revealToken
	overlay.BackgroundTransparency = 1
	overlay.Visible = true
	TweenService:Create(overlay, FADE, { BackgroundTransparency = 0.25 }):Play()

	-- Glow behind the card
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.48)
	glow.Size = UDim2.fromOffset(CARD_SIZE.X * 1.6, CARD_SIZE.Y * 1.35)
	glow.BackgroundColor3 = Color3.new(1, 1, 1)
	glow.BackgroundTransparency = 0.55
	glow.ZIndex = 50
	glow.Parent = overlay
	UIKit.corner(glow, 999)
	CardFace.addAurora(glow)

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.48)
	holder.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	holder.Rotation = -540
	holder.ZIndex = 51
	holder.Parent = overlay
	UIKit.corner(holder, 14)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = holder
	CardFace.render(holder, stroke, card, foil, true)
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") then
			child.ZIndex = 52
		end
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 0.1
	scale.Parent = holder
	TweenService:Create(holder, SPIN_IN, { Rotation = 0 }):Play()
	TweenService:Create(scale, SPIN_IN, { Scale = 1 }):Play()
	task.delay(0.6, sparkleBurst, overlay)

	local banner = UIKit.label(overlay, "✨ FRONTIER CARD! ✨", Enum.Font.FredokaOne, 40, CardEffects.FRONTIER.AURORA[3])
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.fromScale(0.5, 0.06)
	banner.Size = UDim2.new(0.9, 0, 0, 50)
	banner.TextXAlignment = Enum.TextXAlignment.Center
	banner.TextStrokeTransparency = 0.2
	banner.ZIndex = 53
	local subtitle = UIKit.label(overlay, `{card.name} · {card.rarity} · only found in the Frontier`, Enum.Font.GothamBold, 18, UIKit.Colors.Text)
	subtitle.AnchorPoint = Vector2.new(0.5, 1)
	subtitle.Position = UDim2.new(0.5, 0, 0.94, 0)
	subtitle.Size = UDim2.new(0.9, 0, 0, 26)
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.TextStrokeTransparency = 0.4
	subtitle.ZIndex = 53
	local hint = UIKit.label(overlay, "Tap to continue", Enum.Font.Gotham, 13, UIKit.Colors.Subtext)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 0.99, 0)
	hint.Size = UDim2.new(0.6, 0, 0, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.ZIndex = 53

	task.delay(CardEffects.FRONTIER.REVEAL_SECONDS, function()
		if revealToken == token then
			close()
		end
	end)
end

function FrontierRevealController.Start()
	overlay = Instance.new("TextButton")
	overlay.Name = "FrontierReveal"
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(8, 6, 20)
	overlay.Visible = false
	overlay.ZIndex = 49
	overlay.Parent = UIController.GetScreenGui()
	overlay.Activated:Connect(close)

	Remotes.PullAnnouncement.OnClientEvent:Connect(function(_, cardId, foil, kind, finderUserId)
		local card = if typeof(cardId) == "string" then Cards.ById[cardId] else nil
		if kind == "frontier" and card and finderUserId == Players.LocalPlayer.UserId then
			reveal(card, foil == true)
		end
	end)
end

return FrontierRevealController
