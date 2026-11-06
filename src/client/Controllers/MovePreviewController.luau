--!strict
-- Studio only: plays a Pet button move at a chosen grade on your summoned creature against a dummy in front of it (spec
-- 2026-11-05-pet-moves-design "Seeing it in Studio"; DevService /movefx, the admin panel's "Pet moves" buttons), a
-- super (/superfx) or three of its basic attacks (/attackfx). It feeds Util/FightFx the sim's real event shapes (cast,
-- ability, regen ticks, charges and attacks), so what plays is what a fight plays. /skillfx: your character swings a
-- round 1 sword's cut or skill at a dummy with that sword's effects (Util/SwordSkillFx, spec 2026-11-06-sword-skills).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared:WaitForChild("Config"):WaitForChild("Combat"))
local SuperFxConfig = require(Shared:WaitForChild("Config"):WaitForChild("SuperFx"))
local Swords = require(Shared:WaitForChild("Config"):WaitForChild("Swords"))
local SwordFxConfig = require(Shared:WaitForChild("Config"):WaitForChild("SwordFx"))
local Weapons = require(Shared:WaitForChild("Config"):WaitForChild("Weapons"))
local WeaponLooks = require(Shared:WaitForChild("Config"):WaitForChild("WeaponLooks"))
local WeaponLookRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponLookRules"))
local SwordSkillFxRules = require(Shared:WaitForChild("Util"):WaitForChild("SwordSkillFxRules"))
local SwordSkillFxConfig = require(Shared:WaitForChild("Config"):WaitForChild("SwordSkillFx"))
local SwordRules = require(Shared:WaitForChild("Util"):WaitForChild("SwordRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local FightFx = require(ClientUtil:WaitForChild("FightFx"))
local SuperCinematic = require(ClientUtil:WaitForChild("SuperCinematic"))
local SwordAnims = require(ClientUtil:WaitForChild("SwordAnims"))
local SwordSkillFx = require(ClientUtil:WaitForChild("SwordSkillFx"))
local SkillCinematic = require(ClientUtil:WaitForChild("SkillCinematic"))
local ScreenFx = require(ClientUtil:WaitForChild("ScreenFx"))
local CardArt = require(Shared:WaitForChild("Util"):WaitForChild("CardArt"))
local CardArtConfig = require(Shared:WaitForChild("Config"):WaitForChild("CardArt"))
local CreatureController = require(Controllers:WaitForChild("CreatureController"))
local SwordController = require(Controllers:WaitForChild("SwordController"))

local MovePreviewController = {}

local KINDS = { rain = "Rain", vine = "Snare", orbs = "Overcharge", curse = "Curse" }
local ME, FOE = "a:preview", "b:preview" -- sided like a fight's ids (a shield's dome is keyed by side)
local DUMMY_DISTANCE = 14 -- studs in front of the creature
local BIG_HEIGHT = 14 -- studs: the big dummy (an Ember Colossus)
local LINGER = 6 -- seconds the dummy stays after the last event (Curse lasts 5)
local CHARGE_LEAD = 0.6 -- seconds a basic attack's charge leads its hit (about the sim's)

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

-- One basic attack at `at`: its charge, then the hit landing CHARGE_LEAD later
local function basicAttack(timeline: { { at: number, event: any } }, at: number)
	table.insert(timeline, { at = at, event = { type = "charge", from = ME, to = FOE, seconds = CHARGE_LEAD } })
	table.insert(timeline, { at = at + CHARGE_LEAD, event = { type = "attack", from = ME, to = FOE, damage = 10 } })
end

-- A super's events (spec 2026-11-05-super-moves-design): its cast with the wind-up the sim gives it, its landing
local function superTimeline(lookId: string): ({ { at: number, event: any } }, number)
	local look = SuperFxConfig.LOOKS[lookId]
	local ability = Combat.SIGNATURES[look.card]
	local windup = ability.windup
	local onSelf = ability.kind == "TidalShield" or ability.kind == "Eclipse" or ability.kind == "Rebirth"
	local landing: any = { type = "ability", kind = ability.kind, look = lookId, from = ME, to = if onSelf then nil else FOE }
	if ability.kind == "TidalShield" then
		landing.shielded = { ME } -- the preview's only ally: its bubble
		landing.seconds = ability.seconds
	elseif ability.kind == "Rebirth" then
		landing.healed = { ME } -- it heals itself, and stands up a creature off the field (its callout)
		landing.revived = { "a:benched" }
	elseif ability.kind == "Barrage" then
		landing.blink = 1
		landing.damage = 10
	end
	local timeline: { { at: number, event: any } } = {
		{ at = 0, event = { type = "cast", from = ME, kind = ability.kind, look = lookId, seconds = windup, protect = windup + Combat.SUPER_PROTECT_TAIL, to = FOE } },
		{ at = windup, event = landing },
	}
	-- What happens after, from the dummy (a monster, as in a boss fight): a hit the ward soaks then the ward running
	-- out (the bubble ripples, then bursts), or a hit passing through a dodging super
	if ability.kind == "TidalShield" then
		table.insert(timeline, { at = windup + 1, event = { type = "attack", from = FOE, to = ME, damage = 0, absorbed = 40 } })
		table.insert(timeline, { at = windup + 2.2, event = { type = "shieldGone", to = ME } })
	elseif ability.kind == "Barrage" then
		-- Its later hits, a gap apart, each from the next rift
		for blink = 2, ability.hits do
			table.insert(timeline, { at = windup + ability.gap * (blink - 1), event = { type = "ability", kind = "Barrage", from = ME, to = FOE, blink = blink, damage = 10 } })
		end
	elseif ability.kind == "Eclipse" then
		table.insert(timeline, { at = windup + 1, event = { type = "attack", from = FOE, to = ME, damage = 0, dodged = true } })
		-- Its attacks while it lasts: the mirror image strikes with it (owner 2026-11-05)
		basicAttack(timeline, windup + 1.6)
		basicAttack(timeline, windup + 3.2)
		table.sort(timeline, function(a, b)
			return a.at < b.at
		end)
	end
	return timeline, math.max(ability.seconds or 0, 4)
