--!strict
-- The pack (or deck box) on the opening stage (UI project 3 spec 4.1 / 4.2 / 4.7): it floats and rocks while it waits
-- with a light sweeping over the foil, a swipe drags its tear strip a little, then tear() plays the cinematic: bars
-- in and a push-in on the tear line, the strip parting slowly while light leaks out, then the snap (the strip flies
-- off, the rip burst, a flash, a shake and foil shards) and the camera eases back. A deck box's lid lifts instead.
-- The model comes from Util/PackModels (High). Numbers: Config/PackOpening.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local PackOpening = require(Config:WaitForChild("PackOpening"))
local Packs = require(Config:WaitForChild("Packs"))
local PackModels = require(Shared:WaitForChild("Util"):WaitForChild("PackModels"))

local ClientUtil = script.Parent :: Instance
local OpeningStage = require(ClientUtil:WaitForChild("OpeningStage"))
local OpeningFx = require(ClientUtil:WaitForChild("OpeningFx"))

local LOOK = PackOpening.PACK_STAGE
local SCREEN_RIGHT = -1 -- the camera looks along +Z, so a model's -X is the screen's right
local TEAR = PackOpening.TEAR
local STACK = PackOpening.STACK

local OpeningPack = {}

local model: Model? = nil
local packColor = Color3.new(1, 1, 1)
local deck = false
local rest = CFrame.new() -- where it floats (bottom centre pivot)
local height = LOOK.HEIGHT
local idle: RBXScriptConnection? = nil
local lid: BasePart? = nil -- the tear strip, or the deck box's lid
local lidRest = CFrame.new() -- the strip / lid in the model's space
local sheen: Part? = nil
local nextSheen = 0

-- Tweens a model's pivot (TweenService can't), resolving when it's done
local function tweenPivot(target: Model, to: CFrame, seconds: number, style: Enum.EasingStyle, direction: Enum.EasingDirection): Tween
	local value = Instance.new("CFrameValue")
	value.Value = target:GetPivot()
	value.Changed:Connect(function(cframe)
		target:PivotTo(cframe)
	end)
	local t = TweenService:Create(value, TweenInfo.new(seconds, style, direction), { Value = to })
	t.Completed:Once(function()
		value:Destroy()
	end)
	t:Play()
	return t
end

local function stopIdle()
	if idle then
		idle:Disconnect()
		idle = nil
	end
end

-- A point light gliding across the foil's front: its highlight sweeps over the pack
local function sweep()
	if not sheen or not model then
		return
	end
	local front = rest * CFrame.new(0, height * 0.55, -0.9)
	sheen.CFrame = front * CFrame.new(-1.6, 0.4, 0)
	local light = sheen:FindFirstChildOfClass("PointLight") :: PointLight
	light.Brightness = 0
	TweenService:Create(sheen, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { CFrame = front * CFrame.new(1.6, -0.4, 0) }):Play()
	local up = TweenService:Create(light, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true), { Brightness = LOOK.SHEEN_BRIGHTNESS })
	up:Play()
end

local function startIdle()
	stopIdle()
	local start = os.clock()
	nextSheen = start + 0.6
	idle = RunService.RenderStepped:Connect(function()
		if not model then
			return
		end
		local t = os.clock() - start
		local bob = math.sin(t * math.pi * 2 / LOOK.BOB_SECONDS) * LOOK.BOB
		local rock = math.rad(math.sin(t * math.pi * 2 / (LOOK.BOB_SECONDS * 1.3)) * LOOK.SWAY)
		model:PivotTo(rest * CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, rock))
		if os.clock() >= nextSheen then
			nextSheen = os.clock() + LOOK.SHEEN_EVERY
			sweep()
		end
	end)
end

function OpeningPack.clear()
	stopIdle()
	if model then
		model:Destroy()
		model = nil
	end
	if sheen then
		sheen:Destroy()
		sheen = nil
	end
	lid = nil
end

-- The pack (or deck box) floating in the middle of the stage
function OpeningPack.show(pack: Packs.Pack)
	OpeningPack.clear()
	deck = pack.kind == "Deck"
	packColor = pack.color
	local made = if deck then PackModels.deckBox(pack.productId) else PackModels.pack(pack.productId, "High")
	for _, part in made:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = true -- swipes and taps pick it (the controller raycasts)
			part.CastShadow = false
		end
	end
	local _, size = made:GetBoundingBox()
	made:ScaleTo(made:GetScale() * LOOK.HEIGHT / size.Y)
	height = LOOK.HEIGHT
	rest = OpeningStage.root() * CFrame.new(0, -height / 2, 0)
	made:PivotTo(rest)
	made.Parent = OpeningStage.folder()
	model = made
	local piece = made:FindFirstChild(if deck then "Lid" else "Strip")
	lid = if piece and piece:IsA("BasePart") then piece else nil
	lidRest = if lid then made:GetPivot():ToObjectSpace(lid.CFrame) else CFrame.new()
	local light = Instance.new("Part")
	light.Name = "Sheen"
	light.Anchored, light.CanCollide, light.CanQuery, light.CanTouch = true, false, false, false
	light.Transparency = 1
	light.Size = Vector3.one * 0.2
	local point = Instance.new("PointLight")
	point.Range = 2.6
	point.Brightness = 0
	point.Color = Color3.fromRGB(255, 250, 235)
	point.Shadows = false
	point.Parent = light
	light.Parent = OpeningStage.folder()
	sheen = light
	startIdle()
end

