--!strict
-- Server entry point. Requires and starts each service in dependency order.
-- Services that store player data register with DataService in their Start(); DataService starts
-- last and then drives every player's join (load) and leave (save, unload).
local Services = script:WaitForChild("Services")

local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local MonetizationService = require(Services:WaitForChild("MonetizationService"))
local PurchaseService = require(Services:WaitForChild("PurchaseService"))
local UpgradeJobService = require(Services:WaitForChild("UpgradeJobService"))
local PricingService = require(Services:WaitForChild("PricingService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local CardService = require(Services:WaitForChild("CardService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local WeaponService = require(Services:WaitForChild("WeaponService"))
local ForgeService = require(Services:WaitForChild("ForgeService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local ShowcaseService = require(Services:WaitForChild("ShowcaseService"))
local CustomerService = require(Services:WaitForChild("CustomerService"))
local StockService = require(Services:WaitForChild("StockService"))
local RegisterService = require(Services:WaitForChild("RegisterService"))
local OfferService = require(Services:WaitForChild("OfferService"))
local RatingService = require(Services:WaitForChild("RatingService"))
local DecorService = require(Services:WaitForChild("DecorService"))
local WindowService = require(Services:WaitForChild("WindowService"))
local TownWalkerService = require(Services:WaitForChild("TownWalkerService"))
local PackService = require(Services:WaitForChild("PackService"))
local CondenserService = require(Services:WaitForChild("CondenserService"))
local GradingService = require(Services:WaitForChild("GradingService"))
local JobService = require(Services:WaitForChild("JobService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local SwordService = require(Services:WaitForChild("SwordService"))
local WildService = require(Services:WaitForChild("WildService"))
local BattleService = require(Services:WaitForChild("BattleService"))
local KnockoutService = require(Services:WaitForChild("KnockoutService"))
local SupportService = require(Services:WaitForChild("SupportService"))
local ReviewService = require(Services:WaitForChild("ReviewService"))
local ArenaService = require(Services:WaitForChild("ArenaService"))
local BossChestService = require(Services:WaitForChild("BossChestService"))
local BossService = require(Services:WaitForChild("BossService"))
local TitleService = require(Services:WaitForChild("TitleService"))
local FrontierService = require(Services:WaitForChild("FrontierService"))
local TownService = require(Services:WaitForChild("TownService"))
local SceneryService = require(Services:WaitForChild("SceneryService"))
local WelcomeService = require(Services:WaitForChild("WelcomeService"))
local PishService = require(Services:WaitForChild("PishService"))
local TownChikinService = require(Services:WaitForChild("TownChikinService"))
local TutorialService = require(Services:WaitForChild("TutorialService"))
local CombatTutorialService = require(Services:WaitForChild("CombatTutorialService"))
local DevService = require(Services:WaitForChild("DevService"))
local DungeonService = require(Services:WaitForChild("DungeonService"))
local DungeonGateService = require(Services:WaitForChild("DungeonGateService"))
local LevelUpService = require(Services:WaitForChild("LevelUpService"))
local LeaderboardService = require(Services:WaitForChild("LeaderboardService"))
local TurtsService = require(Services:WaitForChild("TurtsService"))
local BinderReadService = require(Services:WaitForChild("BinderReadService"))

local Place = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Place"))

if Place.isDungeon() then
	-- The Dungeon place (one run per reserved server): the run, its fights and the final boss
	EconomyService.Start()
	MonetizationService.Start()
	PurchaseService.Start() -- Robux developer products: the one ProcessReceipt (a "Support the dev" gift can be given here)
	CardService.Start()
	ItemService.Start()
	WeaponService.Start() -- owned and equipped weapons (after ItemService; before SwordService, which reads it)
	JobService.StartLocksOnly() -- before PartyService: cards with a shop job stay out of the party
	PartyService.Start()
	SwordService.Start() -- the standard body and the sword (before BattleService, which uses it)
	WildService.Start() -- the Dungeon's monsters (no wild map)
	BattleService.Start()
	BossChestService.Start() -- the boss chests after a win (BossService hands them over)
	BossService.Start() -- the Prism Hydra's chamber
	SupportService.Start() -- "Support the dev" gifts: aura, best tier (before TitleService: its titles)
	TitleService.Start() -- the title over the name (after BossService and SupportService: their progress)
	DungeonService.Start() -- the run: arrivals, rooms, carried HP (after BattleService and WildService's cavern)
	FrontierService.Start() -- back to the Frontier
	TutorialService.StartLessonsOnly() -- Pish's lessons a level-up here unlocks wait for the town (saved)
	LevelUpService.Start() -- level-up packs and Bag pack openings (after EconomyService, ItemService, BattleService)
	LeaderboardService.StartWrites() -- packs opened here count on the plaza leaderboard
	BinderReadService.Start() -- your binder open shows you reading it (after BattleService)
	DevService.Start() -- Studio only
	DataService.Start() -- last: starts loading players
elseif Place.isFrontier() then
	-- The Frontier place: no plots or shop systems, only what the shared high-level map needs.
	-- Data handlers load in this order (and unload in reverse), as in the main game.
	EconomyService.Start()
	MonetizationService.Start()
	PurchaseService.Start() -- Robux developer products: the one ProcessReceipt (a revive can be bought here)
	CardService.Start()
	ItemService.Start()
	WeaponService.Start() -- owned and equipped weapons (after ItemService; before SwordService, which reads it)
	JobService.StartLocksOnly() -- before PartyService: cards with a shop job stay out of the party
	PartyService.Start()
	SwordService.Start() -- the standard body and the sword (before BattleService, which uses it)
	SceneryService.StartValley() -- the Frontier valley's terrain and scenery (Config/FrontierValley)
	WildService.Start() -- the Frontier valley, its camp, spring and monsters
	BattleService.Start()
	BossChestService.Start() -- the boss chests after a win (BossService hands them over)
	BossService.Start() -- the Frontier bosses: after BattleService and WildService (it uses both)
	KnockoutService.Start() -- knocked out in the Wild: the countdown, Revive here (after PurchaseService)
	SupportService.Start() -- "Support the dev" gifts: aura, best tier (before TitleService: its titles)
	TitleService.Start() -- the title over the name (after BossService and SupportService: their progress)
	FrontierService.Start() -- the Return portal and home button: back to the main game
	DungeonGateService.Start() -- the Dungeon portal: checks, groups, the teleport (after WildService builds the plaza)
	TutorialService.StartLessonsOnly() -- Pish's lessons a level-up here unlocks wait for the town (saved)
	LevelUpService.Start() -- level-up packs and Bag pack openings (after EconomyService, ItemService, BattleService)
	LeaderboardService.StartWrites() -- packs opened here count on the plaza leaderboard
	BinderReadService.Start() -- your binder open shows you reading it (after BattleService)
	DevService.Start() -- Studio only
	DataService.Start() -- last: starts loading players
else
	PlotService.Start() -- builds the plots everything else uses
	-- Data handlers load in this order (and unload in reverse). CardService loads before
	-- PlacementService so displayed cards that can't be restored go back to the binder.
	EconomyService.Start()
	MonetizationService.Start()
	PurchaseService.Start() -- Robux developer products: the one ProcessReceipt (station skips, the revive)
	PricingService.Start()
	CardService.Start()
	ItemService.Start()
	WeaponService.Start() -- owned and equipped weapons (after ItemService; before SwordService, which reads it)
	UpgradeJobService.Start() -- the stations' timed jobs (after CardService, ItemService and WeaponService: it hands items back on load)
	ForgeService.Start() -- the Forge machine: forging, upgrades, reforges (after WeaponService)
	PlacementService.Start()
	DecorService.Start() -- shop looks: the look in use and the looks bought, drawn in the shop (after PlotService)
	WindowService.Start() -- shop windows cut into the walls (after DecorService: the look's liners are cut round them)
	StockService.Start()
	ShowcaseService.Start()
	CustomerService.Start()
	RegisterService.Start()
	OfferService.Start() -- kid offers and haggles at the register (after RegisterService)
	RatingService.Start() -- the shop rating on the sign and the customer flow (after CustomerService)
	ReviewService.Start() -- the phone's Reviews app: customers' posts from their visits (after CustomerService)
	TownWalkerService.Start() -- customers strolling the plaza who pick a shop (after RatingService)
	PackService.Start()
	CondenserService.Start()
	GradingService.Start()
	JobService.Start() -- after CardService, PlacementService and StockService: it loads after them
	PartyService.Start() -- after JobService: party loading checks which cards are working
	SwordService.Start() -- the standard body and the sword (before BattleService, which uses it)
	WildService.Start() -- wild map, plaza portal, spring and monsters
	BattleService.Start() -- after PartyService: unloads first, so a fight ends before the party unloads
	ArenaService.Start() -- PvP: after BattleService and PartyService (it uses both)
	BossChestService.Start() -- the boss chests after a win (BossService hands them over)
	BossService.Start() -- the boss ladder: after BattleService and WildService (it uses both)
	KnockoutService.Start() -- knocked out in the Wild: the countdown, Revive here (after PurchaseService)
	SupportService.Start() -- "Support the dev" gifts: aura, best tier (before TitleService: its titles)
	TitleService.Start() -- the title over the name (after BossService and SupportService: their progress)
	FrontierService.Start() -- the plaza Frontier portal (after WildService builds the plaza)
	TownService.Start() -- street, decor, portal frames and lighting around the plots and portals
	SceneryService.Start() -- terrain round the town and in the portal areas (after TownService)
	PishService.Start() -- Town Pish wandering the town, petted for luck (after PlotService, PackService, TownService)
	TownChikinService.Start() -- Town Chikin on the portal side, petted for Courage (main game)
	TutorialService.Start() -- the first visit with Pish, his gifts and the funnel (after PishService; before DataService.Start)
	CombatTutorialService.Start() -- Chikin's combat tutorial after Pish's (after TutorialService; before DataService.Start)
	WelcomeService.Start() -- the first-visit welcome cinematic's saved flag (before DataService.Start)
	LevelUpService.Start() -- level-up packs and Bag pack openings (after EconomyService, ItemService, BattleService)
	LeaderboardService.Start() -- the plaza leaderboard: most packs opened (after PlotService and the plaza)
	TurtsService.Start() -- Turts' rug shop: restocks, his spot, buys, "restock now" (after PurchaseService and WildService)
	BinderReadService.Start() -- your binder open shows you reading it (after BattleService)
	DevService.Start() -- Studio only
	DataService.Start() -- last: starts loading players
end

print(`[Server] Booted ({if Place.isDungeon() then "Dungeon" elseif Place.isFrontier() then "Frontier" else "main game"})`)
