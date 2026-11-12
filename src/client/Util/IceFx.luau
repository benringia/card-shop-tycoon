--!strict
-- The Frost Tyrant's ice (the owner 2026-11-10; Config/AttackFx ICE, numbers in Util/IceFxRules), drawn on this client
-- by Util/FightFx and Util/DebuffFx: a giant ice spike that hangs over a ring and drops to land with the hit, then
-- shatters (its tip stuck in the ground, pieces flying, ice smoke and frost); his shield, a frosted ice bubble with
-- shards jutting out that grows round him and bursts when broken; and the ice a frozen fighter is locked in, cracking
-- off when it thaws. Ice crystals are glassy diamond prisms with pyramid tips round a glowing core.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("Config"):WaitForChild("AttackFx"))
local IceFxRules = require(Shared:WaitForChild("Util"):WaitForChild("IceFxRules"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))
local CinematicView = require((script.Parent :: Instance):WaitForChild("CinematicView"))

local IceFx = {}

local ICE = AttackFx.ICE
local UP = Vector3.yAxis

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local ICE_COLOR = rgb(ICE.color)
local CORE_COLOR = rgb(ICE.core)
local SMOKE_COLOR = rgb(ICE.smoke)

local function piece(parent: Instance, class: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, transparency: number): BasePart
	local part = Instance.new(class) :: BasePart
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Transparency = transparency
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- The Y turn that puts a CornerWedgePart's high corner (its +X, -Z top corner) toward (-qx, -qz): four of them, one in
-- each quarter round an axis, make a pyramid
local function cornerTurn(qx: number, qz: number): number
	for quarter = 0, 3 do
		local turned = CFrame.Angles(0, math.rad(90 * quarter), 0) * Vector3.new(1, 0, -1)
		if math.abs(turned.X + qx) < 0.01 and math.abs(turned.Z + qz) < 0.01 then
			return math.rad(90 * quarter)
		end
	end
	return 0
end

-- One ice crystal in `model` along `frame`'s Y from its foot: `width` across, `length` long with its tip, glassy (or
-- `material`: the falling spike is pale Ice, seen in the fog); its parts
local function crystal(model: Instance, frame: CFrame, width: number, length: number, transparency: number, material: Enum.Material?): { BasePart }
	local tip = width * 1.3
	local body = math.max(0.1, length - tip)
	local axis = frame * CFrame.Angles(0, math.rad(45), 0)
	local shell = material or Enum.Material.Glass
	local parts = { piece(model, "Part", Vector3.new(width, body, width), axis * CFrame.new(0, body / 2, 0), ICE_COLOR, shell, transparency) }
	for _, quarter in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		table.insert(parts, piece(model, "CornerWedgePart", Vector3.new(width / 2, tip, width / 2), axis * CFrame.new(quarter[1] * width / 4, body + tip / 2, quarter[2] * width / 4) * CFrame.Angles(0, cornerTurn(quarter[1], quarter[2]), 0), ICE_COLOR, shell, transparency))
	end
	table.insert(parts, piece(model, "Part", Vector3.new(width * 0.4, body * 0.95, width * 0.4), axis * CFrame.new(0, body * 0.5, 0), CORE_COLOR, Enum.Material.Neon, 0.3))
	return parts
end

-- The body `root` belongs to, as a box: how far its middle sits above the root and its size (the owner 2026-11-10: the
-- shield and the ice centred on a root at the feet covered half the body); `height` stands in when there's no model
local function bodyBox(root: BasePart, height: number): (Vector3, Vector3)
	local body = root:FindFirstAncestorOfClass("Model")
	if not body then
		return Vector3.zero, Vector3.new(height * 0.8, height, height * 0.8)
	end
	local box, size = body:GetBoundingBox()
	return Vector3.new(0, box.Position.Y - root.Position.Y, 0), size
end

local function model(name: string, at: Vector3): Model
	local made = Instance.new("Model")
	made.Name = name
	made.WorldPivot = CFrame.new(at)
	made.Parent = ElementFx.folder()
	return made
end

