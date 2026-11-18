--!strict
-- The Legendary sky tear on the opening's stage (owner 2026-11-18, pick C of three storyboards: "Pulling a Legendary
-- should play an epic legendary cinematic"; Config/CardReveal SKY_TEAR): through the tease a rift cracks open in the
-- night sky above the cards (a jagged crack of light growing, a glow and turning rays behind it, light pouring down
-- onto the card, the stage rumbling harder), flashes wide as the creature comes through, then closes once the card has
-- spun out of it. Its pictures always face the camera and are unlit, so the stage's dimming can't dull them.
-- OpeningCards plays it; it clears with the card's show.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local CardReveal = require(Config:WaitForChild("CardReveal"))
local PackFx = require(Config:WaitForChild("PackFx"))
local PackOpening = require(Config:WaitForChild("PackOpening"))
local SuperFxConfig = require(Config:WaitForChild("SuperFx"))

local ClientUtil = script.Parent :: Instance
local OpeningStage = require(ClientUtil:WaitForChild("OpeningStage"))
local OpeningFx = require(ClientUtil:WaitForChild("OpeningFx"))

local OpeningRift = {}

local SKY = CardReveal.SKY_TEAR
local HOT = Color3.fromRGB(255, 244, 214) -- the light through the crack
local PULSE = 0.2 -- seconds between the rumble's shakes

type Rift = {
	anchor: Part,
	crack: ImageLabel,
	glow: ImageLabel,
	rays: ImageLabel,
	light: PointLight,
	step: RBXScriptConnection,
	fadeLeak: (seconds: number) -> (),
	leakFading: boolean,
}

local current: Rift? = nil

local function tween(item: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	TweenService:Create(item, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal):Play()
end

local function picture(board: BillboardGui, image: string, tint: Color3, z: number): ImageLabel
	local made = Instance.new("ImageLabel")
	made.BackgroundTransparency = 1
	made.AnchorPoint = Vector2.new(0.5, 0.5)
	made.Position = UDim2.fromScale(0.5, 0.5)
	made.Size = UDim2.fromScale(0, 0)
	made.Image = image
	made.ImageColor3 = tint
	made.ZIndex = z
	made.Parent = board
	return made
end

function OpeningRift.clear()
	local rift = current
	current = nil
	if rift then
		rift.step:Disconnect()
		if not rift.leakFading then
			rift.fadeLeak(0.2)
		end
		rift.anchor:Destroy()
	end
end

-- The sky cracks open over `seconds` above the cards, its light pouring down onto `onto`; returns where the rift is
function OpeningRift.open(color: Color3, seconds: number, onto: Vector3): Vector3
	OpeningRift.clear()
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local at = OpeningStage.screenPoint(view.X * SKY.rift.x, view.Y * SKY.rift.y, PackOpening.CAMERA_DISTANCE + SKY.rift.behind)
	local anchor = Instance.new("Part")
	anchor.Name = "SkyRift"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(at)
	anchor.Parent = OpeningStage.folder()
	local width = SKY.rift.width
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(width * 1.8, width * 1.8)
	board.LightInfluence = 0
	board.Brightness = 2.5
	board.Adornee = anchor
	board.Parent = anchor
	local rays = picture(board, PackFx.IMAGES.rays, color, 1)
	rays.Size = UDim2.fromScale(1, 1)
	rays.ImageTransparency = 1
	local glow = picture(board, PackFx.IMAGES.aura, color:Lerp(HOT, 0.5), 2)
	local crack = picture(board, SuperFxConfig.TEXTURES.crack, HOT, 3)
	local light = Instance.new("PointLight")
	light.Color = color:Lerp(HOT, 0.4)
	light.Range = width * 3
	light.Brightness = 0
	light.Shadows = false
	light.Parent = anchor
	-- cracking open: slowly at first, then all at once
	tween(crack, seconds, { Size = UDim2.fromScale(0.5, 0.34) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(glow, seconds, { Size = UDim2.fromScale(0.55, 0.55) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(rays, seconds, { ImageTransparency = 0.45 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(light, seconds, { Brightness = 3 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local fadeLeak = OpeningFx.leak(at, onto, seconds)
	local start, nextPulse = os.clock(), 0
	local step = RunService.RenderStepped:Connect(function(dt)
		local elapsed = os.clock() - start
		rays.Rotation += 12 * dt
		crack.Rotation = math.sin(elapsed * 9) * 2 -- the crack strains
		if elapsed < seconds and elapsed >= nextPulse then
			nextPulse = elapsed + PULSE
			local p = elapsed / seconds
			OpeningStage.shake(SKY.rumble[1] + (SKY.rumble[2] - SKY.rumble[1]) * p, PULSE * 1.2)
		end
	end)
	current = { anchor = anchor, crack = crack, glow = glow, rays = rays, light = light, step = step, fadeLeak = fadeLeak, leakFading = false }
	return at
end

-- Torn wide: a flash, a quake, a burst of gold, as the creature comes through
function OpeningRift.burst(color: Color3)
	local rift = current
	if not rift then
		return
	end
	tween(rift.crack, 0.3, { Size = UDim2.fromScale(0.78, 0.56) }, Enum.EasingStyle.Back)
	tween(rift.glow, 0.3, { Size = UDim2.fromScale(0.9, 0.9) }, Enum.EasingStyle.Back)
	tween(rift.light, 0.3, { Brightness = 5 })
	OpeningStage.flash(0.9, 0.45)
	OpeningStage.shake(0.14, 0.45)
	local at = rift.anchor.Position
	OpeningFx.burst(at, color, 2.2)
	OpeningFx.shards(at, 24, true, 1)
end

-- Closing up once the card is through
function OpeningRift.close(seconds: number)
	local rift = current
	if not rift then
		return
	end
	tween(rift.crack, seconds, { Size = UDim2.fromScale(0, 0), ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(rift.glow, seconds, { Size = UDim2.fromScale(0, 0), ImageTransparency = 1 })
	tween(rift.rays, seconds, { ImageTransparency = 1 })
	tween(rift.light, seconds, { Brightness = 0 })
	rift.leakFading = true
	rift.fadeLeak(seconds)
	task.delay(seconds, function()
		if current == rift then
			OpeningRift.clear()
		end
	end)
end

return OpeningRift
