# Stars 0-5, Very Rare and "Owned" Wording Implementation Plan (Plan A)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cards start at 0 stars (max 5) with the new star value table, saves move to schema v4, a Very Rare tier with 5 new cards joins the packs, and the UI says "Owned" instead of "fresh"/"raised".

**Architecture:** Star maths stay in the pure, Lune-tested `BeastMath` driven by `Config/Beasts.luau`. Save migrations move out of DataService into a pure `src/server/Util/Migrations.luau` so the v3 → v4 star shift is unit-tested. The plain-copy star default becomes one named constant (`BeastRules.START_STARS`) used everywhere a missing beast meant "1 star". Very Rare is config-only plus a `Cards.RarestFirst` list for rarest-first loops (new cards are numbered 31–35, after the Legendaries).

**Tech Stack:** Roblox Luau (`--!strict`), Rojo 7.7.1, Lune 0.11 for unit tests.

**Spec:** `docs/superpowers/specs/2026-10-20-stars-condenser-design.md` (sections 2, 4, 5, 6, 9). The Condenser (section 3, 7) is Plan B.

## Global Constraints

- Stars range 0–5. Plain copy = level 1, 0 XP, 0 stars.
- `STAR_COSTS = { 4, 8, 12, 16, 24 }` (64 total), `STAR_STAT_GROWTH = 0.15` → stats × `1 + 0.15 × stars`.
- `STAR_VALUE` by stars 0–5 = `{ 1, 6, 15, 30, 50, 80 }`, stored 1-based (index `stars + 1`).
- No level gate on stars; `STAR_UPGRADE_LEVEL` is removed.
- Very Rare: key and display text `"Very Rare"`; order Common 1, Rare 2, Very Rare 3, Epic 4, Legendary 5; color `(40, 210, 200)`; values $3–$6; base stats HP 95 / ATK 19 / SPD 13.
- New cards FS31–FS35: Emberwing (Ember, $3.00), Tidecaller (Tide, $3.50), Briarhorn (Bloom, $4.00), Voltkit (Volt, $5.00), Duskstalker (Shade, $6.00).
- Hit slot odds: Rare 68 / Very Rare 15 / Epic 14 / Legendary 3. Very Rare is not announced.
- Schema v4: every saved beast and displayed card entry with a numeric `stars` gets `stars = max(0, stars - 1)`.
- Player-facing text never says "fresh" or "raised". UI text ASCII plus `·` only.
- All tunable numbers in `src/shared/Config`. DESIGN.md kept in sync in the same change.
- Test command: `"$USERPROFILE/.rokit/bin/lune.exe" run tests/run`.
- Build check: `"$USERPROFILE/.rokit/bin/rojo.exe" build -o <scratchpad>/test.rbxl`; sourcemap: `rojo sourcemap default.project.json -o sourcemap.json`.
- Syntax check (Lune compiler over every file): `lune run <scratchpad>/syntax.luau $(find src -name '*.luau')` — expected `syntax OK`.

## Review Focus

1. **A plain copy still priced or drawn as 1 star** somewhere (a leftover `else 1` / `or 1` default for stars) → its value would be ×6. Pinned in Task 3 by a grep step that must return nothing.
2. **Migration run on an already-v4 save** must change nothing (version gate). Pinned in Task 2 test "run: v4 data unchanged".
3. **Displayed v3 beasts in card cases** (`layout[i].cards[j].stars`) must be lowered too, not only `data.beasts`. Pinned in Task 2 test "v4: lowers displayed card stars".
4. **Rarest-first lists** (case picker, `/beastxp` fallback) must still put Legendaries first even though the new Very Rares are numbered after them. Pinned in Task 4 (`Cards.RarestFirst`) + Studio step.
5. **Corrupt stars** (negative, NaN, above 5, missing) must clamp to 0–5 with 0 as the default. Pinned in Task 1 sanitize tests.

---

### Task 1: Star maths 0–5

