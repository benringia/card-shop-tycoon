--!strict
-- The prologue's stage (spec 2026-11-14-prologue-hydra-design; Config/Prologue): the Hydra's crystal lair built on this
-- client only, high above the world where the server put this player's (PrologueService; a dark stone floor, the
-- Dungeon's sigil, pillars and crystals in a ring, night lighting and fog), the character moved onto it and held still
-- while the cinematics play, every other screen off (back on for the fight: `screens`), the prologue's own overlay
-- (cinema bars, captions, a fade, a Skip button). `home` takes the lair and its lighting away and brings the character
-- back to its shop's door (in the dark, for the wake-up), `leave` puts everything else back and stands the character
-- there (or where it got up).
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Prologue = require(Config:WaitForChild("Prologue"))
local PlotConfig = require(Config:WaitForChild("Plots"))
local SkyLook = require(Shared:WaitForChild("Util"):WaitForChild("SkyLook"))

local ClientUtil = script.Parent :: Instance
local UIKit = require(ClientUtil:WaitForChild("UIKit"))

local PrologueStage = {}

export type Stage = {
	arena: Model,
	gui: ScreenGui,
	centre: Vector3, -- the middle of the floor, on its top
	spot: (name: string) -> CFrame,
	screens: (on: boolean) -> (),
	caption: (text: string, seconds: number, big: boolean?) -> (),
	bars: (on: boolean) -> (),
	skipButton: (onSkip: () -> ()) -> (),
	fade: (toBlack: boolean, seconds: number, white: boolean?) -> (),
	hold: (still: boolean) -> (),
	home: () -> CFrame?,
	leave: (standAt: CFrame?) -> (),
}

local player = Players.LocalPlayer
local ARENA = Prologue.ARENA
local BAR_SHARE = 0.11

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local made = Instance.new("Part")
	made.Name = name
	made.Anchored = true
	made.Size = size
	made.CFrame = cframe
	made.Color = color
	made.Material = material
	made.TopSurface = Enum.SurfaceType.Smooth
	made.BottomSurface = Enum.SurfaceType.Smooth
	made.CastShadow = false
	made.Parent = parent
	return made
end

-- A prop model from PropModels (the Dungeon pack), anchored, standing on `at`, scaled by `scale`
local function prop(parent: Instance, name: string, at: CFrame, scale: number): Model?
	local models = ReplicatedStorage:FindFirstChild("PropModels")
	local source = models and models:FindFirstChild(name)
	if not source or not source:IsA("Model") then
		return nil
	end
	local copy = source:Clone()
	for _, item in copy:GetDescendants() do
		if item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
	copy:ScaleTo(copy:GetScale() * scale)
	copy:PivotTo(at)
	local box, size = copy:GetBoundingBox()
	copy:PivotTo(copy:GetPivot() + Vector3.new(0, at.Position.Y - (box.Position.Y - size.Y / 2), 0))
	copy.Parent = parent
	return copy
end