-- The tear line's middle and ends (just under the top seal), in the stage
local function tearLine(): (Vector3, Vector3, Vector3)
	local pivot = if model then model:GetPivot() else rest
	local y = height * 0.88
	local half = height * 0.32
	local left = (pivot * CFrame.new(-half * SCREEN_RIGHT, y, -0.12)).Position
	local right = (pivot * CFrame.new(half * SCREEN_RIGHT, y, -0.12)).Position
	return (pivot * CFrame.new(0, y, -0.12)).Position, left, right
end

-- Follows the swipe before it tears: the strip lifts a little (0 to 1)
function OpeningPack.drag(progress: number)
	if not model or not lid then
		return
	end
	local p = math.clamp(progress, 0, 1)
	lid.CFrame = model:GetPivot() * lidRest * CFrame.new(0.05 * p * SCREEN_RIGHT, 0.04 * p, 0) * CFrame.Angles(0, 0, -math.rad(5 * p) * SCREEN_RIGHT)
end

-- The cinematic tear (spec 4.2); yields until the camera is back
function OpeningPack.tear()
	if not model then
		return
	end
	stopIdle()
	local middle, left, right = tearLine()
	OpeningStage.bars(true, 0.28)
	OpeningStage.push(TEAR.PUSH_SCALE, middle, TEAR.PUSH_SECONDS)
	OpeningStage.play("crinkle")
	sweep()
	task.wait(TEAR.PUSH_SECONDS)
	-- slow motion: the strip parts while light leaks out of the tear
	local fadeLeak = OpeningFx.leak(left, right, TEAR.PART_SECONDS)
	local pivot = model:GetPivot()
	if lid then
		TweenService:Create(lid, TweenInfo.new(TEAR.PART_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = pivot * lidRest * CFrame.new(0.08 * SCREEN_RIGHT, 0.06, 0) * CFrame.Angles(0, 0, -math.rad(8) * SCREEN_RIGHT),
		}):Play()
	end
	OpeningFx.shards(right, TEAR.SPILL, false, 0.5)
	task.wait(TEAR.PART_SECONDS)
	-- the snap
	OpeningStage.play("snap")
	if lid then
		local strip = lid
		local fly = TweenService:Create(strip, TweenInfo.new(TEAR.SNAP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = pivot * lidRest * CFrame.new(3.2 * SCREEN_RIGHT, -2.6, -0.6) * CFrame.Angles(0.4, 0.3, -math.rad(95) * SCREEN_RIGHT),
			Transparency = 1,
		})
		fly.Completed:Once(function()
			strip:Destroy()
		end)
		fly:Play()
		lid = nil
	end
	OpeningFx.burst(middle, packColor, TEAR.BURST_SIZE)
	OpeningStage.flash(TEAR.FLASH, TEAR.FLASH_SECONDS)
	OpeningStage.shake(TEAR.SHAKE, TEAR.SHAKE_SECONDS)
	OpeningFx.shards(middle, TEAR.SHARDS, false, 1.3)
	fadeLeak(0.3)
	task.wait(TEAR.FLASH_SECONDS)
	OpeningStage.bars(false, 0.28)
	OpeningStage.ease(TEAR.EASE_SECONDS)
	task.wait(TEAR.EASE_SECONDS)
end

-- A deck box opens instead: the camera pushes in, the lid lifts off and flies, the same burst and flash (spec 4.7)
function OpeningPack.open()
	if not model then
		return
	end
	stopIdle()
	local pivot = model:GetPivot()
	local top = (pivot * CFrame.new(0, height, 0)).Position
	OpeningStage.bars(true, 0.28)
	OpeningStage.push(TEAR.PUSH_SCALE * 0.9, top, TEAR.PUSH_SECONDS)
	task.wait(TEAR.PUSH_SECONDS)
	if lid then
		local cover = lid
		TweenService:Create(cover, TweenInfo.new(TEAR.PART_SECONDS * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = pivot * lidRest * CFrame.new(0, 0.12, 0),
		}):Play()
		task.wait(TEAR.PART_SECONDS * 0.6)
		OpeningStage.play("snap")
		local fly = TweenService:Create(cover, TweenInfo.new(TEAR.SNAP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = pivot * lidRest * CFrame.new(-2.8, 2.4, -0.8) * CFrame.Angles(0.6, 0, math.rad(70)),
			Transparency = 1,
		})
		fly.Completed:Once(function()
			cover:Destroy()
		end)
		fly:Play()
		lid = nil
	end
	OpeningFx.burst(top, packColor, TEAR.BURST_SIZE)
	OpeningStage.flash(TEAR.FLASH, TEAR.FLASH_SECONDS)
	OpeningStage.shake(TEAR.SHAKE, TEAR.SHAKE_SECONDS)
	OpeningFx.shards(top, TEAR.SHARDS, false, 1.3)
	task.wait(TEAR.FLASH_SECONDS)
	OpeningStage.bars(false, 0.28)
	OpeningStage.ease(TEAR.EASE_SECONDS)
	task.wait(TEAR.EASE_SECONDS)
end

-- Moves down out of the cards' way (yields)
function OpeningPack.lower()
	if not model then
		return
	end
	stopIdle()
	local t = tweenPivot(model, rest * CFrame.new(0, -STACK.PACK_DOWN, 0), STACK.PACK_DOWN_SECONDS, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	t.Completed:Wait()
end

-- Where the cards come out: the open top's middle, a little behind the front
function OpeningPack.mouth(): Vector3
	local pivot = if model then model:GetPivot() else rest
	return (pivot * CFrame.new(0, height * 0.85, 0.05)).Position
end

-- Drops away out of view, then goes
function OpeningPack.away()
	local current = model
	if not current then
		return
	end
	local t = tweenPivot(current, current:GetPivot() * CFrame.new(0, -4, 0), STACK.PACK_AWAY_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	t.Completed:Once(function()
		if model == current then
			OpeningPack.clear()
		end
	end)
end

return OpeningPack
