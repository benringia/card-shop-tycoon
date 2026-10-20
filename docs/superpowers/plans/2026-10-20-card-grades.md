# Card Grades Implementation Plan (Plan A2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every card copy has a grade (C/B/A/S) that boosts stats and value; same-grade copies stack; a Power number shows strength and rarity always beats grade at equal level and stars.

**Architecture:** Grade maths, Power, the grade roll and the rarity rule live in the pure, Lune-tested `BeastMath`. Plain stacks become `cardId → grade → { normal, foil }`; levelled cards and displayed cards carry `grade`. Schema v5's migration (pure, tested, roll function injected) rolls a grade for every existing copy. Grade is threaded as one more "growth" value next to level and stars through server and client.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo 7.7.1, Lune 0.11.

**Spec:** `docs/superpowers/specs/2026-10-20-card-grades-design.md`

## Global Constraints

- Grades weakest first: `GRADES = { "C", "B", "A", "S" }`; chances C 0.5 / B 0.3 / A 0.15 / S 0.05; bonus C 0 / B 0.03 / A 0.06 / S 0.10 on HP, ATK, SPD and value; `DEFAULT_GRADE = "C"`.
- Power = HP + 5 × ATK + 5 × SPD (`POWER_ATK_WEIGHT = 5`, `POWER_SPD_WEIGHT = 5`).
- Base stats: Common 60/12/10, Rare 80/16/12, Very Rare 100/21/14, Epic 135/27/17, Legendary 180/36/20.
- Rarity rule: at equal level (1, 15, 30) and stars (0–5), max Power of a rarity (best element, S, foil) < min Power of the next rarity (weakest element, C, not foil).
- Grade is rolled only on the server. A client-sent grade only selects which copy to use; the server takes that exact copy or refuses.
- Schema v5; migration in `src/server/Util/Migrations.luau`, roll function passed in.
- Text: `Grade S` (plain ASCII plus `·`).
- Commands: tests `"$USERPROFILE/.rokit/bin/lune.exe" run tests/run`; build `rojo build -o <scratchpad>/test.rbxl`; sourcemap; syntax `lune run <scratchpad>/syntax.luau $(find src -name '*.luau')` → `syntax OK`.
- DESIGN.md kept in sync.

## Review Focus

1. **Grade lost on a move path** (display → remove, customer give-up, player buy, leftovers on load) → card comes back as C. Pinned in Task 4 by a grep step: every `GiveCard(` call passes a grade.
2. **Forged grade from the client** (`DisplayCard` with grade "S" for a player who owns only C) must take nothing. Pinned in Task 4 (`TakeFresh` by exact grade) + Studio step.
3. **Huge or corrupt counts in a v4 save** (1e9, NaN, negative) → migration must finish fast and keep totals. Pinned in Task 2 test "v5: huge counts are capped, totals kept".
4. **Value or price computed without the grade** (default C used for an S copy). Pinned in Task 4/5 grep steps for `getMarketValue(` / `getValue(` / `clampPrice(` / `getPriceStep(` calls.
5. **Rarity rule across levels and stars**, not only Lv 1. Pinned in Task 1 test "power: rarity beats grade".

---

### Task 1: Grade maths, Power and new base stats

**Files:** Modify `src/shared/Config/Beasts.luau`, `src/shared/Util/BeastMath.luau`; Test `tests/BeastMath.spec.luau`.

**Interfaces — Produces (BeastMath):**
- `getStats(config, rarity, element, foil, level, stars, grade): Stats`
- `getValue(config, baseValue, foilMultiplier, foil, level, stars, grade): number`
- `getPower(config, stats: Stats): number`
- `isGrade(config, grade: unknown): boolean`
- `getGradeRank(config, grade: string): number` (1 = C … 4 = S, 0 unknown)
- `rollGrade(config, roll: number): string` (`roll` in [0, 1))
- `sanitize` result gains `grade: string`; `BeastData` gains `grade`.
- Config gains `GRADES, GRADE_CHANCES, GRADE_BONUS, DEFAULT_GRADE, POWER_ATK_WEIGHT, POWER_SPD_WEIGHT`.

