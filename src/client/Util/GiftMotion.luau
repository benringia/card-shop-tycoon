--!strict
-- The gift window's life (owner 2026-11-15: "it's a bit flat. add animation that kids/player will get excited to";
-- Config/Gifts MOTION): tiles popping in one after another, a gift that bobs or rattles as if something's inside,
-- twinkling sparkles round it, a shine sweeping across the big gift and the bars, bars filling up from empty. Every
-- loop stops by itself once its object leaves the screen (destroyed or its window closed).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Gifts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Gifts"))

local Util = script.Parent :: Instance
local Icon = require(Util:WaitForChild("Icon"))
local UIKit = require(Util:WaitForChild("UIKit"))

local GiftMotion = {}

local MOTION = Gifts.MOTION
local random = Random.new()

-- On screen: still parented, and it and every frame above it shown (a closed window hides its children, not their flags)
local function alive(object: Instance): boolean
	local at: Instance? = object
	while at do
		if at:IsA("GuiObject") and not at.Visible then
			return false
		elseif at:IsA("LayerCollector") then
			return at.Enabled
		end
		at = at.Parent
	end
	return false
end

-- `object`'s scale (its own UIScale, made once)
function GiftMotion.scaleOf(object: GuiObject): UIScale
	local scale = object:FindFirstChild("MotionScale") :: UIScale?
	if scale then
		return scale
	end
	local made = Instance.new("UIScale")
	made.Name = "MotionScale"
	made.Parent = object
	return made
end

-- Pops `object` in after `delay` s (small, tipped, then springing to size); `after` runs once it has landed
function GiftMotion.popIn(object: GuiObject, delay: number, after: (() -> ())?)
	local scale = GiftMotion.scaleOf(object)
	scale.Scale = MOTION.pop.from
	local turn = object.Rotation
	object.Rotation = turn + random:NextNumber(-MOTION.pop.tilt, MOTION.pop.tilt)
	task.delay(delay, function()
		if object.Parent == nil then
			return
		end
		local info = TweenInfo.new(MOTION.pop.seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(scale, info, { Scale = 1 }):Play()
		local tip = TweenService:Create(object, info, { Rotation = turn })
		tip:Play()
		if after then
			tip.Completed:Once(after)
		end
	end)
end

-- A soft breath: bigger and back, forever
function GiftMotion.breathe(object: GuiObject, amount: number)
	local scale = GiftMotion.scaleOf(object)
	TweenService:Create(scale, TweenInfo.new(MOTION.breathe, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = amount }):Play()
end

-- Bobbing up and down `px`, forever
function GiftMotion.bob(object: GuiObject, px: number)
	local home = object.Position
	TweenService:Create(object, TweenInfo.new(MOTION.bob, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = home - UDim2.fromOffset(0, px),
	}):Play()
end

-- Rocking side to side `angle` degrees, forever
function GiftMotion.rock(object: GuiObject, angle: number)
	object.Rotation = -angle
	TweenService:Create(object, TweenInfo.new(MOTION.rock, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = angle }):Play()
end

-- A quick rattle every `every` s, as if something inside wants out (a hop and a shake)
function GiftMotion.rattle(object: GuiObject, every: number)
	local home = object.Position
	task.spawn(function()
		while object.Parent do
			task.wait(every + random:NextNumber(0, 0.4))
			if not alive(object) then
				continue
			end
			local hop = TweenService:Create(object, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = home - UDim2.fromOffset(0, MOTION.rattle.hop) })
			hop:Play()
			for _, side in MOTION.rattle.angles do
				TweenService:Create(object, TweenInfo.new(0.05, Enum.EasingStyle.Sine), { Rotation = side }):Play()
				task.wait(0.05)
			end
			TweenService:Create(object, TweenInfo.new(0.16, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Position = home, Rotation = 0 }):Play()
		end
	end)
end

-- Little glossy stars twinkling in a ring round `around` (a picture in `holder`; growing in, turning, fading),
-- `count` at a time
function GiftMotion.sparkles(holder: GuiObject, around: GuiObject, count: number)
	for slot = 1, count do
		task.spawn(function()
			task.wait(slot * MOTION.sparkle.seconds / count)
			while holder.Parent do
				if alive(holder) then
					local size = random:NextInteger(MOTION.sparkle.size[1], MOTION.sparkle.size[2])
					local spark = Icon.make(holder, MOTION.sparkle.icon, UDim2.fromOffset(size, size))
					spark.Name = "Sparkle"
					spark.AnchorPoint = Vector2.new(0.5, 0.5)
					local middle = around.AbsolutePosition + around.AbsoluteSize / 2 - holder.AbsolutePosition
					local angle = random:NextNumber(0, math.pi * 2)
					local reach = around.AbsoluteSize.X * random:NextNumber(MOTION.sparkle.ring[1], MOTION.sparkle.ring[2])
					spark.Position = UDim2.fromOffset(middle.X + math.cos(angle) * reach, middle.Y + math.sin(angle) * reach * 0.85)
					spark.ZIndex = holder.ZIndex + 5
					local glyph = spark:FindFirstChild("Glyph") :: ImageLabel?
					if glyph then
						glyph.ZIndex = spark.ZIndex
					end
					local scale = GiftMotion.scaleOf(spark)
					scale.Scale = 0
					local half = MOTION.sparkle.seconds / 2
					TweenService:Create(scale, TweenInfo.new(half, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
					TweenService:Create(spark, TweenInfo.new(MOTION.sparkle.seconds, Enum.EasingStyle.Linear), { Rotation = random:NextNumber(-90, 90) }):Play()
					task.delay(half, function()
						TweenService:Create(scale, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 }):Play()
					end)
					task.delay(MOTION.sparkle.seconds, spark.Destroy, spark)
				end
				task.wait(MOTION.sparkle.seconds + random:NextNumber(0, MOTION.sparkle.rest))
			end
		end)
	end
end

-- A band of light sweeping across `frame` every `every` s (an overlay with the frame's corners)
function GiftMotion.shine(frame: GuiObject, corner: number, every: number)
	local overlay = Instance.new("Frame")
	overlay.Name = "Shine"
	overlay.BackgroundColor3 = Color3.new(1, 1, 1)
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = frame.ZIndex + 1
	overlay.Parent = frame
	UIKit.corner(overlay, corner)
	local band = Instance.new("UIGradient")
	band.Rotation = 20
	band.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, MOTION.shine.brightest),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	band.Offset = Vector2.new(-1, 0)
	band.Parent = overlay
	task.spawn(function()
		while overlay.Parent do
			band.Offset = Vector2.new(-1, 0)
			if alive(frame) then
				TweenService:Create(band, TweenInfo.new(MOTION.shine.seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Offset = Vector2.new(1, 0) }):Play()
			end
			task.wait(every)
		end
	end)
end

-- A bar's fill growing from empty to `share` after `delay` s
function GiftMotion.fill(fill: GuiObject, share: number, delay: number)
	fill.Size = UDim2.fromScale(0, 1)
	task.delay(delay, function()
		if fill.Parent then
			TweenService:Create(fill, TweenInfo.new(MOTION.fill, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(math.clamp(share, 0, 1), 1),
			}):Play()
		end
	end)
end

return GiftMotion
