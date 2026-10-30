--!strict
-- The Portal Worlds way-finding pieces, built from parts (Portal Worlds spec): wooden signposts with arrow-shaped arms
-- naming each portal in its colour ("This way" under each name), and a wooden arch over each trail where it leaves the
-- island. Their words stop drawing beyond Town.SIGN_DISTANCE. TownService places them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Town = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Town"))

local TrailProps = {}

export type Arm = { text: string, sub: string, color: Color3, yaw: number }

local POST_COLOR = Color3.fromRGB(122, 81, 40)
local BOARD_COLOR = Color3.fromRGB(168, 116, 63)
local LANTERN_COLOR = Color3.fromRGB(255, 200, 120)
local POST_HEIGHT = 7.5
local ARM = { LENGTH = 4.2, HEIGHT = 1.1, THICKNESS = 0.25, TOP = 6.4, STEP = 1.4 }
local ARCH = { HEIGHT = 9, POST = 0.9, BOARD_HEIGHT = 1.8 }

local function piece(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- Words on both faces of a board: the name glowing in its colour, an optional smaller line under it
local function words(board: BasePart, text: string, sub: string?, color: Color3)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(board.Size.X * 60, board.Size.Y * 60)
		gui.LightInfluence = 0
		gui.MaxDistance = Town.SIGN_DISTANCE
		gui.Parent = board
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromScale(0.06, 0.08)
		name.Size = UDim2.fromScale(0.82, if sub then 0.58 else 0.84)
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.45)
		name.TextStrokeColor3 = color
		name.TextStrokeTransparency = 0.2
		name.Text = text
		name.Parent = gui
		if sub then
			local small = Instance.new("TextLabel")
			small.BackgroundTransparency = 1
			small.Position = UDim2.fromScale(0.06, 0.64)
			small.Size = UDim2.fromScale(0.82, 0.3)
			small.Font = Enum.Font.FredokaOne
			small.TextScaled = true
			small.TextColor3 = Color3.fromRGB(255, 246, 225)
			small.Text = sub
			small.Parent = gui
		end
	end
end

-- A post with one arrow-shaped arm per entry, stacked from the top; each arm points along its yaw
-- (TownLayout's convention: the direction a model's front would face)
function TrailProps.signpost(parent: Instance, at: CFrame, arms: { Arm }): Model
	local model = Instance.new("Model")
	model.Name = "Signpost"
	piece(model, "Post", Vector3.new(0.6, POST_HEIGHT, 0.6), at * CFrame.new(0, POST_HEIGHT / 2, 0), POST_COLOR, Enum.Material.Wood)
	piece(model, "Cap", Vector3.new(0.9, 0.3, 0.9), at * CFrame.new(0, POST_HEIGHT + 0.15, 0), POST_COLOR, Enum.Material.Wood)
	for index, arm in arms do
		-- The board's long side (X) turned toward the target: a model facing `yaw` has its +X at yaw + 90
		local turn = at * CFrame.new(0, ARM.TOP - (index - 1) * ARM.STEP, 0) * CFrame.Angles(0, math.rad(arm.yaw + 90), 0)
		local board = piece(model, "Arm", Vector3.new(ARM.LENGTH, ARM.HEIGHT, ARM.THICKNESS), turn * CFrame.new(ARM.LENGTH / 2 + 0.3, 0, 0), BOARD_COLOR, Enum.Material.Wood)
		-- The point: a square turned 45 degrees, half of it past the board's end
		local side = ARM.HEIGHT / math.sqrt(2)
		piece(model, "Tip", Vector3.new(side, side, ARM.THICKNESS), turn * CFrame.new(ARM.LENGTH + 0.3, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), BOARD_COLOR, Enum.Material.Wood)
		words(board, arm.text, arm.sub, arm.color)
	end
	model.Parent = parent
	return model
end

-- An arch over a trail `width` wide; `at` stands on the trail's middle with its front (-Z) facing along the trail
function TrailProps.arch(parent: Instance, at: CFrame, name: string, color: Color3, width: number): Model
	local model = Instance.new("Model")
	model.Name = "TrailArch"
	local half = width / 2 + ARCH.POST
	for _, side in { -1, 1 } do
		piece(model, "Post", Vector3.new(ARCH.POST, ARCH.HEIGHT, ARCH.POST), at * CFrame.new(side * half, ARCH.HEIGHT / 2, 0), POST_COLOR, Enum.Material.Wood)
		local lantern = piece(model, "Lantern", Vector3.new(0.6, 0.8, 0.6), at * CFrame.new(side * (half - 1), ARCH.HEIGHT - 2.2, 0), LANTERN_COLOR, Enum.Material.Neon)
		lantern.CanCollide = false
		lantern.CastShadow = false
	end
	piece(model, "Beam", Vector3.new(width + ARCH.POST * 4, 0.8, ARCH.POST + 0.2), at * CFrame.new(0, ARCH.HEIGHT + 0.4, 0), POST_COLOR, Enum.Material.Wood)
	local board = piece(model, "NameBoard", Vector3.new(width - 1, ARCH.BOARD_HEIGHT, 0.3), at * CFrame.new(0, ARCH.HEIGHT - 1.2, 0), BOARD_COLOR, Enum.Material.Wood)
	board.CanCollide = false
	words(board, string.upper(name), nil, color)
	model.Parent = parent
	return model
end

return TrailProps
