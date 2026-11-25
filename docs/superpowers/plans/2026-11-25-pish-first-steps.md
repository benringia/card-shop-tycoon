# Pish's First Steps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every step of Pish's first visit can be done by tapping what he points at, on a phone, a tablet and a computer.

**Architecture:** A box-based rule in `Util/TalkRules` places the talk card on the spot that leaves the target, its paw
and the Skip pill clear; `TutorialController` points the paw at the Shop tile's `Buy` button (ring round the tile),
gives a phone its own Bag lines, leads an outside player in ("Let's go inside!") and points at the rack's preview,
which `PlacementController` now starts in view beside the player (`CellSearch.nearest`).

**Tech Stack:** Luau (strict), Rojo, Lune tests (`lune run tests/run [Name]`), Roblox Studio MCP for the check.

**Spec:** `docs/superpowers/specs/2026-11-25-pish-first-steps-design.md`

## Global Constraints

- Player text: plain ASCII plus `·` and emoji, each Pish line at most 60 characters (tests/TalkRules).
- Exact new lines: "I brought you a present! Tap the Phone.", "Open it in your Bag! Tap the Phone.", "Tap Bag.",
  "Let's go inside!", "Tap Place!", "Tap an empty spot on the floor, then Place!".
- Pure logic lives in `src/shared/Util` with Lune tests; pure modules don't require siblings.
- No new funnel step (Config/Funnel unchanged); no saved-data change.
- Client files: after editing run the compile check (`lune run <scratch>/compile_check.luau <files>`) and
  `getDiagnostics` for "Unknown global"; TutorialController stays under Luau's 200 locals (new helpers go inside
  existing functions or as few file-level locals as possible).
- Never `sed -i` in `src` (Rojo); edit with Edit/Write.

## Review Focus

1. A target that both card spots cover (a very short or very narrow screen): the card must take the spot covering
   least of it, never flicker between spots each frame. Test: TalkRules "both spots on the target".
2. The Skip pill hidden (a window open) must not push the card off a spot it no longer blocks. Test: TalkRules
   "Skip counts only while it shows" (a spot list without the Skip box picks the top).
3. A player standing in the doorway (half in): inside only 3 studs past the front edge, so "Let's go inside!" can't
   flip on and off at the door every frame. Test: TutorialRules "inside the shop" at 27 / 28 studs out.
4. A new shelf when the shop floor is out of view and every near cell is taken: the preview still starts somewhere
   free (the nearest to the player) and never errors. Test: CellSearch "nothing within reach" returns nil, and the
   controller falls back (Studio).
5. A lesson's Shop tile without a `Buy` button (none exists today, but a tile built differently): the paw falls back
   to the tile itself. Covered in Task 2's code step (`buy or tile`), checked in Studio with the showcase lesson.

---

### Task 0: Commit Studio's fresh switch

Already built and tested on this branch (SaveSlots.fresh, DataService `store.Mock`, `Config/Data.STUDIO_FRESH = false`).

- [ ] **Step 1:** Run `lune run tests/run SaveSlots`. Expected: `6 passed, 0 failed`.
- [ ] **Step 2:** Commit `src/server/Util/SaveSlots.luau src/server/Services/DataService.luau src/shared/Config/Data.luau tests/SaveSlots.spec.luau docs/superpowers/specs/2026-11-25-pish-first-steps-design.md docs/superpowers/plans/2026-11-25-pish-first-steps.md`
  with message `Studio fresh-save switch; Pish first steps spec and plan`.

### Task 1: The talk card never covers what Pish points at

**Files:**
- Modify: `src/shared/Util/TalkRules.luau` (replace `cardAtTop`, the `Target` type and `cardPlace`)
- Modify: `src/client/Util/TutorialCues.luau` (add `skipBox`)
- Modify: `src/client/Util/TutorialTalk.luau` (placement block ~lines 343-369, `keepClear`)
- Test: `tests/TalkRules.spec.luau` (replace the two card-place tests at ~221-244)

