# Robux round: VIP, Quick Open, Night Shift and the Starter Pack

Date: 2026-11-28. Owner's picks from the mockups (https://claude.ai/artifact/LCpNjGyKWk1So3moAuLj41): Store A, Starter
A, VIP name tag B plus the chat tag and the VIP Lounge look; "Quick Open: right now you can skip Open 10 animations by
clicking, remove that. make it unskippable. [skippable] only on Open 50"; "go".

## Why

Before running ads and letting under-16s in, the owner wants the game ready to earn Robux. The scan (2026-11-28) found:
no game passes at all (the game page's Store tab and Roblox's Shop button are empty), only luck useful at any moment,
nothing sold where players spend the most time (353 packs an hour, about 2,100 packs to a Grade S Legendary), no looks
for Robux and no first-buy bundle. These four items fill those gaps with speed, convenience and looks.

## Goals

- Three game passes: **VIP** (149 R$), **Quick Open** (99 R$), **Night Shift** (149 R$).
- One one-time developer product: the **Starter Pack** (99 R$).
- The Store page shows all of them in one list; each purchase gets its win card.
- Players meet each offer where it helps them: the Bag (Quick Open), the Welcome back card (Night Shift), the Decor
  list (VIP Lounge, Sunny Shop), a card shown once (Starter Pack).

## Non-goals

- Robux card packs, cash for Robux, sold grades or stars, a premium currency (pay-to-win or hides prices from kids).
- A subscription, private servers, rewarded video ads (later, with more players).
- New offers inside the first hour of play.

## Anti-goals (a failure even if it works)

- Pressure: fake timers, fake scarcity, "most popular" with no sales behind it, nagging. Each offer shows once in its
  moment or sits quietly where it's useful.
- Calling a paid thing a gift (kids read "gift" as free).
- Anything that makes another player's game worse, or power for Robux.
- An offer that fails silently: a refused buy goes through `Util/Blocked` like every other refusal.

## Constraints

- Server authoritative: ownership is checked on the server (`MonetizationService.HasPass`), never trusted from the
  client. Prices are shown live (`Util/ProductPrice`, managed pricing gives each player theirs).
- Paid random items: the Starter Pack includes 2x Luck (chance-based), so where Roblox restricts those
  (`Util/PaidRandomRules.restricted`) it isn't shown or sold, like the luck boosts. The passes aren't chance-based.
- Saved data: one new saved table (`starter`), so `SCHEMA_VERSION` 45 -> 46 with a migration and its Lune test
  (DESIGN 10.4).
- Plain ASCII words plus `·` and emoji; cotton candy windows (`UIKit`); tap targets 48 px; nothing on another HUD piece.

## Approaches (picked from the mockups)

- Store: **A, one list** (picked) vs B, two tabs. A keeps everything one scroll away; B hides the passes behind a tab.
- Starter Pack: **A, a card shown once after an hour of play** (picked) vs B, a quiet chip by the Phone. A is seen by
  everyone who stays an hour; B is easy to miss.
- VIP name tag: **B, gold name with a crown, your title stays** (picked) vs A, "VIP" as a title. B shows VIP with any
  title. Plus the gold [VIP] chat tag and the VIP Lounge shop look (owner: "still add").

## The design

### 1. Store page (Store A)

