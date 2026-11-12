--!strict
-- Client entry point. Starts each controller; UIController first since others build on its ScreenGui.
local Controllers = script:WaitForChild("Controllers")

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
local TutorialController = require(Controllers:WaitForChild("TutorialController"))
local ChikinController = require(Controllers:WaitForChild("ChikinController"))
local PlazaNpcController = require(Controllers:WaitForChild("PlazaNpcController"))
local FountainFxController = require(Controllers:WaitForChild("FountainFxController"))
local PortalFxController = require(Controllers:WaitForChild("PortalFxController"))
local WelcomeController = require(Controllers:WaitForChild("WelcomeController"))
local CondenserFxController = require(Controllers:WaitForChild("CondenserFxController"))
local CaseSpinController = require(Controllers:WaitForChild("CaseSpinController"))
local WorkerVisualController = require(Controllers:WaitForChild("WorkerVisualController"))
local LevelUpController = require(Controllers:WaitForChild("LevelUpController"))
local RegisterController = require(Controllers:WaitForChild("RegisterController"))
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
local SwordController = require(Controllers:WaitForChild("SwordController"))
local WeaponSwitchController = require(Controllers:WaitForChild("WeaponSwitchController"))
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
-- Effects toned to the scene: on bright ground (snow) they blend their colours in instead of adding light (Util/FxTone)
require(script:WaitForChild("Util"):WaitForChild("FxTone")).Start()

if Place.isFrontier() or Place.isDungeon() then
	-- The Frontier and Dungeon places: no shop, so only the binder, party, creatures and fights
	UIController.Start()
	BinderController.Start()
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
	TitleController.Start() -- titles over names (Dungeon Conqueror)
	SwordController.Start() -- swords on characters, the first-sword popup
	WeaponSwitchController.Start() -- the quick weapon switch chip on the right edge (Q)
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
	end
else
	UIController.Start()
	OrderController.Start()
	PlacementController.Start()
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
	TownCritterController.Start()
	TownPishController.Start() -- Town Pish, drawn on the server's marker (main game)
	TownChikinController.Start() -- Town Chikin on the portal side, the same way (main game)
	TutorialController.Start() -- the first visit with Pish: his cues, skip and replay (after the HUD and TownPishController)
	ChikinController.Start() -- Chikin's combat tutorial after Pish's (after TutorialController)
	PlazaNpcController.Start()
	FountainFxController.Start()
	PortalFxController.Start()
	task.spawn(WelcomeController.Start) -- waits for the Plots folder
	task.spawn(CondenserFxController.Start) -- waits for the Plots folder
	task.spawn(CaseSpinController.Start) -- waits for the Plots folder
	task.spawn(WorkerVisualController.Start) -- waits for the Workers folder
	RegisterController.Start()
	CarryController.Start()
	PackOpeningController.Start()
	BinderController.Start()
	ShowcaseController.Start()
	CardBuyController.Start()
	CondenserController.Start()
	ForgeController.Start() -- the Forge window (weapons): forge, upgrade, reforge at your own Forge
	GradingController.Start()
	JobsController.Start()
	PartyController.Start()
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
	TitleController.Start() -- titles over names (Dungeon Conqueror)
	SwordController.Start() -- swords on characters, the first-sword popup
	WeaponSwitchController.Start() -- the quick weapon switch chip on the right edge (Q)
	LevelUpController.Start() -- the level-up light pillar on you, your creatures and players nearby
end
