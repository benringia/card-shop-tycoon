# Condenser Implementation Plan (Plan B)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Card Condenser machine (shop Lv 4, $500) where the owner combines duplicates of a card into one main copy for +1 star.

**Architecture:** The rule for which duplicates are used and what a star costs lives in a pure, Lune-tested `src/shared/Util/CondenseRules.luau`, used by the client preview and the server. A new shelf kind `"Condenser"` reuses buying, placing, moving and selling. `CondenserService` validates the remote and calls one atomic `CardService.Condense`. A marketplace-style `CondenserController` panel previews before/after.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo 7.7.1, Lune 0.11.

**Spec:** `docs/superpowers/specs/2026-10-20-stars-condenser-design.md` section 3, with the duplicate rule from `docs/superpowers/specs/2026-10-20-card-grades-design.md` section 6.

## Global Constraints

- Star costs `STAR_COSTS = { 4, 8, 12, 16, 24 }` (Config/Beasts); one star per press; max 5 stars.
- Duplicates: plain copies (level 1, 0 XP, 0 stars) of the same card only. Order: all normal copies weakest grade first (C, B, A, S), then foil copies weakest grade first. Levelled or starred copies are never used.
- The main copy keeps its foil, grade, level and XP. A plain main is taken out of its stack first (it is not a duplicate) and becomes an individual card.
- Machine: `Shelves` entry id `"Condenser"`, name "Card Condenser", kind `"Condenser"`, capacity 0, cost 500, unlockLevel 4.
- Server authoritative; the client only sends `Condense(shelfUid, cardId, mainBeastId?, mainFoil?, mainGrade?)`; rate-limited; owner's own Condenser; within use distance.
- Tunables in `src/shared/Config/Condenser.luau`. UI text ASCII + `·`.
- Commands: tests `"$USERPROFILE/.rokit/bin/lune.exe" run tests/run`; build; sourcemap; syntax check (`syntax OK`).

## Review Focus

1. **Main copy counted as its own duplicate** (plain main of grade C, only 4 C copies owned, cost 4) → must refuse (needs 4 others). Pinned in Task 1 test "plain main is not a duplicate".
2. **Forged remote** (main beast ID of another card, main grade not owned, cardId unknown, at 5 stars, not near/own machine) → nothing changes. Pinned in Task 3 code + Studio step.
3. **Levelled copies used as duplicates** → never. Pinned in Task 1 (rules only see plain stacks) + Task 3 (`Condense` only takes from stacks).
4. **Code that assumes "not Products = card case"** (labels, prompts, browse prompt, Showcase.Open, saved cards) must exclude the Condenser. Pinned in Task 2 grep step.
5. **Double press while the first is in flight** → rate limit; the second sees the updated stars and costs more. Pinned in Task 3 (RateLimiter + server recomputes from current state).

---

### Task 1: CondenseRules (pure, tested)

**Files:** Create `src/shared/Util/CondenseRules.luau`, `tests/CondenseRules.spec.luau`; modify `tests/run.luau`.

**Interfaces — Produces:**
```lua
export type Counts = { normal: number, foil: number }
export type Take = { grade: string, foil: boolean, count: number }
export type Main = { beast: boolean, foil: boolean, grade: string, stars: number }
-- byGrade: this card's plain stacks, grade -> counts
CondenseRules.plan(config, byGrade: { [string]: Counts }, main: Main): ({ Take }?, string?)
-- returns the copies to take, or nil and a reason: "max" (5 stars) or "short:<have>:<need>"
CondenseRules.countDuplicates(byGrade, main): number
```
`config` needs `GRADES`, `STAR_COSTS`, `MAX_STARS` (Config/Beasts).

- [ ] **Step 1: Tests** — `tests/CondenseRules.spec.luau`:

```lua
--!strict
local CondenseRules = require("../src/shared/Util/CondenseRules")
local config = require("../src/shared/Config/Beasts")
local expect = require("./lib/expect")

local function counts(normal: number, foil: number)
	return { normal = normal, foil = foil }
end

local function total(takes: { any }): number
	local sum = 0
	for _, take in takes do
		sum += take.count
	end
	return sum
end

return {
	["uses normals weakest grade first, then foils"] = function()
		local stacks = { C = counts(2, 1), B = counts(1, 0), S = counts(3, 2) }
		local takes = CondenseRules.plan(config, stacks, { beast = true, foil = false, grade = "S", stars = 1 }) -- needs 8
		assert(takes, "expected a plan")
		expect.equal(total(takes), 8, "total")
		expect.equal(takes[1].grade, "C", "first C")
		expect.equal(takes[1].foil, false, "first normal")
		expect.equal(takes[2].grade, "B", "then B")
		expect.equal(takes[3].grade, "S", "then S normal")
		expect.equal(takes[3].count, 3, "all S normals")
		expect.equal(takes[4].foil, true, "then foils")
		expect.equal(takes[4].grade, "C", "C foil first")
	end,

	["plain main is not a duplicate"] = function()
		local stacks = { C = counts(4, 0) }
		local takes, reason = CondenseRules.plan(config, stacks, { beast = false, foil = false, grade = "C", stars = 0 })
		expect.isNil(takes, "refused")
		expect.equal(reason, "short:3:4", "reason")
		expect.equal(CondenseRules.countDuplicates(stacks, { beast = false, foil = false, grade = "C", stars = 0 }), 3, "count")
		stacks.C.normal = 5
		local ok = CondenseRules.plan(config, stacks, { beast = false, foil = false, grade = "C", stars = 0 })
		assert(ok, "5 copies: main + 4")
		expect.equal(total(ok), 4, "uses 4")
	end,

	["levelled main counts every plain copy"] = function()
		local takes = CondenseRules.plan(config, { A = counts(4, 0) }, { beast = true, foil = false, grade = "A", stars = 0 })
		assert(takes, "expected a plan")
		expect.equal(total(takes), 4, "uses all 4")
	end,

	["max stars refused"] = function()
		local takes, reason = CondenseRules.plan(config, { C = counts(99, 0) }, { beast = true, foil = false, grade = "C", stars = 5 })
		expect.isNil(takes, "refused")
		expect.equal(reason, "max", "reason")
	end,

	["junk counts are ignored"] = function()
		local stacks: any = { C = { normal = -3, foil = 0 / 0 }, B = "junk", Z = counts(50, 0) }
		local takes, reason = CondenseRules.plan(config, stacks, { beast = true, foil = false, grade = "C", stars = 0 })
		expect.isNil(takes, "unknown grade Z and bad counts don't count")
		expect.equal(reason, "short:0:4", "reason")
	end,
}
```

Add `CondenseRules = require("./CondenseRules.spec"),` to `tests/run.luau`.

- [ ] **Step 2: Run** — Expected: module-not-found error, exit 1.

- [ ] **Step 3: Implement** `src/shared/Util/CondenseRules.luau`:

```lua
--!strict
-- Which duplicates the Condenser uses for the next star, shared by the client preview and the server.
-- Pure (no requires, no Roblox APIs): callers pass Config/Beasts in, so tests/ can run it in Lune.
-- Rule: plain copies of the same card only; all normal copies weakest grade first, then foil copies
-- weakest grade first. A plain main copy is set aside first and is not a duplicate.
local CondenseRules = {}

export type Counts = { normal: number, foil: number }
export type Take = { grade: string, foil: boolean, count: number }
export type Main = { beast: boolean, foil: boolean, grade: string, stars: number }
type Config = { GRADES: { string }, STAR_COSTS: { number }, MAX_STARS: number }

local function readCount(value: any): number
	return if typeof(value) == "number" and value == value and value > 0 and value ~= math.huge then math.floor(value) else 0
end

-- Copies available as duplicates in one stack, after setting a plain main aside
local function available(byGrade: { [string]: any }, grade: string, foil: boolean, main: Main): number
	local stack = byGrade[grade]
	local count = if typeof(stack) == "table" then readCount(if foil then stack.foil else stack.normal) else 0
	if not main.beast and main.grade == grade and main.foil == foil then
		count -= 1
	end
	return math.max(0, count)
end

local function eachStack(config: Config, visit: (grade: string, foil: boolean) -> ())
	for _, foil in { false, true } do
		for _, grade in config.GRADES do
			visit(grade, foil)
		end
	end
end

function CondenseRules.countDuplicates(byGrade: { [string]: any }, main: Main, config: Config?): number
	local grades = if config then config.GRADES else { "C", "B", "A", "S" }
	local total = 0
	for _, foil in { false, true } do
		for _, grade in grades do
			total += available(byGrade, grade, foil, main)
		end
	end
	return total
end

function CondenseRules.plan(config: Config, byGrade: { [string]: any }, main: Main): ({ Take }?, string?)
	if main.stars >= config.MAX_STARS then
		return nil, "max"
	end
	local need = config.STAR_COSTS[math.floor(main.stars) + 1] or math.huge
	local have = CondenseRules.countDuplicates(byGrade, main, config)
	if have < need then
		return nil, `short:{have}:{need}`
	end
	local takes: { Take } = {}
	local remaining = need
	eachStack(config, function(grade, foil)
		local count = math.min(remaining, available(byGrade, grade, foil, main))
		if count > 0 then
			table.insert(takes, { grade = grade, foil = foil, count = count })
			remaining -= count
		end
	end)
	return takes, nil
end

return CondenseRules
```

(Ruling at execution: `countDuplicates` takes `config` as an optional third argument so the grade order comes from config; the spec test calls it without config, which falls back to the same C, B, A, S order.)

- [ ] **Step 4: Run** — Expected: all pass (`44 passed, 0 failed`).
- [ ] **Step 5: Commit** — "Condense rules: which duplicates a star uses".

---

### Task 2: The Condenser as a shelf kind

**Files:** `src/shared/Config/Shelves.luau`, `src/shared/Config/Condenser.luau` (new), `src/server/Services/PlacementService.luau`, `src/client/Controllers/BuildController.luau`, `src/client/Controllers/CardBuyController.luau`, `src/client/Controllers/ShowcaseController.luau`.

- [ ] **Step 1:** `ShelfKind` gains `"Condenser"`; add the entry after Collector Case: `{ id = "Condenser", name = "Card Condenser", kind = "Condenser", capacity = 0, cost = 500, unlockLevel = 4, size = Vector3.new(4, 5, 4), color = Color3.fromRGB(90, 200, 220) }`; header comment lists the kind.
- [ ] **Step 2:** `Config/Condenser.luau`: `{ ACTION_COOLDOWN = 0.5, USE_DISTANCE = 12 }`.
- [ ] **Step 3: PlacementService** — `isCardCase(def)` returns `def.kind == "CustomerCards" or def.kind == "PlayerCards"`; the shelf label for a Condenser reads "Card Condenser" (no counts); material `Neon` accent for the Condenser part; no stock or cards stored; `PlacementService.IsCondenser(shelf)` helper.
- [ ] **Step 4: Client kind checks** — BuildController: shop row detail for Condenser "Combine duplicates for stars · $500"; edit panel hides the Cards row for Condenser and shows a "Condense" row (opens `CondenserController.Open(part)`, Task 4); `applyPromptMode` keeps the stock prompt off for the Condenser. CardBuyController: no Browse prompt on Condensers (`isOtherPlayersCase` only for card cases). ShowcaseController.Open ignores Condensers.
- [ ] **Step 5: Grep (Review Focus 4)** — `grep -rn '~= "Products"\|== "Products"' src --include=*.luau` — every hit treats Condenser correctly.
- [ ] **Step 6:** build, tests, syntax; commit — "Card Condenser shelf kind".

---

### Task 3: Server condensing

**Files:** `src/server/Services/CardService.luau`, `src/server/Services/CondenserService.luau` (new), `src/server/init.server.luau`, `src/shared/Remotes.luau`, `src/server/Services/DevService.luau`.