local function fade(parts: { BasePart }, seconds: number)
	for _, part in parts do
		TweenService:Create(part, TweenInfo.new(seconds), { Transparency = 1 }):Play()
	end
end

-- Ice smoke rolling out of `at`, `count` puffs `size` studs across
local function smoke(at: Vector3, count: number, size: number)
	local anchor = piece(ElementFx.folder(), "Part", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at), CORE_COLOR, Enum.Material.SmoothPlastic, 1)
	Debris:AddItem(anchor, 3)
	local puffs = ElementFx.emitter(anchor, "smoke", SMOKE_COLOR, {
		size = { size * 0.5, size * 1.4 },
		life = { 1.1, 1.8 },
		speed = { 6, 14 },
		spread = 180,
		spin = { -40, 40 },
		accel = Vector3.new(0, 2, 0),
		drag = 3,
		light = 0.3,
		brightness = 1,
		start = 0.25,
		fade = 0.3,
	})
	puffs:Emit(math.max(1, math.round(count * ElementFx.detailShare())))
end

-- Pieces of ice flung out of `at` (IceFxRules.shatterPieces): each a small crystal arcing out and down, then fading
local function shards(at: Vector3, count: number, width: number)
	local holder = model("IceShards", at)
	Debris:AddItem(holder, 1.6)
	for _, spec in IceFxRules.shatterPieces(math.max(3, math.round(count * ElementFx.detailShare()))) do
		local out = CFrame.Angles(0, math.rad(spec.yaw), 0).LookVector
		local size = width * spec.size
		local bit = Instance.new("Model")
		bit.Parent = holder
		local parts = crystal(bit, CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6), size, size * 2.4, 0.15)
		local started = os.clock()
		local turn = CFrame.Angles(math.random() * 0.3 - 0.15, math.random() * 0.3 - 0.15, 0) -- a tumble each frame
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			local t = os.clock() - started
			if t > 1.2 or not bit.Parent then
				connection:Disconnect()
				return
			end
			local position = at + out * spec.speed * t + UP * (spec.up * 2 * t - 30 * t * t)
			bit:PivotTo(CFrame.new(position) * bit:GetPivot().Rotation * turn)
		end)
		task.delay(0.7, function()
			fade(parts, 0.45)
		end)
	end
end

