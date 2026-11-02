--!strict
-- A boss's big-attack warning, look B "closing ring" (spec 2026-11-02-you-in-the-fight-design): a thin white outline
-- of the area on the ground and a glowing ring closing onto it (RingRules.closingScale), then a white flash as it
-- lands. A slam is a circle; a swipe a cone from the boss, the glow shrinking toward its point. Two flat parts with
-- decals per ring, on the ground under it; the server sends the shape (BattleService places it).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SwordFx = require(Shared:WaitForChild("Config"):WaitForChild("SwordFx"))
local RingRules = require(Shared:WaitForChild("Util"):WaitForChild("RingRules"))

local RingFx = {}

export type Ring = { shape: string, x: number, y: number, z: number, dirX: number, dirZ: number, radius: number, length: number, halfAngle: number, warning: number }

local function folder(): Folder
	local existing = workspace:FindFirstChild("BossRings")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = "BossRings"
	made.Parent = workspace
	return made
end

-- The ground under a point (characters and monsters ignored), else 3 studs under it (a character's root height)
local function groundY(x: number, y: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { folder() }
	for _, name in { "Monsters", "AfterImages", "Creatures" } do
		local item = workspace:FindFirstChild(name)
		if item then
			table.insert(ignore, item)
		end
	end
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(x, y + 3, z), Vector3.new(0, -SwordFx.RING_GROUND_RAY, 0), params)
	return if hit then hit.Position.Y else y - 3
end

local function flat(image: string, transparency: number): (Part, Decal)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 0.05, 1)
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = image
	decal.Color3 = Color3.fromRGB(SwordFx.RING_COLOR[1], SwordFx.RING_COLOR[2], SwordFx.RING_COLOR[3])
	decal.Transparency = transparency
	decal.Parent = part
	part.Parent = folder()
	return part, decal
end

-- Where a piece of the ring goes at `scale` times the area: a circle round its centre, a cone from its point
local function placer(ring: Ring, y: number): (part: Part, fit: number, scale: number) -> ()
	if ring.shape == "swipe" then
		local direction = Vector3.new(ring.dirX, 0, ring.dirZ)
		direction = if direction.Magnitude > 0.01 then direction.Unit else Vector3.new(0, 0, -1)
		local apex = Vector3.new(ring.x, y, ring.z)
		local width = 2 * ring.length * math.sin(math.rad(ring.halfAngle))
		return function(part: Part, fit: number, scale: number)
			local length = ring.length * fit * scale
			local centre = apex + direction * (length / 2)
			part.Size = Vector3.new(width * fit * scale, 0.05, length)
			-- the texture's point (its top edge) lands on the part's +Z side (checked in Studio): face +Z back toward the boss
			part.CFrame = CFrame.lookAt(centre, centre + direction)
		end
	end
	local centre = CFrame.new(ring.x, y, ring.z)
	return function(part: Part, fit: number, scale: number)
		local size = ring.radius * 2 * fit * scale
		part.Size = Vector3.new(size, 0.05, size)
		part.CFrame = centre
	end
end

function RingFx.show(ring: Ring)
	local swipe = ring.shape == "swipe"
	local y = groundY(ring.x, ring.y, ring.z) + SwordFx.RING_LIFT
	local place = placer(ring, y)
	local outline, outlineDecal = flat(if swipe then SwordFx.CONE_OUTLINE else SwordFx.RING_OUTLINE, SwordFx.RING_OUTLINE_TRANSPARENCY)
	local glow, glowDecal = flat(if swipe then SwordFx.CONE_GLOW else SwordFx.RING_GLOW, 1)
	place(outline, SwordFx.RING_FIT.outline, 1)
	place(glow, SwordFx.RING_FIT.glow, RingRules.START_SCALE)
	local started = os.clock()
	local closing: RBXScriptConnection
	closing = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		if elapsed >= ring.warning then
			closing:Disconnect()
			-- Landed: a white flash over the area, fading out
			local fade = TweenInfo.new(SwordFx.RING_FLASH_SECONDS)
			place(glow, SwordFx.RING_FIT.glow, 1)
			glowDecal.Transparency = 0
			outlineDecal.Transparency = 0
			TweenService:Create(glowDecal, fade, { Transparency = 1 }):Play()
			TweenService:Create(outlineDecal, fade, { Transparency = 1 }):Play()
			task.delay(SwordFx.RING_FLASH_SECONDS + 0.05, function()
				outline:Destroy()
				glow:Destroy()
			end)
			return
		end
		place(glow, SwordFx.RING_FIT.glow, RingRules.closingScale(elapsed, ring.warning))
		glowDecal.Transparency = math.max(0, 0.7 - elapsed / ring.warning)
	end)
end

return RingFx