**Files:**
- Modify: `src/shared/Config/Beasts.luau`
- Modify: `src/shared/Util/BeastMath.luau`
- Test: `tests/BeastMath.spec.luau`

**Interfaces:**
- Produces: `BeastMath.getCondenseCost(config, stars: number): number?` (nil at 5 stars or below 0); `BeastConfig.STAR_COSTS: { number }`; config field `START_STARS = 0`; `getStats`/`getValue`/`sanitize` treat stars as 0–5.

- [ ] **Step 1: Update the tests first**

In `tests/BeastMath.spec.luau`, replace these tests and add the new ones (keep the XP and level tests as they are):

```lua
	["stats: plain common ember"] = function()
		local stats = BeastMath.getStats(config, "Common", "Ember", false, 1, 0)
		expect.equal(stats.hp, 60, "hp")
		expect.equal(stats.atk, 14, "atk") -- 12 * 1.2 = 14.4
		expect.equal(stats.spd, 10, "spd")
	end,

	["stats: max foil legendary shade"] = function()
		-- growth = 2.74 (Lv 30) * 1.75 (5 stars) * 1.05 (foil) = 5.03475
		local stats = BeastMath.getStats(config, "Legendary", "Shade", true, 30, 5)
		expect.equal(stats.hp, 755, "hp")
		expect.equal(stats.atk, 166, "atk")
		expect.equal(stats.spd, 89, "spd")
	end,

	["stats: unknown rarity and element fall back"] = function()
		local stats = BeastMath.getStats(config, "Mythic", "Plasma", false, 1, 0)
		expect.equal(stats.hp, 60, "hp")
		expect.equal(stats.atk, 12, "atk")
	end,

	["stats: very rare base"] = function()
		local stats = BeastMath.getStats(config, "Very Rare", "Tide", false, 1, 0)
		expect.equal(stats.hp, 114, "hp") -- 95 * 1.2
		expect.equal(stats.atk, 19, "atk")
		expect.equal(stats.spd, 13, "spd")
	end,

	["value: Cindercub Lv 15 3 stars"] = function()
		expect.near(BeastMath.getValue(config, 0.20, 3, false, 15, 3), 14.40, 0.001) -- 0.20 * 2.4 * 30
	end,

	["value: plain foil"] = function()
		expect.near(BeastMath.getValue(config, 0.20, 3, true, 1, 0), 0.60, 0.001)
	end,

	["value: star table 0 to 5"] = function()
		local expected = { 1, 6, 15, 30, 50, 80 }
		for stars = 0, 5 do
			expect.near(BeastMath.getValue(config, 1, 3, false, 1, stars), expected[stars + 1], 0.001, `{stars} stars`)
		end
	end,

	["condense cost per star, 64 total"] = function()
		local total = 0
		for stars, cost in { [0] = 4, [1] = 8, [2] = 12, [3] = 16, [4] = 24 } do
			expect.equal(BeastMath.getCondenseCost(config, stars), cost, `{stars} stars`)
			total += cost
		end
		expect.equal(total, 64, "total")
		expect.isNil(BeastMath.getCondenseCost(config, 5), "max stars")
		expect.isNil(BeastMath.getCondenseCost(config, -1), "negative")
	end,

	["sanitize: clamps out-of-range values"] = function()
		local beast = BeastMath.sanitize(config, { cardId = "FS01", foil = true, level = 99, xp = -5, stars = 9 }, isKnown)
		assert(beast, "expected a beast")
		expect.equal(beast.level, 30, "level")
		expect.equal(beast.stars, 5, "stars")
		expect.equal(beast.xp, 0, "xp")
		expect.equal(beast.foil, true, "foil")
	end,

	["sanitize: stars default and floor are 0"] = function()
		local nan = 0 / 0
		for _, raw in { -3, nan, "two" } do
			local beast = BeastMath.sanitize(config, { cardId = "FS01", level = 1, xp = 0, stars = raw }, isKnown)
			assert(beast, "expected a beast")
			expect.equal(beast.stars, 0, `stars {tostring(raw)}`)
		end
		local missing = BeastMath.sanitize(config, { cardId = "FS01", level = 1, xp = 0 }, isKnown)
		assert(missing, "expected a beast")
		expect.equal(missing.stars, 0, "missing stars")
	end,
```

