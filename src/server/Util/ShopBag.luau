--!strict
-- The shop bag a customer carries out after paying (owner 2026-11-16: "customers that bought something should carry a
-- shopping bag on their way out. shopping bag should have pish and chikin design on them"; Config/Customers BAG).
-- One part with the bag's face picture on both wide sides, three thin rope parts for the handles, welded to the
-- customer's free hand; it hangs from the hand like a bag at your side, turned a little so the picture also shows
-- from behind. It goes with the customer down the street (a town walker) and is taken off if that walker shops again.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CustomerConfig = require(Shared:WaitForChild("Config"):WaitForChild("Customers"))

local ShopBag = {}

local NAME = "ShopBag"
local BAG = CustomerConfig.BAG

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function piece(name: string, size: Vector3, color: Color3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = cframe
	part.Parent = parent
	return part
end

local function weld(part0: BasePart, part1: BasePart)
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = part0
	joint.Part1 = part1
	joint.Parent = part1
end

-- Puts a bag in the customer's hand; `scale` the customer's size (a kid's 0.82). Nothing when it already has one or
-- the rig has no such hand.
function ShopBag.give(model: Model, scale: number)
	if model:FindFirstChild(NAME) then
		return
	end
	local hand = model:FindFirstChild(BAG.hand)
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local width, height, depth = BAG.size[1] * scale, BAG.size[2] * scale, BAG.size[3] * scale
	local handle = BAG.handle
	local thick = handle.thick * scale
	local holder = Instance.new("Model")
	holder.Name = NAME

	-- In the hand's frame: X across the body, so the wide sides (the pictures) face out to the sides, turned `turn`
	local hangFrame = hand.CFrame * CFrame.Angles(0, math.rad(BAG.turn), 0)
	local body = piece("Body", Vector3.new(depth, height, width), rgb(BAG.color), hangFrame * CFrame.new(0, -(BAG.drop * scale + height / 2), 0), holder)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local decal = Instance.new("Decal")
		decal.Texture = BAG.image
		decal.Face = face
		decal.Parent = body
	end

	-- The handles: two cords up from the bag's top and one across, where the hand holds it
	local top = body.CFrame * CFrame.new(0, height / 2, 0)
	local rise = handle.height * scale
	local span = handle.width * scale
	local color = rgb(BAG.handleColor)
	for _, side in { -1, 1 } do
		local cord = piece("Handle", Vector3.new(thick, rise, thick), color, top * CFrame.new(0, rise / 2, side * span / 2), holder)
		weld(body, cord)
	end
	weld(body, piece("Handle", Vector3.new(thick, thick, span + thick), color, top * CFrame.new(0, rise, 0), holder))

	weld(hand, body)
	holder.PrimaryPart = body
	holder.Parent = model
end

function ShopBag.remove(model: Model)
	local bag = model:FindFirstChild(NAME)
	if bag then
		bag:Destroy()
	end
end

return ShopBag