- [ ] **Step 1: Tests first.** In `tests/BeastMath.spec.luau`, append `"C"` as the last argument of every existing `getStats`/`getValue` call; change the "max foil legendary shade" expectation to the new Legendary base (growth 5.03475 × Shade): hp `906` (180 × 5.03475 = 906.3), atk `199` (39.6 × 5.03475 = 199.4), spd `111` (22 × 5.03475 = 110.8). Change "very rare base" to hp `120` (100 × 1.2), atk `21`, spd `14`. Add:

```lua
	["grade: S boosts stats and value by 10%"] = function()
		local c = BeastMath.getStats(config, "Legendary", "Volt", false, 1, 0, "C")
		local s = BeastMath.getStats(config, "Legendary", "Volt", false, 1, 0, "S")
		expect.equal(c.hp, 180, "C hp")
		expect.equal(s.hp, 198, "S hp")
		expect.near(BeastMath.getValue(config, 10, 3, false, 1, 0, "S"), 11, 0.001, "S value")
		expect.near(BeastMath.getValue(config, 10, 3, false, 1, 0, "B"), 10.3, 0.001, "B value")
	end,

	["grade: unknown grade counts as C"] = function()
		local c = BeastMath.getStats(config, "Rare", "Tide", false, 1, 0, "C")
		local x = BeastMath.getStats(config, "Rare", "Tide", false, 1, 0, "Z")
		expect.equal(x.hp, c.hp, "hp")
	end,

	["grade: roll boundaries"] = function()
		local cases = { { 0, "C" }, { 0.49, "C" }, { 0.5, "B" }, { 0.79, "B" }, { 0.8, "A" }, { 0.949, "A" }, { 0.95, "S" }, { 0.9999, "S" } }
		for _, case in cases do
			expect.equal(BeastMath.rollGrade(config, case[1]), case[2], `roll {case[1]}`)
		end
	end,

	["grade: helpers"] = function()
		expect.equal(BeastMath.isGrade(config, "S"), true, "S")
		expect.equal(BeastMath.isGrade(config, "Z"), false, "Z")
		expect.equal(BeastMath.isGrade(config, 5), false, "number")
		expect.equal(BeastMath.getGradeRank(config, "C"), 1, "C rank")
		expect.equal(BeastMath.getGradeRank(config, "S"), 4, "S rank")
		expect.equal(BeastMath.getGradeRank(config, "Z"), 0, "unknown rank")
	end,

	["power: weighted sum"] = function()
		expect.equal(BeastMath.getPower(config, { hp = 60, atk = 12, spd = 10 }), 170, "common base")
	end,

	["power: rarity beats grade at every level and star"] = function()
		local rarities = { "Common", "Rare", "Very Rare", "Epic", "Legendary" }
		local elements = {}
		for name in config.ELEMENT_MULTIPLIERS do
			table.insert(elements, name)
		end
		for i = 1, #rarities - 1 do
			for _, level in { 1, 15, 30 } do
				for stars = 0, 5 do
					local best, worst = -math.huge, math.huge
					for _, element in elements do
						best = math.max(best, BeastMath.getPower(config, BeastMath.getStats(config, rarities[i], element, true, level, stars, "S")))
						worst = math.min(worst, BeastMath.getPower(config, BeastMath.getStats(config, rarities[i + 1], element, false, level, stars, "C")))
					end
					assert(best < worst, `{rarities[i]} {best} >= {rarities[i + 1]} {worst} at Lv {level}, {stars} stars`)
				end
			end
		end
	end,

	["sanitize: grade kept or defaulted"] = function()
		local s = BeastMath.sanitize(config, { cardId = "FS01", level = 1, xp = 0, stars = 0, grade = "S" }, isKnown)
		assert(s, "expected a card")
		expect.equal(s.grade, "S", "kept")
		local bad = BeastMath.sanitize(config, { cardId = "FS01", level = 1, xp = 0, stars = 0, grade = "ZZ" }, isKnown)
		assert(bad, "expected a card")
		expect.equal(bad.grade, "C", "defaulted")
	end,
```

