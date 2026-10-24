--!strict
-- Client entry point. Starts each controller; UIController first since others build on its ScreenGui.
local Controllers = script:WaitForChild("Controllers")

local UIController = require(Controllers:WaitForChild("UIController"))
local OrderController = require(Controllers:WaitForChild("OrderController"))
local PlacementController = require(Controllers:WaitForChild("PlacementController"))
local BuildController = require(Controllers:WaitForChild("BuildController"))
local PricingController = require(Controllers:WaitForChild("PricingController"))
local PriceTagController = require(Controllers:WaitForChild("PriceTagController"))
local RegisterController = require(Controllers:WaitForChild("RegisterController"))
local CarryController = require(Controllers:WaitForChild("CarryController"))
local PackOpeningController = require(Controllers:WaitForChild("PackOpeningController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))
local ShowcaseController = require(Controllers:WaitForChild("ShowcaseController"))
local CardBuyController = require(Controllers:WaitForChild("CardBuyController"))
local CondenserController = require(Controllers:WaitForChild("CondenserController"))
local JobsController = require(Controllers:WaitForChild("JobsController"))
local PartyController = require(Controllers:WaitForChild("PartyController"))
local BuffController = require(Controllers:WaitForChild("BuffController"))
local PartyBarController = require(Controllers:WaitForChild("PartyBarController"))
local CardEffectsController = require(Controllers:WaitForChild("CardEffectsController"))
local AnnouncementController = require(Controllers:WaitForChild("AnnouncementController"))
local CreatureController = require(Controllers:WaitForChild("CreatureController"))
local MonsterController = require(Controllers:WaitForChild("MonsterController"))
local BattleController = require(Controllers:WaitForChild("BattleController"))
local ChallengeController = require(Controllers:WaitForChild("ChallengeController"))
local FrontierController = require(Controllers:WaitForChild("FrontierController"))
local FrontierRevealController = require(Controllers:WaitForChild("FrontierRevealController"))

-- One rounded font for every text in the game, before any screen is built
require(script:WaitForChild("Util"):WaitForChild("FontStyle")).start()

local Place = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Place"))

if Place.isFrontier() then
	-- The Frontier place: no shop, so only the binder, party, creatures and fights
	UIController.Start()
	BinderController.Start()
	PartyController.Start()
	BuffController.Start()
	PartyBarController.Start()
	CreatureController.Start()
	MonsterController.Start()
	BattleController.Start()
	FrontierController.Start() -- the home button
	AnnouncementController.Start() -- Frontier card finds in chat
	FrontierRevealController.Start() -- the big moment when you find a Frontier card
else
	UIController.Start()
	OrderController.Start()
	PlacementController.Start()
	BuildController.Start()
	PricingController.Start()
	PriceTagController.Start()
	RegisterController.Start()
	CarryController.Start()
	PackOpeningController.Start()
	BinderController.Start()
	ShowcaseController.Start()
	CardBuyController.Start()
	CondenserController.Start()
	JobsController.Start()
	PartyController.Start()
	BuffController.Start()
	PartyBarController.Start()
	CardEffectsController.Start()
	AnnouncementController.Start()
	CreatureController.Start()
	MonsterController.Start()
	BattleController.Start()
	ChallengeController.Start()
	FrontierController.Start() -- the portal menu
	FrontierRevealController.Start() -- Frontier cards found with /frontierdrop in Studio
end
