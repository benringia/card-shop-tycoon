--!strict
-- Snappy UI motion: pop in / out, press squash and number bumps, all on a UIScale named "MotionScale".
-- A newer motion on the same object cancels the running one, so fast repeated taps never leave anything
-- stuck half-scaled. Numbers: Config/UIMotion.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIMotion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UIMotion"))

local Motion = {}

local running: { [GuiObject]: Tween } = setmetatable({}, { __mode = "k" }) :: any

local function getScale(gui: GuiObject): UIScale
	local scale = gui:FindFirstChild("MotionScale")
	if scale and scale:IsA("UIScale") then
		return scale
	end
	local created = Instance.new("UIScale")
	created.Name = "MotionScale"
	created.Parent = gui
	return created
end

local function play(gui: GuiObject, to: number, info: TweenInfo): Tween
	local current = running[gui]
	if current then
		current:Cancel()
	end
	local tween = TweenService:Create(getScale(gui), info, { Scale = to })
	running[gui] = tween
	tween:Play()
	return tween
end

-- Grows from a little smaller to full size with a slight overshoot
function Motion.popIn(gui: GuiObject)
	getScale(gui).Scale = UIMotion.OPEN_FROM
	play(gui, 1, TweenInfo.new(UIMotion.OPEN_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
end

-- Shrinks a little and calls onDone when it finishes (not if another motion cancelled it)
function Motion.popOut(gui: GuiObject, onDone: (() -> ())?)
	local tween = play(gui, UIMotion.OPEN_FROM, TweenInfo.new(UIMotion.CLOSE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
	tween.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			getScale(gui).Scale = 1
			if onDone then
				onDone()
			end
		end
	end)
end

-- Stops any motion and shows the object at full size
function Motion.reset(gui: GuiObject)
	local current = running[gui]
	if current then
		current:Cancel()
		running[gui] = nil
	end
	local scale = gui:FindFirstChild("MotionScale")
	if scale and scale:IsA("UIScale") then
		scale.Scale = 1
	end
end

-- Squashes while held, springs back on release
function Motion.press(button: GuiButton)
	local pressInfo = TweenInfo.new(UIMotion.PRESS_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local releaseInfo = TweenInfo.new(UIMotion.PRESS_SECONDS * 2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	button.MouseButton1Down:Connect(function()
		play(button, UIMotion.PRESS_SCALE, pressInfo)
	end)
	local function release()
		if getScale(button).Scale < 1 then
			play(button, 1, releaseInfo)
		end
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	button.Activated:Connect(release)
end

-- A quick grow-and-settle, for a number that just changed
function Motion.bump(gui: GuiObject)
	local half = UIMotion.BUMP_SECONDS / 2
	local tween = play(gui, UIMotion.BUMP_SCALE, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	tween.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			play(gui, 1, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
		end
	end)
end

return Motion