- [ ] **Step 2: Run** tests. Expected: FAIL (wrong legendary/very rare numbers, `rollGrade`/`isGrade`/`getPower` nil), exit 1.

- [ ] **Step 3: Config.** In `Beasts.luau` set `BASE_STATS`:

```lua
		Common = { hp = 60, atk = 12, spd = 10 },
		Rare = { hp = 80, atk = 16, spd = 12 },
		["Very Rare"] = { hp = 100, atk = 21, spd = 14 },
		Epic = { hp = 135, atk = 27, spd = 17 },
		Legendary = { hp = 180, atk = 36, spd = 20 },
```

and add (comment: "rarity always beats grade at equal level and stars — tests/BeastMath.spec checks it"):

```lua
	-- Grades, weakest first. Rolled once when a card is pulled; boost stats and value.
	GRADES = { "C", "B", "A", "S" },
	GRADE_CHANCES = { C = 0.5, B = 0.3, A = 0.15, S = 0.05 },
	GRADE_BONUS = { C = 0, B = 0.03, A = 0.06, S = 0.10 },
	DEFAULT_GRADE = "C",

	-- Power = HP + ATK * weight + SPD * weight: one number to compare cards
	POWER_ATK_WEIGHT = 5,
	POWER_SPD_WEIGHT = 5,
```

- [ ] **Step 4: BeastMath.** Add the config fields to `BeastConfig`; `BeastData` gains `grade: string`. Add:

```lua
local function getGradeMultiplier(config: BeastConfig, grade: string): number
	return 1 + (config.GRADE_BONUS[grade] or 0)
end

function BeastMath.isGrade(config: BeastConfig, grade: unknown): boolean
	return typeof(grade) == "string" and config.GRADE_BONUS[grade] ~= nil
end

function BeastMath.getGradeRank(config: BeastConfig, grade: string): number
	return table.find(config.GRADES, grade) or 0
end

-- roll is a uniform random number in [0, 1); the caller supplies it so this stays pure
function BeastMath.rollGrade(config: BeastConfig, roll: number): string
	local total = 0
	for _, grade in config.GRADES do
		total += config.GRADE_CHANCES[grade] or 0
		if roll < total then
			return grade
		end
	end
	return config.GRADES[#config.GRADES]
end

function BeastMath.getPower(config: BeastConfig, stats: Stats): number
	return stats.hp + stats.atk * config.POWER_ATK_WEIGHT + stats.spd * config.POWER_SPD_WEIGHT
end
```

`getStats` and `getValue` take `grade: string` last and multiply their growth/value by `getGradeMultiplier(config, grade)`. `sanitize` adds `grade = if BeastMath.isGrade(config, entry.grade) then entry.grade :: string else config.DEFAULT_GRADE`.

- [ ] **Step 5: Run** tests. Expected `31 passed, 0 failed` (BeastMath 17 + 8 new, Migrations 6).

- [ ] **Step 6: Commit** `git add src/shared/Config/Beasts.luau src/shared/Util/BeastMath.luau tests/BeastMath.spec.luau` — "Card grades, Power and rarity-beats-grade base stats".

---

### Task 2: Schema v5 migration

**Files:** Modify `src/server/Util/Migrations.luau`, `tests/Migrations.spec.luau`, `src/server/Services/DataService.luau`, `src/shared/Config/Data.luau`.

**Interfaces — Produces:** `Migrations.run(data, targetVersion, rollGrade: (() -> string)?)`; steps receive `(data, rollGrade)`; missing `rollGrade` rolls `"C"`.

