# Party & Summoning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A 3-card party; one summoned creature follows its owner (Creator Store model or placeholder) and gives an element perk.

**Architecture:** Perk maths in pure, Lune-tested `Util/PartyRules`; schema v7 in `Migrations`. `PartyService` owns party state, the summoned creature (AlignPosition/AlignOrientation follower, owner network ownership) and exposes `GetPerk(player, kind)`; CustomerService and StockService read it at the few places a perk applies. `Util/CreatureModels` loads models from `ServerStorage.CreatureModels` (Rojo-synced from `assets/creatures/`), strips scripts and scales them, or builds a placeholder. Client: Party panel + binder "Add to party".

**Tech Stack:** Roblox Luau (`--!strict`), Rojo 7.7.1, Lune 0.11.

**Spec:** `docs/superpowers/specs/2026-10-21-party-summoning-design.md`

## Global Constraints

- Party of 3, one summoned. Party cards: no display, no job; condensing allowed. Working cards can't join.
- Perks (Common value; Rare/VR/Epic/Legendary ×1.5/2/2.5/3; +10% of that per star): Ember Hype +5% spawn rate; Tide Calm +10% queue patience; Bloom Express −10% delivery time; Volt Hustle +5% walk speed; Shade Haggle +5% buy chance (capped at 1).
- Models: `assets/creatures/<CardName>.rbxm` → `ServerStorage.CreatureModels`; every Script/LocalScript/ModuleScript removed; scaled by rarity; fallback placeholder.
- Server authoritative; remotes validated + rate-limited; tunables in `Config/Party.luau`.
- Commands: tests `"$USERPROFILE/.rokit/bin/lune.exe" run tests/run`; build; sourcemap; syntax check.

## Review Focus

1. **A partied card leaving the binder** (display, job, buy) refused; condensing a partied main keeps it partied and the creature updates.
2. **Malicious free models** — any script type (including nested, disabled, or inside tools) never runs; models can't be anchored/colliding blockers; huge models can't lag the server (part-count cap → placeholder).
3. **Perk applied twice or left on** (summon swap, unsummon, death, leave) — WalkSpeed restored; perks read live from the current summon only.
4. **Saved party referencing missing/working/duplicate cards** → dropped on load; summoned slot pointing at an empty slot → none.
5. **Creature physics** — owner network ownership on a creature whose owner left; creature welded/aligned to a destroyed character; never errors.

---

### Task 1: PartyRules and config (pure, tested)

**Files:** Create `src/shared/Config/Party.luau`, `src/shared/Util/PartyRules.luau`, `tests/PartyRules.spec.luau`; modify `tests/run.luau`.

- [ ] **Step 1: Config** (plain data):

```lua
--!strict
-- Party and summoning: 3 party cards, one summoned creature that follows you and gives its element's perk.
return {
	PARTY_SIZE = 3,
	-- Perk per element: kind, and the value for a Common at 0 stars
	PERKS = {
		Ember = { kind = "Hype", base = 0.05 }, -- customers arrive more often
		Tide = { kind = "Calm", base = 0.10 }, -- customers wait longer in the queue
		Bloom = { kind = "Express", base = 0.10 }, -- deliveries arrive faster
		Volt = { kind = "Hustle", base = 0.05 }, -- you walk faster
		Shade = { kind = "Haggle", base = 0.05 }, -- customers more willing to buy at your price
	},
	RARITY_MULTIPLIER = { Common = 1, Rare = 1.5, ["Very Rare"] = 2, Epic = 2.5, Legendary = 3 },
	STAR_BONUS = 0.10, -- each star adds this share of the perk
	SIZE_BY_RARITY = { Common = 0.7, Rare = 0.85, ["Very Rare"] = 1, Epic = 1.2, Legendary = 1.4 },
	CREATURE_HEIGHT = 3, -- studs, a 1.0-size creature's height
	FOLLOW_OFFSET = { side = 3, back = 3, up = 1.5 }, -- studs from the owner's root
	BOB_HEIGHT = 0.4,
	BOB_SECONDS = 2,
	TELEPORT_DISTANCE = 40,
	MAX_MODEL_PARTS = 200, -- bigger models fall back to the placeholder
	ACTION_COOLDOWN = 0.5,
}
```

- [ ] **Step 2: Tests** `tests/PartyRules.spec.luau`:

```lua
--!strict
local PartyRules = require("../src/shared/Util/PartyRules")
local config = require("../src/shared/Config/Party")
local expect = require("./lib/expect")

return {
	["perk by element and rarity"] = function()
		local hype = PartyRules.getPerk(config, "Ember", "Common", 0)
		expect.equal(hype.kind, "Hype", "kind")
		expect.near(hype.value, 0.05, 1e-9, "common")
		expect.near(PartyRules.getPerk(config, "Ember", "Legendary", 0).value, 0.15, 1e-9, "legendary")
		expect.near(PartyRules.getPerk(config, "Tide", "Epic", 0).value, 0.25, 1e-9, "tide epic")
	end,
	["stars add 10% each"] = function()
		expect.near(PartyRules.getPerk(config, "Volt", "Common", 5).value, 0.05 * 1.5, 1e-9, "5 stars")
	end,
	["unknown element or rarity"] = function()
		expect.isNil(PartyRules.getPerk(config, "Plasma", "Common", 0), "no perk")
		expect.near(PartyRules.getPerk(config, "Shade", "Mythic", 0).value, 0.05, 1e-9, "rarity x1")
	end,
	["describe"] = function()
		expect.equal(PartyRules.describe(PartyRules.getPerk(config, "Bloom", "Rare", 0)), "Express: deliveries 15% faster", "bloom")
		expect.equal(PartyRules.describe(PartyRules.getPerk(config, "Ember", "Common", 0)), "Hype: customers 5% more often", "ember")
	end,
}
```
- [ ] **Step 3:** run → fails. **Step 4: Implement** `PartyRules.getPerk(config, element, rarity, stars) -> { kind: string, value: number }?` = base × RARITY_MULTIPLIER[rarity] (default 1) × (1 + STAR_BONUS × stars); `PartyRules.describe(perk)` with texts: Hype "customers N% more often", Calm "customers wait N% longer", Express "deliveries N% faster", Hustle "you walk N% faster", Haggle "customers N% more likely to buy" (N = rounded percent). **Step 5:** run → pass. **Commit** "Party perk rules".

---

### Task 2: Schema v7

- [ ] Test in `tests/Migrations.spec.luau`: `["v7: adds an empty party"]` (version 6 → 7 gives `party = { slots = {}, summoned = nil }`; existing kept). `MIGRATIONS[6]`; `SCHEMA_VERSION = 7`; DataService `SavedParty = { slots: { [string]: string }, summoned: number? }` (slot keys as strings "1".."3" so the saved table is a plain dictionary), `PlayerData.party`, TEMPLATE `party = { slots = {} }`. Run, build. **Commit** "Schema v7: party".

---

### Task 3: Partied lock

**Files:** `CardService.luau`, `JobService.luau`, `ShowcaseService.luau`.

- [ ] `CardService.SetPartied(player, beastId, bool)`, `IsPartied`; sync payload `partied = { [beastId] = true }`; `TakeBeast` refuses partied (and working). Condense allowed.
- [ ] JobService `onAssign` refuses a partied beast ("That card is in your party."); ShowcaseService display refuses partied with "That card is in your party. Remove it first."
- [ ] build, tests. **Commit** "Party cards are locked like working cards".

---

### Task 4: Creature models

**Files:** Create `assets/creatures/README.md` (the checklist + naming), `src/server/Util/CreatureModels.luau`; modify `default.project.json` (`ServerStorage.CreatureModels` → `$path: "assets/creatures"`).

- [ ] `CreatureModels.create(card, sizeMultiplier): Model` — find `ServerStorage.CreatureModels:FindFirstChild(card.name)` (a Model); clone; remove every descendant that `IsA("LuaSourceContainer")`; if part count > MAX_MODEL_PARTS or no BasePart → placeholder; all BaseParts `Anchored = false, CanCollide = false, CanQuery = false, CanTouch = false, Massless = true`; set `PrimaryPart` (existing, else the largest part); weld every other part to it (WeldConstraint) so it moves as one; `ScaleTo(CREATURE_HEIGHT × size / current height)`. Placeholder: a Ball body in the element colour plus two small white eye balls with black pupils, welded, sized the same way. Name the model `Creature_<card.name>`.
- [ ] `README.md`: how to Save to File, naming by exact card name, the checklist (free, no scripts in Explorer, < 200 parts, creature-like), and the originality note.
- [ ] build (Rojo builds with an empty folder: add `.gitkeep`? Rojo ignores non-model files; `README.md` is ignored by Rojo only if… — use a `README.md` outside the synced path: put it at `docs/creatures.md` and keep `assets/creatures/.gitkeep`). **Commit** "Creature models from the Creator Store, with a placeholder".

