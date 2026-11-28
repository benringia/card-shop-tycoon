# Robux Round Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sell VIP, Quick Open and Night Shift (game passes) and a one-time Starter Pack, shown in one Store list and
at the moments they help, with their win cards.

**Architecture:** Pass ownership stays in `MonetizationService` (`Has<Key>` attributes); the Starter Pack is a
one-time unlock like the Extra Job Slot, with a grant hook. Every rule the client shows and the server enforces lives
in a pure Lune-tested module (`StoreRules`, `StarterRules`, `VipRules`, additions to `UnlockRules`, `DecorRules`,
`ItemRules`, `RevealRules`, `OfflineRules`, `TitleRules`); controllers only draw.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run [Spec]`), Python 3 + Pillow (icons).

**Spec:** `docs/superpowers/specs/2026-11-28-robux-round-design.md`

## Global Constraints

- Prices: VIP 149, Quick Open 99, Night Shift 149, Starter Pack 99 (set on Creator Hub, managed pricing on); the game
  reads them live (`Util/ProductPrice`), "Coming soon" while an id is 0.
- No power for Robux; VIP gives looks only (gold name, chat tag, VIP Lounge).
- No fake timers, fake scarcity or "most popular"; tags are true ("NEW" until 2027-01-01 UTC, "ONE TIME", "FOREVER").
- A paid thing is never called a gift: the Starter card says "A one-time pack to start your shop:".
- The Starter Pack holds 2x Luck: hidden and refused where `PaidRandomRules.restricted`; the passes are sold everywhere.
- Server authoritative: ownership via `MonetizationService.HasPass`, open counts capped on the server, refusals
  through `Util/Blocked` (never silent).
- Saved data: `starter = { played = 0, shown = false }`, `SCHEMA_VERSION` 46, migration step `[45]`, Lune-tested.
- UI: plain ASCII plus `·` and emoji; cotton candy (`UIKit`); taps ≥ 48 px; BinderController is at the 200-local
  limit (require new modules inside the function that uses them).
- Edit files under `src` with Edit/Write only (no `sed -i`, no Python rewrites: Rojo is serving).
- Every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

- A chat message's `OnIncomingMessage` runs more than once (sending, then delivered): the [VIP] tag shows once.
  Test: `VipRules` "the prefix is added once" (Task 5).
- A modified client asks for the Starter Pack from a restricted country: refused with a Blocked card, never prompted.
  Test: `UnlockRules` "the Starter Pack is chance-based" (Task 1).
- A purchase arrives before the save loaded (or the luck can't be given yet): not marked bought, Roblox asks again.
  Test: `UnlockRules` "a grant that fails leaves it unbought" (Task 1).
- Roblox's pass check fails at join: a VIP Lounge in use stays (only a confirmed "not owned" switches it back).
  Test: `DecorRules` "keepLook only drops a perk look on a confirmed check" (Task 6).
- A modified client asks to open 9999 packs: 50 with Quick Open, else 10. Test: `ItemRules` "openCap" (Task 7).

---

### Task 1: Passes, the Starter unlock, win cards and `/pass`

**Files:**
- Modify: `src/shared/Config/Monetization.luau`, `src/shared/Util/UnlockRules.luau`,
  `src/server/Services/MonetizationService.luau`, `src/shared/Config/Luck.luau` (WIN),
  `src/client/Controllers/StoreWinController.luau`, `src/shared/Remotes.luau` (StoreWin comment),
  `src/server/Services/DevService.luau`, `src/shared/Config/AdminPanel.luau`
- Test: `tests/UnlockRules.spec.luau`

**Interfaces:**
- Produces: `Monetization.PASSES.{VIP, QuickOpen, NightShift, StarterPack}` (0), `Monetization.UNLOCKS` =
  `{ "ExtraJobSlot", "StarterPack" }`, `Monetization.PRODUCTS.StarterPack` (0), `Monetization.CHANCE =
  { StarterPack = true }`, `Monetization.WIN_KINDS` (`ExtraJobSlot = "jobslot"`, `StarterPack = "starter"`,
  `VIP = "vip"`, `QuickOpen = "quickopen"`, `NightShift = "nightshift"`);
  `UnlockRules.apply(bought: { [string]: boolean }, key: string, grant: (() -> boolean)?): boolean`;
  `UnlockRules.chanceBased(key: string, cfg: any): boolean`;
  `MonetizationService.OnUnlockGrant(key: string, grant: (player: Player) -> boolean)`;
  `MonetizationService.DevGrant(player: Player, key: string, on: boolean)` (Studio, "as if bought": win card, grant);
  `Luck.WIN.{vip, quickopen, nightshift, starter}` each `{ title, text, colors, glyph }`, and `jobslot.glyph = "💼"`.

- [ ] **Step 1: Branch and commit the spec and plan**

```bash
git checkout -b robux-round
git add docs/superpowers/specs/2026-11-28-robux-round-design.md docs/superpowers/plans/2026-11-28-robux-round.md
git commit -m "Robux round: spec and plan"
```

- [ ] **Step 2: Write the failing tests** (in `tests/UnlockRules.spec.luau`)

```lua
["the Starter Pack is a one-time unlock, a pass key and chance-based"] = function()
	assert(table.find(Monetization.UNLOCKS, "StarterPack"))
	expect.equal(Monetization.PASSES.StarterPack, 0)
	expect.equal(Monetization.PRODUCTS.StarterPack ~= nil, true)
	expect.equal(UnlockRules.chanceBased("StarterPack", Monetization), true)
	expect.equal(UnlockRules.chanceBased("ExtraJobSlot", Monetization), false)