- [ ] **Step 1: Tests first.** Add to `tests/Migrations.spec.luau` (helper at top):

```lua
local function sequence(grades: { string }): () -> string
	local i = 0
	return function()
		i += 1
		return grades[(i - 1) % #grades + 1]
	end
end
```

```lua
	["v5: splits old stacks into grades"] = function()
		local data: any = { version = 4, cards = { FS01 = { normal = 3, foil = 1 } }, beasts = {} }
		Migrations.run(data, 5, sequence({ "S", "C", "C", "B" }))
		local stack = data.cards.FS01
		expect.equal(stack.S.normal, 1, "S normal")
		expect.equal(stack.C.normal, 2, "C normal")
		expect.equal(stack.B.foil, 1, "B foil")
		expect.equal(data.version, 5, "version")
	end,

	["v5: levelled and displayed cards get a grade, existing grades kept"] = function()
		local data: any = {
			version = 4,
			cards = {},
			beasts = { a = { cardId = "FS01", stars = 0 }, b = { cardId = "FS02", stars = 0, grade = "A" } },
			layout = { { cards = { { slot = 1, cardId = "FS03" } } } },
		}
		Migrations.run(data, 5, sequence({ "B" }))
		expect.equal(data.beasts.a.grade, "B", "rolled")
		expect.equal(data.beasts.b.grade, "A", "kept")
		expect.equal(data.layout[1].cards[1].grade, "B", "displayed rolled")
	end,

	["v5: huge counts are capped, totals kept"] = function()
		local calls = 0
		local data: any = { version = 4, cards = { FS01 = { normal = 1e9, foil = -5 }, FS02 = { normal = 0 / 0 } } }
		Migrations.run(data, 5, function()
			calls += 1
			return "S"
		end)
		local stack = data.cards.FS01
		expect.equal((stack.S and stack.S.normal or 0) + (stack.C and stack.C.normal or 0), 1e9, "total normal")
		assert(calls <= 10000, `rolled {calls} times`)
		expect.equal(next(data.cards.FS02 or {}), nil, "NaN stack empty")
	end,

	["v5: already graded stacks untouched"] = function()
		local data: any = { version = 4, cards = { FS01 = { S = { normal = 2, foil = 0 } } } }
		Migrations.run(data, 5, sequence({ "C" }))
		expect.equal(data.cards.FS01.S.normal, 2, "kept")
	end,
```

Existing tests keep `Migrations.run(data, 4)` (no roll function).

- [ ] **Step 2: Run.** Expected FAIL (v5 step missing), exit 1.

- [ ] **Step 3: Migrations.**

```lua
-- Copies rolled one by one when stacks get grades (v5); anything beyond this (corrupt data) becomes
-- the lowest grade so loading never stalls
local MAX_ROLLED_COPIES = 10000
local LOWEST_GRADE = "C" -- matches Config/Beasts DEFAULT_GRADE; this module has no requires

local function readCount(value: any): number
	return if typeof(value) == "number" and value == value and value > 0 and value ~= math.huge then math.floor(value) else 0
end

local function isOldStack(entry: any): boolean
	return typeof(entry) == "table" and (entry.normal ~= nil or entry.foil ~= nil)
end

local function gradeStack(old: any, rollGrade: () -> string): { [string]: { normal: number, foil: number } }
	local graded = {}
	local function add(grade: string, side: string, amount: number)
		graded[grade] = graded[grade] or { normal = 0, foil = 0 }
		graded[grade][side] += amount
	end
	for _, side in { "normal", "foil" } do
		local count = readCount(old[side])
		local rolled = math.min(count, MAX_ROLLED_COPIES)
		for _ = 1, rolled do
			add(rollGrade(), side, 1)
		end
		if count > rolled then
			add(LOWEST_GRADE, side, count - rolled)
		end
	end
	return graded
end
```

Step `[4]`:

```lua
	-- v5: every copy has a grade; plain stacks become cardId -> grade -> { normal, foil }
	[4] = function(data, rollGrade)
		if typeof(data.cards) == "table" then
			for cardId, entry in data.cards do
				if isOldStack(entry) then
					data.cards[cardId] = gradeStack(entry, rollGrade)
				end
			end
		end
		local function giveGrade(entry: any)
			if typeof(entry) == "table" and typeof(entry.cardId) == "string" and typeof(entry.grade) ~= "string" then
				entry.grade = rollGrade()
			end
		end
		if typeof(data.beasts) == "table" then
			for _, beast in data.beasts do
				giveGrade(beast)
			end
		end
		if typeof(data.layout) == "table" then
			for _, shelf in data.layout do
				if typeof(shelf) == "table" and typeof(shelf.cards) == "table" then
					for _, card in shelf.cards do
						giveGrade(card)
					end
				end
			end
		end
	end,
```

`MIGRATIONS` type becomes `{ [number]: (data: any, rollGrade: () -> string) -> () }`; `run(data, targetVersion, rollGrade: (() -> string)?)` passes `rollGrade or function() return LOWEST_GRADE end` to each step. Replacing a key's value during `for cardId, entry in data.cards` is allowed (existing key).

- [ ] **Step 4a: BeastRules wrappers** (DataService needs `rollGrade` now): add `GRADES`, `DEFAULT_GRADE`, `isGrade(g: unknown)`, `getGradeRank(g)`, `rollGrade(roll)`, `describeGrade(g) -> "Grade " .. g`, `getPower(card, foil, level, stars, grade)`; `getStats`/`getValue` take `grade` last (a missing grade reads as no bonus, so unconverted callers keep working until Tasks 3-5).

- [ ] **Step 4: DataService + schema.** `Data.luau` `SCHEMA_VERSION = 5`. In DataService: require BeastRules (`ReplicatedStorage.Shared.Util.BeastRules`); `local gradeRng = Random.new()`; call `Migrations.run(profile.Data, DataConfig.SCHEMA_VERSION, function() return BeastRules.rollGrade(gradeRng:NextNumber()) end)`. Types: `export type SavedOwned = { normal: number, foil: number }`; `cards: { [string]: { [string]: SavedOwned } } -- cardId -> grade -> counts`; `SavedBeast` gains `grade: string`; `SavedCard` gains `grade: string?`.

- [ ] **Step 5: Run** tests: expected `35 passed, 0 failed`; build OK; `syntax OK`.

- [ ] **Step 6: Commit** — "Schema v5: every copy gets a grade" (add `src/shared/Util/BeastRules.luau` too).

---

### Task 3: Graded stacks in CardService, packs and dev commands

**Files:** Modify `src/shared/Util/BeastRules.luau`, `src/server/Services/CardService.luau`, `PackService.luau`, `DevService.luau`.

**Interfaces — Produces:**
- BeastRules: `GRADES`, `DEFAULT_GRADE`, `isGrade(g: unknown)`, `getGradeRank(g)`, `rollGrade(roll)`, `describeGrade(g) -> "Grade S"`, `getStats(card, foil, level, stars, grade)`, `getValue(card, foil, level, stars, grade)`, `getPower(card, foil, level, stars, grade)`.
- CardService types: `Owned = { normal, foil }`, `Stacks = { [cardId]: { [grade]: Owned } }`, `PullResult = { cardId, foil, grade }`, `Beast` gains `grade`, `XpTarget = string | { cardId, foil, grade }`.
- CardService: `AddFresh(player, { PullResult })`, `TakeFresh(player, cardId, foil, grade): boolean`, `GiveCard(player, cardId, foil, grade, beast?)`, `GetStacks(player): Stacks`, `AddXP(player, target, amount)`.
- Sync payload `{ stacks: Stacks, beasts }`.

- [ ] **Step 1: BeastRules** — already done in Task 2 Step 4a; nothing to add here.

