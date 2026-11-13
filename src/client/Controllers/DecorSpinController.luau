--!strict
-- Shop decor's Card Pedestal (spec 2026-11-14-shop-decor-design): its floating card (a part tagged "DecorSpin" by
-- Util/DecorLooks.finish) turns slowly about its own up axis, one turn every Decor.SPIN_SECONDS, on this client only.
-- The card's place is kept relative to its piece's pivot, so a moved pedestal takes its card along. Pedestals further
-- than ShopDetail.SCREEN_DISTANCE from the camera stand still.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Decor = require(Config:WaitForChild("Decor"))
local ShopDetail = require(Config:WaitForChild("ShopDetail"))

local TAG = "DecorSpin"

type Spinner = { piece: Model, offset: CFrame } -- the piece's model and the card's resting place in its pivot's space

local DecorSpinController = {}

local spinners: { [BasePart]: Spinner } = {}

local function add(instance: Instance)
	local piece = instance:FindFirstAncestorOfClass("Model")
	if instance:IsA("BasePart") and piece then
		spinners[instance] = { piece = piece, offset = piece:GetPivot():ToObjectSpace(instance.CFrame) }
	end
end

local function remove(instance: Instance)
	if instance:IsA("BasePart") then
		spinners[instance] = nil
	end
end

local function step()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local angle = (os.clock() / Decor.SPIN_SECONDS % 1) * 2 * math.pi
	for card, spinner in spinners do
		local rest = spinner.piece:GetPivot() * spinner.offset
		if (rest.Position - eye).Magnitude <= ShopDetail.SCREEN_DISTANCE then
			card.CFrame = rest * CFrame.Angles(0, angle, 0)
		end
	end
end

function DecorSpinController.Start()
	for _, instance in CollectionService:GetTagged(TAG) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	RunService.RenderStepped:Connect(step)
end

return DecorSpinController
