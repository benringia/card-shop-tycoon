--!strict
-- The Dungeon's puzzles (spec 2026-11-11-dungeon-puzzles), in the Dungeon place only: the prism beams, the weight plates
-- with the secret wall, the element lock, and the chests they give. DungeonService starts it with the cavern's layout
-- and its own checks (hooks: no circular require), opens each puzzle when the run reaches it and hears when one is
-- solved. Every piece is a server-side ProximityPrompt: the handler checks the player is a run member who isn't out,
-- the puzzle is the open one, the player is near and the action's cooldown (RateLimiter). State lives here; the
-- pieces' looks are set on the server (mirror turns, the beam, lit plates and sockets), so every client sees the same.
-- Chests: an invisible anchor with an "Open" prompt; each client draws the chest on it (DungeonPuzzleController) and
-- opens its lid for the player who opened it (Remotes.DungeonChest).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Dungeon = require(Config:WaitForChild("Dungeon"))
local Party = require(Config:WaitForChild("Party"))
local Wild = require(Config:WaitForChild("Wild"))
local SharedUtil = Shared:WaitForChild("Util")
local BeamRules = require(SharedUtil:WaitForChild("BeamRules"))
local CombatMath = require(SharedUtil:WaitForChild("CombatMath"))
local DungeonRules = require(SharedUtil:WaitForChild("DungeonRules"))
local LockRules = require(SharedUtil:WaitForChild("LockRules"))
local PlateRules = require(SharedUtil:WaitForChild("PlateRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local BossService = require(Services:WaitForChild("BossService"))
local CardService = require(Services:WaitForChild("CardService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local DungeonBuilder = require(Util:WaitForChild("DungeonBuilder"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

export type Hooks = {
	canAct: (player: Player) -> boolean, -- a run member who isn't out
	active: () -> { Player }, -- the members still in the run
	runSize: () -> number, -- players the run started with (the plates' count)
	solved: (kind: string) -> (), -- DungeonService.CompleteStep
}

local DungeonPuzzleService = {}

local PROMPT_DISTANCE = 10 -- studs a piece's prompt reaches
local NEAR_SLACK = 6 -- the server's own distance check allows this much more (lag)
local SEND_COOLDOWN = 0.5
local OPEN_COOLDOWN = 0.5
local WRONG_FLASH = 0.45 -- seconds the lock's sockets flash red
local BEAM_COLOR = Color3.fromRGB(255, 226, 122)
local HELD_COLOR = Color3.fromRGB(120, 220, 110)
local IDLE_COLOR = Color3.fromRGB(150, 160, 190) -- a plate's rune ring while nothing stands on it
local WRONG_COLOR = Color3.fromRGB(255, 70, 70)

local layout: DungeonBuilder.DungeonLayout
local hooks: Hooks
local opened: { [string]: boolean } = {} -- puzzles that may be worked now
local reached: { [string]: boolean } = {} -- puzzles the run has got to (the secret wall stays breakable)
local solvedKinds: { [string]: boolean } = {}
local prompts: { [string]: { ProximityPrompt } } = { beams = {}, plates = {}, lock = {} }
local facings: { number } = {}
local plateCount = 2
local posts: { [Player]: number } = {} -- each player's creature's plate
local lockProgress = 0
local lockOrder: { string } = {}
local wallTaps = 0
local wallPrompt: ProximityPrompt? = nil
local chestOpens: { [string]: { [number]: boolean } } = {} -- each chest: the UserIds that opened it
local beamFolder: Folder
local triggers: { [string]: (player: Player) -> () } = {} -- each piece's prompt handler by name (/tap, Studio)
local rng = Random.new()

local allowTurn = RateLimiter.new(Dungeon.BEAMS.TURN_COOLDOWN)
local allowStrike = RateLimiter.new(Dungeon.LOCK.STRIKE_COOLDOWN)
local allowTap = RateLimiter.new(Dungeon.SECRET.TAP_COOLDOWN)
local allowSend = RateLimiter.new(SEND_COOLDOWN)
local allowOpen = RateLimiter.new(OPEN_COOLDOWN)

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- The server's own reach check (a prompt's distance is the client's)
local function near(player: Player, position: Vector3): boolean
	local root = rootOf(player)
	return root ~= nil and (root.Position - position).Magnitude <= PROMPT_DISTANCE + NEAR_SLACK
end

-- Whether `player` may work a piece of puzzle `kind` at `position` now (cooldown last: a refused try costs nothing)
local function mayWork(player: Player, kind: string, position: Vector3, allow: (Player) -> boolean): boolean
	return hooks.canAct(player) and opened[kind] == true and not solvedKinds[kind] and near(player, position) and allow(player)
end

local function prompt(part: BasePart, name: string, action: string, object: string, onTrigger: (player: Player) -> ()): ProximityPrompt
	local made = Instance.new("ProximityPrompt")
	made.Name = name
	made.ActionText = action
	made.ObjectText = object
	made.HoldDuration = 0
	made.MaxActivationDistance = PROMPT_DISTANCE
	made.RequiresLineOfSight = false
	made.Enabled = false
	made.Parent = part
	made.Triggered:Connect(onTrigger)
	-- /tap (Studio): the same handler by the piece's name (a chest by "Chest_<key>")
	local key = part:GetAttribute("ChestKey")
	triggers[if typeof(key) == "string" then `Chest_{key}` else part.Name] = function(player)
		if made.Enabled then
			onTrigger(player)
		end
	end
	return made
end

local function setPrompts(kind: string, enabled: boolean)
	for _, each in prompts[kind] do
		each.Enabled = enabled
	end
end

-- Chests ------------------------------------------------------------------------------------------------------

-- The cash and XP of the fight room before puzzle `kind` (its pack's elite pay), the puzzle chest's prize
local function roomPay(kind: string): (number, number)
	local room: any = nil
	for _, step in Dungeon.STEPS do
		if step.kind == kind then
			break
		elseif step.kind == "fight" then
			room = Dungeon.ROOMS[step.room :: number]
		end
	end
	if not room then
		return 0, 0
	end
	local each = CombatMath.getRewards(Wild, room.level, true)
	return math.round(each.cash * room.count), math.round(each.xp * room.count)
end

local function giveChest(player: Player, key: string)
	if key == "secret" then
		local prize = DungeonRules.secretPrize(BossService.HasFoundSecret(player), rng:NextNumber(), Dungeon.SECRET.MATERIAL_CHANCE)
		if prize == "title" and BossService.MarkSecretFound(player) then
			Remotes.DungeonChest:FireClient(player, { key = key, kind = "secret", title = Dungeon.SECRET.TITLE })
		elseif prize == "material" then
			ItemService.GiveItem(player, Dungeon.SECRET.MATERIAL, 1)
			Remotes.DungeonChest:FireClient(player, { key = key, kind = "secret", item = Dungeon.SECRET.MATERIAL, count = 1 })
		else
			EconomyService.AddCash(player, Dungeon.SECRET.CASH)
			Remotes.DungeonChest:FireClient(player, { key = key, kind = "secret", cash = Dungeon.SECRET.CASH })
		end
		return
	end
	-- the room's own pay: its cash, and its XP split over the party's creatures (a won room's XP is creature XP, far
	-- bigger than shop XP)
	local cash, xp = roomPay(key)
	EconomyService.AddCash(player, cash)
	local party = PartyService.GetParty(player)
	local ids = {}
	for slot = 1, Party.PARTY_SIZE do
		local beastId = if party then party.slots[slot] else nil
		if beastId then
			table.insert(ids, beastId)
		end
	end
	local each = if #ids > 0 then CombatMath.splitXp(xp, #ids) else 0
	for _, beastId in ids do
		CardService.AddXP(player, beastId, each, "fight")
	end
	Remotes.DungeonChest:FireClient(player, { key = key, kind = "puzzle", cash = cash, xp = each })
end

-- A chest at `spot` (its bottom's middle, front -Z): each run member opens it once
local function placeChest(key: string, spot: CFrame)
	chestOpens[key] = {}
	local width = Dungeon.CHEST.WIDTH
	local anchor = Instance.new("Part")
	anchor.Name = "DungeonChest"
	anchor.Anchored = true
	anchor.CanCollide = true
	anchor.Transparency = 1
	anchor.Size = Vector3.new(width, width * 0.74, width * 0.62)
	anchor.CFrame = spot * CFrame.new(0, anchor.Size.Y / 2, 0)
	anchor:SetAttribute("ChestKey", key)
	anchor.Parent = layout.spawn.Parent
	local open = prompt(anchor, "OpenChest", "Open", if key == "secret" then "Secret chest" else "Chest", function(player)
		if not hooks.canAct(player) or not near(player, anchor.Position) or not allowOpen(player) then
			return
		end
		if DungeonRules.once(chestOpens[key], player.UserId) then
			giveChest(player, key)
		end
	end)
	open.MaxActivationDistance = Dungeon.CHEST.DISTANCE
	open.Enabled = true
end

-- Solving -----------------------------------------------------------------------------------------------------

local function releasePost(player: Player)
	if posts[player] then
		posts[player] = nil
		PartyService.SetPost(player, nil)
	end
end

-- A puzzle sound at a piece, heard by everyone near (Config/Dungeon PUZZLE_SOUNDS; owner 2026-11-12: "sounds to
-- indicate what they're doing is right"); `pitch` raises a step that brings it closer
local function cue(at: BasePart, key: string, pitch: number?)
	local spec = (Dungeon.PUZZLE_SOUNDS :: any)[key]
	if not spec then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = spec.id
	sound.Volume = spec.volume
	sound.PlaybackSpeed = (spec.pitch or 1) * (pitch or 1)
	sound.RollOffMaxDistance = 160
	sound.Parent = at
	sound:Play()
	Debris:AddItem(sound, 6)
end

local function solve(kind: string)
	if solvedKinds[kind] then
		return
	end
	solvedKinds[kind] = true
	opened[kind] = false
	setPrompts(kind, false)
	if kind == "plates" then
		for player in table.clone(posts) do
			releasePost(player)
		end
	end
	local spot = if kind == "beams" then layout.beams.chestSpot elseif kind == "plates" then layout.plates.chestSpot else layout.lock.chestSpot
	placeChest(kind, spot)
	local door = if kind == "beams" then layout.beams.prism elseif kind == "plates" then layout.plates.door else layout.lock.door
	cue(door, "solved")
	hooks.solved(kind)
end

-- Prism beams -------------------------------------------------------------------------------------------------

-- The beam drawn along the traced path: one glowing bar per straight run, a spark where it ends
local function drawBeam(path: { BeamRules.Cell }, reached: boolean)
	beamFolder:ClearAllChildren()
	local beams = layout.beams
	local corners = { path[1] }
	for index = 2, #path - 1 do
		local before, here, after = path[index - 1], path[index], path[index + 1]
		if (here.x - before.x) ~= (after.x - here.x) or (here.y - before.y) ~= (after.y - here.y) then
			table.insert(corners, here)
		end
	end
	if #path > 1 then
		table.insert(corners, path[#path])
	end
	for index = 1, #corners - 1 do
		local from, to = beams.cellAt(corners[index].x, corners[index].y), beams.cellAt(corners[index + 1].x, corners[index + 1].y)
		local bar = Instance.new("Part")
		bar.Name = "Beam"
		bar.Anchored = true
		bar.CanCollide = false
		bar.CanQuery = false
		bar.CanTouch = false
		bar.CastShadow = false
		bar.Material = Enum.Material.Neon
		bar.Color = BEAM_COLOR
		bar.Transparency = 0.15
		bar.Size = Vector3.new(0.45, 0.45, (to - from).Magnitude)
		bar.CFrame = CFrame.lookAt((from + to) / 2, to)
		bar.Parent = beamFolder
	end
	if not reached and #path > 0 then
		local last = path[#path]
		local spark = Instance.new("Part")
		spark.Name = "BeamSpark"
		spark.Anchored = true
		spark.CanCollide = false
		spark.CanQuery = false
		spark.Transparency = 1
		spark.Size = Vector3.one
		spark.CFrame = CFrame.new(beams.cellAt(last.x, last.y))
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(BEAM_COLOR)
		emitter.LightEmission = 1
		emitter.Rate = 14
		emitter.Lifetime = NumberRange.new(0.3, 0.6)
		emitter.Speed = NumberRange.new(2, 5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new(0.4, 0)
		emitter.Parent = spark
		spark.Parent = beamFolder
	end
end

local function retrace(): BeamRules.Trace
	local beams = layout.beams
	local traced = BeamRules.trace(beams.layout, facings)
	local cells = {}
	for _, cell in traced.path do
		table.insert(cells, `{cell.x},{cell.y}`)
	end
	beams.gem:SetAttribute("Path", table.concat(cells, ";"))
	beams.gem:SetAttribute("Reached", traced.reached)
	beams.prism:SetAttribute("Lit", traced.reached)
	DungeonBuilder.tint(beams.prism, nil, if traced.reached then 0 else 0.35)
	-- its target marks (column, sparkles, label) only while the beam hasn't reached it
	for _, name in { "TargetColumn", "TargetSparkles", "TargetLabel" } do
		local mark = beams.prism:FindFirstChild(name, true)
		if mark and (mark:IsA("Beam") or mark:IsA("ParticleEmitter") or mark:IsA("BillboardGui")) then
			mark.Enabled = not traced.reached
		end
	end
	drawBeam(traced.path, traced.reached)
	if traced.reached then
		solve("beams")
	end
	return traced
end

local function turnMirror(player: Player, index: number)
	local mirror = layout.beams.mirrors[index]
	if not mirror or not mayWork(player, "beams", mirror.Position, allowTurn) then
		return
	end
	local before = #BeamRules.trace(layout.beams.layout, facings).path
	facings[index] = BeamRules.turn(facings[index])
	mirror.CFrame = DungeonBuilder.facingCFrame(mirror.Position, facings[index])
	mirror:SetAttribute("Facing", facings[index])
	local traced = retrace()
	cue(mirror, "turn")
	if traced.reached then
		cue(layout.beams.prism, "lit")
	elseif #traced.path > before then
		cue(mirror, "closer", 1 + #traced.path * 0.05) -- the light went further: a rising chime
	end
end

-- Weight plates -----------------------------------------------------------------------------------------------

local function plateBox(plate: BasePart): PlateRules.Box
	return { x = plate.Position.X, z = plate.Position.Z, half = plate.Size.X / 2 }
end

local function checkPlates()
	local active = hooks.active()
	local needed = PlateRules.needed(plateCount, #active)
	local points: { PlateRules.Point } = {}
	for _, player in active do
		local root = rootOf(player)
		if root then
			table.insert(points, { x = root.Position.X, z = root.Position.Z })
		end
	end
	for player in table.clone(posts) do
		local marker = PartyService.GetMarker(player)
		if not hooks.canAct(player) or not marker or not marker:GetAttribute("Posted") then
			releasePost(player) -- out, gone, unsummoned or resummoned: the plate rises
		else
			table.insert(points, { x = marker.Position.X, z = marker.Position.Z })
		end
	end
	local held: { boolean } = {}
	for index, plate in layout.plates.plates do
		local box = plateBox(plate)
		local on = false
		for _, point in points do
			if PlateRules.inside(box, point) then
				on = true
				break
			end
		end
		held[index] = on and index <= plateCount
		local used = index <= needed
		if used and held[index] ~= (plate:GetAttribute("Held") == true) then
			cue(plate, if held[index] then "plateOn" else "plateOff")
		end
		plate:SetAttribute("Held", held[index])
		plate:SetAttribute("Needed", used)
		DungeonBuilder.tint(plate, if held[index] then HELD_COLOR else IDLE_COLOR, if used then 0 else 0.7)
		local each = prompts.plates[index]
		if each then
			each.Enabled = used and opened.plates == true
		end
	end
	if PlateRules.open(held, needed) then
		solve("plates")
	end
end

local function sendCreature(player: Player, index: number)
	local plate = layout.plates.plates[index]
	if not mayWork(player, "plates", plate.Position, allowSend) then
		return
	end
	if posts[player] == index then
		releasePost(player)
		notify(player, "Your creature comes back to you.", false)
		return
	end
	if not PartyService.GetMarker(player) then
		notify(player, "Summon a creature first!", true)
		return
	end
	posts[player] = index
	PartyService.SetPost(player, CFrame.new(plate.Position + Vector3.new(0, plate.Size.Y / 2, 0)))
end

-- The secret wall ---------------------------------------------------------------------------------------------

local function tapWall(player: Player)
	local wall = layout.plates.wall
	if wall:GetAttribute("Open") or not hooks.canAct(player) or not reached.plates or not near(player, wall.Position) or not allowTap(player) then
		return
	end
	wallTaps += 1
	wall:SetAttribute("Taps", wallTaps)
	DungeonBuilder.tint(wall, nil, math.max(0, 0.3 - 0.1 * wallTaps)) -- its cracks glow brighter
	if wallTaps < Dungeon.SECRET.TAPS then
		return
	end
	wall:SetAttribute("Open", true)
	DungeonBuilder.hide(wall)
	if wallPrompt then
		wallPrompt.Enabled = false
	end
	placeChest("secret", layout.plates.secretSpot)
end

-- The element lock --------------------------------------------------------------------------------------------

local function showLock()
	for index, socket in layout.lock.sockets do
		local lit = index <= lockProgress
		socket:SetAttribute("Lit", lit)
		socket.Transparency = if lit then 0 else 0.7
	end
end

local function strike(player: Player, element: string)
	local piece = layout.lock.crystals[element]
	if not piece or not mayWork(player, "lock", piece.Position, allowStrike) then
		return
	end
	local progress, result = LockRules.strike(lockProgress, element, lockOrder)
	lockProgress = progress
	showLock()
	if result == "wrong" then
		cue(piece, "wrong")
		local door = layout.lock.door
		door:SetAttribute("Wrong", ((door:GetAttribute("Wrong") :: number?) or 0) + 1)
		for _, socket in layout.lock.sockets do
			socket.Color = WRONG_COLOR
			socket.Transparency = 0.2
		end
		task.delay(WRONG_FLASH, function()
			for _, socket in layout.lock.sockets do
				local index = table.find(layout.lock.sockets, socket) :: number
				socket.Color = layout.lock.crystals[lockOrder[index]].Color
			end
			showLock()
		end)
	elseif result == "done" then
		cue(piece, "right", 1.5)
		solve("lock")
	else
		cue(piece, "right", 1 + progress * 0.12) -- each right crystal a note higher
	end
end

-- API ---------------------------------------------------------------------------------------------------------

-- Builds every piece's prompt (all off until its puzzle opens); DungeonService calls it once
function DungeonPuzzleService.Start(cavern: DungeonBuilder.DungeonLayout, runHooks: Hooks)
	layout = cavern
	hooks = runHooks
	beamFolder = Instance.new("Folder")
	beamFolder.Name = "BeamDraw"
	beamFolder.Parent = layout.spawn.Parent
	for index, mirror in layout.beams.mirrors do
		facings[index] = layout.beams.layout.mirrors[index].facing
		table.insert(prompts.beams, prompt(mirror, "TurnMirror", "Turn", "Crystal mirror", function(player)
			turnMirror(player, index)
		end))
	end
	for index, plate in layout.plates.plates do
		table.insert(prompts.plates, prompt(plate, "SendCreature", "Send creature", "Stone plate", function(player)
			sendCreature(player, index)
		end))
	end
	wallPrompt = prompt(layout.plates.wall, "BreakWall", "Break", "Cracked wall", tapWall)
	lockOrder = LockRules.order(Bosses.BOSSES[Dungeon.BOSS].phases)
	for element, piece in layout.lock.crystals do
		table.insert(prompts.lock, prompt(piece, "StrikeCrystal", "Strike", `{element} crystal`, function(player)
			strike(player, element)
		end))
	end
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < Dungeon.PLATES.CHECK_EVERY then
			return
		end
		since = 0
		if opened.plates and not solvedKinds.plates then
			checkPlates()
		end
	end)
end

-- The run reached puzzle `kind`: its pieces work from now on
function DungeonPuzzleService.Open(kind: string)
	if solvedKinds[kind] or not prompts[kind] then
		return
	end
	opened[kind] = true
	reached[kind] = true
	setPrompts(kind, true)
	if kind == "beams" then
		retrace()
	elseif kind == "plates" then
		plateCount = PlateRules.count(hooks.runSize(), Dungeon.PLATES)
		if wallPrompt then
			wallPrompt.Enabled = true
		end
		checkPlates()
	elseif kind == "lock" then
		showLock()
	end
end

-- Studio only (/puzzle solve): puzzle `kind` solved at once, its chest and all
function DungeonPuzzleService.Solve(kind: string)
	if not RunService:IsStudio() or not prompts[kind] then
		return
	end
	if kind == "beams" then
		DungeonBuilder.tint(layout.beams.prism, nil, 0)
		layout.beams.prism:SetAttribute("Lit", true)
	elseif kind == "lock" then
		lockProgress = #lockOrder
		showLock()
	end
	solve(kind)
end

-- Studio only (/tap <piece>): what pressing that piece's prompt does (Mirror1, Plate2, SecretWall, LockCrystal_Tide,
-- Chest_beams...), every check included; false when there's no such piece or its prompt is off
function DungeonPuzzleService.Tap(player: Player, name: string): boolean
	local handler = triggers[name]
	if not RunService:IsStudio() or not handler then
		return false
	end
	handler(player)
	return true
end

-- A player leaves the run (out or gone): their creature leaves its plate
function DungeonPuzzleService.Release(player: Player)
	releasePost(player)
end

return DungeonPuzzleService
