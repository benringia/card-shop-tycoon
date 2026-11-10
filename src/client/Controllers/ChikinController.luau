--!strict
-- Chikin's combat tutorial on this client (spec docs/superpowers/specs/2026-11-10-chikin-combat-tutorial-design.md):
-- while the server says a step is on (player attribute CombatStep, CombatTutorialService), this player's own Chikin (a
-- marker only this client has, drawn by Util/PishVisual as "Chikin") leads them, reusing Pish's pieces: his arrival
-- (Util/DogArrival, after Pish has gone), the talk card (Util/TutorialTalk with his face), the paw, ring and trail
-- (Util/TutorialCues), the small Skip and the tour card. In a wild fight his card moves to the top and his tips go one
-- at a time with the paw on the combat button (Pet, or Attack, Dodge and Skill once there's a sword); a tip moves on
-- once used or after FIGHT_TIP_SECONDS. His hellos and goodbyes end on their last Next ("next" to the server).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Chikin = require(Config:WaitForChild("Chikin"))
local ChikinTalk = require(Config:WaitForChild("ChikinTalk"))
local WildValleyConfig = require(Config:WaitForChild("WildValley"))
local Wild = require(Config:WaitForChild("Wild"))
local Music = require(Config:WaitForChild("Music"))
local Town = require(Config:WaitForChild("Town"))
local MusicRules = require(Shared:WaitForChild("Util"):WaitForChild("MusicRules"))
local TalkRules = require(Shared:WaitForChild("Util"):WaitForChild("TalkRules"))
local TutorialRules = require(Shared:WaitForChild("Util"):WaitForChild("TutorialRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local DogArrival = require(ClientUtil:WaitForChild("DogArrival"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local OpeningStage = require(ClientUtil:WaitForChild("OpeningStage"))
local PishVisual = require(ClientUtil:WaitForChild("PishVisual"))
local TutorialCues = require(ClientUtil:WaitForChild("TutorialCues"))
local TutorialTalk = require(ClientUtil:WaitForChild("TutorialTalk"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local BattleController = require(Controllers:WaitForChild("BattleController"))
local WeaponRevealController = require(Controllers:WaitForChild("WeaponRevealController"))

local ChikinController = {}

local NAME = "Chikin"
local BESIDE = 3.5 -- studs to the player's left he walks (Pish takes the right)
local TROT = 8 -- studs a second
local FAR = 60 -- studs: further than this (a portal trip) he's simply beside the player again
local SPOT_HEIGHT = 9 -- studs above the ground the paw over a place in town hangs
local TRAIL_REFRESH = 8 -- studs the player moves before the trail is redrawn
local HANDOVER_WAIT = 2.5 -- seconds after Pish has gone before Chikin runs in
local LEAVE_DELAY = 3 -- seconds after a goodbye before he's gone (the next visit straight on keeps him)
local PORTAL = Wild.PLAZA_PORTAL
local WARDEN = WildValleyConfig.BIOMES[1]

type Target = { gui: GuiObject?, part: BasePart?, spot: Vector3? }

local player = Players.LocalPlayer
local step = ""
local introIndex = 1
local marker: Part? = nil
local visual: PishVisual.Visual? = nil
local arriving = false
local cue: (() -> ())? = nil
local cueKey = ""
local cueTarget: Instance? = nil
local trailRemover: (() -> ())? = nil
local trailFrom: Vector3? = nil
local spotAnchor: Part? = nil
local nextSent = false
local leaveToken = 0 -- a goodbye's run-off, cancelled when the next visit starts straight away
-- The fight's tips: which one is on, since when, and whether the last one has been seen through
local tipIndex = 0
local tipStarted = 0
local tipsDone = false
local tipUsed = false
local tipPress: RBXScriptConnection? = nil -- the shown tip's button, to know it was tapped

local function root(): BasePart?
	local character = player.Character
	local part = character and character:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

local function visitOf(stepId: string): (number, number)
	for number, steps in Chikin.VISITS do
		local index = table.find(steps, stepId)
		if index then
			return number, index
		end
	end
	return 0, 0
end

local function shown(gui: Instance?): boolean
	local at = gui
	while at and at:IsA("GuiObject") do
		if not at.Visible then
			return false
		end
		at = at.Parent
	end
	return gui ~= nil
end

local function mainGui(): Instance?
	local gui = player:FindFirstChild("PlayerGui")
	return gui and gui:FindFirstChild("MainGui")
end

-- A window open that this step doesn't use, and its X
local function windowInTheWay(allowed: { [string]: boolean }): GuiObject?
	for _, panel in UIKit.openPanelList() do
		if not allowed[panel.Name] and shown(panel) then
			local close = panel:FindFirstChild("Close", true)
			return if close and close:IsA("GuiObject") then close else panel
		end
	end
	return nil
end

-- The card view's "Add to party" button while it shows
local function addToParty(): GuiObject?
	local gui = mainGui()
	local view = gui and gui:FindFirstChild("CardDetail", true)
	if not view then
		return nil
	end
	for _, item in view:GetDescendants() do
		if (item:IsA("TextLabel") or item:IsA("TextButton")) and item.Text == "Add to party" and shown(item) then
			local button = if item:IsA("GuiButton") then item else item:FindFirstAncestorWhichIsA("GuiButton")
			return button or item
		end
	end
	return nil
end

-- The nearest wild monster not already fighting
local function nearestMonster(): BasePart?
	local folder = workspace:FindFirstChild("Monsters")
	local at = root()
	if not folder or not at then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, item in folder:GetChildren() do
		if item:IsA("BasePart") and item:GetAttribute("Fighting") ~= true then
			local distance = (item.Position - at.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = item, distance
			end
		end
	end
	return best
end

local function spot(at: Vector3): Part
	local made = spotAnchor
	if made and made.Parent and made.Position == at then
		return made
	end
	if made then
		made:Destroy()
	end
	local anchor = Instance.new("Part")
	anchor.Name = "ChikinSpot"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = at
	anchor.Parent = workspace
	spotAnchor = anchor
	return anchor
end

-- What the player is at in this step (Config/ChikinTalk `now` lines) and where Chikin points
local function situation(stepId: string): (string, Target)
	if stepId == "party" then
		local add = addToParty()
		if add then
			return "cardOpen", { gui = add }
		end
		local inTheWay = windowInTheWay({ Binder = true })
		if inTheWay then
			return "closeWindow", { gui = inTheWay }
		end
		local gui = mainGui()
		local binder = gui and gui:FindFirstChild("Binder", true)
		if binder and shown(binder) then
			return "binderOpen", {}
		end
		return "default", { gui = Hud.find("Cards") }
	elseif stepId == "summon" then
		local inTheWay = windowInTheWay({})
		if inTheWay then
			return "closeWindow", { gui = inTheWay }
		end
		local gui = mainGui()
		local slot = gui and gui:FindFirstChild("Slot1", true)
		return "default", { gui = if slot and slot:IsA("GuiObject") then slot else nil }
	elseif stepId == "wild" or stepId == "wild2" then
		return "default", { spot = Vector3.new(PORTAL.x, PORTAL.y + SPOT_HEIGHT, PORTAL.z) }
	elseif stepId == "fight" or stepId == "fight2" then
		return "default", { part = nearestMonster() }
	elseif stepId == "boss" then
		local ground = WARDEN.ground or 0
		return "default", { spot = Vector3.new(WARDEN.portal.x, ground + SPOT_HEIGHT, WARDEN.portal.z) }
	end
	return "default", {}
end

local function clearCue()
	if cue then
		cue()
		cue = nil
	end
	cueKey = ""
	cueTarget = nil
	if trailRemover then
		trailRemover()
		trailRemover = nil
	end
	trailFrom = nil
end

local function play(clip: string)
	if visual then
		PishVisual.play(visual, clip)
	end
end

local function ensureDog()
	if marker then
		return
	end
	local at = root()
	local made = Instance.new("Part")
	made.Name = "TutorialChikin"
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.Transparency = 1
	made.Size = Vector3.new(2, 2, 2)
	local start = if at then at.Position - at.CFrame.RightVector * BESIDE - Vector3.new(0, 3, 0) else Vector3.zero
	made.CFrame = CFrame.new(start)
	made.Parent = workspace
	marker = made
	visual = PishVisual.new(made, NAME)
	if visual then
		PishVisual.nameTag(visual, nil)
	end
end

local function removeDog()
	clearCue()
	if visual then
		PishVisual.destroy(visual)
		visual = nil
	end
	if marker then
		marker:Destroy()
		marker = nil
	end
	if spotAnchor then
		spotAnchor:Destroy()
		spotAnchor = nil
	end
end

-- His tips in a fight, by visit: the creature fights by itself and the Pet move; the sword's Attack, Dodge and Skill
local function fightTips(): { { key: string, button: string, input: { Enum.KeyCode | Enum.UserInputType } } }
	if step == "fight2" then
		return {
			{ key = "attack", button = "attack", input = { Enum.UserInputType.MouseButton1 } },
			{ key = "dodge", button = "dodge", input = { Enum.KeyCode.LeftShift } },
			{ key = "skill", button = "skill", input = { Enum.KeyCode.E } },
		}
	end
	return {
		{ key = "creature", button = "", input = {} },
		{ key = "pet", button = "pet", input = { Enum.KeyCode.R } },
	}
end

local function combatButton(name: string): GuiObject?
	local gui = mainGui()
	local hud = gui and gui:FindFirstChild("CombatHud", true)
	local button = hud and hud:FindFirstChild(name, true)
	return if button and button:IsA("GuiObject") and shown(button) then button else nil
end

-- A tip's words: the key or click version on a keyboard without touch, else the tap version
local function tipLine(key: string, button: GuiObject?): string
	local keys = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
	if key == "attack" and not button then
		return ChikinTalk.FIGHT.attackClick
	elseif keys and ChikinTalk.FIGHT[key .. "Key"] then
		return ChikinTalk.FIGHT[key .. "Key"]
	end
	return ChikinTalk.FIGHT[key]
end

local function showCue(key: string, target: Target)
	local at = root()
	local part = target.part or (if target.spot then spot(target.spot) else nil)
	local thing: Instance? = target.gui or part
	if key ~= cueKey or thing ~= cueTarget then
		if cue then
			cue()
			cue = nil
		end
		cueKey, cueTarget = key, thing
		if tipPress then
			tipPress:Disconnect()
			tipPress = nil
		end
		-- A fight tip's button tapped (phones) counts as using it (final review M2)
		local button = target.gui
		if button and button:IsA("GuiButton") and string.sub(key, 1, 4) == "tip:" then
			tipPress = button.Activated:Connect(function()
				tipUsed = true
			end)
		end
		if target.gui then
			cue = TutorialCues.pawOn(target.gui)
		elseif part then
			cue = TutorialCues.pawOn(part)
		end
		if thing and marker then
			play("point")
		end
	end
	-- The paw trail to a place in the world, redrawn as the player walks
	if part and at then
		local from = at.Position - Vector3.new(0, 3, 0)
		if not trailFrom or (from - trailFrom).Magnitude > TRAIL_REFRESH or not trailRemover then
			if trailRemover then
				trailRemover()
			end
			trailFrom = from
			trailRemover = TutorialCues.trail(from, Vector3.new(part.Position.X, from.Y, part.Position.Z))
		end
	elseif trailRemover then
		trailRemover()
		trailRemover = nil
		trailFrom = nil
	end
end

-- In a fight: his card at the top, one tip at a time with the paw on its button
local function updateFight()
	TutorialTalk.atTop(true)
	if trailRemover then
		trailRemover()
		trailRemover = nil
		trailFrom = nil
	end
	local tips = fightTips()
	if tipIndex == 0 then
		tipIndex, tipStarted, tipsDone, tipUsed = 1, os.clock(), false, false
	end
	if tipsDone then
		TutorialTalk.hide()
		clearCue()
		return
	end
	local tip = tips[tipIndex]
	local limit = if tipIndex == 1 then Chikin.FIRST_TIP_SECONDS else Chikin.FIGHT_TIP_SECONDS
	if tipUsed or os.clock() - tipStarted >= limit then
		tipIndex += 1
		tipStarted, tipUsed = os.clock(), false
		if tipIndex > #tips then
			tipsDone = true
			return
		end
		tip = tips[tipIndex]
	end
	local button = if tip.button ~= "" then combatButton(tip.button) else nil
	TutorialTalk.speaker(NAME)
	TutorialTalk.say(tipLine(tip.key, button), Chikin.STEP_ICONS[step], nil, nil)
	showCue("tip:" .. tip.key, { gui = button })
end

-- His line for the step: his intro one line at a time with Next, then the line for now; a hello or goodbye ends on
-- its last Next (the first fight's end says the lost lines when it wasn't won)
local function updateTalk(situationName: string)
	local talk = ChikinTalk.STEPS[step]
	if not talk then
		return
	end
	if step == "firstWin" then
		local result = player:GetAttribute("ChikinFightResult")
		local lost = result == "lose" or result == "run" or result == "timeout" -- unknown after a rejoin: the cheerful lines
		local lines = table.clone(if lost then ChikinTalk.LOST else talk.intro)
		-- Already at shop level 4: the sword's visit comes straight on, so no "come back at level 4"
		if (player:GetAttribute("Level") or 1) >= Chikin.SWORD_LEVEL then
			lines[#lines] = ChikinTalk.SWORD_NOW
		end
		talk = { intro = lines, now = {} }
	end
	TutorialTalk.atTop(false)
	if TutorialCues.isTourCardOpen() then
		TutorialTalk.hide()
		return
	end
	-- A sword fight lost or run from: the step stays and he cheers them on (until the next fight starts)
	local result = player:GetAttribute("ChikinFightResult")
	if Chikin.WIN_TO_PASS[step] and typeof(result) == "string" and result ~= "win" then
		TutorialTalk.speaker(NAME)
		TutorialTalk.say(ChikinTalk.RETRY, Chikin.STEP_ICONS[step], nil, nil)
		return
	end
	local line = TalkRules.show(talk, introIndex, situationName)
	local label = if not line.next then nil
		elseif not line.finish then ChikinTalk.NEXT
		elseif Chikin.BYE_STEPS[step] and not (step == "firstWin" and (player:GetAttribute("Level") or 1) >= Chikin.SWORD_LEVEL)
			then ChikinTalk.BYE
		else ChikinTalk.GO
	TutorialTalk.speaker(NAME)
	TutorialTalk.say(line.text, Chikin.STEP_ICONS[step], label, function()
		if line.finish then
			if not nextSent then
				nextSent = true
				Remotes.CombatTutorialAction:FireServer("next")
			end
			return
		end
		introIndex += 1
	end)
end

local function openTourCard()
	if visual then
		PishVisual.sound(visual, "whimper")
		PishVisual.play(visual, "headTilt")
	end
	local number, index = visitOf(step)
	local steps = Chikin.VISITS[number] or {}
	TutorialCues.tourCard(math.max(0, index - 1), #steps, function() end, function()
		Remotes.CombatTutorialAction:FireServer("skip")
	end, { tour = ChikinTalk.LABELS.tour, tourGift = ChikinTalk.LABELS.tourGift, icon = "Sword" })
end

-- He walks beside the player on their left (beside a fight's monster he stays with them); a far jump (a portal trip)
-- puts him beside them again
local function follow(dt: number)
	local dog = marker
	local at = root()
	if not dog or not at or arriving then
		return
	end
	local feet = at.Position - Vector3.new(0, 3, 0)
	local goal = feet - at.CFrame.RightVector * BESIDE
	local here = dog.Position
	local flat = Vector3.new(goal.X - here.X, 0, goal.Z - here.Z)
	if flat.Magnitude > FAR then
		dog.CFrame = CFrame.new(goal)
		return
	end
	if flat.Magnitude > 0.3 then
		local nextAt = Vector3.new(here.X, goal.Y, here.Z) + flat.Unit * math.min(flat.Magnitude, TROT * dt)
		dog.CFrame = CFrame.lookAt(nextAt, nextAt + flat.Unit)
	else
		local look = Vector3.new(at.Position.X, here.Y, at.Position.Z)
		if (look - here).Magnitude > 0.1 then
			dog.CFrame = CFrame.lookAt(here, look)
		end
	end
end

local function leading(): boolean
	return step ~= "" and step ~= Chikin.WAIT_STEP
end

-- Focus mode (the owner 2026-11-11): while he leads in town the HUD shows only what his step uses (Config/Chikin
-- FOCUS); the Wild and no tour let it go
local function updateFocus()
	local at = root()
	local inTown = at ~= nil and MusicRules.inTown(at.Position.X, at.Position.Z, Town.BOUNDS, Music.TOWN.margin)
	Hud.setFocus("chikin", TutorialRules.chikinFocus(step, inTown, Chikin.FOCUS, Chikin.WAIT_STEP))
end

local function arrive()
	arriving = true
	TutorialTalk.hide()
	TutorialCues.skipButton(false, openTourCard)
	-- Pish says goodbye and runs off first, or finishes a lesson visit (the two dogs are never on screen together), and
	-- nothing else has the screen: a window (the first-sword popup), a weapon reveal, a pack opening (final review C1, M4)
	local function blocked(): boolean
		return (player:GetAttribute("TutorialStep") or "") ~= ""
			or workspace:FindFirstChild("TutorialPish") ~= nil
			or player:GetAttribute("LoadingDone") ~= true
			or UIKit.anyPanelOpen()
			or WeaponRevealController.IsPlaying()
			or OpeningStage.isShown()
	end
	repeat
		while blocked() and leading() do
			task.wait(0.25)
		end
		task.wait(HANDOVER_WAIT)
	until not blocked() or not leading()
	local at = root()
	if not at or not leading() then
		arriving = false
		return
	end
	ensureDog()
	DogArrival.run(at, marker :: Part, visual, player.Character, function()
		play("bark")
	end, function()
		arriving = false
		if not leading() then
			removeDog() -- his step ended while he ran in (Pish's tour replayed, a skip): he goes
			return
		end
		TutorialCues.skipButton(true, openTourCard)
	end)
end

local function onStep()
	local value = player:GetAttribute("CombatStep")
	local nextStep = if typeof(value) == "string" then value else ""
	if nextStep == step then
		return
	end
	local before = step
	step = nextStep
	introIndex = 1
	nextSent = false
	tipIndex, tipsDone = 0, false
	clearCue()
	updateFocus()
	if not leading() then
		TutorialTalk.atTop(false)
		TutorialTalk.hide()
		TutorialCues.skipButton(false, openTourCard)
		TutorialCues.closeTourCard()
		if marker and not arriving then
			play("celebrate")
			leaveToken += 1
			local token = leaveToken
			task.delay(LEAVE_DELAY, function()
				if token == leaveToken and not leading() then
					removeDog()
				end
			end)
		end
		return
	end
	leaveToken += 1 -- a visit going on (or starting straight after the last): he stays
	-- A visit starts: he runs in (after Pish has gone); otherwise a little hop for a step done
	local _, index = visitOf(step)
	if (before == "" or before == Chikin.WAIT_STEP) and not marker and not arriving then
		task.spawn(arrive)
		return
	end
	ensureDog()
	TutorialCues.skipButton(true, openTourCard)
	if marker and before ~= "" then
		TutorialCues.sparkle(marker.Position + Vector3.new(0, Chikin.HEIGHT, 0))
		play("happyHop")
	end
end

function ChikinController.Start()
	if workspace:GetAttribute("PlaceKind") ~= "Main" then
		return
	end
	player:GetAttributeChangedSignal("CombatStep"):Connect(onStep)
	-- A tip in a fight is used when its button or key is
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if tipIndex == 0 or tipsDone then
			return
		end
		if gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			return -- a click on a window or button isn't a sword swing
		end
		local tip = fightTips()[tipIndex]
		if not tip then
			return
		end
		for _, used in tip.input do
			if input.KeyCode == used or input.UserInputType == used then
				tipUsed = true
			end
		end
	end)
	local tick = 0
	RunService.RenderStepped:Connect(function(dt)
		if visual then
			PishVisual.step(visual, dt)
		end
		if arriving or not leading() then
			return
		end
		follow(dt)
		tick += dt
		if tick < 0.3 then
			return
		end
		tick = 0
		updateFocus() -- in town or out in the Wild
		-- A pack opening or a weapon reveal has the screen: he waits quietly; in a fight his tips go on
		local busy = OpeningStage.isShown() or WeaponRevealController.IsPlaying()
		TutorialCues.quiet("chikin", busy)
		if busy then
			return
		end
		local fighting = BattleController.IsFighting()
		if fighting and (step == "fight" or step == "fight2") then
			updateFight()
			return
		end
		tipIndex = 0
		local situationName, target = situation(step)
		local talk = ChikinTalk.STEPS[step]
		local line = if talk then TalkRules.show(talk, introIndex, situationName) else nil
		if line and line.next and step ~= "boss" then
			clearCue() -- no pointing while he's saying hello (his goodbye at the boss points at its portal all along)
		else
			showCue(step .. ":" .. situationName, target)
		end
		updateTalk(situationName)
	end)
	onStep()
end

return ChikinController