**Interfaces — Produces:** `CardService.Condense(player, cardId: string, main: XpTarget): (Beast?, string?)`; remote `Condense`.

- [ ] **Step 1: `CardService.Condense`** — in one step with no yields: find the main (beast by ID with matching cardId, or a plain stack copy by card/foil/grade); build `byGrade` from the card's stacks; `CondenseRules.plan(Beasts config, byGrade, { beast, foil, grade, stars })`; on nil return `nil, reason`; take each `Take` from the stacks; if the main is plain, take it from its stack and create a beast (new GUID, level 1, xp 0, stars 0, its grade); `stars += 1`; `sync`; return the beast.
- [ ] **Step 2: `CondenserService`** — `Remotes.Condense.OnServerEvent(player, shelfUid, cardId, mainBeastId, mainFoil, mainGrade)`: RateLimiter (`ACTION_COOLDOWN`); `typeof` checks; `PlacementService.GetShelf(player, shelfUid)` must be `IsCondenser`; player root within `USE_DISTANCE` of the shelf part; known card; target = beast ID string, else `{ cardId, foil = mainFoil == true, grade }` with `BeastRules.isGrade(mainGrade)`; call `CardService.Condense`; notify `"{name} is now {stars} stars!"` or the reason ("Not enough duplicates: have X, need Y." / "Already at max stars."). Register in `init.server.luau` after CardService and PlacementService.
- [ ] **Step 3: Remotes** — add `"Condense"` with its comment.
- [ ] **Step 4: DevService** — `/givecard <number> <amount>`: plain copies of card #number, each with a rolled grade (`BeastRules.rollGrade`), capped at 500 per command; header comment and startup print.
- [ ] **Step 5:** build, tests, syntax; commit — "Server condensing with validation and /givecard".

---

### Task 4: Condenser panel

**Files:** `src/client/Controllers/CondenserController.luau` (new), `src/client/init.client.luau`, `src/client/Controllers/BuildController.luau`.

- [ ] **Step 1: Panel** (marketplace style, same size as the case manager, `UIKit.PANEL_Z_INDEX`):
  - Left: cards the player can condense (any card with a levelled copy or ≥ 2 plain copies), rarest first (`Cards.RarestFirst`); row = thumbnail, name, `Owned N`, `Next star: X duplicates`.
  - Right: for the selected card, a "Main copy" list (levelled copies and plain stacks, strongest Power first, tap to choose; default strongest); then `Stars s/5 → s+1/5`, `uses 3 Grade C + 1 Grade B` (from `CondenseRules.plan`), Power and value before → after; **Condense** button (disabled grey with the reason when the plan is nil).
  - Pressing Condense fires `Remotes.Condense:FireServer(shelfUid, cardId, beastId?, foil, grade)` and keeps the panel open; the binder sync re-renders it (the main stays selected by beast ID; a plain main becomes the new levelled card, selected as the strongest).
  - Closes when the player walks away (> `USE_DISTANCE`) or the machine is gone.
- [ ] **Step 2:** Prompt: BuildController's edit panel "Condense" row and an E prompt "Condense" on the owner's Condenser (Edit stays on F with `UIOffset`, per CLAUDE.md overlap rule).
- [ ] **Step 3:** build, tests, syntax, sourcemap; commit — "Condenser panel".

---

### Task 5: Docs and Studio test

- [ ] DESIGN.md: 4.3 shelf list adds the Card Condenser; 5.8 roadmap step 4 "(done)" only after the user confirms; Condenser rules; 10.2 tree (CondenseRules, CondenserService, CondenserController, Config/Condenser, tests). CLAUDE.md commands: `/givecard`.
- [ ] Commit — "Document the Condenser".
- [ ] **Studio test (user):** spec section 9 items 4–7: Lv 4 unlocks it; place it; E opens the panel; `/givecard 30 70` then condense Voidmaw five times (4/8/12/16/24), stats ×1.75 and value ×80 at 5 stars, button disabled at max; not enough duplicates → disabled with reason; Stop → Play keeps stars, used copies stay gone; levelled copies never disappear.
