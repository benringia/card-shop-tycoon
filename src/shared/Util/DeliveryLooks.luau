--!strict
-- The delivery boxes' models (owner 2026-11-14; tools/blender/build_delivery_props.py, Config/Products boxProp): their
-- stickers wear the product's icon. A box model has a Picture part on its front and a PictureBack on its back, each its
-- own part (a decal covers its part's whole face).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UIIcons"))

local DeliveryLooks = {}

local STICKER_FACES = { Picture = Enum.NormalId.Front, PictureBack = Enum.NormalId.Back }

-- The product's own icon (Config/Products icon, UIIcons) on a box model's stickers
function DeliveryLooks.finishBox(model: Instance, icon: string?)
	local image = if icon then UIIcons[icon] else nil
	if not image then
		return
	end
	for _, part in model:GetDescendants() do
		local face = STICKER_FACES[part.Name]
		if part:IsA("BasePart") and face then
			local sticker = Instance.new("Decal")
			sticker.Texture = image
			sticker.Face = face
			sticker.Parent = part
		end
	end
end

return DeliveryLooks
