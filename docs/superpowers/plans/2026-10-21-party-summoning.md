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

### Task 4: Motion kit (pure, tested)

**Files:** Create `src/shared/Util/CreatureMotion.luau`, `tests/CreatureMotion.spec.luau`; extend `Config/Party.luau` with `MOTION = { BREATH_SECONDS = 3, BREATH_AMOUNT = 0.03, HOP_HEIGHT = 0.6, STEP_LENGTH = 2.5, WADDLE_DEGREES = 8, LEAN_DEGREES = 10, LAND_SQUASH = 0.08, HOVER_HEIGHT = 2.5, HOVER_BOB = 0.4 }`, `FLYING = { ... card names }`, `MODEL_FOR_CARD = {}`, glow table `GLOW = { [rarity] = { light, lightRange, sparkles, outline, pulse } }`, `MAX_OUTLINES = 31`.

- `CreatureMotion.getPose(motion, time, speed, distanceWalked, flying) -> { offsetY, scaleX, scaleY, roll, pitch }`:
  idle (speed ≈ 0): offsetY 0 (flyer: HOVER_HEIGHT + bob), scaleY = 1 + BREATH_AMOUNT·sin(2πt/BREATH_SECONDS), scaleX = 1/√scaleY; walking: phase = distanceWalked / STEP_LENGTH; offsetY = HOP_HEIGHT·|sin(π·phase)|; roll = WADDLE·sin(π·phase); pitch = LEAN·min(speed/12, 1); squash near landing.
- Tests: idle breathing stays within ±3% and has no hop; walking hops ≥ 0 and ≤ HOP_HEIGHT; waddle alternates sign each step; flyer idles at hover height; scale keeps volume (scaleX²·scaleY ≈ 1).
- **Commit** "Creature motion kit".

---

### Task 5: PartyService and the server marker

**Files:** Create `src/server/Services/PartyService.luau`; modify `default.project.json` (`ReplicatedStorage.CreatureModels` → `$path: "assets/creatures"`, plus `assets/creatures/.gitkeep`), `Remotes.luau`, `init.server.luau`, `CustomerService.luau`, `StockService.luau`.

- On start: destroy every `LuaSourceContainer` under `ReplicatedStorage.CreatureModels`.
- State per player: `slots[1..3] = beastId?`, `summoned = slot?`, `marker: Part?`.
- Remotes `SetPartySlot(slot, target?)`, `Summon(slot?)`, `RequestParty`, `PartyChanged` (list form: `{ slots = { { slot, beastId } }, summoned, perk = { kind, value, text }? }`). Validation as before: slot 1..3, owned, not working, not already in party; table target → `MakeIndividual`; replacing a slot un-parties the old card.
- Marker: anchored, CanCollide/CanQuery/CanTouch false, Transparency 1, size 1, attributes OwnerUserId/CardId/Foil/Grade/Level/Stars (refreshed on CollectionChanged-worthy changes), in `workspace.Creatures`. One Heartbeat loop moves all markers (throttled to 20 Hz): target = owner root + rotated FOLLOW_OFFSET, raycast down (exclude characters and creatures) for ground Y; face owner's move direction; > TELEPORT_DISTANCE → snap. Owner without a character → marker parked (not destroyed).
- Perks: `PartyService.GetPerk(player, kind)`; Hustle sets WalkSpeed on summon/CharacterAdded, restored on unsummon/unload; hooks in CustomerService (spawn interval, queue patience, buy chance) and StockService (delivery time). PartyService never requires those services.
- Load/save/unload after CardService and JobService; validation per spec; unload removes the marker and restores WalkSpeed.
- build, tests, syntax, sourcemap. **Commit** "PartyService: party, summon marker, perks".

---

### Task 5b: Client creatures

**Files:** Create `src/client/Controllers/CreatureController.luau`.

- Watches `workspace.Creatures` markers; for each: clone `ReplicatedStorage.CreatureModels[MODEL_FOR_CARD[name] or name]` (strip scripts again, part cap, unanchor? no: client-only visual, anchored parts moved by PivotTo each frame; CanCollide/CanQuery/CanTouch false), else placeholder; scale by rarity; element tint only for shared models.
- RenderStepped: smooth follow of the marker (lerp), speed and distance walked from marker motion, pose from `CreatureMotion.getPose`, apply via PivotTo (offset + roll/pitch) and `Model:ScaleTo` for breathing (throttled: scale every other frame).
- Rigged models: if `Animations` folder has Idle/Walk and an AnimationController/Humanoid exists, play them locally by speed instead of the hop/waddle.
- Glow per rarity/element/foil/grade/stars: PointLight, ParticleEmitter, Highlight (rainbow cycle for foil, pulse for Legendary). Every second, give outlines to the MAX_OUTLINES nearest/rarest creatures only.
- Name tag BillboardGui. Cleanup when a marker is removed.
- build, syntax. **Commit** "Creatures drawn on each client with walking, breathing and glow".

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