- [ ] **Step 2: CardService** — stacks nested by grade:
  - `getOwned(stacks, cardId, grade)` creates `stacks[cardId][grade]`.
  - `takeFreshCopy(inventory, cardId, foil, grade)`.
  - `AddFresh` uses `result.grade` if `BeastRules.isGrade`, else `BeastRules.DEFAULT_GRADE`.
  - `TakeFresh(player, cardId, foil, grade)`; `GiveCard(player, cardId, foil, grade, beast?)` (beast path unchanged).
  - `AddXP` plain target `{ cardId, foil, grade }`; new beast gets `grade = target.grade`.
  - `load`: for each `cardId` (known) and each grade in `BeastRules.GRADES`, read `{ normal, foil }` with `readCount`; skip non-tables; beasts via `sanitize` include `grade`.
  - `save`: writes `cards[cardId][grade] = { normal, foil }` for non-empty counts; beasts include `grade`.
  - Guard top-level `data.cards` / `data.beasts` with `typeof(...) == "table"`.
  - Header comment describes the new shape.

- [ ] **Step 3: PackService** — `PullResult` gains `grade`; `rollPack` sets `grade = BeastRules.rollGrade(rng:NextNumber())`; the test-pack legendary also rolls a grade. `PackOpened` already sends the results (now with grade).

- [ ] **Step 4: DevService** — `pickXpTarget` fallback: for `card` in `Cards.RarestFirst`, for grades best first (iterate `BeastRules.GRADES` backwards), foil before normal: return `{ cardId, foil, grade }` for the first copy owned.

- [ ] **Step 5:** tests, build, syntax. Commit — "Graded stacks: packs roll grades, binder stores them".

---

### Task 4: Graded cards on display, customer and player sales

**Files:** Modify `src/shared/Util/CardRules.luau`, `src/shared/Remotes.luau` (comment), `src/server/Services/PlacementService.luau`, `ShowcaseService.luau`, `CustomerService.luau`.

**Interfaces — Produces:** `CardRules.getMarketValue/clampPrice/getPriceStep(card, foil, level?, stars?, grade?)` (grade defaults to `BeastRules.DEFAULT_GRADE`); `DisplayedCard = { cardId, foil, grade, price, beast? }`; part attribute `Grade`; remote `DisplayCard(shelfUid, slot, cardId, foil, beastId?, grade?)`.

- [ ] **Step 1: CardRules** — append `grade: string?` to the three functions, pass `grade or BeastRules.DEFAULT_GRADE` to `BeastRules.getValue`.

- [ ] **Step 2: PlacementService** — `DisplayedCard.grade`; `getGrowth` returns `level, stars, grade`; card part `SetAttribute("Grade", grade)`; reuse check also compares `Grade`; rarity text line reads `{card.rarity} · Grade {grade}`; `readSavedCards`: grade = beast's grade if a beast, else `entry.grade` if `BeastRules.isGrade`, else default; prices use grade; leftovers/`GiveCard` pass `displayed.grade`; `save` writes `grade`. Header comment lists `Grade`.

- [ ] **Step 3: ShowcaseService** — `onDisplayCard(player, shelfUid, slot, cardId, foil, beastId, grade)`: beast path uses `beast.grade`; plain path requires `BeastRules.isGrade(grade)` else return, then `CardService.TakeFresh(player, cardId, foil, grade)`; set `grade` on `DisplayedCard`; every price call passes grade; `onSetPrices` keeps `grade`; Remove/Buy/ReturnFromCustomer call `GiveCard(player, cardId, foil, displayed.grade, displayed.beast)`; `describe` adds ` · Grade {grade}`.

- [ ] **Step 4: CustomerService** — market value passes `displayed.grade`.

- [ ] **Step 5: Remotes comment** for `DisplayCard`.

- [ ] **Step 6: Greps (Review Focus 1, 4).**
  - `grep -rn "GiveCard(" src --include=*.luau` → every call has 4+ args (cardId, foil, grade, beast?).
  - `grep -rn "getMarketValue(\|clampPrice(\|getPriceStep(" src/server --include=*.luau` → every call passes a grade.

