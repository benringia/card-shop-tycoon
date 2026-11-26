--!strict
-- Client entry point. Starts each controller; UIController first since others build on its ScreenGui.
local Controllers = script:WaitForChild("Controllers")

-- Phones stay in landscape (either way up): every window, the binder and the pack opening are laid out for it; in
-- portrait they shrank to a strip (owner 2026-11-17: "make sure nothing is cutoff/overlapping on all devices"). Set
-- again whenever it changes: a respawn copies the place's StarterGui setting (Sensor) back
do
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local function landscape()
		if playerGui.ScreenOrientation ~= Enum.ScreenOrientation.LandscapeSensor then
			playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
		end
	end
	landscape()
	playerGui:GetPropertyChangedSignal("ScreenOrientation"):Connect(landscape)
end

local LoadingController = require(Controllers:WaitForChild("LoadingController"))
local UIController = require(Controllers:WaitForChild("UIController"))
local OrderController = require(Controllers:WaitForChild("OrderController"))
local PlacementController = require(Controllers:WaitForChild("PlacementController"))
local BuildController = require(Controllers:WaitForChild("BuildController"))
local PricingController = require(Controllers:WaitForChild("PricingController"))
local PriceTagController = require(Controllers:WaitForChild("PriceTagController"))
local ShelfInfoController = require(Controllers:WaitForChild("ShelfInfoController"))
local ButterflyController = require(Controllers:WaitForChild("ButterflyController"))
local DayCycleController = require(Controllers:WaitForChild("DayCycleController"))
local TreeSwayController = require(Controllers:WaitForChild("TreeSwayController"))
local TownCritterController = require(Controllers:WaitForChild("TownCritterController"))
local TownPishController = require(Controllers:WaitForChild("TownPishController"))
local TownChikinController = require(Controllers:WaitForChild("TownChikinController"))
local TurtsController = require(Controllers:WaitForChild("TurtsController"))
local BinderPoseController = require(Controllers:WaitForChild("BinderPoseController"))
local TutorialController = require(Controllers:WaitForChild("TutorialController"))
local ChikinController = require(Controllers:WaitForChild("ChikinController"))
local PlazaNpcController = require(Controllers:WaitForChild("PlazaNpcController"))
local FountainFxController = require(Controllers:WaitForChild("FountainFxController"))
local PortalFxController = require(Controllers:WaitForChild("PortalFxController"))
local WelcomeController = require(Controllers:WaitForChild("WelcomeController"))
local PrologueController = require(Controllers:WaitForChild("PrologueController"))
local CondenserFxController = require(Controllers:WaitForChild("CondenserFxController"))
local CaseSpinController = require(Controllers:WaitForChild("CaseSpinController"))
local DecorSpinController = require(Controllers:WaitForChild("DecorSpinController"))
local WindowController = require(Controllers:WaitForChild("WindowController"))
local WorkerVisualController = require(Controllers:WaitForChild("WorkerVisualController"))
local LevelUpController = require(Controllers:WaitForChild("LevelUpController"))
local RegisterController = require(Controllers:WaitForChild("RegisterController"))
local RegisterStationController = require(Controllers:WaitForChild("RegisterStationController"))
local CarryController = require(Controllers:WaitForChild("CarryController"))
local PackOpeningController = require(Controllers:WaitForChild("PackOpeningController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))
local ShowcaseController = require(Controllers:WaitForChild("ShowcaseController"))
local CardBuyController = require(Controllers:WaitForChild("CardBuyController"))
local CondenserController = require(Controllers:WaitForChild("CondenserController"))
local ForgeController = require(Controllers:WaitForChild("ForgeController"))
local GradingController = require(Controllers:WaitForChild("GradingController"))
local JobsController = require(Controllers:WaitForChild("JobsController"))
local PartyController = require(Controllers:WaitForChild("PartyController"))
local BuffController = require(Controllers:WaitForChild("BuffController"))
local PartyBarController = require(Controllers:WaitForChild("PartyBarController"))
local CardEffectsController = require(Controllers:WaitForChild("CardEffectsController"))
local AnnouncementController = require(Controllers:WaitForChild("AnnouncementController"))
local CreatureController = require(Controllers:WaitForChild("CreatureController"))
local CustomerController = require(Controllers:WaitForChild("CustomerController"))
local RatingController = require(Controllers:WaitForChild("RatingController"))
local MonsterController = require(Controllers:WaitForChild("MonsterController"))
local BattleController = require(Controllers:WaitForChild("BattleController"))
local MovePreviewController = require(Controllers:WaitForChild("MovePreviewController"))
local BossBoardController = require(Controllers:WaitForChild("BossBoardController"))
local LootController = require(Controllers:WaitForChild("LootController"))
local AdminPanelController = require(Controllers:WaitForChild("AdminPanelController"))
local ChallengeController = require(Controllers:WaitForChild("ChallengeController"))
local ArenaWatchController = require(Controllers:WaitForChild("ArenaWatchController"))
local FrontierController = require(Controllers:WaitForChild("FrontierController"))
local FrontierRevealController = require(Controllers:WaitForChild("FrontierRevealController"))
local FrontierFxController = require(Controllers:WaitForChild("FrontierFxController"))
local WeaponRevealController = require(Controllers:WaitForChild("WeaponRevealController"))
local SoundscapeController = require(Controllers:WaitForChild("SoundscapeController"))
local TownNightController = require(Controllers:WaitForChild("TownNightController"))
local TownDressController = require(Controllers:WaitForChild("TownDressController"))
local BossChestController = require(Controllers:WaitForChild("BossChestController"))
local DungeonController = require(Controllers:WaitForChild("DungeonController"))
local DungeonPuzzleController = require(Controllers:WaitForChild("DungeonPuzzleController"))
local DungeonObjectiveController = require(Controllers:WaitForChild("DungeonObjectiveController"))
local DungeonIntroController = require(Controllers:WaitForChild("DungeonIntroController"))
local DungeonAmbienceController = require(Controllers:WaitForChild("DungeonAmbienceController"))
local DungeonFallController = require(Controllers:WaitForChild("DungeonFallController"))
local DungeonCinematicController = require(Controllers:WaitForChild("DungeonCinematicController"))
local DungeonRegionController = require(Controllers:WaitForChild("DungeonRegionController"))
local TitleController = require(Controllers:WaitForChild("TitleController"))
local SupportController = require(Controllers:WaitForChild("SupportController"))
local ThanksController = require(Controllers:WaitForChild("ThanksController"))
local ReviewsController = require(Controllers:WaitForChild("ReviewsController"))
local StoreController = require(Controllers:WaitForChild("StoreController"))
local StoreWinController = require(Controllers:WaitForChild("StoreWinController"))
local GiftController = require(Controllers:WaitForChild("GiftController"))
local QuestController = require(Controllers:WaitForChild("QuestController"))
local EventController = require(Controllers:WaitForChild("EventController"))
local WelcomeBackController = require(Controllers:WaitForChild("WelcomeBackController"))
local BulkOpenController = require(Controllers:WaitForChild("BulkOpenController"))
local RecyclerController = require(Controllers:WaitForChild("RecyclerController"))
local TeamController = require(Controllers:WaitForChild("TeamController"))
local SwordController = require(Controllers:WaitForChild("SwordController"))
local WeaponSwitchController = require(Controllers:WaitForChild("WeaponSwitchController"))
local CharacterController = require(Controllers:WaitForChild("CharacterController"))
local CameraLimitController = require(Controllers:WaitForChild("CameraLimitController"))
local FightTouchController = require(Controllers:WaitForChild("FightTouchController"))
local StationTimerController = require(Controllers:WaitForChild("StationTimerController"))
local StockHintController = require(Controllers:WaitForChild("StockHintController"))
local MusicController = require(Controllers:WaitForChild("MusicController"))
local FootstepController = require(Controllers:WaitForChild("FootstepController"))
local WildLoadingController = require(Controllers:WaitForChild("WildLoadingController"))

-- One rounded font for every text in the game, before any screen is built
require(script:WaitForChild("Util"):WaitForChild("FontStyle")).start()

local Place = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Place"))
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))

