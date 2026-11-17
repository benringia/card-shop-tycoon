--!strict
-- The young Hydra's entrance (owner 2026-11-17, playthrough: "make young hydra entrance more epic"; PrologueController
-- act 1; numbers in Config/Prologue ENTRANCE): rainbow cracks racing over the lair's floor from where it will rise, a
-- pillar of light and a burst of crystal shards as the floor breaks open, dust rolling out, and the shockwave of its
-- roar. Drawn on this screen only; all of it gone after `finish`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local AttackFx = require(Config:WaitForChild("AttackFx"))
local Prologue = require(Config:WaitForChild("Prologue"))

local HydraEntrance = {}

export type Entrance = {
	cracks: (seconds: number) -> (), -- the floor splits open from the spot over `seconds`
	burst: () -> (), -- the floor breaks: the light pillar, the crystal shards, the dust
	shockwave: () -> (), -- the roar's ring over the floor
	finish: () -> (), -- everything fades and goes
}

local LOOK = Prologue.ENTRANCE
local RAINBOW = {
	Color3.fromRGB(255, 110, 120),
	Color3.fromRGB(255, 190, 80),
	Color3.fromRGB(255, 240, 120),
	Color3.fromRGB(110, 230, 150),
	Color3.fromRGB(110, 190, 255),
	Color3.fromRGB(190, 140, 255),
}

local function rainbowSequence(): ColorSequence
	local keys = {}
	for index, color in RAINBOW do
		table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#RAINBOW - 1), color))
	end
	return ColorSequence.new(keys)
end

local function neon(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, transparency: number, shape: Enum.PartType?): Part
	local made = Instance.new("Part")
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Material = Enum.Material.Neon
	made.Shape = shape or Enum.PartType.Block
	made.Size = size
	made.CFrame = cframe
	made.Color = color
	made.Transparency = transparency
	made.Parent = parent
	return made
end

local function tween(object: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal):Play()
end

-- Starts the entrance at `spot` (the Hydra's place on the floor); `ground`: the height of the top of what lies on the
-- floor (the lair's sigil, PrologueStage `ground`), so the cracks draw on it, not under it
function HydraEntrance.begin(spot: CFrame, ground: number?): Entrance
	local floor = Vector3.new(spot.X, ground or spot.Y, spot.Z)
	local folder = Instance.new("Folder")
	folder.Name = "HydraEntrance"
	folder.Parent = workspace
	local glowing: { Part } = {}
	local random = Random.new()

	-- an attachment at the spot to burst particles from
	local anchor = neon(folder, Vector3.new(0.2, 0.2, 0.2), CFrame.new(floor), Color3.new(1, 1, 1), 1)
	local emitAt = Instance.new("Attachment")
	emitAt.Parent = anchor

	local function cracks(seconds: number)
		for index = 1, LOOK.cracks do
			local angle = (index / LOOK.cracks) * math.pi * 2 + random:NextNumber(-0.2, 0.2)
			local color = RAINBOW[(index - 1) % #RAINBOW + 1]
			local from = floor + Vector3.new(0, LOOK.crackLift, 0)
			local length = LOOK.crackLength * random:NextNumber(0.7, 1.1)
			-- each crack in a few bent pieces, each growing out of the last's end
			for piece = 1, LOOK.crackPieces do
				angle += random:NextNumber(-0.35, 0.35)
				local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
				local pieceLength = length / LOOK.crackPieces
				local width = LOOK.crackWidth * (1 - (piece - 1) / (LOOK.crackPieces + 1))
				local start = from
				local delay = seconds * (piece - 1) / LOOK.crackPieces
				local grow = seconds / LOOK.crackPieces
				local part = neon(folder, Vector3.new(width, 0.12, 0.05), CFrame.lookAt(start, start + direction), color, 0.1)
				table.insert(glowing, part)
				task.delay(delay, function()
					if part.Parent then
						tween(part, grow, {
							Size = Vector3.new(width, 0.12, pieceLength),
							CFrame = CFrame.lookAt(start, start + direction) * CFrame.new(0, 0, -pieceLength / 2),
						}, Enum.EasingStyle.Linear)
					end
				end)
				from = start + direction * pieceLength
			end
		end
	end

	local function burst()
		-- the pillar of light the Hydra comes up through
		local pillar = neon(folder, Vector3.new(LOOK.pillar.height, LOOK.pillar.width, LOOK.pillar.width), CFrame.new(floor + Vector3.new(0, LOOK.pillar.height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 250, 235), 0.15, Enum.PartType.Cylinder)
		tween(pillar, LOOK.pillar.seconds, { Transparency = 1, Size = Vector3.new(LOOK.pillar.height, LOOK.pillar.width * 2.4, LOOK.pillar.width * 2.4) })
		-- crystal shards flung up, every colour of the prism
		local shards = Instance.new("ParticleEmitter")
		shards.Texture = AttackFx.TEXTURES.shard
		shards.Color = rainbowSequence()
		shards.LightEmission = 0.8
		shards.Lifetime = NumberRange.new(1.2, 2.2)
		shards.Speed = NumberRange.new(LOOK.shardSpeed * 0.6, LOOK.shardSpeed)
		shards.SpreadAngle = Vector2.new(35, 35)
		shards.EmissionDirection = Enum.NormalId.Top
		shards.Acceleration = Vector3.new(0, -workspace.Gravity * 0.35, 0)
		shards.Rotation = NumberRange.new(0, 360)
		shards.RotSpeed = NumberRange.new(-260, 260)
		shards.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0.4) })
		shards.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) })
		shards.Enabled = false
		shards.Parent = emitAt
		shards:Emit(LOOK.shards)
		-- dust rolling out over the floor
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = AttackFx.TEXTURES.smoke
		dust.Color = ColorSequence.new(Color3.fromRGB(205, 195, 230))
		dust.Lifetime = NumberRange.new(1.4, 2.4)
		dust.Speed = NumberRange.new(14, 26)
		dust.SpreadAngle = Vector2.new(80, 80)
		dust.EmissionDirection = Enum.NormalId.Top
		dust.Drag = 2.5
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 14) })
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		dust.Enabled = false
		dust.Parent = emitAt
		dust:Emit(LOOK.dust)
		-- the cracks flare white for a moment
		for _, part in glowing do
			part.Color = part.Color:Lerp(Color3.new(1, 1, 1), 0.6)
		end
	end

	local function shockwave()
		local ring = neon(folder, Vector3.new(0.4, 4, 4), CFrame.new(floor + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(235, 225, 255), 0.25, Enum.PartType.Cylinder)
		tween(ring, LOOK.shockwave.seconds, { Size = Vector3.new(0.4, LOOK.shockwave.size, LOOK.shockwave.size), Transparency = 1 })
	end

	local function finish()
		for _, part in glowing do
			tween(part, LOOK.fadeSeconds, { Transparency = 1 })
		end
		task.delay(LOOK.fadeSeconds + 2.5, function() -- the shards and dust land first
			folder:Destroy()
		end)
	end

	return { cracks = cracks, burst = burst, shockwave = shockwave, finish = finish }
end

return HydraEntrance