-- The lair: floor, rune circle, a ring of pillars and crystals, a cold light
local function buildArena(centre: Vector3): Model
	local arena = Instance.new("Model")
	arena.Name = "PrologueLair"
	local radius = ARENA.radius
	local floor = part(arena, "Floor", Vector3.new(4, (radius + ARENA.rim) * 2, (radius + ARENA.rim) * 2), CFrame.new(centre - Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(38, 36, 58), Enum.Material.Slate)
	floor.Shape = Enum.PartType.Cylinder
	local glow = part(arena, "RuneRing", Vector3.new(0.2, radius * 1.3, radius * 1.3), CFrame.new(centre + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 110, 255), Enum.Material.Neon)
	glow.Shape = Enum.PartType.Cylinder
	glow.CanCollide = false
	glow.Transparency = 0.82
	prop(arena, "DungeonSigil", CFrame.new(centre + Vector3.new(0, 0.12, 0)), radius * 1.2 / 16.8)
	local pieces = { "DungeonPillar", "DungeonCrystals", "DungeonPillarBroken", "CrystalPylon", "DungeonPillar", "ElementCrystal", "DungeonPillar", "DungeonCrystals" }
	for index = 1, 16 do
		local angle = (index - 0.5) / 16 * math.pi * 2
		local at = centre + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius + 6 + (index % 3) * 4)
		local name = pieces[(index - 1) % #pieces + 1]
		local scale = if string.find(name, "Pillar") then 1.6 + (index % 2) * 0.5 else 1.8 + (index % 3) * 0.4
		local made = prop(arena, name, CFrame.lookAt(at, centre) * CFrame.Angles(0, math.rad(index * 37), 0), scale)
		if not made then
			local spike = part(arena, "Crystal", Vector3.new(3, 10 + (index % 3) * 4, 3), CFrame.new(at + Vector3.new(0, 5, 0)) * CFrame.Angles(0, angle, math.rad(10)), Color3.fromRGB(140, 120, 255), Enum.Material.Neon)
			spike.CanCollide = false
		end
	end
	local holder = part(arena, "Light", Vector3.new(1, 1, 1), CFrame.new(centre + Vector3.new(0, 40, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(170, 150, 255)
	light.Range = 60
	light.Brightness = 1.5
	light.Shadows = false
	light.Parent = holder
	arena.Parent = workspace
	return arena
end

-- Night in the lair; returns how to put the lighting back
local function nightLighting(): () -> ()
	SkyLook.hold(true)
	local saved = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
		FogColor = Lighting.FogColor,
		ExposureCompensation = Lighting.ExposureCompensation,
	}
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local savedDensity = if atmosphere then atmosphere.Density else nil
	local savedHaze = if atmosphere then atmosphere.Haze else nil
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.4
	Lighting.Ambient = Color3.fromRGB(70, 60, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(90, 80, 140)
	Lighting.ExposureCompensation = 0.2
	Lighting.FogColor = Color3.fromRGB(30, 22, 60)
	Lighting.FogStart = 60
	Lighting.FogEnd = 260
	if atmosphere then
		atmosphere.Density = 0.45
		atmosphere.Haze = 2
	end
	return function()
		for key, value in saved do
			(Lighting :: any)[key] = value
		end
		if atmosphere and savedDensity and savedHaze then
			atmosphere.Density = savedDensity
			atmosphere.Haze = savedHaze
		end
		SkyLook.hold(false)
	end
end

-- Your shop's door (the middle of its street side), where you wake up
local function shopDoor(): CFrame?
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
			local floor = plot:FindFirstChild("Floor")
			if floor and floor:IsA("BasePart") then
				local outward = Vector3.new(floor.CFrame.LookVector.X, 0, floor.CFrame.LookVector.Z).Unit
				local door = floor.Position + outward * (PlotConfig.DEPTH / 2 - 4) + Vector3.new(0, 4, 0)
				return CFrame.lookAt(door, door + outward)
			end
		end
	end
	return nil
end

-- `centre`: this player's lair (Remotes.PrologueArena)
function PrologueStage.enter(centre: Vector3): Stage
	local arena = buildArena(centre)
	local restoreLighting = nightLighting()

	local gui = Instance.new("ScreenGui")
	gui.Name = "Prologue"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 55
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	local hidden: { ScreenGui } = {}
	local function hideScreens()
		for _, other in player.PlayerGui:GetChildren() do
			if other:IsA("ScreenGui") and other ~= gui and other.Enabled then
				other.Enabled = false
				table.insert(hidden, other)
			end
		end
	end
	local function showScreens()
		for _, other in hidden do
			if other.Parent then
				other.Enabled = true
			end
		end
		table.clear(hidden)
	end
	hideScreens()
	local touch = GuiService.TouchControlsEnabled
	GuiService.TouchControlsEnabled = false

	local barFrames: { Frame } = {}
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0, if top then 0 else 1)
		bar.Position = UDim2.fromScale(0, if top then 0 else 1)
		bar.Size = UDim2.fromScale(1, BAR_SHARE)
		bar.ZIndex = 20
		bar.Parent = gui
		table.insert(barFrames, bar)
	end
	local cover = Instance.new("Frame")
	cover.Name = "Fade"
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BorderSizePixel = 0
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundTransparency = 0
	cover.ZIndex = 40
	cover.Parent = gui
	local captionLabel = UIKit.label(gui, "", Enum.Font.FredokaOne, 34, Color3.new(1, 1, 1))
	captionLabel.AnchorPoint = Vector2.new(0.5, 1)
	captionLabel.Position = UDim2.new(0.5, 0, 1 - BAR_SHARE, -16)
	captionLabel.Size = UDim2.new(0.9, 0, 0, 48)
	captionLabel.TextScaled = true
	captionLabel.TextXAlignment = Enum.TextXAlignment.Center
	captionLabel.TextTransparency = 1
	captionLabel.ZIndex = 45
	local captionEdge = UIKit.outlined(captionLabel, 2)
	captionEdge.Transparency = 1 -- fades with the words (else it stays as hollow letters)
	local captionToken = 0

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local walk, jump, jumpHeight = 16, 50, 7.2
	if humanoid then
		walk, jump, jumpHeight = humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight
	end
	local you = Vector3.new(ARENA.player[1], ARENA.player[2], ARENA.player[3])
	local foe = Vector3.new(ARENA.hydra[1], ARENA.hydra[2], ARENA.hydra[3])
	local spots: { [string]: CFrame } = {
		player = CFrame.lookAt(centre + you, centre + Vector3.new(foe.X, you.Y, foe.Z)),
		hydra = CFrame.lookAt(centre + foe, centre + Vector3.new(you.X, foe.Y, you.Z)),
	}
	local home = if character then character:GetPivot() else nil -- where you stood: back there if you have no shop
	if character then
		character:PivotTo(spots.player)
	end

	local left = false
	local homed: CFrame? = nil -- where `home` brought you (your shop's door)
	local skip: TextButton? = nil
	local fighting = false -- the fight's own HUD is up: no Skip over its buttons
	local held = false
	local holding: RBXScriptConnection? = nil
	local stage: Stage
	stage = {
		arena = arena,
		gui = gui,
		centre = centre,
		spot = function(name: string): CFrame
			return spots[name] or CFrame.new(centre)
		end,
		screens = function(on: boolean)
			if left then
				return
			end
			fighting = on
			if skip then
				skip.Visible = not on
			end
			if on then
				showScreens()
			else
				hideScreens()
			end
		end,
		caption = function(text: string, seconds: number, big: boolean?)
			captionToken += 1
			local token = captionToken
			captionLabel.Text = text
			captionLabel.Position = if big then UDim2.fromScale(0.5, 0.5) else UDim2.new(0.5, 0, 1 - BAR_SHARE, -16)
			captionLabel.AnchorPoint = if big then Vector2.new(0.5, 0.5) else Vector2.new(0.5, 1)
			captionLabel.Size = if big then UDim2.new(0.8, 0, 0, 110) else UDim2.new(0.9, 0, 0, 48)
			TweenService:Create(captionLabel, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
			TweenService:Create(captionEdge, TweenInfo.new(0.35), { Transparency = 0 }):Play()
			task.delay(seconds, function()
				if token == captionToken and captionLabel.Parent then
					TweenService:Create(captionLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
					TweenService:Create(captionEdge, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				end
			end)
		end,
		bars = function(on: boolean)
			for index, bar in barFrames do
				local top = index == 1
				TweenService:Create(bar, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
					Position = if on then UDim2.fromScale(0, if top then 0 else 1) else UDim2.fromScale(0, if top then -BAR_SHARE else 1 + BAR_SHARE),
				}):Play()
			end
		end,
		skipButton = function(onSkip: () -> ())
			task.delay(Prologue.SKIP_AFTER, function()
				if left then
					return
				end
				local made = UIKit.button(gui, "Skip", Color3.fromRGB(40, 44, 58))
				skip = made
				made.Visible = not fighting
				made.Name = "Skip"
				made.AnchorPoint = Vector2.new(1, 0)
				made.Position = UDim2.new(1, -16, BAR_SHARE, 12)
				made.Size = UDim2.fromOffset(120, 52)
				made.TextColor3 = Color3.new(1, 1, 1)
				made.Font = Enum.Font.FredokaOne
				made.TextSize = 24
				made.ZIndex = 50
				made.Activated:Connect(onSkip)
			end)
		end,
		fade = function(toBlack: boolean, seconds: number, white: boolean?)
			cover.BackgroundColor3 = if white then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
			TweenService:Create(cover, TweenInfo.new(seconds), { BackgroundTransparency = if toBlack then 0 else 1 }):Play()
		end,
		hold = function(still: boolean)
			if left then
				return -- already put back (a late call from a fight that was skipped)
			end
			held = still
			if holding then
				holding:Disconnect()
				holding = nil
			end
			if humanoid and humanoid.Parent then
				humanoid.WalkSpeed = if still then 0 else walk
				humanoid.JumpPower = if still then 0 else jump
				humanoid.JumpHeight = if still then 0 else jumpHeight
				if still then
					-- the server sets walk speed too (a summon's Hustle, a fight's end): still means still
					local h = humanoid
					holding = h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
						if held and h.WalkSpeed ~= 0 then
							h.WalkSpeed = 0
						end
					end)
				end
			end
			if root and root.Parent then
				root.AssemblyLinearVelocity = Vector3.zero
			end
			GuiService.TouchControlsEnabled = touch and not still -- the phone's thumbstick: walk out of the rings in the fight
		end,
		home = function(): CFrame?
			if homed or left then
				return homed
			end
			arena:Destroy()
			restoreLighting()
			local door = shopDoor() or home
			if door then
				-- the town round it may have streamed out while you were up in the lair: in first, so you never drop
				-- through a missing floor
				pcall(function()
					player:RequestStreamAroundAsync(door.Position, 4)
				end)
				local now = player.Character
				if now then
					now:PivotTo(door)
				end
			end
			homed = door
			return door
		end,
		leave = function(standAt: CFrame?)
			if left then
				return
			end
			local door = stage.home()
			stage.hold(false)
			left = true
			gui:Destroy()
			showScreens()
			GuiService.TouchControlsEnabled = touch and not UIKit.anyPanelOpen()
			local camera = workspace.CurrentCamera
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = 70
			local now = player.Character
			local nowHumanoid = if now then now:FindFirstChildOfClass("Humanoid") else nil
			if nowHumanoid then
				camera.CameraSubject = nowHumanoid
			end
			local at = standAt or door
			if now and at then
				now:PivotTo(at)
				-- the camera behind you again (it was left wherever the last cinematic shot was)
				camera.CFrame = CFrame.lookAt(at.Position - at.LookVector * 12 + Vector3.new(0, 5, 0), at.Position)
			end
		end,
	}
	stage.hold(true)
	return stage
end

return PrologueStage
