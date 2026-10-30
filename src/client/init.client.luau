--!strict
-- Client entry point. Starts each controller; UIController first since others build on its ScreenGui.
local Controllers = script:WaitForChild("Controllers")

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
local PlazaNpcController = require(Controllers:WaitForChild("PlazaNpcController"))
local WelcomeController = require(Controllers:WaitForChild("WelcomeController"))
local CondenserFxController = require(Controllers:WaitForChild("CondenserFxController"))
local CaseSpinController = require(Controllers:WaitForChild("CaseSpinController"))
local WorkerVisualController = require(Controllers:WaitForChild("WorkerVisualController"))
local RegisterController = require(Controllers:WaitForChild("RegisterController"))
local CarryController = require(Controllers:WaitForChild("CarryController"))
local PackOpeningController = require(Controllers:WaitForChild("PackOpeningController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))
local ShowcaseController = require(Controllers:WaitForChild("ShowcaseController"))
local CardBuyController = require(Controllers:WaitForChild("CardBuyController"))
local CondenserController = require(Controllers:WaitForChild("CondenserController"))
local GradingController = require(Controllers:WaitForChild("GradingController"))
local JobsController = require(Controllers:WaitForChild("JobsController"))
local PartyController = require(Controllers:WaitForChild("PartyController"))
local BuffController = require(Controllers:WaitForChild("BuffController"))
local PartyBarController = require(Controllers:WaitForChild("PartyBarController"))
local CardEffectsController = require(Controllers:WaitForChild("CardEffectsController"))
local AnnouncementController = require(Controllers:WaitForChild("AnnouncementController"))
local CreatureController = require(Controllers:WaitForChild("CreatureController"))
local MonsterController = require(Controllers:WaitForChild("MonsterController"))
local BattleController = require(Controllers:WaitForChild("BattleController"))
local BossBoardController = require(Controllers:WaitForChild("BossBoardController"))
local LootController = require(Controllers:WaitForChild("LootController"))
local AdminPanelController = require(Controllers:WaitForChild("AdminPanelController"))
local ChallengeController = require(Controllers:WaitForChild("ChallengeController"))
local FrontierController = require(Controllers:WaitForChild("FrontierController"))
local FrontierRevealController = require(Controllers:WaitForChild("FrontierRevealController"))
local DungeonController = require(Controllers:WaitForChild("DungeonController"))
local TitleController = require(Controllers:WaitForChild("TitleController"))

-- One rounded font for every text in the game, before any screen is built
require(script:WaitForChild("Util"):WaitForChild("FontStyle")).start()

local Place = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Place"))

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
	BossBoardController.Start() -- the boss ladder (the Frontier bosses' arenas are here)
	LootController.Start() -- boss loot on the ground
	AdminPanelController.Start() -- Studio only: the dev commands as buttons
	FrontierController.Start() -- the home button
	AnnouncementController.Start() -- Frontier card finds in chat
	FrontierRevealController.Start() -- the big moment when you find a Frontier card
	TitleController.Start() -- titles over names (Dungeon Conqueror)
	if Place.isDungeon() then
		DungeonController.Start() -- the run line and Leave
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
	TreeSwayController.Start()
	TownCritterController.Start()
	PlazaNpcController.Start()
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
	GradingController.Start()
	JobsController.Start()
	PartyController.Start()
	BuffController.Start()
	PartyBarController.Start()
	CardEffectsController.Start()
	AnnouncementController.Start()
	CreatureController.Start()
	MonsterController.Start()
	BattleController.Start()
	BossBoardController.Start() -- the boss ladder
	LootController.Start() -- boss loot on the ground
	AdminPanelController.Start() -- Studio only: the dev commands as buttons
	ChallengeController.Start()
	FrontierController.Start() -- the portal menu
	FrontierRevealController.Start() -- Frontier cards found with /frontierdrop in Studio
	TitleController.Start() -- titles over names (Dungeon Conqueror)
end