end,
["the new passes are pass keys"] = function()
	for _, key in { "VIP", "QuickOpen", "NightShift" } do
		expect.equal(typeof(Monetization.PASSES[key]), "number", key)
	end
end,
["a grant that fails leaves it unbought"] = function()
	local bought = {}
	expect.equal(UnlockRules.apply(bought, "StarterPack", function() return false end), false)
	expect.isNil(bought.StarterPack, "Roblox asks again")
	expect.equal(UnlockRules.apply(bought, "StarterPack", function() return true end), true)
	expect.equal(bought.StarterPack, true)
	expect.equal(UnlockRules.apply({}, "ExtraJobSlot", nil), true, "no grant: just owned")
end,
["every pass and unlock has a win card"] = function()
	local Luck = require("../src/shared/Config/Luck")
	for key in Monetization.PASSES do
		local kind = Monetization.WIN_KINDS[key]
		assert(kind, `{key} has a win kind`)
		local win = Luck.WIN[kind]
		assert(win and win.title and win.text and win.glyph, `{kind} has title, text and glyph`)
	end
end,
```

- [ ] **Step 3: Run, expect FAIL**

Run: `lune run tests/run UnlockRules`
Expected: FAIL on the four new tests (StarterPack not listed, `apply`/`chanceBased` nil, no `WIN_KINDS`).

- [ ] **Step 4: Implement**

Config values as in Interfaces; win words from the spec section 7 (`vip` gold and purple `{ {255,210,63}, {118,70,217} }`
glyph 👑; `quickopen` sky `{ {120,200,255}, {28,120,200} }` ⚡; `nightshift` `{ {150,140,255}, {40,48,112} }` 🌙;
`starter` `{ {255,127,184}, {255,184,46} }` 🎁). `UnlockRules.apply`: run the grant first, set `bought[key] = true`
only on true. In `MonetizationService`: the UNLOCKS product handler uses `apply` with the key's registered grant, then
`refresh` and the win card (`WIN_KINDS[key]`); `PromptGamePassPurchaseFinished` (purchased) fires the pass's win card
after `refresh`; `onBuyUnlock` for a chance-based key reads the player's policy (`PolicyService`,
`PaidRandomRules.restricted`) and refuses with `Blocked.tell` ("Not sold where you live."). `StoreWinController`: the
picture is `look.glyph` in a TextLabel when set, else the clover; the clover burst only without a glyph. DevService:
`/pass <VIP|QuickOpen|NightShift|StarterPack> [on|off]` → `MonetizationService.DevGrant`; AdminPanel section
"Robux round" with on/off per key and `SCOPE.pass = "studio"`.

- [ ] **Step 5: Run, expect PASS**

Run: `lune run tests/run UnlockRules` then `lune run tests/run`
Expected: all pass (DevGate / DevRules include the new command's scope).

- [ ] **Step 6: Commit** — `git commit -am "Robux round: passes, the Starter unlock, win cards"`

---

### Task 2: The Store page (Store A)

**Files:**
- Create: `src/shared/Util/StoreRules.luau`
- Modify: `src/shared/Config/Monetization.luau` (`FOREVER`, `NEW`, `NEW_UNTIL`, `STORE` words),
  `src/client/Controllers/StoreController.luau`
- Test: `tests/StoreRules.spec.luau` (register in `tests/run.luau`)

**Interfaces:**
- Consumes: Task 1's pass keys, `WIN_KINDS`, `BuyUnlock`.
- Produces: `StoreRules.forever(owned: { [string]: boolean }, now: number, cfg: any): { { key: string, owned: boolean,
  new: boolean } }` (rows in `cfg.FOREVER` order: VIP, QuickOpen, NightShift, ExtraJobSlot; `new` only for keys in
  `cfg.NEW`, before `cfg.NEW_UNTIL`, and not owned); `StoreRules.showStarter(owned: boolean, restricted: boolean?):
  boolean` (true only when not owned and `restricted == false`). `Monetization.NEW_UNTIL = 1798761600`
  (2027-01-01 00:00 UTC). `Monetization.STORE[key] = { icon, name, line, win }`: VIP 👑 "VIP" "Shine in town" "Gold
  name + VIP look"; QuickOpen ⚡ "Quick Open" "Open 50 at once" "Open 10 becomes Open 50"; NightShift 🌙 "Night Shift"
  "Sell while away" "Away selling 2 h to 4 h"; StarterPack 🎁 "Starter Pack" "One time only" with chips "Sunny Shop
  look", "\"Shop Starter\" title", "2x Luck · 30 min", tag "ONE TIME".

- [ ] **Step 1: Write the failing tests**

```lua
["the Forever rows come in order with their owned state"] = function()
	local rows = StoreRules.forever({ VIP = true }, 0, Monetization)
	expect.equal(#rows, 4)
	expect.equal(rows[1].key, "VIP"); expect.equal(rows[1].owned, true)
	expect.equal(rows[4].key, "ExtraJobSlot"); expect.equal(rows[4].new, false, "not new")
end,
["NEW shows on new passes until NEW_UNTIL, never once owned"] = function()
	local before = StoreRules.forever({}, Monetization.NEW_UNTIL - 1, Monetization)
	expect.equal(before[2].new, true)
	expect.equal(StoreRules.forever({}, Monetization.NEW_UNTIL, Monetization)[2].new, false)
	expect.equal(StoreRules.forever({ QuickOpen = true }, 0, Monetization)[2].new, false)
end,
["the Starter banner shows only unowned and not restricted"] = function()
	expect.equal(StoreRules.showStarter(false, false), true)
	expect.equal(StoreRules.showStarter(true, false), false)
	expect.equal(StoreRules.showStarter(false, true), false)
	expect.equal(StoreRules.showStarter(false, nil), false, "policy still being read")
end,
```

- [ ] **Step 2: Run, expect FAIL** — `lune run tests/run StoreRules` → module not found.

- [ ] **Step 3: Implement** `StoreRules` and the Store page: Starter banner first (when `showStarter`; taps fire
  `Remotes.BuyUnlock` "StarterPack"), the luck section as today, "Forever" rows from `StoreRules.forever` (pass tap:
  `ScreenClear.prompt()` then `MarketplaceService:PromptGamePassPurchase(player, id)`; ExtraJobSlot as today; "Owned"
  quiet button once owned; price via `ProductPrice.ofPass`). Redraw on `HasVIP`, `HasQuickOpen`, `HasNightShift`,
  `HasStarterPack`. Looks as the mockup's Store A (VIP purple with gold outline, Quick Open white with sky outline,
  Night Shift navy to indigo, Starter pink to peach).

- [ ] **Step 4: Run, expect PASS** — `lune run tests/run StoreRules`, then compile-check the controller:
  `lune run <scratch>/compile_check.luau src/client/Controllers/StoreController.luau` → "ok".

- [ ] **Step 5: Commit** — `git commit -am "Robux round: the Store's Forever list and Starter banner"`
  (`git add` the new files first).

---

### Task 3: The Starter Pack on the server (save v46, play counter, offer, grant, title)

**Files:**
- Create: `src/shared/Config/Starter.luau`, `src/shared/Util/StarterRules.luau`,
  `src/server/Services/StarterService.luau` (start it in `init.server.luau` after MonetizationService and LuckService)
- Modify: `src/shared/Config/Data.luau` (46), `src/server/Services/DataService.luau` (template `starter`),
  `src/server/Util/Migrations.luau` (`[45]`), `src/shared/Util/TitleRules.luau` (`unlocks`, kind "unlock"),
  `src/shared/Config/Titles.luau` (`shopStarter`), `src/server/Services/TitleService.luau`,
  `src/shared/Remotes.luau` (`StarterOffer`), `src/server/Services/DevService.luau` (`/starter`), `Config/AdminPanel`
- Test: `tests/StarterRules.spec.luau` (register), `tests/Migrations.spec.luau`, `tests/TitleRules.spec.luau`

**Interfaces:**
- Consumes: `MonetizationService.OnUnlockGrant`, `LuckService.Give(player, "x2", 1800): boolean`.
- Produces: `Starter.PLAY_SECONDS = 3600`, `Starter.LUCK = { strength = "x2", seconds = 1800 }`, `Starter.CARD` words
  (spec section 3), `Starter.POLL = 1`; `StarterRules.clean(saved: any, cfg: any): { played: number, shown: boolean }`;
  `StarterRules.played(played: number, tutorialDone: boolean, mainPlace: boolean, cfg: any): number`;
  `StarterRules.offerDue(state, owned: boolean, restricted: boolean, cfg: any): boolean`;
  `export type Facts = { ready, panelOpen, screenClear, stageShown, revealing, fighting, tour, register: boolean }`;
  `StarterRules.mayShow(facts: Facts): boolean`; remote `StarterOffer` (server → client: show the card; client →
  server: it was shown); `StarterService.Dev(player: Player, action: string): string?` ("offer" | "reset");
  `TitleRules.Progress.unlocks: { [string]: boolean }?`.

- [ ] **Step 1: Write the failing tests**

```lua
-- StarterRules.spec
["play counts only after the first visit, in the main place, up to an hour"] = function()
	expect.equal(StarterRules.played(10, false, true, Starter), 10, "before Pish's visit is done")
	expect.equal(StarterRules.played(10, true, false, Starter), 10, "not in the Frontier or Dungeon")
	expect.equal(StarterRules.played(10, true, true, Starter), 11)
	expect.equal(StarterRules.played(3600, true, true, Starter), 3600, "stops at an hour")
end,
["a saved state is cleaned"] = function()
	local s = StarterRules.clean({ played = 99999, shown = "yes" }, Starter)
	expect.equal(s.played, 3600); expect.equal(s.shown, false)
	expect.equal(StarterRules.clean(nil, Starter).played, 0)
end,
["the card is due after an hour, once, unowned, not restricted"] = function()
	local due = { played = 3600, shown = false }
	expect.equal(StarterRules.offerDue(due, false, false, Starter), true)
	expect.equal(StarterRules.offerDue({ played = 3599, shown = false }, false, false, Starter), false)
	expect.equal(StarterRules.offerDue({ played = 3600, shown = true }, false, false, Starter), false)
	expect.equal(StarterRules.offerDue(due, true, false, Starter), false, "owned")
	expect.equal(StarterRules.offerDue(due, false, true, Starter), false, "restricted")
end,
["the card waits for a calm moment"] = function()
	local calm = { ready = true, panelOpen = false, screenClear = true, stageShown = false, revealing = false,
		fighting = false, tour = false, register = false }
	expect.equal(StarterRules.mayShow(calm), true)
	for _, busy in { "panelOpen", "stageShown", "revealing", "fighting", "tour", "register" } do
		local facts = table.clone(calm); facts[busy] = true
		expect.equal(StarterRules.mayShow(facts), false, busy)
	end
	local notReady = table.clone(calm); notReady.ready = false
	expect.equal(StarterRules.mayShow(notReady), false)
end,
-- Migrations.spec
["v46 (the Starter Pack): every save gets starter = { played = 0, shown = false }"] = function()
	local Data = require("../src/shared/Config/Data")
	expect.equal(Data.SCHEMA_VERSION >= 46, true)
	local data = { version = 45 }
	Migrations.run(data, 46, nil, footprint)
	expect.equal(data.version, 46)
	expect.equal(data.starter.played, 0); expect.equal(data.starter.shown, false)
end,
-- TitleRules.spec
["the Shop Starter title comes with the Starter Pack"] = function()
	local progress = { cleared = {}, secret = false, unlocks = { StarterPack = true } }
	assert(table.find(TitleRules.earned(Titles, progress), "shopStarter"))
	assert(not table.find(TitleRules.earned(Titles, { cleared = {}, secret = false }), "shopStarter"))
end,
```

- [ ] **Step 2: Run, expect FAIL** — `lune run tests/run StarterRules`, `... Migrations`, `... TitleRules`.

- [ ] **Step 3: Implement.** StarterService: `DataService.Register` (load: `StarterRules.clean(data.starter)`; save only
  when loaded; unload); a 1 s loop (`Starter.TICK`) adding play with `StarterRules.played(state.played,
  player:GetAttribute("TutorialDone") == true, not Place.isFrontier() and not Place.isDungeon(), Starter)`; when
  `offerDue` (owned = `MonetizationService.HasPass(player, "StarterPack")`, restricted read once per session through
  `PolicyService` + `PaidRandomRules.restricted`) fire `StarterOffer` once per session; the client's `StarterOffer`
  sets `shown = true` (rate-limited). Grant: `MonetizationService.OnUnlockGrant("StarterPack", function(player) return
  LuckService.Give(player, Starter.LUCK.strength, Starter.LUCK.seconds) end)`. Title `shopStarter`: name "Shop Starter",
  icon 🎁, gradient orange `{255,138,61}` to pink `{255,79,154}`, check `{ kind = "unlock", key = "StarterPack" }`;
  TitleService adds `unlocks = { StarterPack = MonetizationService.HasPass(player, "StarterPack") }` and refreshes on
  `MonetizationService.OnPassChanged`. `/starter offer` fires the card now; `/starter reset` sets `{ played = 0,
  shown = false }`; `SCOPE.starter = "server"`.

- [ ] **Step 4: Run, expect PASS** — the three specs, then `lune run tests/run` (SourceOrder, RequireCycles, DevGate).

- [ ] **Step 5: Commit** — `git add` new files; `git commit -am "Robux round: the Starter Pack's save, counter and grant"`

---

### Task 4: The Starter card (client)

**Files:**
- Create: `src/client/Controllers/StarterController.luau` (start it in `init.client.luau`)
- Test: none in Lune (its rules are Task 3's `StarterRules.mayShow`); compile check and Task 10's Studio pass.

**Interfaces:**
- Consumes: `Remotes.StarterOffer`, `StarterRules.mayShow`, `Starter.CARD`, `Remotes.BuyUnlock`.

- [ ] **Step 1: Implement.** On `StarterOffer`: every `Starter.POLL` s build `Facts` (`ready` = LoadingDone, SeenPrologue,
  SeenWelcome and TutorialDone attributes; `panelOpen` = `UIKit.anyPanelOpen()`; `screenClear` = `ScreenClear.isClear()`;
  `stageShown` = `OpeningStage.isShown()`; `revealing` = `WeaponRevealController.IsPlaying()`; `fighting` = FightHud
  attribute; `tour` = `TutorialRules.tourLeading(...)` as `TitleController.shownHere` reads it; `register` =
  ManningRegister attribute) until `mayShow`, then show the card (`UIKit.panel` cotton candy, butter header "Starter
  Pack!", Pish's peek sticker `HudMascot.images.peek` over its top-left corner, the line, the three rows, gold price
  button with `RobuxPrice`, sky "Maybe later", the amber footnote) and fire `StarterOffer` back. Buy:
  `ScreenClear.prompt()` then `BuyUnlock` "StarterPack"; the card closes when `HasStarterPack` turns true or on
  "Maybe later".

- [ ] **Step 2: Compile check** — `lune run <scratch>/compile_check.luau src/client/Controllers/StarterController.luau`
  → ok.

- [ ] **Step 3: Commit** — `git add` it; `git commit -m "Robux round: the Starter card"`

---

### Task 5: VIP name tag and chat tag

**Files:**
- Create: `src/shared/Config/Vip.luau`, `src/shared/Util/VipRules.luau`, `src/client/Controllers/VipChatController.luau`
- Modify: `src/client/Controllers/TitleController.luau`, `src/client/init.client.luau`
- Test: `tests/VipRules.spec.luau` (register)

**Interfaces:**
- Produces: `Vip.CHAT = { tag = "[VIP]", color = "#FFD23F" }`, `Vip.NAME = { crown = "👑", gradient = { {255,243,176},
  {255,210,63}, {240,160,32} } }`; `VipRules.chatPrefix(prefix: string, cfg: any): string`.

- [ ] **Step 1: Write the failing tests**

```lua
["the prefix puts a gold [VIP] in front"] = function()
	expect.equal(VipRules.chatPrefix("n0gginss:", Vip), '<font color="#FFD23F"><b>[VIP]</b></font> n0gginss:')
end,
["the prefix is added once"] = function()
	local once = VipRules.chatPrefix("n0gginss:", Vip)
	expect.equal(VipRules.chatPrefix(once, Vip), once)
end,
```

- [ ] **Step 2: Run, expect FAIL** — `lune run tests/run VipRules`.
- [ ] **Step 3: Implement.** VipChatController sets `TextChatService.OnIncomingMessage` (none is set today): for a
  message whose `TextSource` is a player with `HasVIP`, return `TextChatMessageProperties` with `PrefixText =
  VipRules.chatPrefix(message.PrefixText, Vip)`. TitleController: with `HasVIP`, the name row gets a `UIGradient` of
  `Vip.NAME.gradient` and a 👑 TextLabel left of the name, placed like `titleLine` places its icon; watch `HasVIP` like
  `Title`.
- [ ] **Step 4: Run, expect PASS**, compile-check both controllers.
- [ ] **Step 5: Commit** — `git commit -m "Robux round: VIP gold name and chat tag"`

---

### Task 6: The VIP Lounge and Sunny Shop looks

**Files:**
- Modify: `src/shared/Config/Decor.luau` (two looks, `PERKS`), `src/shared/Util/DecorRules.luau`,
  `src/server/Services/DecorService.luau`, `src/client/Util/LookTiles.luau`
- Test: `tests/DecorRules.spec.luau`

**Interfaces:**
- Produces: `Look.perk: string?`; `export type Perks = { [string]: boolean }`; `DecorRules.owns(cfg, state, id,
  perks: Perks?)`; `DecorRules.canUse(cfg, state, id, perks: Perks?)`; `DecorRules.keepLook(cfg: any, lookId: string,
  perks: Perks, confirmed: boolean): boolean`; `Decor.PERKS = { VIP = { chip = "VIP only", refuse = "The VIP Lounge is
  for VIPs.", buy = "Get VIP" }, StarterPack = { chip = "Starter Pack", refuse = "Sunny Shop comes in the Starter
  Pack.", buy = "Get it" } }`. Looks: `VipLounge` ("VIP Lounge", perk "VIP", walls `{74,29,102}`, floor `{58,36,24}`
  WoodPlanks, band `{44,15,64}`, trim `{255,214,90}`, extra "topStrip" `{255,214,90}`, wallpaper "") and `SunnyShop`
  ("Sunny Shop", perk "StarterPack", walls `{255,231,150}`, floor `{222,184,135}` WoodPlanks, band `{255,255,255}`,
  trim `{255,255,255}`, wallpaper ""), both price 0, level 1, after the cash looks.

- [ ] **Step 1: Write the failing tests**

```lua
["a perk look is owned only with its perk"] = function()
	local state = DecorRules.clean(Decor, nil)
	expect.equal(DecorRules.owns(Decor, state, "VipLounge", { VIP = true }), true)
	expect.equal(DecorRules.owns(Decor, state, "VipLounge", {}), false)
	expect.equal(DecorRules.owns(Decor, state, "VipLounge"), false)
end,
["a perk look is never bought for cash"] = function()
	local ok, reason = DecorRules.canBuy(Decor, DecorRules.clean(Decor, nil), "SunnyShop", 99, 1e9)
	expect.equal(ok, false); expect.equal(reason, Decor.PERKS.StarterPack.refuse)
end,
["using a perk look needs the perk"] = function()
	local state = DecorRules.clean(Decor, nil)
	expect.equal((DecorRules.canUse(Decor, state, "VipLounge", { VIP = true })), true)
	expect.equal((DecorRules.canUse(Decor, state, "VipLounge", {})), false)
end,
["a saved perk look stays in use, never in the owned list"] = function()
	local state = DecorRules.clean(Decor, { look = "VipLounge", owned = { "VipLounge" } })
	expect.equal(state.look, "VipLounge"); expect.equal(#state.owned, 0)
end,
["keepLook only drops a perk look on a confirmed check"] = function()
	expect.equal(DecorRules.keepLook(Decor, "VipLounge", {}, false), true, "check failing: keep")
	expect.equal(DecorRules.keepLook(Decor, "VipLounge", {}, true), false, "confirmed not owned")
	expect.equal(DecorRules.keepLook(Decor, "VipLounge", { VIP = true }, true), true)
	expect.equal(DecorRules.keepLook(Decor, "CozyWood", {}, true), true)
end,
```

- [ ] **Step 2: Run, expect FAIL** — `lune run tests/run DecorRules`.
- [ ] **Step 3: Implement.** DecorService passes `perks` (`VIP`, `StarterPack` from `MonetizationService.HasPass`) to
  `canUse`/`owns`; after `DataLoaded` and on `OnPassChanged` it checks `keepLook` (`confirmed = not
  MonetizationService.IsCheckFailing(player, perk)`) and switches to `Decor.DEFAULT_LOOK` when false. LookTiles: a perk
  row shows its chip; held → "Use"/"Using"; not held → gold `PERKS.buy` + live price (VIP: pass prompt; Starter:
  `BuyUnlock`); the Sunny Shop row is hidden for a restricted player.
- [ ] **Step 4: Run, expect PASS**, `lune run tests/run`, compile-check LookTiles.
- [ ] **Step 5: Commit** — `git commit -am "Robux round: VIP Lounge and Sunny Shop looks"`

---

### Task 7: Quick Open

**Files:**
- Modify: `src/shared/Config/Levels.luau` (`OPEN_QUICK = 50`), `src/shared/Util/ItemRules.luau`,
  `src/shared/Util/RevealRules.luau`, `src/shared/Config/PackOpening.luau` (`BULK.QUICK` words),
  `src/server/Services/LevelUpService.luau`, `src/client/Controllers/BinderController.luau` (Bag detail),
  `src/client/Controllers/BulkOpenController.luau`
- Test: `tests/ItemRules.spec.luau`, `tests/RevealRules.spec.luau`

**Interfaces:**
- Produces: `ItemRules.openCap(quick: boolean, cfg: any): number`; `ItemRules.bagButtons(have: number, quick: boolean,
  cfg: any): { many: number, quick: number, offer: boolean }`; `RevealRules.skippable(packs: number, openMany: number):
  boolean`; `RevealRules.bestPulls(rarities: { string }, from: string, rank: { [string]: number }, limit: number):
  ({ number }, number, number)` (indices best rarity first, ties in pull order; how many below `from`; how many best
  pulls over `limit`); `PackOpening.BULK.QUICK = { title = "%d packs opened!", best = "Best pulls: Very Rare and up",
  rest = "+ %d Commons and Rares went to your binder", overflow = "+ %d more cards went to your binder", none = "No Very
  Rare this time", more = "Open %d more", limit = 50 }`.

- [ ] **Step 1: Write the failing tests**

```lua
-- ItemRules.spec
["openCap: 50 with Quick Open, else 10"] = function()
	expect.equal(ItemRules.openCap(true, Levels), 50)
	expect.equal(ItemRules.openCap(false, Levels), 10)
	expect.equal(ItemRules.openMany(9999, ItemRules.openCap(true, Levels)), 50)
end,
["the Bag's buttons"] = function()
	local b = ItemRules.bagButtons(64, true, Levels)
	expect.equal(b.many, 10); expect.equal(b.quick, 50); expect.equal(b.offer, false)
	expect.equal(ItemRules.bagButtons(37, true, Levels).quick, 37)
	expect.equal(ItemRules.bagButtons(10, true, Levels).quick, 0, "Open 10 covers it")
	expect.equal(ItemRules.bagButtons(64, false, Levels).offer, true)
	expect.equal(ItemRules.bagButtons(10, false, Levels).offer, false)
end,
-- RevealRules.spec
["only Open 50 can be skipped"] = function()
	expect.equal(RevealRules.skippable(10, 10), false)
	expect.equal(RevealRules.skippable(2, 10), false)
	expect.equal(RevealRules.skippable(11, 10), true)
end,
["best pulls: Very Rare and up, best first, capped"] = function()
	local rank = { Common = 1, Rare = 2, ["Very Rare"] = 3, Epic = 4, Legendary = 5 }
	local picks, below, over = RevealRules.bestPulls({ "Common", "Epic", "Very Rare", "Legendary", "Rare", "Epic" }, "Very Rare", rank, 3)
	expect.equal(table.concat(picks, ","), "4,2,6")
	expect.equal(below, 2); expect.equal(over, 1)
	local none, b2, o2 = RevealRules.bestPulls({ "Common", "Rare" }, "Very Rare", rank, 50)
	expect.equal(#none, 0); expect.equal(b2, 2); expect.equal(o2, 0)
end,
```

- [ ] **Step 2: Run, expect FAIL** — `lune run tests/run ItemRules` and `RevealRules`.
- [ ] **Step 3: Implement.** LevelUpService caps with `ItemRules.openCap(MonetizationService.HasPass(player,
  "QuickOpen"), Levels)`. Bag detail (require Monetization, ProductPrice, RobuxPrice inside the function): under Open /
  Open 10, `bagButtons.quick > 0` → lilac "⚡ Open N" firing `OpenBagPacks(openId, Levels.OPEN_QUICK)`; `offer` → gold
  "⚡ Open 50" with the live pass price → `PromptGamePassPurchase` (quiet "Coming soon" while the id is 0). Bulk open:
  for `packs > Levels.OPEN_MANY` the grid holds only `bestPulls` (limit `QUICK.limit`), the title, the best line, the
  rest/overflow/none line and "⚡ Open N more"; the backdrop tap turns the rest over only when `RevealRules.skippable`
  (Open 10: no tap, no "Tap to turn them all over").
- [ ] **Step 4: Run, expect PASS**, `lune run tests/run`, compile-check BinderController and BulkOpenController.
- [ ] **Step 5: Commit** — `git commit -am "Robux round: Quick Open, and Open 10 can't be skipped"`

---

### Task 8: Night Shift

**Files:**
- Modify: `src/shared/Config/Offline.luau` (`NIGHT_SHIFT`), `src/shared/Util/OfflineRules.luau`,
  `src/server/Services/OfflineService.luau`, `src/client/Controllers/WelcomeBackController.luau`,
  `src/shared/Remotes.luau` (WelcomeBack comment)
- Test: `tests/OfflineRules.spec.luau`

**Interfaces:**
- Produces: `Offline.NIGHT_SHIFT = { factor = 2, owned = "Night Shift sold for %s h (%s h without it)", offer = "Your
  shop sold for %s h. Night Shift keeps it selling for %s h." }`; `OfflineRules.caps(cfg, nightShift: boolean, factor:
  number)` (a copy with `MAX_MINUTES` and `MAX_EXTRA_MINUTES` times `factor` when owned); `OfflineRules.limit(cfg,
  racks: number, restocker: boolean): number`; `OfflineRules.nightShiftNote(away: number, normal: number, shift:
  number, owned: boolean): { owned: boolean, sold: number, other: number }?`; `OfflineRules.hoursText(minutes: number):
  string`; the WelcomeBack summary's `nightShift` field (that note or nil).

- [ ] **Step 1: Write the failing tests**

```lua
["Night Shift doubles both limits"] = function()
	local cfg = OfflineRules.caps(Offline, true, Offline.NIGHT_SHIFT.factor)
	expect.equal(cfg.MAX_MINUTES, 240); expect.equal(cfg.MAX_EXTRA_MINUTES, 240)
	expect.equal(OfflineRules.caps(Offline, false, 2).MAX_MINUTES, 120)
end,
["the selling limit"] = function()
	expect.equal(OfflineRules.limit(Offline, 0, true), 120)
	expect.equal(OfflineRules.limit(Offline, 3, false), 120, "no Restocker: racks don't sell")
	expect.equal(OfflineRules.limit(Offline, 3, true), 210)
	expect.equal(OfflineRules.limit(Offline, 9, true), 240)
end,
["the note shows only when away past the normal limit"] = function()
	expect.isNil(OfflineRules.nightShiftNote(100, 120, 240, true))
	local owned = OfflineRules.nightShiftNote(380, 120, 240, true)
	expect.equal(owned.sold, 240); expect.equal(owned.other, 120)
	local offer = OfflineRules.nightShiftNote(380, 120, 240, false)
	expect.equal(offer.sold, 120); expect.equal(offer.other, 240)
	expect.equal(OfflineRules.nightShiftNote(180, 120, 240, true).sold, 180)
end,
["hours in plain words"] = function()
	expect.equal(OfflineRules.hoursText(120), "2"); expect.equal(OfflineRules.hoursText(150), "2.5")
end,
```

- [ ] **Step 2: Run, expect FAIL** — `lune run tests/run OfflineRules`.
- [ ] **Step 3: Implement.** In `sellAway`: `nightShift = MonetizationService.HasPass(player, "NightShift")`, `cfg =
  OfflineRules.caps(Offline, nightShift, Offline.NIGHT_SHIFT.factor)` used for `minutesAway` (cap `cfg.MAX_MINUTES +
  cfg.MAX_EXTRA_MINUTES`), `split` and `planRacks`; `pending.nightShift = OfflineRules.nightShiftNote(away uncapped,
  limit(Offline, racks, restocker), limit(caps(Offline, true, factor), racks, restocker), nightShift)`. Welcome back
  card: owned → indigo chip "🌙 " + `owned` words; not owned → a white row with the moon, the `offer` words and a small
  gold live-price button (`PromptGamePassPurchase` NightShift); the panel's `MaxSize` grows for it.
- [ ] **Step 4: Run, expect PASS**, `lune run tests/run`, compile-check WelcomeBackController.
- [ ] **Step 5: Commit** — `git commit -am "Robux round: Night Shift"`

---

### Task 9: Pass icons

**Files:**
- Create: `tools/ui-art/make_pass_icons.py`, `assets/ui/passes/{VIP,QuickOpen,NightShift,StarterPack}.png`

- [ ] **Step 1: Write the script** (Pillow, 512 x 512: the Store tiles' gradients in a rounded square, a thick white
  outline, the big icon drawn as shapes: crown, bolt, moon with a star, gift box; Fredoka Bold from `tools/ui-art/fonts`
  only if a word is drawn).
- [ ] **Step 2: Run** `python tools/ui-art/make_pass_icons.py` → four PNGs; look at each.
- [ ] **Step 3: Commit** — `git add tools/ui-art/make_pass_icons.py assets/ui/passes; git commit -m "Robux round: pass icons"`

---

### Task 10: Docs and the Studio pass

**Files:**
- Modify: `DESIGN.md` (8, 5.7, 7.12, 4.8, titles, 10.4 v46), `CLAUDE.md` (dev commands `/pass`, `/starter`, the
  admin panel section, `assets/ui/passes`, the new and changed tests in the tests list)

- [ ] **Step 1: Docs** as listed; `lune run tests/run` → all pass; `rojo build -o <scratch>/test.rbxl` → builds.
- [ ] **Step 2: Studio (main place, Rojo serving):** Play; Output clean. With `/pass <key> on` for each: the win card;
  the Store (screenshot); a VIP's gold name and crown and a chat line with [VIP]; `/decor VipLounge` and the Decor list
  rows; `/item firstSparkPack 64` and the Bag's three buttons (owner and not); Open 50's results and its tap skip; an
  Open 10 that a tap no longer skips; `/away 400` with and without Night Shift; `/starter offer` and the card at a calm
  moment; the HUD overlap scan on a phone (iPhone 17 Pro) for the Bag, the card and the Welcome back row.
- [ ] **Step 3: Commit** — `git commit -am "Robux round: docs"`; then tell the owner exactly what to judge in Studio
  and what to make on Creator Hub (three passes, one product, icons from `assets/ui/passes`).
