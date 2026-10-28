--!strict
-- Card inspector: the card as a real 3D card in front of the camera. Drag to tilt it (it eases back when you
-- let go), drag far sideways or press Flip to turn it over. Legendaries keep their element aura, foil its holo.
-- While it's up the camera waits at an empty stage high above the world (Inspector.STAGE_POSITION), with a solid
-- dark sheet just behind the card, so nothing of the world shows (solid: a see-through sheet hides the card's
-- faces). The card's right edge follows the info panel (SetCardRight, UiLayout.inspectorCard); the card view
-- (CardDetailController) puts its Flip button under it (GetCardRect).
local GuiService = game:GetService("GuiService")
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
local UiLayout = require(Shared:WaitForChild("Util"):WaitForChild("UiLayout"))

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
local savedCameraCFrame: CFrame? = nil
local cardRight: number? = nil -- GUI x of the card's right edge (nil: CARD_RIGHT_SHARE of the width)
local cardRect: UiLayout.Rect? = nil -- where the card shows, in GUI pixels (below the top bar inset)
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
	local view = camera.ViewportSize
	-- GUI space starts inside the safe area (top bar, notches): its x and y are inset from the viewport's
	local inset = GuiService:GetGuiInset()
	local right = cardRight
	local offset, rect = UiLayout.inspectorCard(
		{ w = view.X, h = view.Y },
		camera.FieldOfView,
		Inspector.DISTANCE,
		{ w = Inspector.CARD_SIZE.X, h = Inspector.CARD_SIZE.Y },
		Inspector.OFFSET_Y,
		if right then right + inset.X else view.X * Inspector.CARD_RIGHT_SHARE,
		Inspector.MARGIN_PX
	)
	cardRect = { x = rect.x - inset.X, y = rect.y - inset.Y, w = rect.w, h = rect.h }
	local base = camera.CFrame * CFrame.new(offset, Inspector.OFFSET_Y, -Inspector.DISTANCE)
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
-- Tags and bubbles drawn on top of everything (customer moods, pet name tags) would show through the backdrop:
-- they're switched off while the card is up, and back on when it closes
local hiddenTags: { [BillboardGui]: boolean } = {}
local tagWatch: RBXScriptConnection? = nil

local function hideTag(item: Instance)
	if item:IsA("BillboardGui") and item.AlwaysOnTop and item.Enabled then
		hiddenTags[item] = true
		item.Enabled = false
	end
end

local function hideTags()
	for _, item in workspace:GetDescendants() do
		hideTag(item)
	end
	tagWatch = workspace.DescendantAdded:Connect(hideTag)
end

local function showTags()
	if tagWatch then
		tagWatch:Disconnect()
		tagWatch = nil
	end
	for tag in hiddenTags do
		if tag.Parent then
			tag.Enabled = true
		end
	end
	table.clear(hiddenTags)
end

-- A gold ribbon across the lower card face ("BEST COPY"), or none
local function setRibbon(text: string?)
	local old = frontFrame:FindFirstChild("Ribbon")
	if old then
		old:Destroy()
	end
	if not text then
		return
	end
	local ribbon = Instance.new("TextLabel")
	ribbon.Name = "Ribbon"
	ribbon.AnchorPoint = Vector2.new(0.5, 1)
	ribbon.Position = UDim2.fromScale(0.5, 0.74)
	ribbon.Size = UDim2.fromScale(0.62, 0.07)
	ribbon.BackgroundColor3 = Inspector.RIBBON_COLOR
	ribbon.Font = Enum.Font.FredokaOne
	ribbon.Text = text
	ribbon.TextScaled = true
	ribbon.TextColor3 = Color3.new(1, 1, 1)
	ribbon.ZIndex = 20
	ribbon.Parent = frontFrame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ribbon
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = Color3.fromRGB(11, 15, 26)
	edge.Thickness = 10
	edge.Parent = ribbon
	local textEdge = Instance.new("UIStroke")
	textEdge.Color = Color3.fromRGB(11, 15, 26)
	textEdge.Thickness = 6
	textEdge.Parent = ribbon
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.Parent = ribbon
end

-- Where the card's right edge goes (GUI x, like a frame's AbsolutePosition): just left of the info panel
function CardInspectorController.SetCardRight(px: number)
	cardRight = px
end

-- Where the card shows on screen (GUI pixels, below the top bar inset), or nil while closed
function CardInspectorController.GetCardRect(): UiLayout.Rect?
	return if cardPart then cardRect else nil
end

function CardInspectorController.Show(card: Card, foil: boolean, growth: Growth?, ribbon: string?)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if not backdrop then
		buildBackdrop(camera)
		hideTags()
		savedCameraType = camera.CameraType
		savedCameraCFrame = camera.CFrame
		camera.CameraType = Enum.CameraType.Scriptable -- the camera holds still; drags turn the card
		camera.CFrame = CFrame.new(Inspector.STAGE_POSITION) -- away from the world: no customers walk past
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
	local key = `{card.id}:{foil}:{if growth then `{growth.level}:{growth.stars}:{growth.grade}` else ""}:{ribbon or ""}`
	if key == shownKey then
		return
	end
	shownKey = key
	buildCard(camera)
	CardFace.render(frontFrame, frontStroke, card, foil, true, growth)
	setRibbon(ribbon)
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
		showTags()
	end
	local camera = workspace.CurrentCamera
	if camera and savedCameraCFrame then
		camera.CFrame = savedCameraCFrame
	end
	if camera and savedCameraType then
		camera.CameraType = savedCameraType
	end
	savedCameraType = nil
	savedCameraCFrame = nil
	cardRect = nil
	shownKey = ""
	dragging = false
end

return CardInspectorController
