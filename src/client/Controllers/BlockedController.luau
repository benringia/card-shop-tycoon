--!strict
-- What you can't do yet, made plain (owner 2026-11-12: "add a visual that indicates the player is not qualified yet,
-- apply this to the entire game"):
--   * when the server refuses you for a requirement (Remotes.Blocked, server Util/Blocked), a big locked card pops in the
--     middle of the screen with a lock, the reason, and a soft denied sound;
--   * before you press: a prompt carrying a RequireLevel attribute shows a lock and the level needed in place of its
--     normal action while your shop level is below it (back to normal once you reach it).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local UiConfig = require(Shared:WaitForChild("Config"):WaitForChild("Blocked"))

local BlockedController = {}

local player = Players.LocalPlayer
local lastShown = { reason = "", at = 0 }

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- The locked card: a lock, "Not yet", the reason; pops in, shakes once, floats away
local function showCard(reason: string)
	local now = os.clock()
	if reason == lastShown.reason and now - lastShown.at < UiConfig.REPEAT_SECONDS then
		return -- the same refusal again a moment later (a held key, a double tap)
	end
	lastShown.reason, lastShown.at = reason, now
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local old = playerGui:FindFirstChild("BlockedCard")
	if old then
		old:Destroy()
	end
	local camera = workspace.CurrentCamera
	local phone = camera ~= nil and camera.ViewportSize.X < 900
	local gui = Instance.new("ScreenGui")
	gui.Name = "BlockedCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 45
	gui.IgnoreGuiInset = true
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.4)
	card.Size = UDim2.fromOffset(if phone then 300 else 440, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = rgb(UiConfig.BACK)
	card.BackgroundTransparency = 0.04
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = card
	local edge = Instance.new("UIStroke")
	edge.Color = rgb(UiConfig.EDGE)
	edge.Thickness = 3
	edge.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = card
	local function line(text: string, size: number, color: Color3, order: number, font: Enum.Font)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = font
		label.TextSize = if phone then math.floor(size * 0.8) else size
		label.TextColor3 = color
		label.Text = text
		label.TextWrapped = true
		label.Size = UDim2.new(1, 0, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.LayoutOrder = order
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(20, 12, 30)
		stroke.Thickness = 2
		stroke.Parent = label
		label.Parent = card
	end
	line(UiConfig.ICON, 40, Color3.new(1, 1, 1), 1, Enum.Font.FredokaOne)
	line(UiConfig.TITLE, 28, rgb(UiConfig.EDGE), 2, Enum.Font.FredokaOne)
	line(reason, 22, Color3.new(1, 1, 1), 3, Enum.Font.GothamBold)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = card
	card.Parent = gui
	gui.Parent = playerGui
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- a little shake: "no"
	task.delay(0.3, function()
		for _, x in { -10, 9, -6, 4, 0 } do
			card.Position = UDim2.new(0.5, x, 0.4, 0)
			task.wait(0.04)
		end
	end)
	local sound = Instance.new("Sound")
	sound.SoundId = UiConfig.SOUND.id
	sound.Volume = UiConfig.SOUND.volume
	sound.PlaybackSpeed = UiConfig.SOUND.pitch
	sound.Parent = SoundService
	sound:Play()
	task.delay(4, sound.Destroy, sound)
	task.delay(UiConfig.SECONDS, function()
		if not gui.Parent then
			return
		end
		local away = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(card, away, { Position = UDim2.fromScale(0.5, 0.3), BackgroundTransparency = 1 }):Play()
		TweenService:Create(edge, away, { Transparency = 1 }):Play()
		for _, label in card:GetChildren() do
			if label:IsA("TextLabel") then
				TweenService:Create(label, away, { TextTransparency = 1 }):Play()
			end
		end
		task.delay(0.4, gui.Destroy, gui)
	end)
end

-- A prompt that needs a shop level: locked text while you're below it, its own text once you reach it
local function dressPrompt(prompt: ProximityPrompt)
	local need = tonumber(prompt:GetAttribute("RequireLevel"))
	if not need then
		return
	end
	if prompt:GetAttribute("OwnAction") == nil then
		prompt:SetAttribute("OwnAction", prompt.ActionText)
		prompt:SetAttribute("OwnObject", prompt.ObjectText)
	end
	local level = tonumber(player:GetAttribute("Level")) or 0
	if level < need then
		prompt.ActionText = UiConfig.PROMPT_ACTION
		prompt.ObjectText = string.gsub(UiConfig.PROMPT_OBJECT, "{level}", tostring(need))
	else
		prompt.ActionText = prompt:GetAttribute("OwnAction") :: string
		prompt.ObjectText = prompt:GetAttribute("OwnObject") :: string
	end
end

function BlockedController.Start()
	Remotes.Blocked.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and typeof(payload.reason) == "string" then
			showCard(payload.reason)
		end
	end)
	ProximityPromptService.PromptShown:Connect(dressPrompt)
end

return BlockedController