Also change `stars = 1` to `stars = 0` in the "xp above the level cap", "NaN level" and "rejects unknown cards" tests.

- [ ] **Step 2: Run tests to verify they fail**

Run: `"$USERPROFILE/.rokit/bin/lune.exe" run tests/run`
Expected: FAIL lines for "max foil legendary shade", "very rare base", "Cindercub Lv 15 3 stars", "star table 0 to 5", "condense cost" (`getCondenseCost` is nil), "stars default and floor are 0"; exit code 1.

- [ ] **Step 3: Update the config**

In `src/shared/Config/Beasts.luau`:

```lua
	MAX_LEVEL = 30,
	START_STARS = 0, -- every card starts with no stars
	MAX_STARS = 5,
```

Add to `BASE_STATS` between Rare and Epic:

```lua
		["Very Rare"] = { hp = 95, atk = 19, spd = 13 },
```

Replace the star lines and remove `STAR_UPGRADE_LEVEL` (and its comment):

```lua
	STAR_STAT_GROWTH = 0.15, -- +15% stats per star
```

```lua
	-- Value multiplier by stars 0-5 (index = stars + 1). Roughly the duplicates condensed plus a bonus.
	STAR_VALUE = { 1, 6, 15, 30, 50, 80 },
	-- Duplicates condensed for the next star: 0->1, 1->2, 2->3, 3->4, 4->5 (64 total)
	STAR_COSTS = { 4, 8, 12, 16, 24 },
```

- [ ] **Step 4: Update BeastMath**

In `src/shared/Util/BeastMath.luau`:
- `BeastConfig` gains `START_STARS: number,` and `STAR_COSTS: { number },`.
- `getStats`: `* (1 + config.STAR_STAT_GROWTH * stars)`.
- `getValue`: `* (config.STAR_VALUE[stars + 1] or 1)`.
- `sanitize`: `local stars = clampInteger(entry.stars, 0, config.MAX_STARS, config.START_STARS)`.
- Add after `getXpToNext`:

```lua
-- Duplicates needed for the next star, or nil if there is no next star
function BeastMath.getCondenseCost(config: BeastConfig, stars: number): number?
	if stars < 0 or stars >= config.MAX_STARS then
		return nil
	end
	return config.STAR_COSTS[math.floor(stars) + 1]
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `"$USERPROFILE/.rokit/bin/lune.exe" run tests/run`
Expected: `17 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add src/shared/Config/Beasts.luau src/shared/Util/BeastMath.luau tests/BeastMath.spec.luau
git commit -m "Stars 0-5 with condense costs and new star value table"
```

---

### Task 2: Schema v4 and pure migrations

**Files:**
- Create: `src/server/Util/Migrations.luau`
- Create: `tests/Migrations.spec.luau`
- Modify: `tests/run.luau`, `src/server/Services/DataService.luau`, `src/shared/Config/Data.luau`

**Interfaces:**
- Produces: `Migrations.run(data: any, targetVersion: number)` — applies steps from `data.version` (default 1) up to `targetVersion`, then sets `data.version = targetVersion`. No requires, no Roblox APIs.

- [ ] **Step 1: Write the failing tests**

`tests/Migrations.spec.luau`:

```lua
--!strict
local Migrations = require("../src/server/Util/Migrations")
local expect = require("./lib/expect")