end

local SWORD_MOVES = { cut1 = 1, cut2 = 2, cut3 = 3, skill = 0 }

-- /skillfx: your character swings the moveset's cut or skill (its own animation) at a dummy in front of you, with the
-- weapon's effects at its colours and level
local function playSword(payload: any)
	local moveset = if typeof(payload.skillFx) == "string" then Swords.SWORDS[payload.skillFx] else nil
	local weapon = if typeof(payload.weapon) == "string" then Weapons.ById[payload.weapon] else nil
	local cut = if typeof(payload.move) == "string" then SWORD_MOVES[payload.move] else nil
	local character = game:GetService("Players").LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not moveset or not moveset.fx or not weapon or not cut or typeof(payload.level) ~= "number" or typeof(payload.grade) ~= "string" then
		return
	elseif not character or not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	if playing then
		playing()
	end
	local fx = moveset.fx
	local dummy, _, model = makeDummy(root.CFrame, false)
	local anims = SwordAnims.load(humanoid, payload.skillFx)
	local colors = SwordSkillFx.colorsOf(weapon.id)
	local layers = WeaponLookRules.layers(WeaponLooks, weapon.rarity, payload.level, payload.grade, "hand")
	local scale = SwordSkillFxRules.scale(layers.trailScale)
	local move = payload.move
	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		local track = anims.track(move)
		if track then
			track:Stop(0.1)
			track:Destroy()
		end
		dummy:Destroy()
		if model then
			model:Destroy()
		end
		if playing == stop then
			playing = nil
		end
	end
	playing = stop
	SwordController.DrawNow() -- the sword in your hand, as in a fight
	anims.play(move)
	SwordController.PlayCues(move) -- the equipped sword's sounds (equip the previewed one to hear its own)
	local length = if cut == 0 then moveset.skill.length else moveset.combo[cut].length
	local blade = SwordController.BladeOf(character)
	if cut == 0 then
		-- Aimed at the dummy as a fight aims at a boss (SwordRules.skillImpact), with your shakes and camera moment
		local look = root.CFrame.LookVector
		local dummyTarget = { id = "dummy", x = dummy.Position.X, z = dummy.Position.Z, radius = dummy.Size.X / 2 }
		local x, z = SwordRules.skillImpact(moveset.skill.shape, root.Position.X, root.Position.Z, look.X, look.Z, { dummyTarget })
		local aim = if x and z then Vector3.new(x, root.Position.Y, z) else dummy.Position
		local shake = SwordSkillFxConfig.SHAKE
		SwordSkillFx.skill(character, fx.skill, colors, scale, aim, {
			blade = blade,
			released = function()
				ScreenFx.shake(shake.release)
			end,
			burst = function()
				ScreenFx.shake(shake.impact)
				local spec = SwordSkillFxConfig.LOOKS[fx.skill]
				if spec and spec.burstSound then
					SwordController.PlaySound(spec.burstSound)
				end
			end,
		})
		local spec = SwordSkillFxConfig.LOOKS[fx.skill]
		local beats = if spec and spec.cinematic then spec.beats else nil
		if beats then
			local travel = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z).Magnitude / math.max(beats.speed, 1)
			SkillCinematic.play(root, aim - Vector3.new(0, 3, 0), beats.release, travel, function(): boolean
				return not stopped
			end)
			length += travel + SwordSkillFxConfig.CINEMATIC.hold
		end
	else
		task.delay(SwordFxConfig.ARCS[move].from, function()
			if not stopped then
				SwordSkillFx.slash(character, fx.slash, cut, colors, scale, blade)
			end
		end)
		if cut == 3 then
			task.delay(moveset.combo[3].hitAt, function()
				local at = SwordSkillFx.slamPoint(character)
				if at and not stopped then
					SwordSkillFx.finisher(at, fx.finisher, colors, scale)
				end
			end)
		end
	end
	task.delay(length + 2, stop)
end

local function play(payload: any)
	if payload.skillFx ~= nil then
		playSword(payload)
		return
	end
	local superLook = if typeof(payload.super) == "string" and SuperFxConfig.LOOKS[payload.super] then payload.super else nil
	local kind = if superLook then Combat.SIGNATURES[SuperFxConfig.LOOKS[superLook].card].kind
		elseif payload.attack == true then "attack"
		else KINDS[payload.move]
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
		blink = CreatureController.Blink,
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
			SuperCinematic.release()
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
	elseif kind == "attack" then
		timeline = {}
		for index = 0, 2 do
			basicAttack(timeline, index * 1.4)
		end
		linger = 2
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
