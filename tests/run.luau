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
	PortalTrails = require("./PortalTrails.spec"),
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