return {
	["v4: lowers saved beast stars by one, not below 0"] = function()
		local data: any = { version = 3, beasts = { a = { stars = 1 }, b = { stars = 3 }, c = { stars = 0 } } }
		Migrations.run(data, 4)
		expect.equal(data.beasts.a.stars, 0, "1 -> 0")
		expect.equal(data.beasts.b.stars, 2, "3 -> 2")
		expect.equal(data.beasts.c.stars, 0, "0 stays 0")
		expect.equal(data.version, 4, "version")
	end,

	["v4: lowers displayed card stars"] = function()
		local data: any = {
			version = 3,
			beasts = {},
			layout = { { shelfId = "CardCase", cards = { { slot = 1, cardId = "FS30", stars = 2 }, { slot = 2, cardId = "FS01" } } } },
		}
		Migrations.run(data, 4)
		expect.equal(data.layout[1].cards[1].stars, 1, "displayed beast")
		expect.isNil(data.layout[1].cards[2].stars, "plain displayed card untouched")
	end,

	["v4: tolerates missing and junk tables"] = function()
		local data: any = { version = 3, layout = { "junk", { cards = "junk" } } }
		Migrations.run(data, 4)
		expect.equal(data.version, 4, "version")
	end,

	["run: v4 data unchanged"] = function()
		local data: any = { version = 4, beasts = { a = { stars = 2 } } }
		Migrations.run(data, 4)
		expect.equal(data.beasts.a.stars, 2, "not lowered twice")
	end,

	["run: v1 goes through every step"] = function()
		local data: any = { showcase = { 1 } }
		Migrations.run(data, 4)
		expect.isNil(data.showcase, "v2 dropped showcase")
		expect.equal(typeof(data.beasts), "table", "v3 added beasts")
		expect.equal(data.version, 4, "version")
	end,
}
```

In `tests/run.luau` add to `specs`: `Migrations = require("./Migrations.spec"),`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `"$USERPROFILE/.rokit/bin/lune.exe" run tests/run`
Expected: error loading `../src/server/Util/Migrations` (module not found), exit code 1.

- [ ] **Step 3: Create Migrations**

`src/server/Util/Migrations.luau`:

```lua
--!strict
-- Save data migrations. MIGRATIONS[n] upgrades a profile from version n to n + 1.
-- Pure (no requires, no Roblox APIs) so tests/ can run it in Lune. DataService calls run().
local Migrations = {}

local function lowerStars(entry: any)
	if typeof(entry) == "table" and typeof(entry.stars) == "number" then
		entry.stars = math.max(0, entry.stars - 1)
	end
end

local MIGRATIONS: { [number]: (data: any) -> () } = {
	-- v2: displayed cards live on each saved shelf; the old top-level showcase list was never used
	[1] = function(data)
		data.showcase = nil
	end,
	-- v3: levelled cards live in their own table; existing cards are plain stacks already
	[2] = function(data)
		data.beasts = data.beasts or {}
	end,
	-- v4: stars now run 0-5 instead of 1-5, so every saved star count drops by one
	[3] = function(data)
		if typeof(data.beasts) == "table" then
			for _, beast in data.beasts do
				lowerStars(beast)
			end
		end
		if typeof(data.layout) == "table" then
			for _, shelf in data.layout do
				if typeof(shelf) == "table" and typeof(shelf.cards) == "table" then
					for _, card in shelf.cards do
						lowerStars(card)
					end
				end
			end
		end
	end,
}

function Migrations.run(data: any, targetVersion: number)
	local version = if typeof(data.version) == "number" then data.version else 1
	while version < targetVersion do
		local step = MIGRATIONS[version]
		if step then
			step(data)
		end
		version += 1
	end
	data.version = targetVersion
end

