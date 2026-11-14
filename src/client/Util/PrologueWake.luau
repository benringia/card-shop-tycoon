--!strict
-- The prologue's wake-up (owner 2026-11-15: "in the town, I slowly open my eyes and see Chikin and Pish waking me up";
-- Config/Prologue WAKE): you lie on your back on the street in front of your shop, your head toward it; Pish and
-- Chikin stand over you (their own models, Util/PishVisual, drawn on this screen only); the camera is your eyes,
-- looking up at them; your eyelids (two soft black lids on the prologue's screen) open with a blink between
-- (PrologueRules.lids) while the blur clears; their lines pop up in speech cards with their faces. PrologueController
-- runs its timing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Prologue = require(Config:WaitForChild("Prologue"))
local LoadingScreen = require(Config:WaitForChild("LoadingScreen"))
local Pish = require(Config:WaitForChild("Pish"))
local PrologueRules = require(Shared:WaitForChild("Util"):WaitForChild("PrologueRules"))

local ClientUtil = script.Parent :: Instance
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local PishVisual = require(ClientUtil:WaitForChild("PishVisual"))
local PrologueBody = require(ClientUtil:WaitForChild("PrologueBody"))

local PrologueWake = {}

export type Wake = {
	lying: CFrame, -- your root lying on your back
	standing: CFrame, -- your root once you're up, facing the dogs and your shop
	eye: (t: number) -> CFrame, -- the camera: your eyes looking up at them
	step: (t: number, dt: number) -> (),
	play: (dog: string, clip: string) -> (),
	say: (dog: string, text: string, seconds: number) -> (),
	getUp: () -> (), -- your head and what you wear back, the dogs standing up straight facing you
	destroy: () -> (),
}

local WAKE = Prologue.WAKE
local KNOCK = Prologue.KNOCK
local OUT = 12 -- studs out from your shop's door: you and the dogs all on the street
local SOFT = 0.15 -- the lids' soft edge (share of the screen's height)

-- Each dog's face: its first painted card on the loading screen's binder (Config/LoadingScreen DOG_CARDS)
local function faces(): { [string]: string }
	local found: { [string]: string } = {}
	for _, card in LoadingScreen.DOG_CARDS do
		found[card.dog] = found[card.dog] or card.image
	end
	return found
end

