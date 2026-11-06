--!strict
-- Runs every spec file listed below. Each spec returns { [testName] = function }.
-- Usage: lune run tests/run
local process = require("@lune/process")

local specs: { [string]: { [string]: () -> () } } = {
	BeastMath = require("./BeastMath.spec"),
	Migrations = require("./Migrations.spec"),
	SaleRules = require("./SaleRules.spec"),
	CondenseRules = require("./CondenseRules.spec"),
	JobRules = require("./JobRules.spec"),
	LevelMath = require("./LevelMath.spec"),
	LevelRemap = require("./LevelRemap.spec"),
	LevelUpRules = require("./LevelUpRules.spec"),
	BinderCovers = require("./BinderCovers.spec"),
	OrderRules = require("./OrderRules.spec"),
	LevelUpFxConfig = require("./LevelUpFxConfig.spec"),
	HoverRules = require("./HoverRules.spec"),
	ProductPictureRules = require("./ProductPictureRules.spec"),
	PartyRules = require("./PartyRules.spec"),
	CreatureMotion = require("./CreatureMotion.spec"),
	CreatureAssets = require("./CreatureAssets.spec"),
	CombatMath = require("./CombatMath.spec"),
	BattleSim = require("./BattleSim.spec"),
	SourceOrder = require("./SourceOrder.spec"),
	PvpRules = require("./PvpRules.spec"),
	Frontier = require("./Frontier.spec"),
	Dungeon = require("./Dungeon.spec"),
	DungeonRules = require("./DungeonRules.spec"),
	ItemRules = require("./ItemRules.spec"),
	TownLayout = require("./TownLayout.spec"),
	PropFit = require("./PropFit.spec"),
	ShelfStock = require("./ShelfStock.spec"),
	ShelfLayout = require("./ShelfLayout.spec"),
	PetRig = require("./PetRig.spec"),
	KeyframeTiming = require("./KeyframeTiming.spec"),
	BeastFxRules = require("./BeastFxRules.spec"),
	RigGuess = require("./RigGuess.spec"),
	CellSearch = require("./CellSearch.spec"),
	ShelvesConfig = require("./ShelvesConfig.spec"),
	RevealRules = require("./RevealRules.spec"),
	ElementFxRules = require("./ElementFxRules.spec"),
	BinderSpreads = require("./BinderSpreads.spec"),
	OddsRules = require("./OddsRules.spec"),
	NewPulls = require("./NewPulls.spec"),
	PityRules = require("./PityRules.spec"),
	BossRules = require("./BossRules.spec"),
	CreatureCull = require("./CreatureCull.spec"),
	AdminPanel = require("./AdminPanel.spec"),
	UiLayout = require("./UiLayout.spec"),
	CompareRules = require("./CompareRules.spec"),
	PageCurl = require("./PageCurl.spec"),
	BinderFit = require("./BinderFit.spec"),
	BinderGesture = require("./BinderGesture.spec"),
	PackFxConfig = require("./PackFxConfig.spec"),
	ShowcaseLayout = require("./ShowcaseLayout.spec"),
	OpeningFlow = require("./OpeningFlow.spec"),
	OpeningLayout = require("./OpeningLayout.spec"),
	ShopDetail = require("./ShopDetail.spec"),
	PricingConfig = require("./PricingConfig.spec"),
	PortalTrails = require("./PortalTrails.spec"),
	TownTerrain = require("./TownTerrain.spec"),
	DayCycle = require("./DayCycle.spec"),
	FrameWatchdog = require("./FrameWatchdog.spec"),
	Wander = require("./Wander.spec"),
	WelcomePath = require("./WelcomePath.spec"),
	PlazaLayout = require("./PlazaLayout.spec"),
	PortalLooks = require("./PortalLooks.spec"),
	LavaCracks = require("./LavaCracks.spec"),
	ModelPreload = require("./ModelPreload.spec"),
	CardArt = require("./CardArt.spec"),
	WildValley = require("./WildValley.spec"),
	WildPopulation = require("./WildPopulation.spec"),
	MonsterLooks = require("./MonsterLooks.spec"),
	BossMoments = require("./BossMoments.spec"),
	MoveFx = require("./MoveFx.spec"),
	SkillText = require("./SkillText.spec"),
	SuperFx = require("./SuperFx.spec"),
	CustomerTypes = require("./CustomerTypes.spec"),
	CollectorRules = require("./CollectorRules.spec"),
	OfferRules = require("./OfferRules.spec"),
	HaggleRules = require("./HaggleRules.spec"),
	ReactionRules = require("./ReactionRules.spec"),
	RatingRules = require("./RatingRules.spec"),
	WalkerRules = require("./WalkerRules.spec"),
	StageRules = require("./StageRules.spec"),
	WalkStep = require("./WalkStep.spec"),
	TiredRules = require("./TiredRules.spec"),
	CreatureFlight = require("./CreatureFlight.spec"),
	ToastRules = require("./ToastRules.spec"),
	WeaponsConfig = require("./WeaponsConfig.spec"),
	WeaponRules = require("./WeaponRules.spec"),
	WeaponLookRules = require("./WeaponLookRules.spec"),
	SoundLevel = require("./SoundLevel.spec"),
	WildLoadingRules = require("./WildLoadingRules.spec"),
	SwordsConfig = require("./SwordsConfig.spec"),
	SwordRules = require("./SwordRules.spec"),
	SwordArcRules = require("./SwordArcRules.spec"),
	SwingGate = require("./SwingGate.spec"),
	RingRules = require("./RingRules.spec"),
	HpBarRules = require("./HpBarRules.spec"),
	CombatPreload = require("./CombatPreload.spec"),
	LoadingRules = require("./LoadingRules.spec"),
	AttackTiming = require("./AttackTiming.spec"),
	FightMotion = require("./FightMotion.spec"),
	FightFxRules = require("./FightFxRules.spec"),
	MonsterMoves = require("./MonsterMoves.spec"),
	ShakeRules = require("./ShakeRules.spec"),
	DamagePop = require("./DamagePop.spec"),
	VictoryRules = require("./VictoryRules.spec"),
	MarkerNames = require("./MarkerNames.spec"),
	DebuffRules = require("./DebuffRules.spec"),
	SwapKeys = require("./SwapKeys.spec"),
	SummonMotion = require("./SummonMotion.spec"),
	DefeatRules = require("./DefeatRules.spec"),
	PetVoice = require("./PetVoice.spec"),
	MusicRules = require("./MusicRules.spec"),
	XpPill = require("./XpPill.spec"),
	SparkPath = require("./SparkPath.spec"),
	HudMascotRules = require("./HudMascotRules.spec"),
	ContrastRules = require("./ContrastRules.spec"),
	SoftColors = require("./SoftColors.spec"),
	SquishRules = require("./SquishRules.spec"),
}

-- `lune run tests/run <SpecName>` runs only that spec
local only = process.args[1]
local passed, failed = 0, 0
for specName, tests in specs do
	if only and specName ~= only then
		continue
	end
	for testName, test in tests do
		local ok, err = pcall(test)
		if ok then
			passed += 1
		else
			failed += 1
			print(`FAIL {specName} > {testName}\n    {err}`)
		end
	end
end
print(`{passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
