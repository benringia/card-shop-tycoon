# Card Shop Tycoon (Roblox)

Read DESIGN.md first. It is the source of truth for scope, numbers, and structure.
Keep it in sync: when code changes a rule, number or file, update DESIGN.md in the same change.

## Stack
- Roblox, Luau, synced with Rojo (`default.project.json`)
- `src/server` → ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client, `src/shared` → ReplicatedStorage.Shared
- `ServerPackages/` (Wally, not in git) → ServerStorage.ServerPackages. ProfileStore lives there.
- `assets/creatures` → ReplicatedStorage.CreatureModels: creature models saved as `<CardName>.rbxm`
  (docs/creatures.md). Scripts inside them are destroyed on server start and stripped on clients.
- `assets/monsters` → ReplicatedStorage.MonsterModels: wild monster models saved as `<Species>.rbxm`, same rules.
- `assets/props` → ServerStorage.PropModels: town prop models saved as `<Slot>.rbxm` (docs/props.md). Missing
  ones get a code-built stand-in; the same script test applies.
- Files use `.luau`. `init.server.luau` / `init.client.luau` are entry points and set service start order.
- Tools via Rokit (`rokit.toml`): rojo, wally. Published (private) as "Cardshop Simulator" on GitHub `benringia/card-shop-tycoon`.

## Commands
- `rojo serve` — sync to Studio (restart after editing `default.project.json`)
- `rojo serve frontier.project.json` — sync the Frontier place (port 34873; same `src`, Workspace attribute
  `PlaceKind = "Frontier"`). Place ids live in `Config/Places.luau`; teleports only work in the published game.
- `rojo build -o <scratch>/test.rbxl` — quick check that the project builds
- `rojo sourcemap default.project.json -o sourcemap.json` — refresh after adding files so luau-lsp resolves requires
- `wally install` — fetch packages after cloning or changing `wally.toml`
- `lune run tests/run` — unit tests for pure modules (BeastMath, Migrations, SaleRules, CondenseRules, PocketLayout, JobRules, LevelMath, PartyRules,
  CreatureMotion, CombatMath, BattleSim, PvpRules, Frontier, ItemRules) plus the model script gate (CreatureAssets) and SourceOrder (no local function or file-level local used above its definition, no module used without a require). Pure logic goes in Roblox-free modules so it can be tested here.
- luau-lsp "Unknown require: unsupported path" on `(script.Parent :: Instance)` requires is editor-only; ignore.
  "Undefined type `unknown`" comes from the old Roblox LSP extension; ignore.

## Rules
- Server authoritative. Client sends intents through remotes, server validates and changes state.
- All cash/XP changes go through EconomyService only.
- Pack rolls happen on the server only.
- Every remote is defined in `src/shared/Remotes.luau`. Validate arg types/ranges, ownership and distance, and
  rate-limit with `src/server/Util/RateLimiter.luau`. Never trust a client-sent price: compare or recompute it.
- All tunable numbers live in `src/shared/Config`. No magic numbers in services.
- Rules the client previews and the server enforces live in `src/shared/Util` (PlacementGrid, PriceRules,
  CardRules, LevelRules) so both sides agree.
- Use `--!strict` and type annotations where practical.
- Never edit synced scripts inside Studio; code lives in this repo.

## Player data
- DataService owns each player's lifecycle (claim plot → load → … → save → unload → release plot).
  Services never use PlayerAdded/PlayerRemoving for saved state; they `DataService.Register({load, save, unload})`.
- `save` must do nothing if that service never loaded for the player, so a failed load can't wipe data.
- Validate everything on load (unknown IDs, bad numbers, layouts that no longer fit). Never silently lose
  items: return them somewhere (e.g. displayed cards → binder).
- Changing the saved shape: bump `SCHEMA_VERSION` in `Config/Data.luau`, add a step to `MIGRATIONS` in `server/Util/Migrations.luau` (with a Lune test),
  update the types/template and DESIGN.md 10.4.
- Every card copy has a grade (C/B/A/S), rolled only on the server. Any code that moves, prices or values a
  card must carry its grade along with level and stars (CardService.GiveCard/TakeFresh, CardRules, BeastRules).
- Saved tables hold plain data only (no Instances, Vector3, Color3; no mixed or gappy arrays).

## UI
- Mobile-first: tap targets ≥ 48px, test landscape phone in the Device emulator.
- Build UI in code with `src/client/Util/UIKit.luau`; card faces with `CardFace.luau`.
- ScreenGuis made in code default to `ZIndexBehavior.Global`; set `Sibling` (MainGui does) or a raised panel hides its own children.
- Text: plain ASCII plus `·` and emoji only. Gotham/FredokaOne draw symbols like ✦ − ★ as empty boxes.
- HUD buttons stack on the middle-left (clear of the mobile thumbstick and jump button).
- Panels made with `UIKit.panel` hide the thumbstick and jump button while open (they cover panel buttons on phones).
- Two ProximityPrompts on one part overlap: show one at a time, or offset with `UIOffset`.
- Owner-only prompts are created on the client for the owner's own plot, so visitors never see them.

## Workflow
- Work one system at a time. After each, tell me exactly what to test in Studio (stop → Play to load new code).
- Studio-only chat commands (DevService): `/cash <n>`, `/xp <n>`, `/level <n>`, `/testpack` (foil legendary),
  `/beastxp <n>`, `/givecard <number> <amount>` (plain copies for testing the Condenser),
  `/jobslot` (toggle the Extra Job Slot pass in Studio), `/wild` (go to the wild map), `/rest` (wake resting
  cards), `/elite` (an elite monster next to you), `/arena` (go to the arena stands), `/frontierdrop` (a Star Shard and a Frontier card).
- Multiplayer: Test tab → Local Server, 2 players.
- Saving in Studio needs "Enable Studio access to API services", set on Creator Hub → Game details → API services.
- After I confirm a system works: tick it in DESIGN.md, commit, and push.