- [ ] **Step 7:** tests, build, syntax. Commit — "Displayed cards keep their grade through sales and saves".

---

### Task 5: Grades in the UI

**Files:** Modify `src/client/Util/CardFace.luau`, `src/client/Controllers/PackOpeningController.luau`, `BinderController.luau`, `ShowcaseController.luau`, `CardBuyController.luau`.

**Interfaces — Consumes:** sync payload `{ stacks: cardId → grade → Owned, beasts }`; part attribute `Grade`; `PackOpened` results with `grade`.
**Produces:** `CardFace.Growth = { level, stars, grade }`; `BinderController.GetCollection()` still returns per-card summed `{ normal, foil }`; new `BinderController.GetGradedStacks()`.

- [ ] **Step 1: CardFace** — `Growth` gains `grade: string`; when growth is given, the line at 0.55 reads `Grade S · Lv 1 · 0 stars`; stats row reads `Power {p} · HP {hp} ATK {atk} SPD {spd}`; all stats/value calls pass the grade (`DEFAULT_GRADE` when growth is nil).

- [ ] **Step 2: Pack reveal** — `PullResult` gains `grade`; `CardView` keeps `grade`; flip renders with growth `{ level = 1, stars = BeastRules.START_STARS, grade = view.grade }`; value line passes grade.

- [ ] **Step 3: Binder** —
  - Store `graded` (raw payload stacks) and `collection` (summed per card) on change; `GetGradedStacks()` returns `graded`.
  - Detail rows: one row per (grade, foil) stack with count > 0 and one per levelled card, all sorted by Power (desc). Stack row title `{FOIL · }Grade S · Owned 2 · Lv 1 · 0 stars`, value right; second line `Power p · HP · ATK · SPD`; third line star hint. Levelled rows add `Grade X` to the title and `Power` to the stats line.
  - Selection key: beast ID, or `"stack:" .. grade .. ":" .. tostring(foil)`; opening a card selects the strongest row; the big card renders the selected row's growth.
  - Tile chip shows best grade and best level: `S`, `S · Lv 12`, or nothing; chip width 60.

- [ ] **Step 4: Case picker and rows** — picker plain tiles one per (card, grade, foil) with `x{count}`, face growth `{ level = 1, stars = START_STARS, grade }`, fires `DisplayCard(..., card.id, foil, nil, grade)`; levelled tiles pass `grade = beast.grade`; filters unchanged. Row: `getGrowthFromPart` returns `level, stars, grade` (`Grade` attribute, default `DEFAULT_GRADE`); market/step/clamp/nudge/typed price pass grade; title adds `· Grade {grade}`.

- [ ] **Step 5: Browse/buy** — `getGrowthFromPart` returns grade; faces get it; `describe` and detail text show `Grade S`; market passes grade.

- [ ] **Step 6: Greps.** `grep -rn "getMarketValue(\|getValue(\|getStats(\|clampPrice(\|getPriceStep(" src/client --include=*.luau` → every call passes a grade.

- [ ] **Step 7:** tests, build, syntax, sourcemap. Commit — "Show grades and Power on cards, binder, picker, browse and pack reveal".

---

### Task 6: Docs and Studio test

**Files:** `DESIGN.md` (5.8 grades table, Power, base stats table; 10.4 schema v5: `cards = { [cardId] = { [grade] = { normal, foil } } }`, beasts/layout `grade`, history "v5 grades"), `CLAUDE.md` (Player data: grades note).

- [ ] **Step 1:** Update docs. **Step 2:** build + tests. **Step 3:** Commit — "Document card grades".
- [ ] **Step 4: Studio test (user)** — spec section 7, plus: forged grade (Review Focus 2) is covered by server code; check by displaying a card and confirming the case shows the same grade as the binder row it came from.
