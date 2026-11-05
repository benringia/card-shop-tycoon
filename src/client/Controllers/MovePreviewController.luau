--!strict
-- Studio only: plays a Pet button move at a chosen grade on your summoned creature against a dummy in front of it (spec
-- 2026-11-05-pet-moves-design "Seeing it in Studio"; DevService /movefx, the admin panel's "Pet moves" buttons). It
-- feeds Util/FightFx the sim's real event shapes (cast, ability, regen ticks, attacks spending orbs), so what plays is
-- what a fight plays.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared:WaitForChild("Config"):WaitForChild("Combat"))
local SuperFxConfig = require(Shared:WaitForChild("Config"):WaitForChild("SuperFx"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local FightFx = require(ClientUtil:WaitForChild("FightFx"))
local SuperCinematic = require(ClientUtil:WaitForChild("SuperCinematic"))
local CardArt = require(Shared:WaitForChild("Util"):WaitForChild("CardArt"))
local CardArtConfig = require(Shared:WaitForChild("Config"):WaitForChild("CardArt"))
local CreatureController = require(Controllers:WaitForChild("CreatureController"))

local MovePreviewController = {}

local KINDS = { rain = "Rain", vine = "Snare", orbs = "Overcharge", curse = "Curse" }
local ME, FOE = "preview:me", "preview:foe"
local DUMMY_DISTANCE = 14 -- studs in front of the creature
local BIG_HEIGHT = 14 -- studs: the big dummy (an Ember Colossus)
local LINGER = 6 -- seconds the dummy stays after the last event (Curse lasts 5)

local playing: (() -> ())? = nil -- stops the preview running now

-- A dummy foe on the ground in front of the creature: a monster model on an invisible root part
local function makeDummy(from: CFrame, big: boolean): (BasePart, number, Model?)
	local spot = from.Position + from.LookVector * DUMMY_DISTANCE
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(spot + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
	local ground = if hit then hit.Position.Y else spot.Y - 2
	local models = ReplicatedStorage:FindFirstChild("MonsterModels")
	local source = models and models:FindFirstChild(if big then "emberColossus" else "Mossling")
	local model: Model? = nil
	local height = if big then BIG_HEIGHT else 4
	if source and source:IsA("Model") then
		local copy = source:Clone()
		for _, item in copy:GetDescendants() do
			if item:IsA("Script") or item:IsA("LocalScript") then
				item:Destroy()
			elseif item:IsA("BasePart") then
				item.Anchored = true
				item.CanCollide = false
				item.CanQuery = false
			end
		end
		local _, size = copy:GetBoundingBox()
		copy:ScaleTo(copy:GetScale() * height / math.max(size.Y, 0.1))
		local facing = CFrame.lookAt(Vector3.new(spot.X, ground, spot.Z), Vector3.new(from.Position.X, ground, from.Position.Z))
		copy:PivotTo(facing)
		local box, boxSize = copy:GetBoundingBox()
		copy:PivotTo(copy:GetPivot() - Vector3.new(0, box.Position.Y - boxSize.Y / 2 - ground, 0))
		copy.Parent = workspace
		model = copy
	end
	local root = Instance.new("Part")
	root.Name = "MovePreviewDummy"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.Transparency = 1
	root.Size = Vector3.new(height * 0.6, height, height * 0.6)
	root.CFrame = CFrame.new(spot.X, ground + height / 2, spot.Z)
	root.Parent = model or workspace -- inside the model, so effects that darken the foe's model find it
	return root, height, model
end

-- Your own summoned creature's marker
local function myMarker(): BasePart?
	local userId = game:GetService("Players").LocalPlayer.UserId
	for _, item in workspace:GetDescendants() do
		if item:IsA("BasePart") and item:GetAttribute("OwnerUserId") == userId and typeof(item:GetAttribute("BeastId")) == "string" then
			if CreatureController.GetFightView(item) then
				return item
			end
		end
	end
	return nil
end

-- A super's events (spec 2026-11-05-super-moves-design): its cast with the wind-up the sim gives it, its landing
local function superTimeline(lookId: string): ({ { at: number, event: any } }, number)
	local look = SuperFxConfig.LOOKS[lookId]
	local ability = Combat.SIGNATURES[look.card]
	local windup = ability.windup
	local onSelf = ability.kind == "TidalShield" or ability.kind == "Eclipse"
	return {
		{ at = 0, event = { type = "cast", from = ME, kind = ability.kind, look = lookId, seconds = windup, protect = windup + Combat.SUPER_PROTECT_TAIL, to = FOE } },
		{ at = windup, event = { type = "ability", kind = ability.kind, look = lookId, from = ME, to = if onSelf then nil else FOE } },
	}, math.max(ability.seconds or 0, 4)
end

local function play(payload: any)
	local superLook = if typeof(payload.super) == "string" and SuperFxConfig.LOOKS[payload.super] then payload.super else nil
	local kind = if superLook then Combat.SIGNATURES[SuperFxConfig.LOOKS[superLook].card].kind else KINDS[payload.move]
	local grade = payload.grade
	if not kind or typeof(grade) ~= "string" then
		return
	end
	if playing then
		playing()
	end
	local marker = myMarker()
	if not marker then
		return
	end
	local big = payload.big == true or (superLook ~= nil and SuperFxConfig.LOOKS[superLook].tier == "Legendary")
	local dummy, height, model = makeDummy(marker.CFrame, big)
	local dispatcher = FightFx.new({
		marker = function(id: string): BasePart?
			return if id == ME then marker elseif id == FOE then dummy else nil
		end,
		creature = function(target: BasePart): any
			if target ~= marker then
				return nil
			end
			local view = CreatureController.GetFightView(target)
			return if view then { root = view.root, element = view.element, height = view.height, grade = grade, mine = true } else nil
		end,
		setCharging = CreatureController.SetCharging,
		pose = CreatureController.Pose,
		dash = CreatureController.Dash,
		monster = function(target: BasePart): any
			return if target == dummy then { root = dummy, height = height, key = "preview", lengths = {} } else nil
		end,
	})
	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		if superLook then
			SuperCinematic.cut()
		end
		dispatcher.destroy()
		dummy:Destroy()
		if model then
			model:Destroy()
		end
		if playing == stop then
			playing = nil
		end
	end
	playing = stop
	-- The timeline: the cast, the move after the wind-up, then Rain's ticks or Overcharge's three fast attacks
	local windup = Combat.ABILITY_WINDUP
	local timeline: { { at: number, event: any } } = {
		{ at = 0, event = { type = "cast", from = ME, kind = kind, seconds = windup } },
		{ at = windup, event = { type = "ability", kind = kind, from = ME, to = if kind == "Rain" then nil else FOE } },
	}
	local linger = LINGER
	if superLook then
		local lasts
		timeline, lasts = superTimeline(superLook)
		linger = lasts + 2
	elseif kind == "Rain" then
		for tick = 1, Combat.ABILITIES.Tide.ticks do
			table.insert(timeline, { at = windup + tick * Combat.ABILITIES.Tide.every, event = { type = "regen", from = ME, to = ME, heal = 50 } })
		end
	elseif kind == "Overcharge" then
		for index = 1, Combat.ABILITIES.Volt.attacks do
			local left = Combat.ABILITIES.Volt.attacks - index
			table.insert(timeline, { at = windup + 0.6 * index, event = { type = "attack", from = ME, to = FOE, damage = 1, orb = left } })
		end
	end
	local last = timeline[#timeline].at
	task.spawn(function()
		local start = os.clock()
		for _, entry in timeline do
			local wait = entry.at - (os.clock() - start)
			if wait > 0 then
				task.wait(wait)
			end
			if stopped then
				return
			end
			dispatcher.onEvents({ entry.event })
			if superLook then
				-- The caster's cinematic, as in a fight (BattleController does this for your real supers)
				local event = entry.event
				if event.type == "cast" then
					local look = SuperFxConfig.LOOKS[superLook]
					SuperCinematic.play({
						look = superLook,
						tier = look.tier,
						grade = grade,
						cardName = look.card,
						art = CardArt.pick(look.card, 320, CardArtConfig),
						color = Color3.fromRGB(look.color[1], look.color[2], look.color[3]),
						creature = (CreatureController.GetFightView(marker) or { root = marker }).root,
						height = (CreatureController.GetFightView(marker) or { height = 4 }).height,
						target = dummy,
						seconds = event.seconds,
						protect = event.protect,
						hideHud = function() end,
					})
				elseif event.type == "ability" then
					SuperCinematic.impact()
				end
			end
		end
		task.wait(math.max(0, last + linger - (os.clock() - start)))
		stop()
	end)
end

function MovePreviewController.Start()
	if not RunService:IsStudio() then
		return
	end
	Remotes.MovePreview.OnClientEvent:Connect(play)
end

return MovePreviewController