return Migrations
```

- [ ] **Step 4: Use it from DataService, bump the schema**

In `src/server/Services/DataService.luau`: delete the `MIGRATIONS` table and the local `migrate` function; add `local Migrations = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("Migrations"))` next to the other requires (use the file's existing `Services` local; if it has none, add `local Services = script.Parent :: Instance`); replace the `migrate(data)` call with `Migrations.run(data, DataConfig.SCHEMA_VERSION)`. Update the `SavedBeast`/`SavedCard` comments so stars read "0-5".

In `src/shared/Config/Data.luau`: `SCHEMA_VERSION = 4`.

- [ ] **Step 5: Run tests, build, syntax**

Run tests: Expected `22 passed, 0 failed`. Build: `Built project to test.rbxl`. Syntax: `syntax OK`.

- [ ] **Step 6: Commit**

```bash
git add src/server/Util/Migrations.luau tests/Migrations.spec.luau tests/run.luau src/server/Services/DataService.luau src/shared/Config/Data.luau
git commit -m "Schema v4: stars start at 0; migrations move to a tested pure module"
```

---

### Task 3: Plain copies are 0 stars everywhere

**Files:**
- Modify: `src/shared/Util/BeastRules.luau`, `src/shared/Util/CardRules.luau`
- Modify: `src/server/Services/CardService.luau`, `CustomerService.luau`, `PlacementService.luau`, `ShowcaseService.luau`
- Modify: `src/client/Util/CardFace.luau`, `src/client/Controllers/CardBuyController.luau`, `ShowcaseController.luau`, `BinderController.luau`

**Interfaces:**
- Consumes: `BeastMath.getCondenseCost` (Task 1), config `START_STARS` (Task 1).
- Produces: `BeastRules.START_STARS: number`; `BeastRules.getCondenseCost(stars: number): number?`; `BeastRules.describeStarProgress(stars: number): string` (level parameter removed).

- [ ] **Step 1: BeastRules**

Add `BeastRules.START_STARS = Beasts.START_STARS` beside `MAX_STARS`, add:

```lua
function BeastRules.getCondenseCost(stars: number): number?
	return BeastMath.getCondenseCost(Beasts, stars)
end
```

Replace `describeStarProgress`:

```lua
-- What the player needs to do for the next star
function BeastRules.describeStarProgress(stars: number): string
	local progress = `Stars {stars}/{Beasts.MAX_STARS}`
	local cost = BeastMath.getCondenseCost(Beasts, stars)
	if not cost then
		return `{progress} · max stars`
	end
	return `{progress} · condense {cost} duplicates for the next star`
end
```

`describeGrowth` stays (`Lv 1 · 0 stars`, `Lv 4 · 1 star`).

- [ ] **Step 2: Replace every plain-copy star default**

Each of these currently defaults stars to 1; change to `BeastRules.START_STARS` (add `BeastRules` require where the file lacks it, using the file's existing `Shared` local):
- `CardRules.luau:22` `stars or 1` → `stars or BeastRules.START_STARS`; comment "level 1, 0 stars".
- `CardService.luau` `AddXP` new beast `stars = 1` → `stars = BeastRules.START_STARS`.
- `CustomerService.luau:386`, `PlacementService.luau:146` and `:482`, `ShowcaseService.luau:48` and `:115`: `if beast then beast.stars else 1` → `... else BeastRules.START_STARS`.
- `CardFace.luau:102`, `CardBuyController.luau:78`, `ShowcaseController.luau:98`: the stars fallback `else 1` → `else BeastRules.START_STARS` (level fallback stays 1).
- `CardBuyController.luau:226` and `BinderController.luau:201`: `describeStarProgress(level, stars)` → `describeStarProgress(stars)`.

- [ ] **Step 3: Grep for leftovers (Review Focus 1)**

Run: `grep -rn "stars else 1\|stars or 1\|stars = 1\b\|STAR_UPGRADE" src --include=*.luau`
Expected: no output.

- [ ] **Step 4: Tests, build, syntax, sourcemap**

Tests `22 passed, 0 failed`; build OK; `syntax OK`.

- [ ] **Step 5: Commit**

```bash
git add src
git commit -m "Plain copies are 0 stars; star hint points to condensing"
```

---

### Task 4: Very Rare tier and five new cards

**Files:**
- Modify: `src/shared/Config/Rarities.luau`, `Cards.luau`, `Packs.luau`, `CardEffects.luau`, `PackOpening.luau`
- Modify: `src/client/Controllers/ShowcaseController.luau`, `src/server/Services/DevService.luau`
- Modify: `DESIGN.md` (5.2, 5.3, 5.4)

**Interfaces:**
- Produces: `Cards.RarestFirst: { Card }` — highest rarity order first, then highest number first.

- [ ] **Step 1: Rarities**

```lua
	Common = { order = 1, color = Color3.fromRGB(160, 160, 160), minValue = 0.10, maxValue = 0.50 },
	Rare = { order = 2, color = Color3.fromRGB(70, 140, 255), minValue = 1, maxValue = 3 },
	["Very Rare"] = { order = 3, color = Color3.fromRGB(40, 210, 200), minValue = 3, maxValue = 6 },
	Epic = { order = 4, color = Color3.fromRGB(170, 80, 255), minValue = 5, maxValue = 20 },
	Legendary = { order = 5, color = Color3.fromRGB(255, 200, 40), minValue = 40, maxValue = 150 },