-- The floor's height under `at` (the street), or `fallback`
local function floorAt(at: Vector3, ignore: { Instance }, fallback: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(at + Vector3.new(0, 6, 0), Vector3.new(0, -24, 0), params)
	return if hit then hit.Position.Y else fallback
end

local function lid(gui: ScreenGui, top: boolean): Frame
	local frame = Instance.new("Frame")
	frame.Name = if top then "LidTop" else "LidBottom"
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(0, if top then 0 else 1)
	frame.Size = UDim2.fromScale(1, 0.5 + SOFT)
	frame.ZIndex = 41
	frame.Parent = gui
	-- black, fading out over its inner edge
	local edge = Instance.new("UIGradient")
	edge.Rotation = if top then 90 else -90
	local solid = 0.5 / (0.5 + SOFT)
	edge.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(solid, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	edge.Parent = frame
	return frame
end

-- `door`: your shop's door (PrologueStage.home); `gui`: the prologue's screen; `character`: yours
function PrologueWake.new(gui: ScreenGui, character: Model, door: CFrame): Wake
	local outward = Vector3.new(door.LookVector.X, 0, door.LookVector.Z)
	outward = if outward.Magnitude > 0.01 then outward.Unit else Vector3.zAxis
	local toShop = -outward
	local spot = door.Position + outward * OUT
	local floor = floorAt(spot, { character }, door.Position.Y - 3)
	local ground = Vector3.new(spot.X, floor, spot.Z)
	local right = toShop:Cross(Vector3.yAxis)
	local lying = PrologueBody.onBack(ground + Vector3.new(0, KNOCK.lie, 0), toShop)
	local head = ground + toShop * 1.6 + Vector3.new(0, 0.6, 0)
	local standing = CFrame.lookAt(Vector3.new(spot.X, door.Position.Y, spot.Z), Vector3.new(spot.X, door.Position.Y, spot.Z) + toShop)

	-- the dogs past your head, one each side, looking down at you
	local dogs: { [string]: PishVisual.Visual } = {}
	local markers: { BasePart } = {}
	for index, name in { "Pish", "Chikin" } do
		local side = if index == 1 then -1 else 1
		local at = ground + toShop * (1.6 + WAKE.beyond) + right * side * WAKE.side
		local marker = Instance.new("Part")
		marker.Name = `Wake{name}`
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.Transparency = 1
		marker.Size = Vector3.new(2, 2, 2)
		-- leaning in over you, nose down (the dog tips about its feet)
		marker.CFrame = CFrame.lookAt(at, Vector3.new(head.X, at.Y, head.Z)) * CFrame.Angles(-math.rad(WAKE.lean), 0, 0)
		marker.Parent = workspace
		table.insert(markers, marker)
		local visual = PishVisual.new(marker, name)
		if visual then
			dogs[name] = visual
		end
	end
	-- the camera sits in your head: your head and what's on it hidden on this screen (their own Transparency, put back
	-- after: the camera's fading resets LocalTransparencyModifier on anything in the character)
	local hidden: { [BasePart]: number } = {}
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") and (item.Name == "Head" or item:FindFirstAncestorWhichIsA("Accessory")) then
			hidden[item] = item.Transparency
			item.Transparency = 1
		end
	end
	local function showYou()
		for part, transparency in hidden do
			if part.Parent then
				part.Transparency = transparency
			end
		end
		table.clear(hidden)
	end
	local faceHeight = Pish.HEIGHT * 0.8
	-- a little over their heads, so they peer down into view rather than fill it
	local lookAt = ground + toShop * (1.6 + WAKE.beyond) + Vector3.new(0, faceHeight + 0.9, 0)

	local camera = workspace.CurrentCamera
	local blur = Instance.new("BlurEffect")
	blur.Name = "PrologueWakeBlur"
	blur.Size = WAKE.blur
	blur.Parent = camera
	local top, bottom = lid(gui, true), lid(gui, false)
	local reach = 0.5 + SOFT
	local function setLids(open: number)
		top.Position = UDim2.fromScale(0, -reach * open)
		bottom.Position = UDim2.fromScale(0, 1 + reach * open)
		blur.Size = WAKE.blur * (1 - open)
	end
	setLids(0)
	local dogFaces = faces()
	local bubble: Frame? = nil

	local wake: Wake = {
		lying = lying,
		standing = standing,
		eye = function(t: number): CFrame
			-- a slow, dazed sway that settles as you come to
			local daze = math.max(0, 1 - t / 8)
			local roll = math.sin(t * 0.9) * math.rad(6) * daze
			return CFrame.lookAt(head, lookAt + right * math.sin(t * 0.6) * 0.4 * daze) * CFrame.Angles(0, 0, roll)
		end,
		step = function(t: number, dt: number)
			setLids(PrologueRules.lids(t, Prologue))
			for _, visual in dogs do
				PishVisual.step(visual, dt)
			end
		end,
		play = function(dog: string, clip: string)
			local visual = dogs[dog]
			if visual then
				PishVisual.play(visual, clip)
			end
		end,
		say = function(dog: string, text: string, seconds: number)
			if bubble then
				bubble:Destroy()
			end
			local card = Instance.new("Frame")
			card.Name = "WakeLine"
			card.AnchorPoint = Vector2.new(0.5, 1)
			card.Position = UDim2.new(0.5, 0, 1, -40)
			card.Size = UDim2.new(0.9, 0, 0, 92)
			card.BackgroundColor3 = Color3.fromRGB(255, 248, 232)
			card.ZIndex = 46
			card.Parent = gui
			bubble = card
			UIKit.corner(card, 26)
			local limit = Instance.new("UISizeConstraint")
			limit.MaxSize = Vector2.new(520, 92)
			limit.Parent = card
			local edge = Instance.new("UIStroke")
			edge.Color = Color3.fromRGB(255, 190, 90)
			edge.Thickness = 3
			edge.Parent = card
			local face = Instance.new("ImageLabel")
			face.BackgroundTransparency = 1
			face.Image = dogFaces[dog] or ""
			face.Position = UDim2.fromOffset(8, 6)
			face.Size = UDim2.fromOffset(80, 80)
			face.ScaleType = Enum.ScaleType.Crop
			face.ZIndex = 47
			face.Parent = card
			UIKit.corner(face, 18)
			local who = UIKit.label(card, dog, Enum.Font.FredokaOne, 18, Color3.fromRGB(230, 120, 40))
			who.Position = UDim2.fromOffset(100, 10)
			who.Size = UDim2.new(1, -110, 0, 22)
			who.ZIndex = 47
			local said = UIKit.label(card, text, Enum.Font.FredokaOne, 24, Color3.fromRGB(59, 42, 82))
			said.Position = UDim2.fromOffset(100, 34)
			said.Size = UDim2.new(1, -110, 0, 50)
			said.TextWrapped = true
			said.TextScaled = true
			said.ZIndex = 47
			local size = Instance.new("UITextSizeConstraint")
			size.MaxTextSize = 24
			size.Parent = said
			local scale = Instance.new("UIScale")
			scale.Scale = 0.5
			scale.Parent = card
			TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			task.delay(seconds, function()
				if bubble == card then
					card:Destroy()
					bubble = nil
				end
			end)
		end,
		getUp = function()
			showYou()
			-- they step out to either side in front of you, standing straight, so you see them over your shoulder
			for index, marker in markers do
				local side = if index == 1 then -1 else 1
				local at = ground + toShop * 2.6 + right * side * 2.8
				marker.CFrame = CFrame.lookAt(at, Vector3.new(spot.X, at.Y, spot.Z))
			end
		end,
		destroy = function()
			for _, visual in dogs do
				PishVisual.destroy(visual)
			end
			for _, marker in markers do
				marker:Destroy()
			end
			blur:Destroy()
			showYou()
			top:Destroy()
			bottom:Destroy()
			if bubble then
				bubble:Destroy()
			end
		end,
	}
	return wake
end

return PrologueWake
