# Beast Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn cards into Glimmerbeasts: fresh copies stack, a copy becomes an individual beast (level, XP, stars) once it grows, and stats/value follow from that everywhere cards are shown, displayed or sold.

**Architecture:** Pure maths (stats, value, XP, save validation) lives in a Roblox-free `BeastMath` module tested with Lune. `BeastRules` wraps it with game config for server and client. `CardService` owns fresh stacks and raised beasts; cases, customers and player purchases carry a beast as a unit. Save schema goes to v3 with a no-loss migration.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo 7.7, ProfileStore, Lune (new, for unit tests), Rokit.

**Spec:** `docs/superpowers/specs/2026-10-20-beast-cards-design.md`

## Global Constraints

- All tunable numbers in `src/shared/Config` (new `Config/Beasts.luau`); no magic numbers in services.
- Server authoritative: XP, levels and stars only ever change through `CardService.AddXP` on the server.
- Every player-data service registers `load/save/unload` with DataService; `save` does nothing if it never loaded.
- Saved-shape changes: bump `SCHEMA_VERSION` (to 3), add a `MIGRATIONS` step, update DESIGN.md 10.4.
- UI text is ASCII plus `·` only: stars are written `"2-star"`, never ★.
- Level 1–30, stars 1–5, `xpToNext(L) = round(50 × L^1.5)`, value per spec 3.2, stats per spec 3.1.
- `--!strict` on every new file; match surrounding code style (comments only where non-obvious).

## Review Focus