---

### Task 5: PartyService

**Files:** Create `src/server/Services/PartyService.luau`; modify `Remotes.luau`, `init.server.luau`, `CustomerService.luau`, `StockService.luau`.

- [ ] State per player: `slots[1..3] = beastId?`, `summoned = slot?`, `creature = { model, root, alignPosition, alignOrientation, attachment }?`.
- [ ] Remotes `SetPartySlot(slot, target?)`, `Summon(slot?)`, `RequestParty`, `PartyChanged` (`{ slots = { { slot, beastId } }, summoned, perk = { kind, value, text }? }` — list form).
  - SetPartySlot: rate limit; slot 1..3; target nil → remove (unsummon if it was summoned, `SetPartied(false)`); target string beast owned, not working, not already in party; table → `MakeIndividual`; replace an occupied slot (old card un-partied).
  - Summon: nil → unsummon; slot with a card → despawn current, spawn new.
- [ ] Creature: `CreatureModels.create(card, SIZE_BY_RARITY[rarity])`, billboard (name, `Grade · Lv · stars`), parented to a `Creatures` folder; root gets Attachment + `AlignPosition` (RigidityEnabled false, MaxForce high, Responsiveness 25) and `AlignOrientation` (Responsiveness 20); a Heartbeat loop per server (one connection for all creatures) sets the targets: owner root position + offset (side/back/up rotated by the owner's facing) + bob; orientation = owner's facing. Distance > TELEPORT_DISTANCE → PivotTo next to the owner. `root:SetNetworkOwner(owner)` in pcall. Owner without a character → hide (keep model parented to nil) until CharacterAdded.
- [ ] Perks: `PartyService.GetPerk(player, kind): number` (0 unless the summoned card's perk is that kind; reads the beast's current rarity/stars live). Hustle: on summon/unsummon/CharacterAdded set `Humanoid.WalkSpeed = DEFAULT_WALK_SPEED × (1 + perk)` (16 default via `StarterPlayer.CharacterWalkSpeed`), restore on unsummon.
- [ ] Hooks: CustomerService — spawn interval ÷ (1 + Hype), QUEUE_PATIENCE × (1 + Calm), band.chance × (1 + Haggle) capped at 1 (both shopFor and shopForCard); StockService — DELIVERY_SECONDS × (1 − Express). PartyService must not require these services (they require it).
- [ ] Load/save/unload (after CardService and JobService): load validates (beast exists, not working, no duplicates), `SetPartied(true)`, deferred summon; save writes string-keyed slots; unload despawns, restores WalkSpeed.
- [ ] build, tests, syntax, sourcemap. **Commit** "PartyService: party, summoned creature, perks".

---

### Task 6: Client

**Files:** Create `src/client/Controllers/PartyController.luau`; modify `BinderController.luau`, `ShowcaseController.luau`, `JobsController.luau` (none), `init.client.luau`.

- [ ] PartyController: HUD button "Party" (top of the stack, above Jobs: `0.5, -198`), panel (UIKit) with 3 slot rows: card face, name, grade/level/stars, perk text (`PartyRules.describe`), **Summon/Unsummon**, **Remove**; empty slot "Add cards from your binder".
- [ ] Binder card view: a third button "Add to party" (opens a slot chooser 1–3; shows "In party" for partied cards; disabled for working cards). Rows tag "In party". Tile chip adds "Party".
- [ ] Case picker excludes partied cards (`BinderController.GetPartied()`); Condenser keeps them.
- [ ] build, tests, syntax, sourcemap. **Commit** "Party panel and adding cards from the binder".

---

### Task 7: Docs and Studio test

- [ ] DESIGN.md: 5.8 step 3 (built, awaiting Studio test) + perks table; 10.2 tree (PartyService, CreatureModels, PartyRules, Config/Party, PartyController, assets/creatures); 10.4 v7 `party`; 5.5 note: free Creator Store models as stand-ins. CLAUDE.md: Rojo maps `assets/creatures`; models' scripts are stripped. `docs/creatures.md` linked from DESIGN 5.5.
- [ ] Commit "Document party and summoning". Studio test: spec section 7.
