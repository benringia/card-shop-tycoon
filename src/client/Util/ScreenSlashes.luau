--!strict
-- Thousand Cuts' slashes and flashes across your own screen (owner 2026-11-09: "the slashes are hard to see. can add the
-- slashes and flashes across the screen"; numbers in Config/SwordSkillFx SCREEN, where they cross in
-- Util/ScreenSlashRules): glowing lines with white cores ripping across the whole screen, drawn in fast and fading, and
-- white flashes. One ScreenGui over the HUD, made on first use; everything on it cleans itself up.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SwordSkillFxConfig = require(Shared:WaitForChild("Config"):WaitForChild("SwordSkillFx"))
local ScreenSlashRules = require(Shared:WaitForChild("Util"):WaitForChild("ScreenSlashRules"))

local ScreenSlashes = {}

local WHITE = Color3.new(1, 1, 1)
local FADE = 0.12 -- seconds a slash takes to fade once its hold is over
-- Both ends tapered, solid through the middle
local TAPER = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.18, 0.1),
	NumberSequenceKeypoint.new(0.82, 0.1),
	NumberSequenceKeypoint.new(1, 1),
})

local gui: ScreenGui? = nil

local function layer(): ScreenGui
	local made = gui
	if made and made.Parent then
		return made
	end
	local fresh = Instance.new("ScreenGui")
	fresh.Name = "ScreenSlashes"
	fresh.IgnoreGuiInset = true
	fresh.ResetOnSpawn = false
	fresh.DisplayOrder = 40
	fresh.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	fresh.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = fresh
	return fresh
end

local function band(parent: Instance, color: Color3, thick: number, transparency: number): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(0, thick)
	local taper = Instance.new("UIGradient")
	taper.Transparency = TAPER
	taper.Parent = frame
	frame.Parent = parent
	return frame
end

-- One slash across the screen: a dark glow band (the weapon's `deep` colour pushed toward black) round a thin core in
-- its `glow` colour, drawn out from its middle, held, then faded
local function slash(at: ScreenSlashRules.Slash, glowColor: Color3, deepColor: Color3)
	local cfg = SwordSkillFxConfig.SCREEN
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local view = camera.ViewportSize
	local length = math.sqrt(view.X * view.X + view.Y * view.Y) * at.length
	local glow = band(layer(), deepColor:Lerp(Color3.new(), cfg.darken), cfg.thick, 0.1)
	glow.Position = UDim2.fromScale(at.x, at.y)
	glow.Rotation = at.angle
	local core = band(glow, glowColor:Lerp(WHITE, cfg.coreWhite), cfg.core, 0)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.new(1, 0, 0, cfg.core)
	TweenService:Create(glow, TweenInfo.new(cfg.draw, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(length, cfg.thick) }):Play()
	task.delay(cfg.draw + cfg.hold, function()
		TweenService:Create(glow, TweenInfo.new(FADE), { BackgroundTransparency = 1, Size = UDim2.fromOffset(length, cfg.thick * 0.3) }):Play()
		TweenService:Create(core, TweenInfo.new(FADE), { BackgroundTransparency = 1 }):Play()
	end)
	Debris:AddItem(glow, cfg.draw + cfg.hold + FADE + 0.1)
end

-- A flash over the whole screen, `strength` 0-1 of white (a little of `color` in it), fading out
function ScreenSlashes.flash(strength: number, color: Color3)
	local cfg = SwordSkillFxConfig.SCREEN
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = WHITE:Lerp(color, 0.25)
	frame.BackgroundTransparency = 1 - math.clamp(strength, 0, 1)
	frame.Parent = layer()
	TweenService:Create(frame, TweenInfo.new(cfg.flashSeconds), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(frame, cfg.flashSeconds + 0.1)
end

-- A wave of cuts: SCREEN.perWave slashes ripping across the screen in the weapon's colours (`glow`, `deep`), a few
-- hundredths of a second apart, and a flash
function ScreenSlashes.wave(glowColor: Color3, deepColor: Color3)
	local cfg = SwordSkillFxConfig.SCREEN
	for index, at in ScreenSlashRules.wave(cfg.perWave, math.random) do
		task.delay((index - 1) * cfg.draw * 0.5, function()
			slash(at, glowColor, deepColor)
		end)
	end
	ScreenSlashes.flash(cfg.flash, glowColor)
end

-- The harvest: a big X across the screen and a bright flash
function ScreenSlashes.cross(glowColor: Color3, deepColor: Color3)
	for _, at in ScreenSlashRules.cross() do
		slash(at, glowColor, deepColor)
	end
	ScreenSlashes.flash(SwordSkillFxConfig.SCREEN.hitFlash, glowColor)
end

return ScreenSlashes