-- A spike shattering on the ground at `ground` (the ring's centre): its tip stuck in the ground, pieces flying, ice
-- smoke rolling out, a frost patch fading, the shatter's sound
function IceFx.shatter(ground: Vector3)
	local look = ICE.spike
	local stub = model("IceSpikeStub", ground)
	local parts = crystal(stub, CFrame.new(ground - UP * look.length * 0.08) * CFrame.Angles(math.rad(math.random(-10, 10)), 0, math.rad(math.random(-10, 10))) * CFrame.Angles(math.rad(180), 0, 0) * CFrame.new(0, -look.length * 0.3, 0), look.width, look.length * 0.3, 0.15)
	task.delay(1.3, function()
		fade(parts, 0.6)
	end)
	Debris:AddItem(stub, 2.1)
	shards(ground + UP * 1.5, look.pieces, look.width)
	smoke(ground + UP * 1, look.smoke, look.width * 1.6)
	ElementFx.burst(ground + UP * 1.5, ICE_COLOR, 2.4)
	ElementFx.ring(ground, CORE_COLOR, look.width * 2.6, 0.5)
	local frost = piece(ElementFx.folder(), "Part", Vector3.new(0.15, look.width * 3, look.width * 3), CFrame.new(ground + UP * 0.12) * CFrame.Angles(0, 0, math.rad(90)), SMOKE_COLOR, Enum.Material.Ice, 0.2)
	frost.Shape = Enum.PartType.Cylinder
	TweenService:Create(frost, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	Debris:AddItem(frost, 2.3)
	ElementFx.sound(ICE.sounds.shatter, ground, 1.1)
end

-- A giant ice spike over `ground` (a ring's centre) for the `seconds` till its hit: it forms high up, point down, hangs
-- glowing, drops the last ICE.spike.fall seconds with a whoosh and shatters as it lands (the hit's event then draws
-- the frost shockwave: Util/FightFx)
function IceFx.spike(ground: Vector3, seconds: number)
	local look = ICE.spike
	local spike = model("IceSpike", ground)
	local parts = crystal(spike, CFrame.identity * CFrame.Angles(math.rad(180), 0, 0), look.width, look.length, 0.05, Enum.Material.Ice)
	local glow = Instance.new("PointLight")
	glow.Color = ICE_COLOR
	glow.Range = look.light
	glow.Brightness = 2
	glow.Shadows = false
	glow.Parent = parts[1]
	for _, part in parts do
		part.CFrame = CFrame.new(ground + UP * (look.height + look.length)) * part.CFrame
	end
	spike.WorldPivot = CFrame.new(ground + UP * (look.height + look.length))
	-- it forms out of nothing
	local finals: { [BasePart]: number } = {}
	for _, part in parts do
		finals[part] = part.Transparency
		part.Transparency = 1
		TweenService:Create(part, TweenInfo.new(0.25), { Transparency = finals[part] }):Play()
	end
	local trail = ElementFx.emitter(parts[1], "smoke", SMOKE_COLOR, { size = { 3, 6 }, life = { 0.4, 0.7 }, speed = 1, spread = 30, light = 0.3, brightness = 1, start = 0.4 })
	trail.Rate = 18 * ElementFx.detailShare()
	local started = os.clock()
	local whooshed = false
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if not whooshed and t >= IceFxRules.dropAt(seconds, look.fall) then
			whooshed = true
			ElementFx.sound(ICE.sounds.fall, ground + UP * look.height * 0.5, 0.9)
		end
		if t >= seconds or not spike.Parent then
			connection:Disconnect()
			spike:Destroy()
			if t >= seconds then
				IceFx.shatter(ground)
			end
			return
		end
		spike:PivotTo(CFrame.new(ground + UP * (IceFxRules.heightAt(t, seconds, look.fall, look.height) + look.length)))
	end)
end

export type Shield = { shatter: () -> (), remove: () -> () }

-- His shield: a frosted ice bubble round `root` (about his `height` across) with shards jutting out of it, growing in
-- with an ice crackle and following him; shatter() bursts it (pieces, ice smoke, a crash), remove() just takes it away
function IceFx.shield(root: BasePart, height: number, maxRadius: number?): Shield
	local look = ICE.shield
	local lift, size = bodyBox(root, height)
	-- round his whole body: half its largest side, and a little more
	local radius = math.min(math.max(size.X, size.Y, size.Z) * look.radius, maxRadius or math.huge) -- a wide body (the Hydra's necks): kept inside its ring
	local centre = root.Position + lift
	local holder = model("IceShield", centre)
	-- a camera moment that fades him out of its way fades his shield too
	CinematicView.attach(root:FindFirstAncestorOfClass("Model"), holder)
	local parts: { BasePart } = {}
	local bubble = piece(holder, "Part", Vector3.one * radius * 2, CFrame.new(centre), ICE_COLOR, Enum.Material.Glass, look.transparency)
	bubble.Shape = Enum.PartType.Ball
	table.insert(parts, bubble)
	for _, spec in IceFxRules.shieldShards(look.shards) do
		local outward = (CFrame.Angles(0, math.rad(spec.yaw), 0) * CFrame.Angles(math.rad(spec.pitch), 0, 0)).LookVector
		local foot = centre + outward * radius * 0.9
		for _, part in crystal(holder, CFrame.lookAt(foot, foot + outward) * CFrame.Angles(math.rad(-90), 0, 0), radius * spec.width, radius * spec.length, 0.2) do
			table.insert(parts, part)
		end
	end
	holder.WorldPivot = CFrame.new(centre)
	-- it grows in round him
	holder:ScaleTo(0.2)
	local grown = 0.2
	local started = os.clock()
	ElementFx.sound(ICE.sounds.shieldForm, centre, 1)
	smoke(centre, 10, height * 0.25)
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if not holder.Parent or not root.Parent then
			connection:Disconnect()
			holder:Destroy()
			return
		end
		local share = math.clamp((os.clock() - started) / look.grow, 0, 1)
		local scale = 0.2 + 0.8 * (1 - (1 - share) ^ 3)
		if scale ~= grown then
			holder:ScaleTo(scale)
			grown = scale
		end
		-- following him only when he moves (a lunge): about 145 parts
		if (holder:GetPivot().Position - (root.Position + lift)).Magnitude > 0.05 then
			holder:PivotTo(CFrame.new(root.Position + lift))
		end
	end)
	local done = false
	local function remove()
		if done then
			return
		end
		done = true
		connection:Disconnect()
		holder:Destroy()
	end
	local function shatter()
		if done then
			return
		end
		local at = root.Position + lift
		remove()
		shards(at, 18, radius * 0.5)
		smoke(at, 16, height * 0.35)
		ElementFx.burst(at, ICE_COLOR, 3)
		ElementFx.sound(ICE.sounds.shieldBreak, at, 1.2)
	end
	return { shatter = shatter, remove = remove }
end

-- The ice round a frozen fighter cracking off: pieces flying, a crunch (IceFx.encase's block)
function IceFx.thaw(block: Model)
	if not block.Parent then
		return
	end
	local at = block:GetPivot().Position
	local size = block:GetExtentsSize().Y
	block:Destroy()
	shards(at, 8, size * 0.3)
	ElementFx.sound(ICE.sounds.freeze, at, 0.7)
end

-- A fighter frozen solid (a spike's hit: Frozen on a player, a pet's freeze): a glassy block of ice round `root` (about
-- `height` tall) with crystals at its foot and a crunch, following it; it cracks off after `seconds` (nil: when
-- IceFx.thaw is called on the block it returns)
function IceFx.encase(root: BasePart, height: number, seconds: number?): Model
	local look = ICE.encase
	local lift, size = bodyBox(root, height)
	local tall = size.Y * look.tall
	local wide = math.max(size.X, size.Z) * look.width
	local centre = root.Position + lift
	local holder = model("IceBlock", centre)
	CinematicView.attach(root:FindFirstAncestorOfClass("Model"), holder)
	local block = piece(holder, "Part", Vector3.new(wide, tall, wide), CFrame.new(centre), ICE_COLOR, Enum.Material.Glass, look.transparency)
	local parts: { BasePart } = { block }
	for index = 1, look.crystals do
		local angle = index / look.crystals * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local foot = centre - UP * tall * 0.42 + out * wide * 0.5
		local lean = CFrame.lookAt(foot, foot + out + UP * 2.2) * CFrame.Angles(math.rad(-90), 0, 0)
		for _, part in crystal(holder, lean, tall * 0.16, tall * (0.35 + 0.1 * (index % 3)), 0.2) do
			table.insert(parts, part)
		end
	end
	holder.WorldPivot = CFrame.new(centre)
	ElementFx.sound(ICE.sounds.freeze, centre, 1)
	smoke(centre, 6, tall * 0.4)
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if not holder.Parent or not root.Parent then
			connection:Disconnect()
			holder:Destroy()
			return
		end
		holder:PivotTo(CFrame.new(root.Position + lift))
	end)
	if seconds then
		task.delay(seconds, function()
			IceFx.thaw(holder)
		end)
	end
	return holder
end

-- His claw swipe landing at `at` from `from`: an icy slash, a puff of snow and frost sparks
function IceFx.strike(at: Vector3, from: Vector3)
	ElementFx.slash(at, from, ICE_COLOR, "vine", 1, 1.6, 30)
	ElementFx.burst(at, ICE_COLOR, 1.6)
	smoke(at, 5, 3)
end

-- The spike's hit on the ring: a frost shockwave across it (the spike itself shatters on its own clock: IceFx.spike)
function IceFx.release(ground: Vector3, radius: number)
	ElementFx.ring(ground, ICE_COLOR, radius, 0.6)
	ElementFx.eruption(ground, ICE_COLOR, radius * 0.8, 6)
end

return IceFx
