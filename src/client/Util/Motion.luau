--!strict
-- Snappy UI motion: pop in / out, press squash and number bumps, all on a UIScale named "MotionScale".
-- A newer motion on the same object cancels the running one, so fast repeated taps never leave anything
-- stuck half-scaled. Numbers: Config/UIMotion.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIMotion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UIMotion"))

local Motion = {}

local running: { [GuiObject]: Tween } = setmetatable({}, { __mode = "k" }) :: any
local closing: { [GuiObject]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- popping out: presses leave it alone
local hoverScales: { [GuiObject]: number } = setmetatable({}, { __mode = "k" }) :: any -- Motion.hover's size
local hovering: { [GuiObject]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- under a mouse now

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
	closing[gui] = nil
	getScale(gui).Scale = UIMotion.OPEN_FROM
	play(gui, 1, TweenInfo.new(UIMotion.OPEN_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
end

-- Shrinks a little and calls onDone when it finishes (not if another motion cancelled it)
function Motion.popOut(gui: GuiObject, onDone: (() -> ())?)
	closing[gui] = true
	local tween = play(gui, UIMotion.OPEN_FROM, TweenInfo.new(UIMotion.CLOSE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
	tween.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			closing[gui] = nil
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
	closing[gui] = nil
	local scale = gui:FindFirstChild("MotionScale")
	if scale and scale:IsA("UIScale") then
		scale.Scale = 1
	end
end

-- Squashes while held, springs back on release. `squishy` (the cotton candy buttons, spec
-- 2026-11-03-cotton-candy-ui-design): a deeper dip, and the release bounces past full size before it settles.
function Motion.press(button: GuiButton, squishy: boolean?)
	local pressInfo = TweenInfo.new(UIMotion.PRESS_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local releaseInfo = TweenInfo.new(UIMotion.PRESS_SECONDS * 2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local bounceInfo = TweenInfo.new(UIMotion.SQUISH_BOUNCE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local settleInfo = TweenInfo.new(UIMotion.SQUISH_SETTLE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	button.MouseButton1Down:Connect(function()
		if not closing[button] then
			play(button, if squishy then UIMotion.SQUISH_PRESS else UIMotion.PRESS_SCALE, pressInfo)
		end
	end)
	local function release()
		if closing[button] or getScale(button).Scale >= 1 then
			return
		end
		-- Back to its hover size while the mouse is still on it (Motion.hover), else full size
		local rest = if hovering[button] then hoverScales[button] or 1 else 1
		if not squishy then
			play(button, rest, releaseInfo)
			return
		end
		play(button, rest * UIMotion.RELEASE_OVERSHOOT, bounceInfo).Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				play(button, rest, settleInfo)
			end
		end)
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	button.Activated:Connect(release)
end

-- Grows a little under a mouse and settles back when it leaves (the soft look's hover instead of Roblox's grey one;
-- spec 2026-11-03-cotton-candy-ui-design). Touch has no hover.
function Motion.hover(button: GuiButton, scale: number)
	hoverScales[button] = scale
	local info = TweenInfo.new(UIMotion.HOVER_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	button.MouseEnter:Connect(function()
		if not UserInputService.MouseEnabled or closing[button] then
			return
		end
		hovering[button] = true
		play(button, scale, info)
	end)
	button.MouseLeave:Connect(function()
		hovering[button] = nil
		if not closing[button] then
			play(button, 1, info)
		end
	end)
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
