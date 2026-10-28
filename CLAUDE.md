# Card Shop Tycoon (Roblox)

Read DESIGN.md first. It is the source of truth for scope, numbers, and structure.
Keep it in sync: when code changes a rule, number or file, update DESIGN.md in the same change.

## Stack
- Roblox, Luau, synced with Rojo (`default.project.json`)
- `src/server` → ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client, `src/shared` → ReplicatedStorage.Shared
- `ServerPackages/` (Wally, not in git) → ServerStorage.ServerPackages. ProfileStore lives there.
- `assets/creatures` → ReplicatedStorage.CreatureModels: creature models saved as `<CardName>.rbxm`
  (docs/creatures.md). Scripts inside them are destroyed on server start and stripped on clients.
- Original creatures (replacing the bought packs card by card) live in the pack file `assets/creatures/Originals.rbxm`
  (`Party.CREATURE_MODELS` entries `{ pack = "Originals", model = "<Card>" }`), built by `tools/blender/build_<card>.py`
  on `tools/blender/voxel_kit.py` (run in Blender through the Blender MCP), sources in `assets/blender/<Card>/`
  (.blend, .fbx, palette PNG; not synced). Workflow and rules: docs/creatures.md "Original models".
- `assets/monsters` → ReplicatedStorage.MonsterModels: wild monster models saved as `<Species>.rbxm`, boss models as
  `<bossId>.rbxm` (`prismHydra.rbxm`, built by `tools/blender/build_prismHydra.py`), same rules.
- `assets/props` → ReplicatedStorage.PropModels (clients build placement ghosts from them): town prop models saved as `<Slot>.rbxm` (docs/props.md). Missing
  ones get a code-built stand-in; the same script test applies.
- `assets/place-props`: prop models that contain unions (Rojo live sync drops union shapes). Not synced: inserted
  into the place file's `ReplicatedStorage.PlaceProps` with Insert from File (docs/props.md).
- `assets/town` → Workspace.TownDecor: hand-placed town scenery saved from Studio as `TownDecor.rbxm` (docs/props.md).
- `assets/ui/card-art` (one painting per card, `docs/card-art.md`), `assets/ui/card-scenes` (one JPEG per element; ids for both in `Config/CardDesign`) and `assets/ui/packs` (pack fronts, ids in
  `Config/Packs`): art made with Figma's image generator, uploaded as images. Not synced by Rojo.
- `assets/ui/icons`: UI icon PNGs (ids in `Config/UIIcons`), cut from Figma-generated sheets by
  `tools/ui-icons/slice_icons.py <sheet> <1|2|3>` (needs Pillow). Not synced by Rojo.
- Files use `.luau`. `init.server.luau` / `init.client.luau` are entry points and set service start order.
- Tools via Rokit (`rokit.toml`): rojo, wally. Published (private) as "Cardshop Simulator" on GitHub `benringia/card-shop-tycoon`.

## Commands
- `rojo serve` — sync to Studio (restart after editing `default.project.json`)
- `rojo serve frontier.project.json` — sync the Frontier place (port 34873; same `src`, Workspace attribute
  `PlaceKind = "Frontier"`; the main project sets it to `"Main"`). Place ids live in `Config/Places.luau`; teleports
  only work in the published game. Each Studio window connects to its own port: a main place window on 34873 boots
  as the Frontier (its Output says "Booted (Frontier)" and the Frontier spring fails to build).