`StoreController`, top to bottom: the **Starter Pack banner** (only while not owned and not restricted: gift icon,
"Starter Pack", "One time only", chips "Sunny Shop look", "\"Shop Starter\" title", "2x Luck · 30 min" and a true
"ONE TIME" tag, gold price button), the "Feeling lucky?" banner and the three luck boosts as today, then **Forever**:
VIP, Quick Open, Night Shift, the Extra Job Slot. Each pass tile: its icon box, name, short line, its win chip, a "NEW"
tag until `Monetization.NEW_UNTIL` (2027-01-01 UTC, true while they're new), the live price, "Owned" once yours,
"Coming soon" while its id is 0. Words and looks as the mockup (Store A).

### 2. The three game passes

`Config/Monetization.PASSES` gains `VIP`, `QuickOpen`, `NightShift` (0 until the owner makes them). Everything already
in `MonetizationService` applies: `Has<Key>` attributes for every client, the session cache, the retry backoff,
`PromptGamePassPurchaseFinished` granting at once, Studio's `DevPass_<Key>`. A pass tile's tap prompts the pass on the
client (`MarketplaceService:PromptGamePassPurchase`, as the Extra Job Slot's pass fallback does). On a granted
purchase the server fires the pass's win card (section 7). A pass bought outside the game (the game page, Roblox's
Shop) counts from the next check (join).

### 3. Starter Pack

- **Product:** a one-time developer product `StarterPack` in `Monetization.UNLOCKS` (sold once, saved in `data.unlocks`,
  counted as owning `HasStarterPack`, exactly like the Extra Job Slot). Its grant, once per purchase (the receipt is
  recorded): the Sunny Shop look becomes usable (section 4c), the "Shop Starter" title is earned (a new title check
  `{ kind = "unlock", key = "StarterPack" }`, gradient orange to pink, icon 🎁), and 30 minutes of 2x Luck are added
  (`LuckService`, the same as buying Luck30). Then its win card.
- **The card (Starter A):** shown once, the first calm moment after an hour of play. Play is counted on the server, one
  second at a time, only after Pish's first visit is done and only in the main place, up to 3,600 s, then it stops
  counting (saved `starter.played`). When it reaches 3,600, the Starter Pack isn't owned, the player isn't restricted
  and `starter.shown` is false, the server tells the client; the client waits for a calm moment (no window open, no
  fight, no tour or lesson, not at the register or placing, the screen clear: the What now? tips' facts), shows the card
  and reports it; only then the server saves `starter.shown = true` (so a session that never got a calm moment shows it
  next time). Words: "Starter Pack!", "A one-time pack to start your shop:", the three rows ("Sunny Shop look · A shop
  look only in this pack", "\"Shop Starter\" title · It shows over your name", "2x Luck · 30 min · Better last cards in
  your packs"), the gold price button, "Maybe later", and "It stays in the Store if you change your mind." Pish peeks
  over its top-left corner.
- **Save:** `starter = { played = 0, shown = false }` (v46; every older save starts there, so players who played before
  see the card after one more hour of play).

### 4. VIP

- **a. Name tag (B):** for a player with `HasVIP`, `TitleController` draws the name row in a gold gradient with a 👑 just
  left of it (placed like the title row's icon); the title row above is unchanged. Everyone sees it, every place.
- **b. Chat tag:** a client `TextChatService.OnIncomingMessage` callback (the game sets none today): for a message
  whose `TextSource` belongs to a player with `HasVIP`, `PrefixText` gains a gold bold `[VIP] ` in front
  (`Util/VipRules.chatPrefix`, pure).
- **c. Decor looks:** two new looks in `Config/Decor.LOOKS`, listed after the cash looks: **VIP Lounge**
  (`vip = true`: plum walls, gold trim and band, dark wood floor) and **Sunny Shop** (`unlock = "StarterPack"`:
  butter walls, white trim, light wood). Neither is sold for cash. `DecorRules` takes what the player holds
  (`perks = { VIP = bool, StarterPack = bool }`): `owns` is true for a held one, `canBuy` refuses both ("VIP only",
  "From the Starter Pack"), `canUse` needs the perk. The Decor list row of a look you don't hold shows its chip ("VIP
  only" / "Starter Pack") and a gold "Get VIP · 149" / "Get it · 99" that prompts the pass / the product. A shop using
  the VIP Lounge whose owner is confirmed not to own VIP (a check that succeeded, never a failing one) switches to Cozy
  Wood. Wallpapers: Figma-generated like the six looks, made seamless by `tools/textures/make_seamless.py`, once the
  owner OKs the AI credits; until then `wallpaper = ""` (the walls' plain colour, already supported).

### 5. Quick Open

- **Bag (`BinderController` Bag detail):** Open and Open 10 stay. With more than 10 packs in the stack: a pass owner
  gets a lilac "⚡ Open N" under them (N = up to `Levels.OPEN_QUICK` = 50); anyone else gets a gold "⚡ Open 50" with the
  live price that prompts the pass.
- **Server (`LevelUpService.onOpenBagPacks`):** the most opened at once is `OPEN_QUICK` with the pass, else `OPEN_MANY`
  (10), checked on the server (`ItemRules.openCap`). Pity, luck, NEW and shop XP per pack as today.
- **Results for more than 10 packs (`BulkOpenController`):** "50 packs opened!", the totals line (cards · NEW · worth),
  "Best pulls: Very Rare and up" with only those cards turning over (best first, at most 50 shown, the rest counted),
  "+ N Commons and Rares went to your binder" (or "No Very Rare this time" with none), Continue and "⚡ Open N more".
  A Legendary still tears the sky.
- **Skipping (owner):** Open 10 can't be skipped any more: a tap does nothing and "Tap to turn them all over" is gone.
  Only Open 50 can be skipped: a tap turns the rest over at once (`RevealRules.skippable(count)`: more than
  `OPEN_MANY`). The single-pack opening is unchanged.

### 6. Night Shift

- **Caps:** with the pass the welcome-back limits double (`Offline.NIGHT_SHIFT.factor` = 2, `OfflineRules.caps`): 2 h
  of selling becomes 4 h, and the racks' extra 2 h becomes 4 h (8 h in all with a Restocker). The server checks the pass
  before working out what sold.
- **Welcome back card:** a pass owner away longer than the normal limit sees a night chip "🌙 Night Shift sold for 4 h
  (2 h without it)". Anyone else away longer than their limit sees one quiet row: "Your shop sold for 2 h. Night Shift
  keeps it selling for 4 h." with a small gold price button (prompts the pass). Away shorter than the limit: no Night
  Shift words at all.

### 7. Win cards

`StoreWinController` and `Luck.WIN` gain `vip` ("VIP!" "Your name shines gold in town!", gold and purple),
`quickopen` ("QUICK OPEN!" "Open 50 packs at once!", sky), `nightshift` ("NIGHT SHIFT!" "Your shop sells for 4 h
while you're away!", indigo with a moon), `starter` ("STARTER PACK!" "Sunny Shop look, your title and 2x Luck!", pink
and gold), with their big icons (crown, lightning, moon, gift). Same rays, shimmer and timing as today.

### 8. On Creator Hub (the owner)

Game passes VIP (149), Quick Open (99), Night Shift (149); developer product Starter Pack (99); managed pricing on for
all four. Their 512 px icons are drawn by a new script, `tools/ui-art/make_pass_icons.py` (Pillow, the tiles' gradients
and icons; no AI credits), into `assets/ui/passes/`. The ids go in `Config/Monetization`.

### 9. Dev tools

`/pass <VIP|QuickOpen|NightShift|StarterPack> [on|off]` (Studio: `MonetizationService.SetDevPass`, like `/jobslot`),
`/starter offer` (the card now, whatever the counters), `/starter reset` (played 0, not shown) and the admin panel's
"Robux round" buttons for each, through `Util/DevAccess` like every dev command.

### 10. Tests (Lune)

`StoreRules` (the page's rows, owned and NEW states, the banner only when not owned and not restricted), `StarterRules`
(the play counter: after the first visit, capped; when the card may show; shown once), `DecorRules` (VIP and Starter
looks: owns, buy refused, use needs the perk, the switch back to Cozy Wood only on a confirmed check), `TitleRules`
(the "unlock" check), `VipRules` (the chat prefix), `ItemRules.openCap` and the Bag's buttons, `RevealRules.skippable`
and the best pulls, `OfflineRules.caps` and the Night Shift words, `Migrations` v46, the win cards' config, plus the
gates already there (SourceOrder, RequireCycles, DevGate, ContrastRules, ToastRules and the HUD overlap scan in Studio).

### 11. Docs

DESIGN.md: 8 (the passes and the Starter Pack built, prices), 5.7 (Open 10 no skip, Open 50), 7.12 (Night Shift), 4.8
(the two looks), the titles (Shop Starter), 10.4 (v46). CLAUDE.md: the dev commands, `assets/ui/passes`, the tests.
The vault: decisions log; the playbook's lessons if any.

## Calls I made (tell me if any are wrong)

- Prices: VIP 149, Quick Open 99, Night Shift 149, Starter Pack 99 (managed pricing then gives regional prices).
- Passes, not developer products, for VIP, Quick Open and Night Shift: they list themselves on the game page and in
  Roblox's Shop; the Starter Pack is a one-time developer product because it holds timed luck.
- "NEW" on the three pass tiles until 2027-01-01.
- The Starter card counts an hour of play after Pish's first visit; old saves count from 0.
- The Starter card says "pack", never "gift".
- VIP gives looks only (gold name, chat tag, VIP Lounge): no gameplay perk.
- Quick Open's results show only Very Rare and up (the rest counted); at most 50 shown.
- Night Shift doubles both limits (8 h with a Restocker and racks).
- No new analytics events: Creator Hub's monetization pages count sales.