**Interfaces:**
- Produces: `TalkRules.Box = { x: number, y: number, w: number, h: number }`,
  `TalkRules.Spot = { name: string, boxes: { Box } }`, `TalkRules.overlap(a: Box, b: Box): number` (shared area, 0
  when apart or touching), `TalkRules.pawBox(target: Box, room: number): Box` (`room` square centred over the
  target's middle, its bottom on the target's top), `TalkRules.pickSpot(spots: { Spot }, target: Box?, paw: Box?): string`,
  `TalkRules.cardPlace(spots: { Spot }, target: Box?, paw: Box?, forceTop: boolean, manning: boolean): string`
  ("side" when manning and not forceTop; "top" when forceTop; else pickSpot; no target: the first spot's name).
- Produces: `TutorialCues.skipBox(card: TalkRules.Box, below: boolean): TalkRules.Box?` (nil while Skip is hidden:
  not wanted, or a window open), `TutorialTalk.keepClear(target: GuiObject?, paw: GuiObject?)` (paw defaults to target).

- [ ] **Step 1: Write the failing tests** (phone numbers measured 2026-11-25 on the iPhone 17 Pro sim, HUD 750 x 323;
  card 420 x 76 at x 97; top spot y 8, bottom spot y 146; Skip 84 x 48 at x 421, y 78 under the top card, y 104 over
  the bottom one; laptop card 552 x 100 at x 553, top y 8, bottom y 343):

```lua
["the talk card takes the spot that leaves Pish's target clear (phone)"] = function()
	local function spots(skip: boolean)
		local top = { { x = 97, y = 8, w = 420, h = 76 } }
		local bottom = { { x = 97, y = 146, w = 420, h = 76 } }
		if skip then
			table.insert(top, { x = 421, y = 78, w = 84, h = 48 })
			table.insert(bottom, { x = 421, y = 104, w = 84, h = 48 })
		end
		return { { name = "top", boxes = top }, { name = "bottom", boxes = bottom } }
	end
	local bag = { x = 286, y = 163, w = 64, h = 64 } -- the Phone's second row
	expect.equal(TalkRules.cardPlace(spots(true), bag, TalkRules.pawBox(bag, 82), false, false), "top", "the Bag: top (its paw may touch the card)")
	local shop = { x = 286, y = 75, w = 64, h = 64 } -- the Phone's first row
	expect.equal(TalkRules.cardPlace(spots(true), shop, TalkRules.pawBox(shop, 82), false, false), "bottom", "the Shop app: bottom")
	local tile = { x = 27, y = 122, w = 340, h = 100 } -- the Small Pack Rack tile, the paw on its $100 button
	local buy = { x = 127, y = 170, w = 232, h = 44 }
	expect.equal(TalkRules.cardPlace(spots(true), tile, TalkRules.pawBox(buy, 82), false, false), "top", "the rack: top")
	expect.equal(TalkRules.cardPlace(spots(true), nil, nil, false, false), "top", "nothing pointed at")
end,
["the talk card on a laptop window and a computer's bottom tile"] = function()
	local spots = {
		{ name = "top", boxes = { { x = 553, y = 8, w = 552, h = 100 } } },
		{ name = "bottom", boxes = { { x = 553, y = 343, w = 552, h = 100 } } },
	}
	local tile = { x = 478, y = 169, w = 222, h = 214 }
	local buy = { x = 486, y = 327, w = 206, h = 48 }
	expect.equal(TalkRules.cardPlace(spots, tile, TalkRules.pawBox(buy, 82), false, false), "top", "the rack's $100 clear")
	local bag = { x = 840, y = 478, w = 72, h = 72 }
	expect.equal(TalkRules.cardPlace(spots, bag, TalkRules.pawBox(bag, 82), false, false), "top", "a bottom tile: top as before")
end,
["both spots on the target: the one covering less of it"] = function()
	local spots = {
		{ name = "top", boxes = { { x = 0, y = 0, w = 100, h = 60 } } },
		{ name = "bottom", boxes = { { x = 0, y = 40, w = 100, h = 60 } } },
	}
	-- the target spans y 50..90: the top card covers 10 x 20 of it, the bottom one 40 x 20
	expect.equal(TalkRules.pickSpot(spots, { x = 10, y = 50, w = 20, h = 40 }, nil), "top", "the one covering less")
end,
["Skip counts only while it shows"] = function()
	local target = { x = 430, y = 100, w = 60, h = 20 } -- under the top card's Skip, clear of both cards
	local withSkip = { { name = "top", boxes = { { x = 97, y = 8, w = 420, h = 76 }, { x = 421, y = 78, w = 84, h = 48 } } }, { name = "bottom", boxes = { { x = 97, y = 146, w = 420, h = 76 } } } }
	local noSkip = { { name = "top", boxes = { { x = 97, y = 8, w = 420, h = 76 } } }, { name = "bottom", boxes = { { x = 97, y = 146, w = 420, h = 76 } } } }
	expect.equal(TalkRules.pickSpot(withSkip, target, nil), "bottom", "Skip under the top card would cover it")
	expect.equal(TalkRules.pickSpot(noSkip, target, nil), "top", "Skip hidden: the top again")
end,
["at the register the talk card stands aside; a fight keeps it at the top"] = function()
	local spots = { { name = "top", boxes = { { x = 0, y = 0, w = 100, h = 60 } } }, { name = "bottom", boxes = { { x = 0, y = 200, w = 100, h = 60 } } } }
	local high = { x = 10, y = 20, w = 20, h = 20 }
	expect.equal(TalkRules.cardPlace(spots, nil, nil, false, true), "side", "manning the register")
	expect.equal(TalkRules.cardPlace(spots, high, nil, true, false), "top", "a fight")
	expect.equal(TalkRules.cardPlace(spots, high, nil, true, true), "top", "a fight on the register")
	expect.equal(TalkRules.cardPlace(spots, high, nil, false, false), "bottom", "a button under the top card")
end,
```

  Delete the old `cardAtTop` / `cardPlace` tests.

- [ ] **Step 2:** Run `lune run tests/run TalkRules`. Expected: FAIL, `attempt to call a nil value` (pawBox).
- [ ] **Step 3: Implement** the Interfaces above in `TalkRules.luau`. `pickSpot`: first spot whose boxes overlap
  neither target nor paw; else first that leaves the target clear; else least target area covered (first wins ties).
- [ ] **Step 4:** Run `lune run tests/run TalkRules`. Expected: all pass.
- [ ] **Step 5: Client wiring.** `TutorialCues.skipBox` with the docking maths of its RenderStepped
  (x = card.x + card.w - SKIP_DOCKED.inset - SKIP_SIZE.X; below: y = card.y + card.h - overlap; above:
  y = card.y + overlap - SKIP_SIZE.Y). In `TutorialTalk`: `avoidPaw` beside `avoid`; boxes from `AbsolutePosition`
  / `AbsoluteSize`; the bottom spot keeps its HUD-tile lift (from the paw target); `where = TalkRules.cardPlace(...)`;
  `keepClear(target, paw)`. Update the file's header comment (no `cardAtTop`).
- [ ] **Step 6:** Compile check the two client files; `lune run tests/run` whole suite. Expected: 0 failed.
- [ ] **Step 7:** Commit `Pish's card takes the spot that leaves his target clear`.

### Task 2: The paw on the Buy button, the ring round the tile

**Files:**
- Modify: `src/client/Controllers/BuildController.luau:263` (name the tile's price button `Buy`)
- Modify: `src/client/Util/TutorialCues.luau` (`pawOn(target, ring)`)
- Modify: `src/client/Controllers/TutorialController.luau` (Target `ring`, `targetRing`, `pointPaw`, `keepClear` call,
  `stepSituation` buildRack shopOpen, `lessonSituation` tile)

**Interfaces:**
- Consumes: `TutorialTalk.keepClear(target, paw)` (Task 1).
- Produces: `TutorialCues.pawOn(target: GuiObject | BasePart, ring: GuiObject?): () -> ()` (ring, its edge and ping
  round `ring or target`; the paw at `target`), Target field `ring: GuiObject?`.

- [ ] **Step 1:** Check nothing finds the tile's button by its old name: grep `src/client` for `"TextButton"` lookups
  in Shop tiles (ShopTile included). Expected: none.
- [ ] **Step 2: Implement.** `button.Name = "Buy"`. `pawOn`: shape and clipping of the ring from `ring or target`,
  the paw's place from `target`. TutorialController: shopOpen returns `{ gui = buy or tile, ring = if buy then tile else nil }`
  (`buy = inside(tile, "Buy")`); the lesson `tile` situation the same; `pointPaw` passes the ring and keys on it;
  `TutorialTalk.keepClear(targetRing(), targetButton())`.
- [ ] **Step 3:** Compile check the three files; whole suite. Expected: 0 failed (SourceOrder included).
- [ ] **Step 4:** Commit `Pish's paw on the rack's Buy, the ring round its tile`.

### Task 3: Pish's Bag lines on a phone

**Files:**
- Modify: `src/shared/Config/PishTalk.luau` (giftPack/gift `now.phone`, `now.trayOpen`; TEACH `bagApp`)
- Modify: `src/client/Controllers/TutorialController.luau` (`bagSituation`, the trophy lesson's mapping)
- Test: `tests/TalkRules.spec.luau`

- [ ] **Step 1: Write the failing test**

```lua
["on a phone his Bag lines go through the Phone, then Bag"] = function()
	local present, gift = PishTalk.STEPS.giftPack, PishTalk.STEPS.gift
	expect.equal(TalkRules.show(present, #present.intro + 1, "phone").text, "I brought you a present! Tap the Phone.")
	expect.equal(TalkRules.show(present, #present.intro + 1, "trayOpen").text, "Tap Bag.")
	expect.equal(TalkRules.show(gift, #gift.intro + 1, "phone").text, "Open it in your Bag! Tap the Phone.")
	expect.equal(TalkRules.show(gift, #gift.intro + 1, "trayOpen").text, "Tap Bag.")
	expect.equal(PishTalk.TEACH.bagApp, "Tap Bag.")
	expect.equal(TalkRules.show(present, #present.intro + 1, "default").text, "I brought you a present. Open your Bag!", "a computer keeps its line")
end,
```

- [ ] **Step 2:** `lune run tests/run TalkRules`. Expected: FAIL on the first equal.
- [ ] **Step 3: Implement** the lines; `bagSituation`: Bag window shut and `Hud.inPhone("Bag")` gives "trayOpen" with
  the Phone open (`Hud.isTrayOpen()`), else "phone", target `{ hud = "Bag" }`; the trophy lesson maps "phone" to TEACH
  `default` and "trayOpen" to `bagApp`.
- [ ] **Step 4:** `lune run tests/run TalkRules` then the whole suite; compile check. Expected: 0 failed.
- [ ] **Step 5:** Commit `Pish's Bag lines on a phone: the Phone, then Bag`.

### Task 4: "Let's go inside!"

**Files:**
- Modify: `src/shared/Config/Pish.luau` (`INSIDE = { margin = 3, spot = 12, height = 5 }`, studs)
- Modify: `src/shared/Util/TutorialRules.luau` (`insideShop`)
- Modify: `src/shared/Config/PishTalk.luau` (buildRack `now.outside`)
- Modify: `src/client/Controllers/TutorialController.luau` (buildRack "outside" situation)
- Test: `tests/TutorialRules.spec.luau`, `tests/TalkRules.spec.luau`

**Interfaces:**
- Produces: `TutorialRules.insideShop(out: number, side: number, width: number, depth: number, margin: number): boolean`
  (`out`: studs from the floor's centre toward the street; `side`: across).

- [ ] **Step 1: Write the failing tests**

```lua
-- tests/TutorialRules.spec.luau
["inside the shop: within its sides and back, 3 studs past the front edge"] = function()
	local W, D, M = 50, 60, Pish.INSIDE.margin
	expect.equal(TutorialRules.insideShop(38, 0, W, D, M), false, "the wake spot on the sidewalk")
	expect.equal(TutorialRules.insideShop(28, 0, W, D, M), false, "in the doorway")
	expect.equal(TutorialRules.insideShop(27, 0, W, D, M), true, "3 studs in")
	expect.equal(TutorialRules.insideShop(0, 26, W, D, M), false, "past the side wall")
	expect.equal(TutorialRules.insideShop(-31, 0, W, D, M), false, "behind the back wall")
	expect.equal(TutorialRules.insideShop(-20, -20, W, D, M), true, "the back corner")
end,
-- tests/TalkRules.spec.luau
["the rack step leads an outside player in"] = function()
	local rack = PishTalk.STEPS.buildRack
	expect.equal(TalkRules.show(rack, #rack.intro + 1, "outside").text, "Let's go inside!")
end,
```

- [ ] **Step 2:** `lune run tests/run TutorialRules` and `TalkRules`. Expected: FAIL (nil call; line missing).
- [ ] **Step 3: Implement** `insideShop`, `Pish.INSIDE`, the line. In `stepSituation` buildRack, after the window,
  Shop and Phone checks: outside (offsets from the plot's `Floor` by dot products with its outward
  `LookVector` and right vector, sizes from `Floor.Size`) returns "outside", `{ spot = floor.Position + outward *
  (floor.Size.Z / 2 - INSIDE.spot) + Vector3.yAxis * INSIDE.height }` (the trail and paw come from `spot` targets).
  No floor or no character: treat as inside.
- [ ] **Step 4:** Both tests pass; whole suite; compile check.
- [ ] **Step 5:** Commit `Pish leads you inside before the rack`.

### Task 5: A new shelf's preview starts in view beside you

**Files:**
- Modify: `src/shared/Util/CellSearch.luau` (`nearest`)
- Modify: `src/shared/Config/Placement.luau` (`START`)
- Modify: `src/client/Controllers/PlacementController.luau` (start cell, `GhostPart`, `IsValid`)
- Modify: `src/shared/Config/PishTalk.luau` (buildRack `now.placing`, `now.placingMove`)
- Modify: `src/client/Controllers/TutorialController.luau` (placing situations, `ghost` targets, no trail)
- Test: `tests/CellSearch.spec.luau`, `tests/TalkRules.spec.luau`

**Interfaces:**
- Produces: `CellSearch.nearest(startX: number, startZ: number, maxX: number, maxZ: number, reach: number, free: (x: number, z: number) -> boolean): Cell?`,
  `Placement.START = { anchors = { { x = 0.3, y = 0.5 }, { x = 0.7, y = 0.5 }, { x = 0.5, y = 0.4 } }, reach = 3 }`
  (viewport shares; cells), `PlacementController.GhostPart(): BasePart?`, `PlacementController.IsValid(): boolean`,
  Target field `ghost: boolean?`.

- [ ] **Step 1: Write the failing tests**

```lua
-- tests/CellSearch.spec.luau
["the nearest free cell within reach"] = function()
	local onlyOne = function(x: number, z: number) return x == 7 and z == 5 end
	local found = CellSearch.nearest(5, 5, 10, 10, 3, onlyOne)
	expect.equal(found and found.x, 7)
	expect.equal(found and found.z, 5)
	expect.equal(CellSearch.nearest(5, 5, 10, 10, 1, onlyOne), nil, "nothing within reach")
	local any = CellSearch.nearest(-3, 20, 10, 10, 2, function() return true end)
	expect.equal(any and any.x, 0, "start clamped into range")
	expect.equal(any and any.z, 10)
end,
-- tests/TalkRules.spec.luau
["placing the tour's rack: Tap Place, or an empty spot while it can't go there"] = function()
	local rack = PishTalk.STEPS.buildRack
	expect.equal(TalkRules.show(rack, #rack.intro + 1, "placing").text, "Tap Place!")
	expect.equal(TalkRules.show(rack, #rack.intro + 1, "placingMove").text, "Tap an empty spot on the floor, then Place!")
end,
```

- [ ] **Step 2:** Run both. Expected: FAIL.
- [ ] **Step 3: Implement.** `nearest` walks `byDistance` and stops past `reach`. `PlacementController.Begin` makes
  the session first, then for a new shelf (`opts.gridX == nil`) tries each anchor (`camera:ViewportPointToRay`,
  floor-only raycast, `worldToCell`, `CellSearch.nearest` with `isFree`); none: the free cell nearest the character
  (reach = the plot's size); `pointer = nil` so it stays until a tap or a mouse move. TutorialController: placing
  returns "placing" (valid) or "placingMove", `{ ghost = true }`; `partFor` returns `PlacementController.GhostPart()`
  for it; `updateTrail` draws none for a ghost target.
- [ ] **Step 4:** Tests pass; whole suite; compile check PlacementController and TutorialController.
- [ ] **Step 5:** Commit `A new shelf's preview starts in view beside you; Pish points at it`.

### Task 6: Docs, Studio check

- [ ] **Step 1:** DESIGN.md: 7.6 (the card's spot rule, the Bag lines on a phone, "Let's go inside!", the paw on
  Buy, "Tap Place!"), 4.3 placement (the start spot), the owner's test save paragraph (`STUDIO_FRESH`), 13 backlog
  (the Bag window's phone scale; the results set bar's layout pick). CLAUDE.md: the test list (TalkRules,
  TutorialRules, CellSearch, SaveSlots) and the switch. Commit `Pish first steps: docs`.
- [ ] **Step 2:** Studio: `STUDIO_FRESH = true` locally (not committed), fresh runs on the iPhone 17 Pro sim and the
  default window through giftPack, summonPal, buildRack (inside, placing); screenshots; switch back off; tell the owner
  what to judge.