```

- [ ] **Step 2: Cards**

Append to `ROWS` after Voidmaw:

```lua
	{ "Emberwing", "Ember", "Very Rare", 3.00 },
	{ "Tidecaller", "Tide", "Very Rare", 3.50 },
	{ "Briarhorn", "Bloom", "Very Rare", 4.00 },
	{ "Voltkit", "Volt", "Very Rare", 5.00 },
	{ "Duskstalker", "Shade", "Very Rare", 6.00 },
```

Add `local Rarities = require((script.Parent :: Instance):WaitForChild("Rarities"))` at the top, and after the build loop:

```lua
-- Rarest first (then highest number), for lists that show the best cards on top.
-- Card numbers are not in rarity order: the Very Rares (31-35) came after the Legendaries.
local RarestFirst = table.clone(List)
local function getOrder(card: Card): number
	local tier = Rarities.Tiers[card.rarity]
	return if tier then tier.order else 0
end
table.sort(RarestFirst, function(a, b)
	if getOrder(a) ~= getOrder(b) then
		return getOrder(a) > getOrder(b)
	end
	return a.number > b.number
end)
```

Return `RarestFirst = RarestFirst`. Header comment: "Set 1 card list (35 cards)".

- [ ] **Step 3: Use RarestFirst**

- `ShowcaseController.luau` picker: `for index = #Cards.List, 1, -1 do local card = Cards.List[index]` → `for _, card in Cards.RarestFirst do`.
- `DevService.luau` `pickXpTarget`: same replacement.

- [ ] **Step 4: Odds and per-rarity tables**

- `Packs.luau` slot 5: `{ { rarity = "Rare", weight = 0.68 }, { rarity = "Very Rare", weight = 0.15 }, { rarity = "Epic", weight = 0.14 }, { rarity = "Legendary", weight = 0.03 } }`.
- `CardEffects.luau` `BY_RARITY`, between Rare and Epic: `["Very Rare"] = { glow = 0.6, glowRange = 4, sparkleRate = 1, burst = 24, pop = false, flash = false, pulse = false },`.
- `PackOpening.luau`: `STROKE_THICKNESS` add `["Very Rare"] = 3.5`; `HIT_SOUND_IDS` add `["Very Rare"] = ""`.

- [ ] **Step 5: DESIGN.md**

5.2 table: add row `| Very Rare | Cyan | $3 – $6 |` between Rare and Epic. 5.3 slot 5: `Rare 68% / Very Rare 15% / Epic 14% / Legendary 3%`. 5.4: title "(35 cards)", count line "15 Common, 9 Rare, 5 Very Rare, 4 Epic, 2 Legendary", add rows 31–35. 5.8 base stats table: add `| Very Rare | 95 | 19 | 13 |`.

