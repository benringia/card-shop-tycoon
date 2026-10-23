--!strict
-- Card inspector: the card as a real 3D card in front of the camera. Drag to tilt it (it eases back when you
-- let go), drag far sideways or press Flip to turn it over. Legendaries keep their element aura, foil its holo.
-- A solid dark sheet just behind the card hides the world (solid: a see-through one hides the card's faces). The binder shows the copies list beside it (BinderController).
-- Local only: the card part lives under the camera, so nobody else sees it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Inspector = require(Config:WaitForChild("Inspector"))
local ElementFx = require(Config:WaitForChild("ElementFx"))
local ElementFxRules = require(Shared:WaitForChild("Util"):WaitForChild("ElementFxRules"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local ElementAura = require(ClientUtil:WaitForChild("ElementAura"))

type Card = typeof(Cards.List[1])
export type Growth = CardFace.Growth

local player = Players.LocalPlayer

local CardInspectorController = {}

local cardPart: Part? = nil
local backdrop: Part? = nil
local frontFrame: Frame
local frontStroke: UIStroke
local renderConnection: RBXScriptConnection? = nil
local inputConnections: { RBXScriptConnection } = {}
local savedCameraType: Enum.CameraType? = nil
local yaw, pitch = 0, 0 -- current tilt (degrees)
local dragYaw, dragPitch = 0, 0 -- what the drag asks for
local flipped = false
local dragging = false
local lastPointer = Vector2.zero
local shownKey = ""

local function surface(part: BasePart, face: Enum.NormalId): (Frame, UIStroke)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = Inspector.FACE_PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Brightness = Inspector.FACE_BRIGHTNESS
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Parent = frame
	return frame, stroke
end

-- A fresh card part per card shown, so the old card's effects (aura, bolts) go with it
local function buildCard(camera: Camera)
	if cardPart then
		cardPart:Destroy()
	end
	local part = Instance.new("Part")
	part.Name = "InspectedCard"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = Inspector.CARD_SIZE
	part.Color = Color3.fromRGB(30, 26, 40)
	part.Parent = camera
	cardPart = part
	frontFrame, frontStroke = surface(part, Enum.NormalId.Front)
	local backFrame, backStroke = surface(part, Enum.NormalId.Back)
	CardFace.renderBack(backFrame, backStroke)
end

local function buildBackdrop(camera: Camera)
	local sheet = Instance.new("Part")
	sheet.Name = "InspectorBackdrop"
	sheet.Anchored = true
	sheet.CanCollide = false
	sheet.CanQuery = false
	sheet.CanTouch = false
	sheet.CastShadow = false
	sheet.Material = Enum.Material.SmoothPlastic
	sheet.Color = Inspector.BACKDROP_COLOR
	sheet.Size = Vector3.new(60, 40, 0.05)
	sheet.Parent = camera
	backdrop = sheet
end

local function onRender(dt: number)
	local camera = workspace.CurrentCamera
	local part = cardPart
	if not camera or not part then
		return
	end
	-- Ease towards the drag (or back to rest), with the flip adding a half turn
	local targetYaw = (if dragging then dragYaw else 0) + (if flipped then 180 else 0)
	local targetPitch = if dragging then dragPitch else 0
	local blend = math.clamp(dt * Inspector.RETURN_SPEED, 0, 1)
	yaw += (targetYaw - yaw) * blend
	pitch += (targetPitch - pitch) * blend
	local base = camera.CFrame * CFrame.new(Inspector.OFFSET_X, 0, -Inspector.DISTANCE)
	-- Face the camera (the part's front, -Z, points back at it), then tilt
	part.CFrame = base * CFrame.Angles(math.rad(pitch), math.rad(yaw + 180), 0)
	local sheet = backdrop
	if sheet then
		sheet.CFrame = camera.CFrame * CFrame.new(0, 0, -(Inspector.DISTANCE + Inspector.BACKDROP_GAP))
	end
end

-- The binder's full-screen panel counts every click as handled UI, so instead a drag starts anywhere except
-- over a button or a scrolling list (the info panel's rows and buttons)
local function overControls(position: Vector3): boolean
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end
	for _, item in playerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
		if item:IsA("GuiButton") or item:IsA("ScrollingFrame") or item:IsA("TextBox") then
			return true
		end
	end
	return false
end

local function onInputBegan(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if overControls(input.Position) then
			return
		end
		lastPointer = Vector2.new(input.Position.X, input.Position.Y)
		dragging = true
		dragYaw, dragPitch = 0, 0
	end
end

local function onInputChanged(input: InputObject)
	if not dragging then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		-- Sideways turns freely (far enough flips it on release); up/down tilts at most MAX_TILT
		local pointer = Vector2.new(input.Position.X, input.Position.Y)
		local delta = pointer - lastPointer
		lastPointer = pointer
		dragYaw = math.clamp(dragYaw + delta.X * Inspector.DRAG_DEGREES_PER_PIXEL, -180, 180)
		dragPitch = math.clamp(dragPitch - delta.Y * Inspector.DRAG_DEGREES_PER_PIXEL, -Inspector.MAX_TILT, Inspector.MAX_TILT)
	end
end

local function onInputEnded(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if dragging and math.abs(dragYaw) >= Inspector.FLIP_DRAG then
		flipped = not flipped
	end
	dragging = false
end

function CardInspectorController.IsOpen(): boolean
	return backdrop ~= nil
end

-- Shows this card (and copy) in the inspector, opening it if needed
function CardInspectorController.Show(card: Card, foil: boolean, growth: Growth?)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if not backdrop then
		buildBackdrop(camera)
		savedCameraType = camera.CameraType
		camera.CameraType = Enum.CameraType.Scriptable -- the camera holds still; drags turn the card
		yaw, pitch, flipped = 0, 0, false
		renderConnection = RunService.RenderStepped:Connect(onRender)
		table.insert(inputConnections, UserInputService.InputBegan:Connect(onInputBegan))
		table.insert(inputConnections, UserInputService.InputChanged:Connect(onInputChanged))
		table.insert(inputConnections, UserInputService.InputEnded:Connect(onInputEnded))
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			table.insert(inputConnections, humanoid.Died:Connect(CardInspectorController.Close))
		end
	end
	local key = `{card.id}:{foil}:{if growth then `{growth.level}:{growth.stars}:{growth.grade}` else ""}`
	if key == shownKey then
		return
	end
	shownKey = key
	buildCard(camera)
	CardFace.render(frontFrame, frontStroke, card, foil, true, growth)
	local part = cardPart :: Part
	-- Legendaries keep their element aura
	if card.rarity == "Legendary" then
		local intensity = ElementFxRules.intensity(
			ElementFx.INTENSITY,
			if growth then growth.grade else "C",
			if growth then growth.stars else 0
		)
		ElementAura.attach(part, card.element, intensity)
	end
end

function CardInspectorController.Flip()
	flipped = not flipped
end

function CardInspectorController.Close()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	for _, connection in inputConnections do
		connection:Disconnect()
	end
	table.clear(inputConnections)
	if cardPart then
		cardPart:Destroy()
		cardPart = nil
	end
	if backdrop then
		backdrop:Destroy()
		backdrop = nil
	end
	local camera = workspace.CurrentCamera
	if camera and savedCameraType then
		camera.CameraType = savedCameraType
	end
	savedCameraType = nil
	shownKey = ""
	dragging = false
end

return CardInspectorController
