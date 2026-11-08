--!strict
-- A hit landing in the free VFX packs' look (Config/SwordFx IMPACT and ELEMENT_HIT; docs/weapons.md "Pack effects"):
-- the packs' slash streaks and arc on a cut, the spark streaks and the element's own particles on every hit
-- (FightFxRules.hitSpecs), all bursting from a holder standing level and turned to face your camera, the impact's
-- emitters again a beat later (the echo). Your sword's cuts (Util/HitFx.impact) and every creature's basic attack
-- (Util/FightFx) land with it, sized to what was hit (scaleFor).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SwordFx = require(Shared:WaitForChild("Config"):WaitForChild("SwordFx"))
local FightFxRules = require(Shared:WaitForChild("Util"):WaitForChild("FightFxRules"))
local SwordArcRules = require(Shared:WaitForChild("Util"):WaitForChild("SwordArcRules"))
local PackEmitter = require((script.Parent :: Instance):WaitForChild("PackEmitter"))

local PackHit = {}

local sizeScales: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

-- How big a hit's effects are on `model` (SwordArcRules.impactScale from its size, SwordFx IMPACT bySize; 1 with no
-- model), worked out once per model
function PackHit.scaleFor(model: Model?): number
	if not model then
		return 1
	end
	local known = sizeScales[model]
	if known then
		return known
	end
	local extents = model:GetExtentsSize()
	local scale = SwordArcRules.impactScale(extents.X, extents.Y, extents.Z, SwordFx.IMPACT.bySize)
	sizeScales[model] = scale
	return scale
end

-- A hit at `at` under `parent`: sizes and speeds `scale` times the packs', in `tint`, with `element`'s particles (none
-- for nil) and the slash streaks and arc when it's a `cut`; `share` of the particle counts (1: all)
function PackHit.play(parent: Instance, at: Vector3, scale: number, tint: Color3, element: string?, cut: boolean, share: number)
	local impact = SwordFx.IMPACT
	local eye = workspace.CurrentCamera.CFrame.Position
	local x, y, z = SwordArcRules.impactFacing(at.X, at.Y, at.Z, eye.X, eye.Z)
	local part = Instance.new("Part")
	part.Name = "PackHit"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = if x and y and z then CFrame.lookAt(at, Vector3.new(x, y, z)) else CFrame.new(at)
	part.Parent = parent
	Debris:AddItem(part, impact.seconds)
	local echoes: { { emitter: ParticleEmitter, count: number } } = {}
	for _, spec in FightFxRules.hitSpecs(SwordFx, element, cut) do
		local emitter = PackEmitter.make(spec, scale, tint)
		emitter.Parent = part
		local count = math.max(1, math.round(spec.count * share))
		emitter:Emit(count)
		if table.find(impact.emitters, spec) then
			table.insert(echoes, { emitter = emitter, count = count })
		end
	end
	task.delay(impact.echo.after, function()
		if not part.Parent then
			return
		end
		for _, echo in echoes do
			echo.emitter:Emit(math.max(1, math.round(echo.count * impact.echo.share)))
		end
	end)
end

return PackHit