- [ ] **Step 6: Tests, build, syntax, sourcemap**

Tests `22 passed, 0 failed`; build OK; `syntax OK`.

- [ ] **Step 7: Commit**

```bash
git add src DESIGN.md
git commit -m "Add Very Rare tier with five new cards and rebalanced hit slot"
```

---

### Task 5: "Owned" wording and docs

**Files:**
- Modify: `src/client/Controllers/BinderController.luau`, `CardBuyController.luau`, `ShowcaseController.luau`, `src/client/Util/CardFace.luau` (comments)
- Modify: `src/server/Services/DevService.luau`, `CardService.luau` (comments only)
- Modify: `DESIGN.md` (5.8, 10.4), `CLAUDE.md`

- [ ] **Step 1: Binder**

- Tile badge (`refresh`): plain count `n = inBinder.normal + inBinder.foil`, levelled count `m = #getRaised(id)`. Text: `n > 0 and m > 0` → `Owned {n} · {m} levelled`; `n > 0` → `Owned {n}`; `m > 0` → `{m} levelled`; else `on display`.
- Detail summary: `string.format("Owned %d%s%s", freshCount + #raised, if onDisplay > 0 then " · " .. onDisplay .. " on display" else "", <tap hint as now>)`.
- Plain row title: `Owned {count} · Lv 1 · 0 stars` where count is `x2`-style text without the `x` (`2`, `1 foil`, `2 + 1 foil`). Second line: `BeastRules.describeStarProgress(BeastRules.START_STARS)` instead of "Give a copy XP...".
- Comments: "raised beast" → "levelled card"; "fresh copy" → "plain copy".

- [ ] **Step 2: Browse and case manager**

- `CardBuyController.luau`: `describeKind` returns `BeastRules.describeGrowth(level, stars)` only (no "raised beast"/"fresh copy"); delete `isBeast` if now unused; comments updated.
- `ShowcaseController.luau` title: drop `{if raised then "" else " (fresh)"}` and the now-unused `raised` local.

- [ ] **Step 3: Wording grep**

Run: `grep -rn "fresh\|raised" src/client --include=*.luau | grep -v -i refresh | grep '"'`
Expected: no output (no player-facing string contains either word).

- [ ] **Step 4: Docs**

DESIGN.md 5.8: stars 0–5 table of costs, value table `{ 1, 6, 15, 30, 50, 80 }`, stats `1 + 0.15 × stars`, remove the Lv 30 star-gate lines, note "Stars come only from the Condenser (Plan B)". 10.4: `version = 4`, beast comment "stars 0-5", schema history "v4 stars start at 0". CLAUDE.md Commands: the `lune run tests/run` line now says "(BeastMath, Migrations)".

- [ ] **Step 5: Tests, build, syntax, sourcemap**

Tests `22 passed, 0 failed`; build OK; `syntax OK`.

- [ ] **Step 6: Commit**

```bash
git add src DESIGN.md CLAUDE.md
git commit -m "Say Owned instead of fresh/raised; document stars 0-5"
```

- [ ] **Step 7: Studio test (user) — spec section 9 items 1–3 + Review Focus**

1. Old save with a 1-star beast (from `/beastxp`) loads as `Lv N · 0 stars`, same level and XP.
2. Plain copies show `0 stars` and the same value as before (Hushmoth $0.50).
3. Odds button shows `Rare 68% / Very Rare 15% / Epic 14% / Legendary 3%`; rip packs until a Very Rare appears: cyan frame, glow between Rare and Epic.
4. Binder shows `x/35 cards`; badges read `Owned 2` / `1 levelled`; no "fresh" or "raised" anywhere.
5. Case picker lists Legendaries above the new Very Rares (Review Focus 4).
6. Binder star hint: `Stars 0/5 · condense 4 duplicates for the next star`.
7. Stop → Play: everything persists, nothing lowered a second time (Review Focus 2).