LoadingController.Start() -- the loading screen's steps (ReplicatedFirst shows it from the first frame)
-- What you can't do yet: a big locked card with the reason, locked prompts showing the level needed (every place)
require(Controllers:WaitForChild("BlockedController")).Start()
-- A teleport's loading screen the moment it starts, before Roblox shows its own copy (Remotes.Departing)
require(Controllers:WaitForChild("DepartureController")).Start()
require(Controllers:WaitForChild("KnockoutController")).Start() -- knocked out in the Wild: the countdown, Revive here
-- Effects toned to the scene: on bright ground (snow) they blend their colours in instead of adding light (Util/FxTone)
require(script:WaitForChild("Util"):WaitForChild("FxTone")).Start()

if Place.isFrontier() or Place.isDungeon() then
	-- The Frontier and Dungeon places: no shop, so only the binder, party, creatures and fights
	UIController.Start()
	BinderController.Start()
	BinderPoseController.Start() -- anyone with their binder open holds it up, reading
	PartyController.Start()
	BuffController.Start()
	PartyBarController.Start()
	CreatureController.Start()
	MonsterController.Start()
	BattleController.Start()
	MovePreviewController.Start() -- Studio only: /movefx plays a Pet button move at a grade
	BossBoardController.Start() -- the boss ladder (the Frontier bosses' arenas are here)
	LootController.Start() -- boss loot on the ground
	AdminPanelController.Start() -- Studio only: the dev commands as buttons
	FrontierController.Start() -- the home button
	AnnouncementController.Start() -- Frontier card finds in chat
	FrontierRevealController.Start() -- the big moment when you find a Frontier card
	WeaponRevealController.Start() -- a boss's weapon drop and forged weapons: the reveal on the stage
	BossChestController.Start() -- a boss win's three chests on the stage (BossChestService)
	SoundscapeController.Start() -- spot sounds round you, the town's night bed and gusts (not the Dungeon)
	TitleController.Start() -- titles over names (small, in their gradient)
	SupportController.Start() -- "Support the dev": tap Pish for the card; he asks after a good moment
	ThanksController.Start() -- a gift's thank-you: Pish and Chikin run in, then the glow
	SwordController.Start() -- swords on characters, the first-sword popup
	WeaponSwitchController.Start() -- the quick weapon switch chip on the right edge (Q)
	CharacterController.Start() -- the character window: your character, Stats / Elements / Titles, your weapon (P)
	CameraLimitController.Start() -- how far the camera zooms out (Config/CameraLimits)
	FightTouchController.Start() -- a phone's fight: the camera pulled out, the jump button aside
	LevelUpController.Start() -- the level-up light pillar on you, your creatures and players nearby
	FootstepController.Start() -- footsteps on whatever you walk on
	if Place.isDungeon() then
		DungeonController.Start() -- the run line and Leave
		DungeonPuzzleController.Start() -- the puzzles' chests and swings
		DungeonObjectiveController.Start() -- the objective at the top right
		DungeonIntroController.Start() -- the Hydra's welcome when the run opens
		DungeonAmbienceController.Start() -- the eerie music, distant roars, eyes in the dark, spot sounds
		DungeonFallController.Start() -- a fall into the chasm: a yell and the screen going black
		DungeonCinematicController.Start() -- a puzzle's gate opening, the way to the Hydra
		DungeonRegionController.Start() -- each region's haze as you walk in, Volt's flicker
		PortalFxController.Start() -- the castle gate's swirl turning
		-- the arrival message may have come before these listened (a RemoteEvent's queue goes to the first listener)
		Remotes.DungeonRun:FireServer()
	else
		DayCycleController.Start() -- the Frontier valley's skies (Config/DayCycle FRONTIER)
		MusicController.Start() -- its areas' and boss arenas' music (Config/Music FRONTIER)
		PortalFxController.Start() -- its portals' swirls turning (the owner 2026-11-10: "some are no animations")
		FrontierFxController.Start() -- its snow, red eyes, lightning, tornado, vortex, floating rocks and tremors
		TeamController.Start() -- teams in the Frontier: Team up prompts, invites, the team strip, boss calls
		QuestController.Start() -- daily quests: the tracker (not in the Dungeon: its objective holds the top right)
		EventController.Start() -- the weekly event's chip under the quest strip (after QuestController)
	end
else
	UIController.Start()
	OrderController.Start()
	PlacementController.Start()
	-- the Edit bar on what you placed (before the controllers that open it: Build, Window)
	require(Controllers:WaitForChild("EditBarController")).Start()
	BuildController.Start()
	PricingController.Start()
	PriceTagController.Start()
	ShelfInfoController.Start()
	ButterflyController.Start()
	DayCycleController.Start()
	MusicController.Start() -- music in the town, the Wild valley's areas and its boss arenas
	FootstepController.Start() -- footsteps on whatever you walk on
	WildLoadingController.Start() -- the Wild's loading screen: holds you still until the valley round you is in
	TreeSwayController.Start()
	TownNightController.Start() -- the street lights brighter and fireflies at night
	TownDressController.Start() -- string lights, falling leaves, shooting stars, an event day's colours and pennants
	TownCritterController.Start()
	TownPishController.Start() -- Town Pish, drawn on the server's marker (main game)
	TownChikinController.Start() -- Town Chikin on the portal side, the same way (main game)
	TurtsController.Start() -- Turts' rug shop: him, his rug, your offers, the shop window (main game)
	TutorialController.Start() -- the first visit with Pish: his cues, skip and replay (after the HUD and TownPishController)
	ChikinController.Start() -- Chikin's combat tutorial after Pish's (after TutorialController)
	PlazaNpcController.Start()
	FountainFxController.Start()
	PortalFxController.Start()
	task.spawn(WelcomeController.Start) -- waits for the Plots folder
	PrologueController.Start() -- a new player's first join: the Hydra takes it all (the welcome flight waits for it)
	task.spawn(CondenserFxController.Start) -- waits for the Plots folder
	task.spawn(CaseSpinController.Start) -- waits for the Plots folder
	DecorSpinController.Start() -- the Card Pedestals' turning cards (shop decor)
	WindowController.Start() -- placing shop windows on the walls, and their Edit prompts
	-- the shop rooms: the owner's Unlock prompt on each locked door, and a room's opening moment
	require(Controllers:WaitForChild("ShopRoomController")).Start()
	require(Controllers:WaitForChild("ShopLodController")).Start() -- other shops' screens drawn closer, far shops' stock hidden
	-- the packenship.co vans down the street, the boxes hopping onto pads, the unboxing onto shelves, the waiting chip
	require(Controllers:WaitForChild("DeliveryController")).Start()
	task.spawn(WorkerVisualController.Start) -- waits for the Workers folder
	RegisterController.Start()
	RegisterStationController.Start() -- manning the register in first person: scan, Charge, the card machine, the drawer
	CarryController.Start()
	-- anyone carrying a box holds it in both arms (Config/CarryPose)
	require(Controllers:WaitForChild("CarryPoseController")).Start()
	PackOpeningController.Start()
	BinderController.Start()
	BinderPoseController.Start() -- anyone with their binder open holds it up, reading
	ShowcaseController.Start()
	CardBuyController.Start()
	CondenserController.Start()
	ForgeController.Start() -- the Forge window (weapons): forge, upgrade, reforge at your own Forge
	GradingController.Start()
	require(Controllers:WaitForChild("BulkBinController")).Start() -- the Bulk Bin's window: the extras that go in
	StationTimerController.Start() -- countdowns over your stations while they hold a job
	StockHintController.Start() -- the shelves that glow while you carry a box of their product
	require(Controllers:WaitForChild("StorageController")).Start() -- storage racks: the stock clipboard, the box hop
	JobsController.Start()
	PartyController.Start()
	ReviewsController.Start() -- the phone's Reviews app (after the other apps: it's the last icon)
	StoreController.Start() -- the phone's Store app: luck boosts and the Extra Job Slot for Robux
	StoreWinController.Start() -- the win card when a Store purchase goes through
	GiftController.Start() -- daily, weekly and monthly gifts: the Gift tile, the window, the win moments
	TeamController.Start() -- teams in this world: Team up prompts, invites, the team strip, boss calls
	QuestController.Start() -- daily quests: the tracker under the team strip, the window, claims (after TeamController)
	EventController.Start() -- the weekly event's chip under the quest strip (after QuestController, before Turts' chip)
	WelcomeBackController.Start() -- what the shop sold while you were away, once the screen is free
	BulkOpenController.Start() -- Open 10: a stack of Bag packs opened at once, the cards in a grid
	RecyclerController.Start() -- the Recycler's window: extra cards into upgrade materials
	BuffController.Start()
	PartyBarController.Start()
	CardEffectsController.Start()
	AnnouncementController.Start()
	CreatureController.Start()
	CustomerController.Start() -- collectors' thought bubbles
	RatingController.Start() -- the shop rating chip and its tips
	MonsterController.Start()
	BattleController.Start()
	MovePreviewController.Start() -- Studio only: /movefx plays a Pet button move at a grade
	BossBoardController.Start() -- the boss ladder
	LootController.Start() -- boss loot on the ground
	AdminPanelController.Start() -- Studio only: the dev commands as buttons
	ChallengeController.Start()
	ArenaWatchController.Start() -- PvP from the stands: the fight's attacks
	FrontierController.Start() -- the portal menu
	FrontierRevealController.Start() -- Frontier cards found with /frontierdrop in Studio
	WeaponRevealController.Start() -- a boss's weapon drop and forged weapons: the reveal on the stage
	BossChestController.Start() -- a boss win's three chests on the stage (BossChestService)
	SoundscapeController.Start() -- spot sounds round you, the town's night bed and gusts (not the Dungeon)
	TitleController.Start() -- titles over names (small, in their gradient)
	SupportController.Start() -- "Support the dev": tap Pish for the card; he asks after a good moment
	ThanksController.Start() -- a gift's thank-you: Pish and Chikin run in, then the glow
	SwordController.Start() -- swords on characters, the first-sword popup
	WeaponSwitchController.Start() -- the quick weapon switch chip on the right edge (Q)
	CharacterController.Start() -- the character window: your character, Stats / Elements / Titles, your weapon (P)
	CameraLimitController.Start() -- how far the camera zooms out (Config/CameraLimits)
	FightTouchController.Start() -- a phone's fight: the camera pulled out, the jump button aside
	LevelUpController.Start() -- the level-up light pillar on you, your creatures and players nearby
end