- `rojo serve dungeon.project.json` — sync the Dungeon place (port 34874; Workspace attribute `PlaceKind = "Dungeon"`).
  In Studio the run starts for whoever is in that window; `/room <2-4>` opens the doors and puts you at that room's gate
  (4: the Prism Hydra's chamber).
- `rojo build -o <scratch>/test.rbxl` — quick check that the project builds
- `rojo sourcemap default.project.json -o sourcemap.json` — refresh after adding files so luau-lsp resolves requires
- `wally install` — fetch packages after cloning or changing `wally.toml`
- `lune run tools/economy/sim [players]` — economy simulator: hours to first Epic, first Legendary and a Grade S
  Legendary with 1 star, from the real odds, pity, grading costs and shop profit (Monte Carlo)
- `lune run tools/balance/bosses [fights] [players]` — boss balance: win rates per boss for parties at 0.8x / 1x / 1.3x
  the recommended Power, a typical party (best card at it, two at 60%) and one maxed Legendary with two Lv 1 cards;
  with players > 1 every row is a group of that many players against the scaled boss
- `lune run tests/run` — unit tests for pure modules (BeastMath, Migrations, SaleRules, CondenseRules, PocketLayout, JobRules, LevelMath, PartyRules,
  CreatureMotion, CombatMath, BattleSim, PvpRules, Frontier, Dungeon, DungeonRules, ItemRules, TownLayout, PropFit, ShelfStock, ShelfLayout, PetRig, KeyframeTiming, BeastFxRules, RigGuess, CellSearch, ShelvesConfig, RevealRules, ElementFxRules, BinderSpreads, OddsRules, NewPulls, PityRules, BossRules, CreatureCull, AdminPanel, UiLayout, CompareRules) plus the model script gate (CreatureAssets) and SourceOrder (no local function or file-level local used above its definition, no module used without a require). Pure logic goes in Roblox-free modules so it can be tested here.
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
- Fonts: FredokaOne (titles, buttons) and Nunito Bold (body), applied by `Util/FontStyle` (code may keep naming Gotham). Fredoka does not load in Play.
- Text: plain ASCII plus `·` and emoji only. Gotham/FredokaOne draw symbols like ✦ − ★ as empty boxes.
- HUD buttons go through `Util/Hud` (Manage tray on the left, tiles at the bottom centre, context tiles for
  Drop/Rip), clear of the mobile thumbstick and jump button. Look and motion: `Util/UIKit`, `Util/Motion`.
- `UIKit.panel` windows open one at a time (set the `Overlay` attribute for one that opens on top of another).
- Panels made with `UIKit.panel` hide the thumbstick and jump button while open (they cover panel buttons on phones).
- Two ProximityPrompts on one part overlap: show one at a time, or offset with `UIOffset`.
- Owner-only prompts are created on the client for the owner's own plot, so visitors never see them.

## Workflow
- Work one system at a time. After each: Lune tests → Rojo sync (`rojo serve` running) → Claude presses Play through
  the Roblox Studio MCP, checks Output for errors and screenshots the key spots, fixes anything obvious, then tells
  me exactly what to judge in Studio (stop → Play to load new code).
- Skills: `roblox-dev-skill` (user scope, `~/.claude/skills`, MSayib/roblox-dev-skill: Luau, security, DataStores,
  UI, performance, Studio MCP) for Roblox knowledge; the rules in this file win where it differs (it edits scripts
  in Studio and its template uses PlayerAdded; here code lives in the repo and saved state goes through DataService).
  Studio's own `skill` tool has Roblox's first-party guides: `rbx-device-simulator-lua` for phone/tablet UI checks,
  `rbx-scene-analysis` and `rbx-perf-profiling` for memory and frame time, `rbx-debug` for breakpoints.
- Studio MCP: reading and inspecting the place is fine anytime; ask before changing the place itself (deleting or
  editing objects, Lighting, the Baseplate). Scripts still live only in the repo.
- Remodelling a creature (docs/creatures.md "Original models"): look at its card art and rarity (the more common the
  card, the cuter it looks: Common cute, Rare and Very Rare slightly dangerous and medium size, Epic very dangerous and bigger, Legendary godlike and big), make it in the
  stylized cartoon style of the Cute Pets pack (smooth, simple shapes, flat colours, light, keeping the mythical card
  design): generate it with Meshy through the Blender MCP, reduce it to a few thousand triangles and rig it with our
  own skinning (`tools/blender/rig_kit.py`, one `rig_<card>.py` with bone positions per creature); the scripted voxel builds are the older models, give it every bone the creature needs named for `PetRig`, its own fidgets/tail/bounce
  (`Party.CREATURE_STYLE`) and a signature idle (`Party.SIGNATURE`, poses in `Util/PetRig`, effects in
  `Util/SignatureFx`, Lune-tested). I import the FBX (Rig Type Custom, Keep Zero Influence Bones); Claude resets the
  MeshPart's `PivotOffset` rotation, builds `Workspace.Originals` from the current pack plus the new model; I save the
  folder over `assets/creatures/Originals.rbxm`; Claude checks every model is in the synced pack before deleting the
  workspace copy. New card art (Figma, `docs/card-art.md`) when the design changes.
- Studio-only chat commands (DevService; from the Studio MCP run them with
  `ServerStorage.DevCommand:Invoke(player, "/boss 1")`): `/cash <n>`, `/xp <n>`, `/level <n>`, `/testpack` (foil legendary),
  `/beastxp <n>`, `/givecard <number> <amount>` (plain copies for testing the Condenser), `/room <2-4>` (Dungeon window),
  `/jobslot` (toggle the Extra Job Slot pass in Studio), `/wild` (go to the wild map), `/rest` (wake resting
  cards), `/elite` (an elite monster next to you), `/arena` (go to the arena stands), `/frontierdrop` (a Star Shard and a Frontier card),
  `/raritypack [foil]` (a pack with one card of each rarity, to see every reveal), `/item <id> <n>` (any Config/Items
  item), `/boss <1-6> [fight|group]` (to boss n's arena gate; 1-3 in the main game, 4-6 in the Frontier; with fight or group, use that prompt; boss 7 is reached through the Dungeon run), `/legendarys [foil]` (a Grade S
  copy of every Legendary, to see the lightning on display), `/maxcard <name or number> [foil]` (one copy at max level,
  max stars and Grade S, for testing fights).
- Admin panel (Studio only): the "Admin" tile on the left opens every dev command as a button (`Config/AdminPanel`,
  `AdminPanelController`, remote `DevPanel` handled only in Studio), plus +1/+10 of every item and Go/Fight/Group per boss.
- Multiplayer: Test tab → Local Server, 2 players.
- Saving in Studio needs "Enable Studio access to API services", set on Creator Hub → Game details → API services.
- After I confirm a system works: tick it in DESIGN.md, commit, and push.
- Keep the Obsidian vault `C:/Users/Ben/Documents/obsidian/card-shop-tycoon` up to date as we go (Home.md is the
  index): creature roster, decisions log, lessons learned and the topic notes, written for reuse on future projects.
