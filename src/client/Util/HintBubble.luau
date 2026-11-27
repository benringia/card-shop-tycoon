--!strict
-- The What now? tip's bubble (spec 2026-11-27-what-now-hints-design, the owner's look 1): Pish's face, one short line
-- and a small x in a white pill standing on the gold arrow (Util/TutorialCues.pointerOf): over it when it points down
-- at a button or a thing, beside it when it waits at the screen's edge (Util/HintRules.bubbleAt), still while the arrow
-- bounces, never on the arrow or the ring it points into (owner 2026-11-28). Hidden while the arrow is. Built once,
-- shown again for each tip (client HintController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Hints = require(Config:WaitForChild("Hints"))
local HudGrowConfig = require(Config:WaitForChild("HudGrow"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local HintRules = require(Shared:WaitForChild("Util"):WaitForChild("HintRules"))

local ClientUtil = script.Parent :: Instance
local Hud = require(ClientUtil:WaitForChild("Hud"))
local TutorialCues = require(ClientUtil:WaitForChild("TutorialCues"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))

local HintBubble = {}

local LOOK = Hints.BUBBLE
local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FACE_BACK = Color3.fromRGB(255, 246, 224)
local FACE_EDGE = Color3.fromRGB(255, 215, 122)
local X_BACK = Color3.fromRGB(241, 232, 251)
local X_INK = Color3.fromRGB(122, 99, 160)

type Parts = { bubble: Frame, words: TextLabel, close: TextButton, scale: UIScale }
local parts: Parts? = nil
local onClose: (() -> ())? = nil
local follow: RBXScriptConnection? = nil
local AVOID_EVERY = 0.5 -- seconds between looks at where the HUD's pieces are

local function drawn(gui: GuiObject): boolean
	if gui.BackgroundTransparency < 0.95 then
		return true
	end
	if (gui:IsA("TextLabel") or gui:IsA("TextButton")) and gui.Text ~= "" and gui.TextTransparency < 0.95 then
		return true
	end
	return (gui:IsA("ImageLabel") or gui:IsA("ImageButton")) and gui.Image ~= "" and gui.ImageTransparency < 0.95
end

-- The HUD's pieces on the screen, for the bubble to keep clear of (owner 2026-11-28 "make sure no overlapping
-- elements"): what MainGui draws, its hidden windows skipped whole, the soft glows round tiles and portraits left out
-- (see-through at their edges); the toasts make room for the bubble themselves (UIController, ToastRules.hangBelow)
local function hudBoxes(): { HintRules.Box }
	local boxes: { HintRules.Box } = {}
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local main = if playerGui then playerGui:FindFirstChild("MainGui") else nil
	if not main or not main:IsA("ScreenGui") then
		return boxes
	end
	local view = main.AbsoluteSize
	local function walk(node: Instance)
		for _, child in node:GetChildren() do
			if child:IsA("GuiObject") then
				if child.Visible and child.Name ~= "Toasts" then
					local at, size = child.AbsolutePosition, child.AbsoluteSize
					local cover = size.X >= view.X * 0.6 and size.Y >= view.Y * 0.6 -- a layer the HUD sits in
					if size.X > 1 and size.Y > 1 and not cover and child.Name ~= "Glow" and drawn(child) then
						table.insert(boxes, { x = at.X, y = at.Y, w = size.X, h = size.Y })
					end
					walk(child)
				end
			elseif child:IsA("Folder") then
				walk(child)
			end
		end
	end
	walk(main)
	return boxes
end

local function build(): Parts
	local bubble = Instance.new("Frame")
	bubble.Name = "HintBubble"
	bubble.Size = UDim2.fromOffset(0, LOOK.height)
	bubble.AutomaticSize = Enum.AutomaticSize.X
	bubble.BackgroundColor3 = Color3.new(1, 1, 1)
	bubble.Visible = false
	bubble.ZIndex = 21
	bubble.Parent = TutorialCues.screen()
	UIKit.corner(bubble, LOOK.height / 2)
	UIKit.outline(bubble, UIStyle.BABY.lilac.deep, 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, (LOOK.height - LOOK.face) / 2)
	pad.Parent = bubble
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 8)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = bubble

	local face = Instance.new("ImageLabel")
	face.Name = "Face"
	face.Size = UDim2.fromOffset(LOOK.face, LOOK.face)
	face.BackgroundColor3 = FACE_BACK
	face.Image = Hints.FACE
	face.ScaleType = Enum.ScaleType.Crop
	face.LayoutOrder = 1
	face.ZIndex = 22
	face.Parent = bubble
	UIKit.corner(face, LOOK.face / 2)
	UIKit.outline(face, FACE_EDGE, 2)

	local words = UIKit.label(bubble, "", Enum.Font.FredokaOne, LOOK.text, UIStyle.CREAM.INK)
	words.Name = "Words"
	words.Size = UDim2.fromOffset(0, LOOK.height)
	words.AutomaticSize = Enum.AutomaticSize.X
	words.TextWrapped = false
	words.LayoutOrder = 2
	words.ZIndex = 22

	-- the x: a finger-sized tap area (LOOK.tap) round a small circle
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = ""
	close.AutoButtonColor = false
	close.BackgroundTransparency = 1
	close.Size = UDim2.fromOffset(LOOK.tap, LOOK.tap)
	close.LayoutOrder = 3
	close.ZIndex = 22
	close.Parent = bubble
	-- a capital X centred both ways (UIKit.label starts left-aligned; owner 2026-11-27: "center the X")
	local dot = UIKit.label(close, "X", Enum.Font.FredokaOne, 14, X_INK)
	dot.TextXAlignment = Enum.TextXAlignment.Center
	dot.TextYAlignment = Enum.TextYAlignment.Center
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(LOOK.x, LOOK.x)
	dot.BackgroundTransparency = 0
	dot.BackgroundColor3 = X_BACK
	dot.ZIndex = 23
	UIKit.corner(dot, LOOK.x / 2)
	close.Activated:Connect(function()
		local callback = onClose
		if callback then
			callback()
		end
	end)

	local made: Parts = { bubble = bubble, words = words, close = close, scale = Hud.scaleWith(bubble, 1, true) }
	parts = made
	return made
end

-- Stand `text` on the newest arrow until the returned remover runs; `closed` runs when its x is tapped
function HintBubble.show(text: string, closed: () -> ()): () -> ()
	local made = parts or build()
	if follow then
		follow:Disconnect()
	end
	onClose = closed
	made.words.Text = text
	-- it pops in at the HUD's size (its UIScale is the HUD's: Hud.scaleWith keeps its rest in an attribute)
	local rest = made.bubble:GetAttribute(HudGrowConfig.ATTRIBUTE)
	local scale = if typeof(rest) == "number" then rest else made.scale.Scale
	made.scale.Scale = scale * 0.7
	TweenService:Create(made.scale, POP, { Scale = scale }):Play()
	local avoid: { HintRules.Box } = {}
	local lookedAt = -math.huge
	local connection = RunService.RenderStepped:Connect(function()
		local arrow = TutorialCues.pointerOf()
		local layer = TutorialCues.screen()
		made.bubble.Visible = arrow ~= nil
		if not arrow then
			return
		end
		local now = os.clock()
		if now - lookedAt >= AVOID_EVERY then
			lookedAt = now
			avoid = hudBoxes()
		end
		local size, view, origin = made.bubble.AbsoluteSize, layer.AbsoluteSize, layer.AbsolutePosition
		local at = HintRules.bubbleAt(arrow.box, arrow.rotation, { w = size.X, h = size.Y }, { w = view.X, h = view.Y }, LOOK, arrow.target, avoid)
		made.bubble.Position = UDim2.fromOffset(at.x - origin.X, at.y - origin.Y)
	end)
	follow = connection
	return function()
		connection:Disconnect()
		if follow == connection then
			follow = nil
			onClose = nil
			made.bubble.Visible = false
		end
	end
end

return HintBubble