1. **Old saves (schema v2)** — must load with every fresh card and displayed card intact and no beasts lost; migration adds `beasts = {}` only. Pinned in Task 3 (Studio step) and Task 1 (`sanitize` tests).
2. **Corrupt or tampered beast entries** (NaN/huge level, negative XP, XP above the level's cap, unknown card, non-table) — must clamp or drop without erroring. Pinned in Task 1 `sanitize` tests.
3. **Beast ID collisions** — a displayed beast restored with an ID that already exists in the binder must get a new ID, never overwrite. Pinned in Task 4 (`restore` code + Studio step 6).
4. **Swapped beast in a Collector Case slot** — owner replaces a Lv 20 with a Lv 1 of the same card while a buyer's confirm box is open; the buy must be refused. Pinned in Task 4 (`expectedBeastId` check + Studio step 5).
5. **XP on a fresh card the player no longer has** (count 0, or card on display) — `AddXP` must return nil and change nothing. Pinned in Task 3 (`AddXP` code) and Task 6 Studio step 2.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `rokit.toml` | modify | add `lune` |
| `tests/lib/expect.luau` | create | tiny assertion helpers for Lune tests |
| `tests/run.luau` | create | Lune test runner |
| `tests/BeastMath.spec.luau` | create | unit tests for BeastMath |
| `src/shared/Config/Beasts.luau` | create | growth/stat/value/XP numbers (plain data, no Roblox types) |
| `src/shared/Util/BeastMath.luau` | create | pure maths + save validation, no requires |
| `src/shared/Util/BeastRules.luau` | create | game-facing wrapper: card + config → BeastMath |
| `src/shared/Util/CardRules.luau` | modify | market value / price clamp / step accept level + stars |
| `src/shared/Config/Data.luau` | modify | `SCHEMA_VERSION = 3` |
| `src/server/Services/DataService.luau` | modify | `SavedBeast`, `beasts` field, v3 migration, `SavedCard` beast fields |
| `src/server/Services/CardService.luau` | rewrite | fresh stacks + beasts, `AddXP`, sync `{stacks, beasts}` |
| `src/server/Services/PackService.luau` | modify | `AddCards` → `AddFresh` |
| `src/server/Services/PlacementService.luau` | modify | displayed cards can be beasts; save/restore; card part attributes |
| `src/server/Services/ShowcaseService.luau` | modify | display/remove/price/buy/return carry beasts |
| `src/server/Services/CustomerService.luau` | modify | card purchase judged on beast value |
| `src/shared/Remotes.luau` | modify | `DisplayCard` + `BuyDisplayedCard` gain a beast ID argument |
| `src/client/Util/CardFace.luau` | modify | optional level/stars line and stats row |
| `src/client/Controllers/BinderController.luau` | modify | stacks + beasts, raised list in detail |
| `src/client/Controllers/ShowcaseController.luau` | modify | picker shows beasts; rows priced on beast value |
| `src/client/Controllers/CardBuyController.luau` | modify | browse/confirm show level; buy sends beast ID |
| `src/server/Services/DevService.luau` | modify | `/beastxp <amount>` |
| `DESIGN.md`, `CLAUDE.md` | modify | beasts section, tree, schema v3, Lune command |

---

### Task 1: Beast maths with Lune tests

**Files:**
- Modify: `rokit.toml`
- Create: `tests/lib/expect.luau`, `tests/run.luau`, `tests/BeastMath.spec.luau`
- Create: `src/shared/Config/Beasts.luau`, `src/shared/Util/BeastMath.luau`

**Interfaces:**
- Produces:
  - `BeastMath.getStats(config, rarity: string, element: string, foil: boolean, level: number, stars: number) -> { hp: number, atk: number, spd: number }`
  - `BeastMath.getValue(config, baseValue: number, foilMultiplier: number, foil: boolean, level: number, stars: number) -> number` (rounded to cents)
  - `BeastMath.getXpToNext(config, level: number) -> number` (0 at max level)
  - `BeastMath.applyXp(config, level: number, xp: number, amount: number) -> (number, number)`
  - `BeastMath.sanitize(config, raw: unknown, isKnownCard: (string) -> boolean) -> BeastData?` where `BeastData = { cardId: string, foil: boolean, level: number, xp: number, stars: number }`
  - Config module `Beasts` with keys used below.

- [ ] **Step 1: Install Lune**

Run:
```powershell
$rk = "$env:USERPROFILE\.rokit\bin\rokit.exe"; & $rk trust lune-org/lune; & $rk add lune-org/lune; & "$env:USERPROFILE\.rokit\bin\lune.exe" --version
```
Expected: `rokit.toml` gains a `lune = "lune-org/lune@<version>"` line; version prints.

- [ ] **Step 2: Write the test helpers and runner**

`tests/lib/expect.luau`:
```lua
--!strict
-- Minimal assertions for Lune unit tests. Errors carry a readable message.
local expect = {}

function expect.equal(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function expect.near(actual: number, expected: number, tolerance: number, label: string?)
	if math.abs(actual - expected) > tolerance then
		error(`{label or "value"}: expected ~{expected}, got {actual}`, 2)
	end
end

function expect.isNil(actual: any, label: string?)
	if actual ~= nil then
		error(`{label or "value"}: expected nil, got {tostring(actual)}`, 2)
	end
end

return expect
```

`tests/run.luau`:
```lua
--!strict
-- Runs every spec file listed below. Each spec returns { [testName] = function }.
-- Usage: lune run tests/run
local process = require("@lune/process")

local specs: { [string]: { [string]: () -> () } } = {
	BeastMath = require("./BeastMath.spec"),
}

local passed, failed = 0, 0
for specName, tests in specs do
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
```

- [ ] **Step 3: Write the failing tests**

`tests/BeastMath.spec.luau`:
```lua
--!strict
local BeastMath = require("../src/shared/Util/BeastMath")
local config = require("../src/shared/Config/Beasts")
local expect = require("./lib/expect")

local function isKnown(cardId: string): boolean
	return cardId == "FS01"
end

return {
	["stats: fresh common ember"] = function()
		local stats = BeastMath.getStats(config, "Common", "Ember", false, 1, 1)
		expect.equal(stats.hp, 60, "hp")
		expect.equal(stats.atk, 14, "atk") -- 12 * 1.2 = 14.4
		expect.equal(stats.spd, 10, "spd")
	end,

	["stats: max foil legendary shade"] = function()
		-- growth = 2.74 (Lv 30) * 1.6 (5 stars) * 1.05 (foil) = 4.6032
		local stats = BeastMath.getStats(config, "Legendary", "Shade", true, 30, 5)
		expect.equal(stats.hp, 690, "hp")
		expect.equal(stats.atk, 152, "atk")
		expect.equal(stats.spd, 81, "spd")
	end,

	["stats: unknown rarity and element fall back"] = function()
		local stats = BeastMath.getStats(config, "Mythic", "Plasma", false, 1, 1)
		expect.equal(stats.hp, 60, "hp")
		expect.equal(stats.atk, 12, "atk")
	end,

	["value: spec example Cindercub Lv 15 3-star"] = function()
		expect.near(BeastMath.getValue(config, 0.20, 3, false, 15, 3), 1.08, 0.001)
	end,

	["value: fresh foil"] = function()
		expect.near(BeastMath.getValue(config, 0.20, 3, true, 1, 1), 0.60, 0.001)
	end,

	["xp curve"] = function()
		expect.equal(BeastMath.getXpToNext(config, 1), 50, "Lv1")
		expect.equal(BeastMath.getXpToNext(config, 2), 141, "Lv2")
		expect.equal(BeastMath.getXpToNext(config, 29), 7808, "Lv29")
		expect.equal(BeastMath.getXpToNext(config, 30), 0, "max")
	end,

	["applyXp: several level-ups carry the remainder"] = function()
		local level, xp = BeastMath.applyXp(config, 1, 0, 500) -- 50 + 141 + 260 = 451
		expect.equal(level, 4, "level")
		expect.equal(xp, 49, "xp")
	end,

	["applyXp: stops at max level with 0 xp"] = function()
		local level, xp = BeastMath.applyXp(config, 29, 7800, 100)
		expect.equal(level, 30, "level")
		expect.equal(xp, 0, "xp")
		local level2, xp2 = BeastMath.applyXp(config, 30, 0, 1000)
		expect.equal(level2, 30, "level at cap")
		expect.equal(xp2, 0, "xp at cap")
	end,

	["applyXp: ignores zero, negative and NaN amounts"] = function()
		local nan = 0 / 0
		for _, amount in { 0, -10, nan } do
			local level, xp = BeastMath.applyXp(config, 3, 20, amount)
			expect.equal(level, 3, "level")
			expect.equal(xp, 20, "xp")
		end
	end,

	["sanitize: clamps out-of-range values"] = function()
		local beast = BeastMath.sanitize(config, { cardId = "FS01", foil = true, level = 99, xp = -5, stars = 9 }, isKnown)
		assert(beast, "expected a beast")
		expect.equal(beast.level, 30, "level")
		expect.equal(beast.stars, 5, "stars")
		expect.equal(beast.xp, 0, "xp")
		expect.equal(beast.foil, true, "foil")
	end,

	["sanitize: xp above the level cap is trimmed"] = function()
		local beast = BeastMath.sanitize(config, { cardId = "FS01", level = 2, xp = 999, stars = 1 }, isKnown)
		assert(beast, "expected a beast")
		expect.equal(beast.xp, 140, "xp") -- xpToNext(2) - 1
		expect.equal(beast.foil, false, "missing foil -> false")
	end,

	["sanitize: NaN level falls back to 1"] = function()
		local beast = BeastMath.sanitize(config, { cardId = "FS01", level = 0 / 0, xp = 0, stars = 1 }, isKnown)
		assert(beast, "expected a beast")
		expect.equal(beast.level, 1, "level")
	end,

	["sanitize: rejects unknown cards and non-tables"] = function()
		expect.isNil(BeastMath.sanitize(config, { cardId = "NOPE", level = 1, xp = 0, stars = 1 }, isKnown), "unknown")
		expect.isNil(BeastMath.sanitize(config, "junk", isKnown), "string")
		expect.isNil(BeastMath.sanitize(config, nil, isKnown), "nil")
	end,
}
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `lune run tests/run` (use `& "$env:USERPROFILE\.rokit\bin\lune.exe" run tests/run` if PATH isn't refreshed)
Expected: error requiring `../src/shared/Util/BeastMath` (module not found).

- [ ] **Step 5: Write the config**

`src/shared/Config/Beasts.luau`:
```lua
--!strict
-- Glimmerbeast growth, stats and value. See DESIGN.md section 5.8 and the beast cards spec.
-- Plain numbers only (no Roblox types) so Lune unit tests can load this file.
return {
	MAX_LEVEL = 30,
	MAX_STARS = 5,

	-- Base stats by rarity, before element, level, stars and foil
	BASE_STATS = {
		Common = { hp = 60, atk = 12, spd = 10 },
		Rare = { hp = 80, atk = 16, spd = 12 },
		Epic = { hp = 110, atk = 22, spd = 14 },
		Legendary = { hp = 150, atk = 30, spd = 16 },
	},
	ELEMENT_MULTIPLIERS = {
		Ember = { hp = 1, atk = 1.2, spd = 1 },
		Tide = { hp = 1.2, atk = 1, spd = 1 },
		Bloom = { hp = 1.1, atk = 1.1, spd = 1 },
		Volt = { hp = 1, atk = 1, spd = 1.25 },
		Shade = { hp = 1, atk = 1.1, spd = 1.1 },
	},
	LEVEL_STAT_GROWTH = 0.06, -- +6% per level above 1
	STAR_STAT_GROWTH = 0.15, -- +15% per star above 1
	FOIL_STAT_MULTIPLIER = 1.05,

	LEVEL_VALUE_GROWTH = 0.10, -- +10% value per level above 1
	STAR_VALUE = { 1, 1.5, 2.25, 3.5, 5 }, -- value multiplier by star count

	-- XP to go from level L to L + 1 = round(XP_BASE * L ^ XP_EXPONENT)
	XP_BASE = 50,
	XP_EXPONENT = 1.5,
}
```

- [ ] **Step 6: Write BeastMath**

`src/shared/Util/BeastMath.luau`:
```lua
--!strict
-- Pure Glimmerbeast maths: stats, value, the XP curve, and validation of saved beasts.
-- No Roblox APIs and no requires, so it runs in Studio and in Lune tests (tests/).
-- Callers pass the config (Config/Beasts.luau) in; BeastRules does that for game code.
export type Stats = { hp: number, atk: number, spd: number }
export type BeastData = { cardId: string, foil: boolean, level: number, xp: number, stars: number }
export type BeastConfig = {
	MAX_LEVEL: number,
	MAX_STARS: number,
	BASE_STATS: { [string]: Stats },
	ELEMENT_MULTIPLIERS: { [string]: Stats },
	LEVEL_STAT_GROWTH: number,
	STAR_STAT_GROWTH: number,
	FOIL_STAT_MULTIPLIER: number,
	LEVEL_VALUE_GROWTH: number,
	STAR_VALUE: { number },
	XP_BASE: number,
	XP_EXPONENT: number,
}

local NO_ELEMENT: Stats = { hp = 1, atk = 1, spd = 1 }

local BeastMath = {}

local function isFiniteNumber(value: unknown): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function clampInteger(value: unknown, min: number, max: number, default: number): number
	if not isFiniteNumber(value) then
		return default
	end
	return math.clamp(math.floor(value :: number), min, max)
end

function BeastMath.getStats(config: BeastConfig, rarity: string, element: string, foil: boolean, level: number, stars: number): Stats
	local base = config.BASE_STATS[rarity] or config.BASE_STATS.Common
	local elementBias = config.ELEMENT_MULTIPLIERS[element] or NO_ELEMENT
	local growth = (1 + config.LEVEL_STAT_GROWTH * (level - 1))
		* (1 + config.STAR_STAT_GROWTH * (stars - 1))
		* (if foil then config.FOIL_STAT_MULTIPLIER else 1)
	return {
		hp = math.round(base.hp * elementBias.hp * growth),
		atk = math.round(base.atk * elementBias.atk * growth),
		spd = math.round(base.spd * elementBias.spd * growth),
	}
end

function BeastMath.getValue(config: BeastConfig, baseValue: number, foilMultiplier: number, foil: boolean, level: number, stars: number): number
	local value = baseValue
		* (if foil then foilMultiplier else 1)
		* (1 + config.LEVEL_VALUE_GROWTH * (level - 1))
		* (config.STAR_VALUE[stars] or 1)
	return math.round(value * 100) / 100
end

function BeastMath.getXpToNext(config: BeastConfig, level: number): number
	if level >= config.MAX_LEVEL then
		return 0
	end
	return math.round(config.XP_BASE * level ^ config.XP_EXPONENT)
end

-- Applies every level-up the XP covers; leftover XP carries over. XP stops at max level.
function BeastMath.applyXp(config: BeastConfig, level: number, xp: number, amount: number): (number, number)
	if not isFiniteNumber(amount) or amount <= 0 then
		return level, xp
	end
	local total = xp + math.floor(amount)
	while level < config.MAX_LEVEL do
		local needed = BeastMath.getXpToNext(config, level)
		if total < needed then
			break
		end
		total -= needed
		level += 1
	end
	if level >= config.MAX_LEVEL then
		total = 0
	end
	return level, total
end

-- Turns untrusted saved data into a valid beast, or nil if it can't be one
function BeastMath.sanitize(config: BeastConfig, raw: unknown, isKnownCard: (string) -> boolean): BeastData?
	if typeof(raw) ~= "table" then
		return nil
	end
	local entry = raw :: { [string]: unknown }
	local cardId = entry.cardId
	if typeof(cardId) ~= "string" or not isKnownCard(cardId) then
		return nil
	end
	local level = clampInteger(entry.level, 1, config.MAX_LEVEL, 1)
	local stars = clampInteger(entry.stars, 1, config.MAX_STARS, 1)
	local xpCap = math.max(0, BeastMath.getXpToNext(config, level) - 1)
	return {
		cardId = cardId,
		foil = entry.foil == true,
		level = level,
		xp = clampInteger(entry.xp, 0, xpCap, 0),
		stars = stars,
	}
end

return BeastMath
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `lune run tests/run`
Expected: `13 passed, 0 failed`.

- [ ] **Step 8: Check the Roblox build still works**

Run: `rojo build -o <scratchpad>/test.rbxl` then `rojo sourcemap default.project.json -o sourcemap.json`
Expected: builds (tests/ is not in the Rojo tree, so nothing new syncs except the two modules).

- [ ] **Step 9: Commit**

```bash
git add rokit.toml tests src/shared/Config/Beasts.luau src/shared/Util/BeastMath.luau
git commit -m "Add beast maths with Lune unit tests"
```

---

### Task 2: BeastRules and beast-aware card prices

**Files:**
- Create: `src/shared/Util/BeastRules.luau`
- Modify: `src/shared/Util/CardRules.luau`

**Interfaces:**
- Consumes: `BeastMath.*` (Task 1), `Config/Beasts`, `Config/Cards`, `Config/Rarities`.
- Produces:
  - `BeastRules.MAX_LEVEL: number`, `BeastRules.MAX_STARS: number`
  - `BeastRules.getStats(card, foil: boolean, level: number, stars: number) -> Stats`
  - `BeastRules.getValue(card, foil: boolean, level: number, stars: number) -> number`
  - `BeastRules.getXpToNext(level: number) -> number`
  - `BeastRules.applyXp(level: number, xp: number, amount: number) -> (number, number)`
  - `BeastRules.sanitize(raw: unknown) -> BeastData?`
  - `BeastRules.describeGrowth(level: number, stars: number) -> string` → `"Lv 6 · 2-star"`
  - `CardRules.getMarketValue(card, foil, level: number?, stars: number?)`, `CardRules.clampPrice(price, card, foil, level?, stars?)`, `CardRules.getPriceStep(card, foil, level?, stars?)` — level/stars default to 1, so existing callers are unchanged.

- [ ] **Step 1: Create BeastRules**

`src/shared/Util/BeastRules.luau`:
```lua
--!strict
-- Beast stats, value and XP for game code (server and client): looks up the card's rarity,
-- element and base value, then defers to the pure BeastMath with the game's config.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Beasts = require(Config:WaitForChild("Beasts"))
local Cards = require(Config:WaitForChild("Cards"))
local Rarities = require(Config:WaitForChild("Rarities"))
local BeastMath = require((script.Parent :: Instance):WaitForChild("BeastMath"))

type Card = typeof(Cards.List[1])

local BeastRules = {}

BeastRules.MAX_LEVEL = Beasts.MAX_LEVEL
BeastRules.MAX_STARS = Beasts.MAX_STARS

local function isKnownCard(cardId: string): boolean
	return Cards.ById[cardId] ~= nil
end

function BeastRules.getStats(card: Card, foil: boolean, level: number, stars: number): BeastMath.Stats
	return BeastMath.getStats(Beasts, card.rarity, card.element, foil, level, stars)
end

function BeastRules.getValue(card: Card, foil: boolean, level: number, stars: number): number
	return BeastMath.getValue(Beasts, card.value, Rarities.FOIL_MULTIPLIER, foil, level, stars)
end

function BeastRules.getXpToNext(level: number): number
	return BeastMath.getXpToNext(Beasts, level)
end

function BeastRules.applyXp(level: number, xp: number, amount: number): (number, number)
	return BeastMath.applyXp(Beasts, level, xp, amount)
end

function BeastRules.sanitize(raw: unknown): BeastMath.BeastData?
	return BeastMath.sanitize(Beasts, raw, isKnownCard)
end

-- "Lv 6 · 2-star" (text, because Roblox's built-in fonts can't draw a star symbol)
function BeastRules.describeGrowth(level: number, stars: number): string
	return `Lv {level} · {stars}-star`
end

return BeastRules
```

- [ ] **Step 2: Make CardRules beast-aware**

In `src/shared/Util/CardRules.luau`:
- Add after the `Showcase` require: `local BeastRules = require((script.Parent :: Instance):WaitForChild("BeastRules"))`
- Remove the now-unused `Rarities` require.
- Replace `getMarketValue`, `clampPrice` and `getPriceStep` with:

```lua
-- Market value of a fresh copy (level 1, 1 star) or a raised beast
function CardRules.getMarketValue(card: Card, foil: boolean, level: number?, stars: number?): number
	return BeastRules.getValue(card, foil, level or 1, stars or 1)
end

-- Showcase price: rounded to cents, between MIN_PRICE and MAX_MARKUP × market value
function CardRules.clampPrice(price: number, card: Card, foil: boolean, level: number?, stars: number?): number
	local market = CardRules.getMarketValue(card, foil, level, stars)
	return math.clamp(roundCents(price), Showcase.MIN_PRICE, roundCents(market * Showcase.MAX_MARKUP))
end

-- One +/- tap in the showcase UI, scaled to the card's value so commons and legendaries both feel right
function CardRules.getPriceStep(card: Card, foil: boolean, level: number?, stars: number?): number
	local step = roundCents(CardRules.getMarketValue(card, foil, level, stars) * Showcase.PRICE_STEP_RATIO)
	return math.max(Showcase.MIN_PRICE_STEP, step)
end
```

- [ ] **Step 3: Build and type-check**

Run: `rojo build -o <scratchpad>/test.rbxl`, `rojo sourcemap default.project.json -o sourcemap.json`, then check VS Code diagnostics for `BeastRules.luau` and `CardRules.luau`.
Expected: build succeeds; no luau-lsp (source "Luau") errors other than the known "unsupported path" on `(script.Parent :: Instance)` requires.

- [ ] **Step 4: Lune regression**

Run: `lune run tests/run` → still `13 passed, 0 failed`.

- [ ] **Step 5: Studio smoke test (user)**

Stop → Play. Open a Glass Showcase's Cards panel: prices, steps and "% of market" for fresh cards are exactly what they were before (fresh = level 1, 1 star). No red errors in Output.

- [ ] **Step 6: Commit**

```bash
git add src/shared/Util/BeastRules.luau src/shared/Util/CardRules.luau
git commit -m "Add BeastRules and level-aware card prices"
```

---

### Task 3: Save schema v3 and CardService stacks + beasts

**Files:**
- Modify: `src/shared/Config/Data.luau`, `src/server/Services/DataService.luau`
- Rewrite: `src/server/Services/CardService.luau`
- Modify: `src/server/Services/PackService.luau`, `src/server/Services/PlacementService.luau` (one call), `src/server/Services/ShowcaseService.luau` (calls only)
- Modify: `src/client/Controllers/BinderController.luau` (payload shape only)

**Interfaces:**
- Consumes: `BeastRules.sanitize`, `BeastRules.applyXp` (Task 2).
- Produces (CardService):
  - `export type Beast = { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number }`
  - `export type XpTarget = string | { cardId: string, foil: boolean }`
  - `AddFresh(player, results: { { cardId: string, foil: boolean } })`
  - `TakeFresh(player, cardId: string, foil: boolean) -> boolean`
  - `AddBeast(player, beast: Beast) -> Beast` (assigns a new ID if the ID is taken)
  - `TakeBeast(player, beastId: string) -> Beast?`
  - `GetBeast(player, beastId: string) -> Beast?`
  - `GetBeasts(player) -> { [string]: Beast }`, `GetStacks(player) -> { [string]: Owned }`
  - `GiveCard(player, cardId: string, foil: boolean, beast: Beast?)` (beast → AddBeast, else AddFresh)
  - `AddXP(player, target: XpTarget, amount: number) -> Beast?`
  - `IsLoaded(player) -> boolean`
  - Client payload of `CollectionChanged`: `{ stacks: { [cardId]: Owned }, beasts: { [beastId]: Beast } }`
- Produces (DataService): `export type SavedBeast = { cardId: string, foil: boolean, level: number, xp: number, stars: number }`; `PlayerData.beasts: { [string]: SavedBeast }`; `SavedCard` gains `beastId: string?, level: number?, xp: number?, stars: number?`.

- [ ] **Step 1: Schema v3 in DataService and config**

`src/shared/Config/Data.luau`: `SCHEMA_VERSION = 3`.

`src/server/Services/DataService.luau`:
- Replace the `SavedCard` type and add `SavedBeast`:
```lua
export type SavedCard = {
	slot: number,
	cardId: string,
	foil: boolean,
	price: number,
	-- Set when the displayed card is a raised beast
	beastId: string?,
	level: number?,
	xp: number?,
	stars: number?,
}
export type SavedBeast = { cardId: string, foil: boolean, level: number, xp: number, stars: number }
```
- In `PlayerData` add after `cards`: `beasts: { [string]: SavedBeast }, -- raised beasts by ID`
- In `TEMPLATE` add after `cards = {},`: `beasts = {},`
- In `MIGRATIONS` add:
```lua
	-- v3: raised beasts live in their own table; existing cards are fresh stacks already
	[2] = function(data)
		data.beasts = data.beasts or {}
	end,
```

- [ ] **Step 2: Rewrite CardService**

Replace the whole of `src/server/Services/CardService.luau` with:
```lua
--!strict
-- Each player's cards: fresh stacks { [cardId] = { normal, foil } } of untouched copies, and raised
-- beasts { [beastId] = Beast } with their own level, XP and stars. A fresh copy becomes a beast the
-- first time it gains XP. Cards on display leave here while shown (PlacementService holds them).
-- The client gets { stacks, beasts } on every change. Saved through DataService.
-- (DESIGN.md calls this CollectionService; renamed to avoid clashing with Roblox's own service.)
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Collection = require(Config:WaitForChild("Collection"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local DataService = require(Services:WaitForChild("DataService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData

export type Owned = { normal: number, foil: number }
export type PullResult = { cardId: string, foil: boolean }
export type Beast = { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number }
export type XpTarget = string | { cardId: string, foil: boolean }

type Inventory = { stacks: { [string]: Owned }, beasts: { [string]: Beast } }

local CardService = {}

local inventories: { [Player]: Inventory } = {}
local allowRequest = RateLimiter.new(Collection.REQUEST_COOLDOWN)

local function sync(player: Player)
	local inventory = inventories[player]
	if inventory then
		Remotes.CollectionChanged:FireClient(player, { stacks = inventory.stacks, beasts = inventory.beasts })
	end
end

local function getOwned(stacks: { [string]: Owned }, cardId: string): Owned
	local owned = stacks[cardId]
	if not owned then
		owned = { normal = 0, foil = 0 }
		stacks[cardId] = owned
	end
	return owned
end

-- Removes one fresh copy without syncing; returns false if there is none
local function takeFreshCopy(inventory: Inventory, cardId: string, foil: boolean): boolean
	local owned = inventory.stacks[cardId]
	if not owned then
		return false
	end
	if foil then
		if owned.foil <= 0 then
			return false
		end
		owned.foil -= 1
	else
		if owned.normal <= 0 then
			return false
		end
		owned.normal -= 1
	end
	return true
end

-- Adds a batch of fresh copies (a pack, a purchase, cards coming back off display) and syncs once
function CardService.AddFresh(player: Player, results: { PullResult })
	local inventory = inventories[player]
	if not inventory then
		return
	end
	for _, result in results do
		if Cards.ById[result.cardId] then
			local owned = getOwned(inventory.stacks, result.cardId)
			if result.foil then
				owned.foil += 1
			else
				owned.normal += 1
			end
		end
	end
	sync(player)
end

function CardService.TakeFresh(player: Player, cardId: string, foil: boolean): boolean
	local inventory = inventories[player]
	if not inventory or not takeFreshCopy(inventory, cardId, foil) then
		return false
	end
	sync(player)
	return true
end

-- Adds a raised beast. Keeps its ID unless that ID is already used, then gives it a new one.
function CardService.AddBeast(player: Player, beast: Beast): Beast
	local inventory = inventories[player]
	if not inventory then
		return beast
	end
	if inventory.beasts[beast.id] then
		beast = table.clone(beast)
		beast.id = HttpService:GenerateGUID(false)
	end
	inventory.beasts[beast.id] = beast
	sync(player)
	return beast
end

function CardService.TakeBeast(player: Player, beastId: string): Beast?
	local inventory = inventories[player]
	local beast = if inventory then inventory.beasts[beastId] else nil
	if not inventory or not beast then
		return nil
	end
	inventory.beasts[beastId] = nil
	sync(player)
	return beast
end

function CardService.GetBeast(player: Player, beastId: string): Beast?
	local inventory = inventories[player]
	return if inventory then inventory.beasts[beastId] else nil
end

function CardService.GetBeasts(player: Player): { [string]: Beast }
	local inventory = inventories[player]
	return if inventory then inventory.beasts else {}
end

function CardService.GetStacks(player: Player): { [string]: Owned }
	local inventory = inventories[player]
	return if inventory then inventory.stacks else {}
end

-- Returns a card to the binder the way it left: as its beast, or as a fresh copy
function CardService.GiveCard(player: Player, cardId: string, foil: boolean, beast: Beast?)
	if beast then
		CardService.AddBeast(player, beast)
	else
		CardService.AddFresh(player, { { cardId = cardId, foil = foil } })
	end
end

-- The only way beasts gain XP. A fresh-card target splits one copy off its stack into a new beast.
-- Returns the beast, or nil if the player doesn't have the target.
function CardService.AddXP(player: Player, target: XpTarget, amount: number): Beast?
	local inventory = inventories[player]
	if not inventory then
		return nil
	end
	local beast: Beast?
	if typeof(target) == "string" then
		beast = inventory.beasts[target]
	elseif Cards.ById[target.cardId] and takeFreshCopy(inventory, target.cardId, target.foil) then
		local newBeast: Beast = {
			id = HttpService:GenerateGUID(false),
			cardId = target.cardId,
			foil = target.foil,
			level = 1,
			xp = 0,
			stars = 1,
		}
		inventory.beasts[newBeast.id] = newBeast
		beast = newBeast
	end
	if not beast then
		return nil
	end
	beast.level, beast.xp = BeastRules.applyXp(beast.level, beast.xp, amount)
	sync(player)
	return beast
end

function CardService.IsLoaded(player: Player): boolean
	return inventories[player] ~= nil
end

local function readCount(value: unknown): number
	return if typeof(value) == "number" and value == value and value > 0 then math.floor(value) else 0
end

-- Unknown card IDs, bad counts and invalid beasts in saved data are dropped or clamped
local function load(player: Player, data: PlayerData)
	local stacks: { [string]: Owned } = {}
	for cardId, saved in data.cards do
		if Cards.ById[cardId] and typeof(saved) == "table" then
			local owned = { normal = readCount(saved.normal), foil = readCount(saved.foil) }
			if owned.normal + owned.foil > 0 then
				stacks[cardId] = owned
			end
		end
	end

	local beasts: { [string]: Beast } = {}
	for beastId, saved in data.beasts do
		local clean = BeastRules.sanitize(saved)
		if typeof(beastId) == "string" and clean then
			beasts[beastId] = {
				id = beastId,
				cardId = clean.cardId,
				foil = clean.foil,
				level = clean.level,
				xp = clean.xp,
				stars = clean.stars,
			}
		end
	end

	inventories[player] = { stacks = stacks, beasts = beasts }
	sync(player)
end

local function save(player: Player, data: PlayerData)
	local inventory = inventories[player]
	if not inventory then
		return
	end
	local cards = {}
	for cardId, owned in inventory.stacks do
		if owned.normal + owned.foil > 0 then
			cards[cardId] = { normal = owned.normal, foil = owned.foil }
		end
	end
	local beasts = {}
	for beastId, beast in inventory.beasts do
		beasts[beastId] = { cardId = beast.cardId, foil = beast.foil, level = beast.level, xp = beast.xp, stars = beast.stars }
	end
	data.cards = cards
	data.beasts = beasts
end

function CardService.Start()
	DataService.Register({
		name = "CardService",
		load = load,
		save = save,
		unload = function(player: Player)
			inventories[player] = nil
		end,
	})

	Remotes.RequestCollection.OnServerEvent:Connect(function(player)
		if allowRequest(player) then
			sync(player)
		end
	end)
end

return CardService
```

- [ ] **Step 3: Update call sites to the renamed API**

- `PackService.luau`: in `deliverPack`, `CardService.AddCards(player, results)` → `CardService.AddFresh(player, results)`.
- `PlacementService.luau`: in `load`, `CardService.AddCards(player, leftovers)` → `CardService.AddFresh(player, leftovers)`.
- `ShowcaseService.luau`: `CardService.TakeCard(` → `CardService.TakeFresh(`; every `CardService.AddCards(` → `CardService.AddFresh(`.

Run a search to confirm nothing still calls the old names:
`Grep "AddCards|TakeCard\(" src` → no matches.

- [ ] **Step 4: Client reads the new payload**

In `BinderController.luau`:
- Add `type Beast = { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number }` next to `Owned`.
- Add state `local beasts: { [string]: Beast } = {}` next to `collection`.
- Replace `onCollectionChanged` with:
```lua
local function onCollectionChanged(payload: { stacks: { [string]: Owned }, beasts: { [string]: Beast } })
	if typeof(payload) ~= "table" then
		return
	end
	collection = if typeof(payload.stacks) == "table" then payload.stacks else {}
	beasts = if typeof(payload.beasts) == "table" then payload.beasts else {}
	refresh()
end
```
- Add next to `GetCollection`:
```lua
-- The player's raised beasts (not counting ones on display)
function BinderController.GetBeasts(): { [string]: Beast }
	return beasts
end
```
(`ShowcaseController` keeps using `GetCollection()` for fresh stacks until Task 5.)

- [ ] **Step 5: Build, type-check, regression tests**

Run `rojo build`, `rojo sourcemap`, VS Code diagnostics for the changed files, and `lune run tests/run`.
Expected: build OK, no new Luau errors, Lune `13 passed`.

- [ ] **Step 6: Studio test (user) — Review Focus 1**

1. Stop → Play with your existing save. Output: no `[DataService] ... failed`. Binder shows the same cards and counts as before; cards in your cases are still there.
2. Rip a pack: binder counts go up as before.
3. Put a fresh card in a case and Remove it: it comes back to the binder.
4. Stop → Play: everything above persists.

- [ ] **Step 7: Commit**

```bash
git add src/shared/Config/Data.luau src/server/Services src/client/Controllers/BinderController.luau
git commit -m "Store raised beasts alongside fresh stacks (schema v3)"
```

---

### Task 4: Beasts in cases, customer sales and player purchases

**Files:**
- Modify: `src/server/Services/PlacementService.luau`, `src/server/Services/ShowcaseService.luau`, `src/server/Services/CustomerService.luau`, `src/shared/Remotes.luau`

**Interfaces:**
- Consumes: `CardService.Beast`, `CardService.TakeBeast`, `CardService.GetBeast`, `CardService.GiveCard` (Task 3); `CardRules` level-aware functions, `BeastRules.sanitize`, `BeastRules.describeGrowth` (Task 2).
- Produces:
  - `PlacementService.DisplayedCard = { cardId: string, foil: boolean, price: number, beast: CardService.Beast? }`
  - Card part attributes: `CardId, Foil, Price, Slot, ShelfUid, OwnerUserId, ShelfKind` (existing) plus `Level: number`, `Stars: number`, `BeastId: string?`.
  - Remote `DisplayCard(shelfUid, slot, cardId, foil, beastId: string?)`.
  - Remote `BuyDisplayedCard(ownerUserId, shelfUid, slot, cardId, foil, expectedPrice, expectedBeastId: string?)`.

- [ ] **Step 1: Remotes comments**

In `src/shared/Remotes.luau` replace the two entries:
```lua
	"DisplayCard", -- client → server: (shelfUid: string, slot: number, cardId: string, foil: boolean, beastId: string?) binder → case
	...
	"BuyDisplayedCard", -- client → server: (ownerUserId, shelfUid, slot, cardId, foil, expectedPrice, expectedBeastId?) from a Collector Case
```

- [ ] **Step 2: PlacementService — beast-carrying displayed cards**

- Requires: add `local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))`.
- Types: replace `export type DisplayedCard = ...` with
```lua
type Beast = CardService.Beast
-- A card in a case slot: a fresh copy (beast = nil) or a specific raised beast
export type DisplayedCard = { cardId: string, foil: boolean, price: number, beast: Beast? }
```
- Add helper above `buildCardPart`:
```lua
local function getGrowth(displayed: DisplayedCard): (number, number)
	local beast = displayed.beast
	return if beast then beast.level else 1, if beast then beast.stars else 1
end
```
- In `buildCardPart`, after `part:SetAttribute("ShelfKind", shelf.def.kind)` add:
```lua
	local level, stars = getGrowth(displayed)
	part:SetAttribute("Level", level)
	part:SetAttribute("Stars", stars)
	part:SetAttribute("BeastId", if displayed.beast then displayed.beast.id else nil)
```
  and replace the four `addCardText` lines with:
```lua
	addCardText(frame, card.name, 0.04, 0.2)
	if displayed.foil then
		addCardText(frame, "FOIL", 0.25, 0.12)
	end
	if displayed.beast then
		addCardText(frame, BeastRules.describeGrowth(level, stars), 0.38, 0.13)
	end
	addCardText(frame, card.rarity, 0.53, 0.14).TextColor3 = Rarities.Tiers[card.rarity].color
	addCardText(frame, string.format("$%.2f", displayed.price), 0.72, 0.22).Name = "PriceLabel"
```
- In `renderCardSlot`, extend the "same card" check so a different beast rebuilds the part:
```lua
	if existing and displayed
		and existing:GetAttribute("CardId") == displayed.cardId
		and existing:GetAttribute("Foil") == displayed.foil
		and existing:GetAttribute("BeastId") == (if displayed.beast then displayed.beast.id else nil)
	then
```
- In `save`, replace the `savedCards` insert with:
```lua
			local beast = displayed.beast
			table.insert(savedCards, {
				slot = slot,
				cardId = displayed.cardId,
				foil = displayed.foil,
				price = displayed.price,
				beastId = if beast then beast.id else nil,
				level = if beast then beast.level else nil,
				xp = if beast then beast.xp else nil,
				stars = if beast then beast.stars else nil,
			})
```
- In `readSavedCards`, replace the body from `local card = Cards.ById[entry.cardId]` through the `local displayed` line with:
```lua
		local card = Cards.ById[entry.cardId]
		if not card then
			continue
		end
		local beast: Beast? = nil
		if typeof(entry.beastId) == "string" then
			local clean = BeastRules.sanitize(entry)
			if clean then
				beast = { id = entry.beastId, cardId = clean.cardId, foil = clean.foil, level = clean.level, xp = clean.xp, stars = clean.stars }
			end
		end
		local level = if beast then beast.level else 1
		local stars = if beast then beast.stars else 1
		local price = if typeof(entry.price) == "number" and entry.price == entry.price
			then CardRules.clampPrice(entry.price, card, entry.foil, level, stars)
			else CardRules.getMarketValue(card, entry.foil, level, stars)
		local displayed: DisplayedCard = { cardId = entry.cardId, foil = entry.foil, price = price, beast = beast }
```
- In `restoreShelf`, replace the final loop with (Review Focus 3 — an ID already in the binder gets a new one):
```lua
	for slot, displayed in readSavedCards(def, saved.cards, leftovers) do
		local beast = displayed.beast
		if beast and CardService.GetBeast(player, beast.id) then
			beast.id = HttpService:GenerateGUID(false)
		end
		PlacementService.SetDisplayedCard(shelf, slot, displayed)
	end
```
- In `load`, replace the leftovers block with:
```lua
	for _, displayed in leftovers do
		CardService.GiveCard(player, displayed.cardId, displayed.foil, displayed.beast)
	end
```

- [ ] **Step 3: ShowcaseService — display, remove, price, buy, customers**

- Requires: add `local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))`.
- Add helper below `isSlot`:
```lua
local function getGrowth(displayed: DisplayedCard): (number, number)
	local beast = displayed.beast
	return if beast then beast.level else 1, if beast then beast.stars else 1
end
```
- Replace `describe` with:
```lua
local function describe(displayed: DisplayedCard): string
	local card = Cards.ById[displayed.cardId]
	local name = `{if displayed.foil then "foil " else ""}{card.name}`
	local beast = displayed.beast
	return if beast then `{name} ({BeastRules.describeGrowth(beast.level, beast.stars)})` else name
end
```
- Replace `onDisplayCard` with:
```lua
local function onDisplayCard(player: Player, shelfUid: unknown, slot: unknown, cardId: unknown, foil: unknown, beastId: unknown)
	if not allowAction(player) or not isSlot(slot) or typeof(cardId) ~= "string" or typeof(foil) ~= "boolean" then
		return
	end
	local card = Cards.ById[cardId]
	local shelf = getOwnCase(player, shelfUid)
	if not card or not shelf then
		return
	end
	local slotNumber = slot :: number
	if slotNumber > shelf.def.capacity or shelf.cards[slotNumber] then
		return
	end

	local beast: CardService.Beast? = nil
	if typeof(beastId) == "string" then
		local owned = CardService.GetBeast(player, beastId)
		if not owned or owned.cardId ~= cardId or owned.foil ~= foil then
			notify(player, "You don't have that beast in your binder.", true)
			return
		end
		beast = CardService.TakeBeast(player, beastId)
	elseif not CardService.TakeFresh(player, cardId, foil) then
		notify(player, "You don't have that card in your binder.", true)
		return
	end

	local level = if beast then beast.level else 1
	local stars = if beast then beast.stars else 1
	PlacementService.SetDisplayedCard(shelf, slotNumber, {
		cardId = cardId,
		foil = foil,
		price = CardRules.clampPrice(CardRules.getMarketValue(card, foil, level, stars), card, foil, level, stars),
		beast = beast,
	})
end
```
- In `onRemoveCard` replace the `CardService.AddFresh(...)` line with:
  `CardService.GiveCard(player, displayed.cardId, displayed.foil, displayed.beast)`
- In `onSetPrices`, replace the `PlacementService.SetDisplayedCard(...)` call with:
```lua
			local level, stars = getGrowth(displayed)
			PlacementService.SetDisplayedCard(shelf, slot :: number, {
				cardId = displayed.cardId,
				foil = displayed.foil,
				price = CardRules.clampPrice(price, card, displayed.foil, level, stars),
				beast = displayed.beast,
			})
```
- In `onBuyCard` (Review Focus 4): add a final parameter `expectedBeastId: unknown`, and right after the existing `displayed.cardId ~= cardId or displayed.foil ~= foil` check add:
```lua
	local actualBeastId = if displayed.beast then displayed.beast.id else nil
	local wantedBeastId = if typeof(expectedBeastId) == "string" then expectedBeastId else nil
	if actualBeastId ~= wantedBeastId then
		notify(buyer, "That card is no longer for sale.", true)
		return
	end
```
  and replace `CardService.AddFresh(buyer, { { cardId = displayed.cardId, foil = displayed.foil } })` with
  `CardService.GiveCard(buyer, displayed.cardId, displayed.foil, displayed.beast)`.
- In `ReturnFromCustomer`, replace the final `CardService.AddFresh(...)` with
  `CardService.GiveCard(owner, displayed.cardId, displayed.foil, displayed.beast)`.

- [ ] **Step 4: CustomerService judges a beast at its value**

In `shopForCard`, replace the `band` line with:
```lua
	local level = if displayed.beast then displayed.beast.level else 1
	local stars = if displayed.beast then displayed.beast.stars else 1
	local band = PriceRules.getBand(displayed.price, CardRules.getMarketValue(card, displayed.foil, level, stars))
```

- [ ] **Step 5: Build, type-check, regression tests**

Run `rojo build`, `rojo sourcemap`, VS Code diagnostics for the four files, `lune run tests/run`.
Expected: build OK, no new Luau errors, Lune `13 passed`. (The client still sends no beast ID, so behaviour for fresh cards is unchanged until Task 5.)

- [ ] **Step 6: Studio regression (user)**

Fresh-card flows still work end to end: display → customer buys from a Glass Showcase; display → second player buys from a Collector Case; Remove; Stop → Play keeps displayed cards. (Beast-specific checks run in Task 6 once XP can be granted.)

- [ ] **Step 7: Commit**

```bash
git add src/server/Services src/shared/Remotes.luau
git commit -m "Carry raised beasts through cases, customer sales and purchases"
```

---

### Task 5: UI — card faces, binder, picker, browse

**Files:**
- Modify: `src/client/Util/CardFace.luau`, `src/client/Controllers/BinderController.luau`, `src/client/Controllers/ShowcaseController.luau`, `src/client/Controllers/CardBuyController.luau`

**Interfaces:**
- Consumes: `BeastRules.getStats/getValue/getXpToNext/describeGrowth`, `CardRules` level-aware functions (Task 2); payload + `BinderController.GetBeasts()` (Task 3); remotes and card part attributes `Level/Stars/BeastId` (Task 4).
- Produces: `CardFace.render(frame, stroke, card, foil, showValue: boolean?, growth: { level: number, stars: number }?)`.

- [ ] **Step 1: CardFace — level line and stats row**

In `CardFace.luau`:
- Add require: `local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))`.
- Add type: `export type Growth = { level: number, stars: number }`.
- Replace `CardFace.render` with:
```lua
-- showValue = false for small tiles (hides value and stats). growth = nil for a fresh copy.
function CardFace.render(frame: Frame, stroke: UIStroke, card: Card, foil: boolean, showValue: boolean?, growth: Growth?)
	clear(frame)
	local level = if growth then growth.level else 1
	local stars = if growth then growth.stars else 1
	frame.BackgroundColor3 = Cards.ELEMENTS[card.element] or BACK_COLOR
	stroke.Color = CardFace.getRarityColor(card.rarity)
	stroke.Thickness = PackOpening.STROKE_THICKNESS[card.rarity] or 2

	CardFace.addLabel(frame, card.name, 0.05, 0.14, Enum.Font.FredokaOne)
	-- Placeholder art until real card art exists: the element's initial, big
	CardFace.addLabel(frame, string.sub(card.element, 1, 1), 0.24, 0.3, Enum.Font.FredokaOne).TextTransparency = 0.3
	if growth then
		CardFace.addLabel(frame, BeastRules.describeGrowth(level, stars), 0.55, 0.08, Enum.Font.GothamBold)
	end
	if showValue ~= false then
		local stats = BeastRules.getStats(card, foil, level, stars)
		CardFace.addLabel(frame, `HP {stats.hp} · ATK {stats.atk} · SPD {stats.spd}`, 0.64, 0.07, Enum.Font.GothamBold)
	end
	CardFace.addLabel(frame, card.rarity, 0.72, 0.1, Enum.Font.GothamBold).TextColor3 = CardFace.getRarityColor(card.rarity)
	if showValue ~= false then
		CardFace.addLabel(frame, string.format("$%.2f", BeastRules.getValue(card, foil, level, stars)), 0.84, 0.1, Enum.Font.GothamBold)
	end

	-- Plain text only: Roblox's built-in fonts have no glyphs for symbols like stars
	if foil then
		CardFace.addLabel(frame, "FOIL", 0.18, 0.06, Enum.Font.GothamBold)
		addFoilShimmer(frame)
	end
end
```
- `CardRules` is no longer used in CardFace; remove that require.

- [ ] **Step 2: Binder — raised beasts**

In `BinderController.luau`:
- Requires: add `local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))`.
- Add helpers below `getCount`:
```lua
-- This card's raised beasts in the binder, strongest (highest value) first
local function getRaised(cardId: string): { Beast }
	local list: { Beast } = {}
	for _, beast in beasts do
		if beast.cardId == cardId then
			table.insert(list, beast)
		end
	end
	local card = Cards.ById[cardId]
	table.sort(list, function(a, b)
		return BeastRules.getValue(card, a.foil, a.level, a.stars) > BeastRules.getValue(card, b.foil, b.level, b.stars)
	end)
	return list
end
```
- In `refresh`, a card counts as owned if `binderTotal + shown + #getRaised(id) > 0`, and the badge becomes:
```lua
			local raised = #getRaised(tile.card.id)
			local freshText = if binderTotal == 0
				then (if raised > 0 then "" else "on display")
				elseif inBinder.foil == 0 then `x{inBinder.normal}`
				elseif inBinder.normal == 0 then `{inBinder.foil} foil`
				else `x{inBinder.normal} · {inBinder.foil} foil`
			tile.countLabel.Text = if raised > 0
				then (if freshText == "" then `{raised} raised` else `{freshText} · {raised} raised`)
				else freshText
```
- Detail view: add state `local raisedList: ScrollingFrame`. In `buildDetail`, change `detailInfo.Size` to `UDim2.new(1, -192, 0, 92)` and add below it:
```lua
	raisedList = Instance.new("ScrollingFrame")
	raisedList.Position = UDim2.fromOffset(180, 112)
	raisedList.Size = UDim2.new(1, -192, 0, 76)
	raisedList.BackgroundTransparency = 1
	raisedList.BorderSizePixel = 0
	raisedList.ScrollBarThickness = 4
	raisedList.CanvasSize = UDim2.new()
	raisedList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	raisedList.ZIndex = 11
	raisedList.Parent = detail
	local raisedLayout = Instance.new("UIListLayout")
	raisedLayout.Padding = UDim.new(0, 4)
	raisedLayout.SortOrder = Enum.SortOrder.LayoutOrder
	raisedLayout.Parent = raisedList
```
- In `refreshDetail`, replace the `detailInfo.Text = ...` block with a shorter text and fill the list:
```lua
	detailInfo.Text = string.format(
		"#%02d %s · %s %s\nFresh: %d normal, %d foil · on display: %d\nMarket (fresh): $%.2f (foil $%.2f)",
		card.number, card.name, card.element, card.rarity,
		inBinder.normal, inBinder.foil, shown.normal + shown.foil,
		CardRules.getMarketValue(card, false), CardRules.getMarketValue(card, true)
	)
	for _, child in raisedList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local raised = getRaised(card.id)
	for index, beast in raised do
		local stats = BeastRules.getStats(card, beast.foil, beast.level, beast.stars)
		local toNext = BeastRules.getXpToNext(beast.level)
		local line = UIKit.label(raisedList, string.format(
			"%s%s · XP %s · $%.2f\nHP %d  ATK %d  SPD %d",
			if beast.foil then "FOIL " else "",
			BeastRules.describeGrowth(beast.level, beast.stars),
			if toNext > 0 then `{beast.xp}/{toNext}` else "max",
			BeastRules.getValue(card, beast.foil, beast.level, beast.stars),
			stats.hp, stats.atk, stats.spd
		), Enum.Font.Gotham, 12, UIKit.Colors.Text)
		line.LayoutOrder = index
		line.Size = UDim2.new(1, -6, 0, 30)
		line.ZIndex = 12
	end
	if #raised == 0 then
		local none = UIKit.label(raisedList, "No raised beasts yet. " .. HOW_TO_SELL, Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
		none.Size = UDim2.new(1, -6, 0, 60)
		none.ZIndex = 12
	end
```
- In `refreshDetail`, the "owned" early-return must also count raised beasts: `if inBinder.normal + inBinder.foil + shown.normal + shown.foil + #getRaised(card.id) == 0 then`.

- [ ] **Step 3: Case picker and slot rows**

In `ShowcaseController.luau`:
- Requires: add `local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))`.
- `makeCardFace(parent, card, foil, showValue, growth: CardFace.Growth?)` — pass `growth` through to `CardFace.render`.
- Add helper:
```lua
local function getGrowthFromPart(part: BasePart): (number, number)
	local level, stars = part:GetAttribute("Level"), part:GetAttribute("Stars")
	return if typeof(level) == "number" then level else 1, if typeof(stars) == "number" then stars else 1
end
```
- In `buildFilledRow`: after reading `foil`, add `local level, stars = getGrowthFromPart(cardPart)`; use `CardRules.getMarketValue(card, foil, level, stars)` and `CardRules.getPriceStep(card, foil, level, stars)`; `nudge` and `setTypedPrice` clamp with `CardRules.clampPrice(newPrice, card, foil, level, stars)` (add `level, stars` parameters to both and pass them through); the thumbnail gets `if level > 1 or stars > 1 then { level = level, stars = stars } else nil`; the title appends `· {BeastRules.describeGrowth(level, stars)}` when `level > 1 or stars > 1`.
- In `renderPicker`, before the fresh-stack loop, add raised beasts (rarest/most valuable first), each sending its ID:
```lua
	local raised = {}
	for _, beast in BinderController.GetBeasts() do
		table.insert(raised, beast)
	end
	table.sort(raised, function(a, b)
		local cardA, cardB = Cards.ById[a.cardId], Cards.ById[b.cardId]
		return BeastRules.getValue(cardA, a.foil, a.level, a.stars) > BeastRules.getValue(cardB, b.foil, b.level, b.stars)
	end)
	for _, beast in raised do
		local card = Cards.ById[beast.cardId]
		if card and passesFilter(card, beast.foil) then
			order += 1
			local tile = Instance.new("TextButton")
			tile.LayoutOrder = order
			tile.BackgroundTransparency = 1
			tile.Text = ""
			tile.Parent = pickerList
			makeCardFace(tile, card, beast.foil, true, { level = beast.level, stars = beast.stars })
			tile.Activated:Connect(function()
				local part, slot = casePart, pickerSlot
				picker.Visible = false
				if part and slot then
					Remotes.DisplayCard:FireServer(part:GetAttribute("ShelfUid"), slot, card.id, beast.foil, beast.id)
				end
			end)
		end
	end
```
- The empty-state check uses `next(collection) == nil and next(BinderController.GetBeasts()) == nil`.

- [ ] **Step 4: Browse panel and buy confirm**

In `CardBuyController.luau`:
- Requires: add `local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))`.
- Add `getGrowthFromPart` (same as Step 3).
- `describe(part)`: append ` ({BeastRules.describeGrowth(level, stars)})` when `level > 1 or stars > 1`.
- Every `CardRules.getMarketValue(card, foil)` becomes `CardRules.getMarketValue(card, foil, level, stars)` using `getGrowthFromPart(part)`.
- `makeFace(...)` gains a `growth` parameter passed to `CardFace.render`; tiles and the detail view pass the part's growth (nil when level 1 and 1 star).
- `onConfirmBuy`: add a final argument `part:GetAttribute("BeastId")` to `Remotes.BuyDisplayedCard:FireServer(...)`.

- [ ] **Step 5: Build, type-check, regression tests**

Run `rojo build`, `rojo sourcemap`, diagnostics for the four files, `lune run tests/run` (`13 passed`).

- [ ] **Step 6: Studio check (user)**

Pack reveal cards now show an HP · ATK · SPD row and no level line. Binder tiles/detail look as before plus "No raised beasts yet". Picker and browse look as before for fresh cards. (Beasts appear in Task 6.)

- [ ] **Step 7: Commit**

```bash
git add src/client
git commit -m "Show beast level, stars and stats in card faces, binder, picker and browse"
```

---

### Task 6: /beastxp, docs, and the full beast test pass

**Files:**
- Modify: `src/server/Services/DevService.luau`, `DESIGN.md`, `CLAUDE.md`

**Interfaces:**
- Consumes: `CardService.AddXP/GetBeasts/GetStacks` (Task 3), `BeastRules.describeGrowth` (Task 2).

- [ ] **Step 1: /beastxp**

In `DevService.luau`:
- Requires: `local Cards = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Cards"))`, `local Rarities = require(...Config:WaitForChild("Rarities"))`, `local BeastRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("BeastRules"))`, `local CardService = require(Services:WaitForChild("CardService"))`.
- Add:
```lua
-- Highest-rarity raised beast (then highest level); otherwise the rarest fresh copy, foil first
local function pickXpTarget(player: Player): CardService.XpTarget?
	local best: CardService.Beast? = nil
	local bestScore = -1
	for _, beast in CardService.GetBeasts(player) do
		local card = Cards.ById[beast.cardId]
		local score = Rarities.Tiers[card.rarity].order * 100 + beast.level
		if score > bestScore then
			best, bestScore = beast, score
		end
	end
	if best then
		return best.id
	end
	local stacks = CardService.GetStacks(player)
	for index = #Cards.List, 1, -1 do
		local card = Cards.List[index]
		local owned = stacks[card.id]
		if owned and owned.foil > 0 then
			return { cardId = card.id, foil = true }
		elseif owned and owned.normal > 0 then
			return { cardId = card.id, foil = false }
		end
	end
	return nil
end

local function grantBeastXp(player: Player, amount: number)
	local target = pickXpTarget(player)
	local beast = if target then CardService.AddXP(player, target, amount) else nil
	if not beast then
		Remotes.Notify:FireClient(player, "No card in your binder to give XP to.", true)
		return
	end
	local card = Cards.ById[beast.cardId]
	Remotes.Notify:FireClient(player, `{card.name} is now {BeastRules.describeGrowth(beast.level, beast.stars)}`, false)
end
```
- Register: `addCommand(folder, "beastxp", withAmount(grantBeastXp))`, add `/beastxp <amount>` to the header comment and the startup print. Add `local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))` if not present.

- [ ] **Step 2: Docs**

DESIGN.md:
- New section **5.8 Glimmerbeasts** after 5.7: the roadmap (5 sub-projects), the beast fields, the stat/value/XP formulas (copy the tables from spec section 3), and "fresh copies stack; a copy becomes a beast when it first gains XP".
- 10.2 tree: add `Config/Beasts.luau`, `Util/BeastMath.luau` (pure, Lune-tested), `Util/BeastRules.luau`, and a top-level `tests/` folder.
- 10.4 schema: add `beasts = {}, -- { [beastId] = { cardId, foil, level, xp, stars } }`; layout `cards` entries gain `beastId?, level?, xp?, stars?`; schema history adds "v3 raised beasts table".
- 7.4 Staff: note that beast shop jobs (roadmap 2) replace hired staff.

CLAUDE.md, Commands section: add
`- lune run tests/run — unit tests for pure modules (BeastMath). Pure logic goes in Roblox-free modules so it can be tested here.`

- [ ] **Step 3: Build, type-check, tests**

`rojo build`, `rojo sourcemap`, diagnostics for DevService, `lune run tests/run` (`13 passed`).

- [ ] **Step 4: Full Studio beast test (user) — spec section 7 + Review Focus**

1. Existing save loads unchanged (fresh stacks, displayed cards).
2. `/beastxp 500` with a fresh legendary: toast "Solarion is now Lv 4 · 1-star"; binder shows the stack one lower and "1 raised"; detail lists the beast with XP 49/400. With an empty binder: "No card in your binder to give XP to." (Review Focus 5).
3. Repeat `/beastxp 100000`: reaches Lv 30, XP shows "max", stats ≈ 2.74× Lv 1.
4. Put the raised beast in a Glass Showcase: picker shows it first with "Lv 30 · 1-star"; its default price equals its value; customers judge against that value.
5. Collector Case, 2 players: P1 displays the beast; P2 browses (sees level), opens the confirm box; P1 removes it and puts a fresh copy of the same card in the same slot; P2 confirms → refused (Review Focus 4). P2 buys the beast normally → P2's binder shows it at the same level/XP.
6. Stop → Play: beasts in binder and cases come back with level/XP/stars; no duplicates (Review Focus 3).
7. Card faces show level/stars text and stats; no box glyphs anywhere.

- [ ] **Step 5: Commit**

```bash
git add src/server/Services/DevService.luau DESIGN.md CLAUDE.md
git commit -m "Add /beastxp and document Glimmerbeast cards"
```
