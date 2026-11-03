# Card Shop Tycoon (Roblox)

Read DESIGN.md first. It is the source of truth for scope, numbers, and structure.
Keep it in sync: when code changes a rule, number or file, update DESIGN.md in the same change.

## Stack
- Roblox, Luau, synced with Rojo (`default.project.json`)
- `src/server` → ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client, `src/shared` → ReplicatedStorage.Shared,
  `src/first` → ReplicatedFirst.LoadingScreen (the loading screen, in all three project files)
- `ServerPackages/` (Wally, not in git) → ServerStorage.ServerPackages. ProfileStore lives there.
- `assets/creatures` → ReplicatedStorage.CreatureModels: creature models saved as `<CardName>.rbxm`
  (docs/creatures.md). Only models a card or town animal uses (Lune-tested); the bought packs' unused models are kept in
  `assets/creature-packs-unused` (not synced). Scripts inside them are destroyed on server start and stripped on clients.
- Original creatures (replacing the bought packs card by card) live in the pack file `assets/creatures/Originals.rbxm`
  (`Party.CREATURE_MODELS` entries `{ pack = "Originals", model = "<Card>" }`), built by `tools/blender/build_<card>.py`
  on `tools/blender/voxel_kit.py` (run in Blender through the Blender MCP), sources in `assets/blender/<Card>/`
  (.blend, .fbx, palette PNG; not synced). Workflow and rules: docs/creatures.md "Original models".
- `assets/monsters` → ReplicatedStorage.MonsterModels: wild monster models saved as `<Species>.rbxm`, boss models as
  `<bossId>.rbxm` (`prismHydra.rbxm`, built by `tools/blender/build_prismHydra.py`; the Wild bosses `meadowWarden`,
  `caveBroodQueen`, `emberColossus` from Meshy, rigged by `rig_<boss>.py`, docs/creatures.md "Wild bosses"), same rules.
- `assets/props` → ReplicatedStorage.PropModels (clients build placement ghosts from them): town prop models saved as `<Slot>.rbxm` (docs/props.md). Missing
  ones get a code-built stand-in; the same script test applies.
  The town portals (`PortalWild`, `PortalFrontier`, `PortalArena`) are built by `tools/blender/build_portal_<world>.py` on
  `portal_kit.py` (sources in `assets/blender/Portal<World>/`); until one is saved today's `Portal` frame stands in. The
  caldera's `Volcano`, `CharredTree` and `ObsidianShards` come from `build_volcano.py`, `build_charred_tree.py`,
  `build_obsidian_shards.py` (docs/props.md). The Wild boss arenas' `StandingStone`, `Stalagmite`, `Web`, `Cocoon`,
  `Bones`, `CaveDome` and `LavaCliff` come from `build_arena_props.py`.
- `assets/place-props`: prop models that contain unions (Rojo live sync drops union shapes). Not synced: inserted
  into the place file's `ReplicatedStorage.PlaceProps` with Insert from File (docs/props.md).
- `assets/town` → Workspace.TownDecor: hand-placed town scenery saved from Studio as `TownDecor.rbxm` (docs/props.md).
- `assets/ui/card-art` (one painting per card, `docs/card-art.md`; half-size copies in `assets/ui/card-art-small`, ids for both in `Config/CardArt`), `assets/ui/card-scenes` (one JPEG per element; ids for both in `Config/CardDesign`) and `assets/ui/packs` (pack fronts, ids in
  `Config/Packs`): art made with Figma's image generator, uploaded as images. Not synced by Rojo.
- `assets/ui/covers`: the binder's set cover paintings (creature-free, Figma-generated, 680 wide; ids in
  `Config/BinderCovers`). Not synced by Rojo.
- `assets/ui/mascot`: the HUD mascot's stickers (peek and tail; ids in `Config/HudMascot`), Figma-generated on flat green
  and cut out by `tools/ui-art/cutout.py`; swapping the mascot: `docs/hud-mascot.md`. Not synced by Rojo.
- `assets/ui/icons`: UI icon PNGs (ids in `Config/UIIcons`), cut from Figma-generated sheets by
  `tools/ui-icons/slice_icons.py <sheet> <1-4>` (needs Pillow). Not synced by Rojo.
- `assets/packs` → ReplicatedStorage.PackModels: the pack, deck box and display box (`Pack.rbxm`, `DeckBox.rbxm`,
  `DisplayBox.rbxm`, each with `Looks/<look>` SurfaceAppearances), built by `tools/blender/build_pack.py`,
  `build_deckbox.py`, `build_displaybox.py` on `pack_kit.py`, textures by `tools/textures/make_pack_textures.py`;
  sources in `assets/blender/Pack/`. `Util/PackModels` falls back to code-built stand-ins while they're missing
  (docs/packs.md: rebuilding, importing, the Rojo mapping).
- `assets/ui/fx`: the pack opening's effect sheets (rip burst, shards, glints, mote, rays, leak), rendered by
  `tools/blender/build_pack_fx.py` and cut into flipbooks by `tools/textures/make_flipbooks.py`; ids in
  `Config/PackFx`. Uploaded as images, not synced by Rojo.
- `assets/weapons` → ReplicatedStorage.WeaponModels: sword models (`StarterSword.rbxm`, built by
  `tools/blender/build_starter_sword.py`, imported in Studio, finished by `lune run tools/weapons/finish_sword`: the FBX
  importer drops colours and turns pivots). `assets/animations` → ReplicatedStorage.SwordAnimations: the sword moves as
  KeyframeSequences (`<Sword>/<move>.rbxm`), keyed in Blender by `tools/blender/anim_<sword>.py` on `anim_kit.py`,
  converted by `lune run tools/anim/build_kfs`; published ids go in `Config/Swords` (docs/animations.md).
  `assets/monster-animations` → ReplicatedStorage.MonsterAnimations: monster and boss attack clips
  (`<model>/<clip>.rbxm`), keyed on their bone rigs by `tools/blender/anim_<model>.py` on `anim_bone_kit.py`, built by
  `lune run tools/anim/build_bone_clips <model>`, played client-side by `Util/ClipPlayer` (docs/animations.md "Bone
  rigs"; no upload).
  `assets/ui/combat`: the boss-fight HUD's slanted buttons, HP bars and red hit flash and the closing rings
  (`tools/textures/make_slant_buttons.py`, `make_hp_bars.py`, `make_ring_textures.py`), uploaded as images, not synced.
  `assets/ui/fx-levelup`: the level-up pillar's rune circle, beam and mote (white with alpha), rendered by
  `tools/blender/build_levelup_fx.py` (source `assets/blender/LevelUpFx/`) and finished by
  `tools/textures/make_levelup_fx.py`; uploaded as images, ids in `Config/LevelUpFx` IMAGES, not synced.
  `assets/ui/fx-attack`: the fight effects' white textures (glow, streak, bolt, slash, shard...), made by
  `tools/textures/make_attack_fx.py`, uploaded as images (ids in `Config/AttackFx` TEXTURES), not synced. Particle
  textures must be square; a beam runs a texture's height along its length (the bolt is upright).
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
- `lune run tools/balance/bosses [fights] [players] [boss]` — boss balance: win rates per boss for parties at 0.8x / 1x /
  1.3x the recommended Power, a typical party (best card at it, two at 60%) and one maxed Legendary with two Lv 1 cards,
  each for a player who stands still and one who fights well with the sword (targets: well 85% at 1x / 50% at 0.8x,
  still 60% / 15%); with players > 1 every row is a group of that many players against the scaled boss. Every creature
  fights with its fight perk; `NO_PERKS=1` in front runs without them, to compare (`NO_DEBUFFS=1`: without the
  bosses' ring debuffs)
- `lune run tools/balance/wild [fights] [wild|frontier|both]` — wild monster balance: win rate and fight length per
  species at its zone's lowest, middle and highest level, normal and elite, against the card nearest the zone boss's
  recommended Power, three ways: no sword yet, standing still, fighting well (targets: normal about 12.5 s, well ~90%,
  still ~75%, the Meadow ~75% with no sword; elite 25-35 s, well ~65%)
- `lune run tests/run` — unit tests for pure modules (BeastMath, Migrations, SaleRules, CondenseRules, JobRules, LevelMath, PartyRules,
  CreatureMotion, CombatMath, BattleSim, SwordsConfig, SwordRules, RingRules, HpBarRules, CombatPreload, LoadingRules, AttackTiming, FightMotion, FightFxRules, MonsterMoves, ShakeRules, DamagePop, VictoryRules, MarkerNames, DebuffRules, SwapKeys, SummonMotion, DefeatRules, PetVoice, MusicRules, XpPill, SparkPath, HudMascotRules, ContrastRules, SoftColors, SquishRules, PvpRules, Frontier, Dungeon, WildPopulation, DungeonRules, ItemRules, TownLayout, PropFit, ShelfStock, ShelfLayout, PetRig, KeyframeTiming, BeastFxRules, RigGuess, CellSearch, ShelvesConfig, RevealRules, ElementFxRules, BinderSpreads, OddsRules, NewPulls, PityRules, BossRules, CreatureCull, AdminPanel, UiLayout, CompareRules, LevelRemap, LevelUpRules, BinderCovers, OrderRules, LevelUpFxConfig, PageCurl, BinderFit, BinderGesture, ShowcaseLayout, OpeningFlow, OpeningLayout, PackFxConfig, ShopDetail: every shop screen sets a draw distance, PortalTrails,
  TownTerrain, DayCycle, FrameWatchdog, Wander, WelcomePath, PlazaLayout, PortalLooks, LavaCracks, ModelPreload, CardArt, WildValley, MonsterLooks, BossMoments) plus the model script gate (CreatureAssets) and SourceOrder (no local function or file-level local used above its definition, no module used without a require). Pure logic goes in Roblox-free modules so it can be tested here. Lune can't build Vector3 or Color3, so numbers a test reads live in plain-data configs (`CaseLayout`, `PackOpeningLayout`, `CardReveal`, `PackFx`), and pure modules don't require siblings (no `script` in Lune).
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
- Windows are cotton candy (`UIKit.panel`'s default theme, still named "cream" in code; the binder passes "dark" plus
  `softButtons`, fight screens never use it). Inside one, take colours from `UIKit.colorsFor(frame)` (no white text or
  slate rows on it); a plain frame that acts as a window calls `UIKit.creamWindow`. Buttons there are soft
  (`UIKit.isSoft`): pass the kit's named colours (`Colors.Accent`...) and they become baby colours. Colours live in
  `Config/CreamTheme` and `Config/BabyColors`, checked by `tests/ContrastRules` and `tests/SoftColors`.
- ScreenGuis made in code default to `ZIndexBehavior.Global`; set `Sibling` (MainGui does) or a raised panel hides its own children.
- Fonts: FredokaOne (titles, buttons) and Montserrat Bold (body; Nunito before 2026-11-03), applied by `Util/FontStyle` (code may keep naming Gotham). Fredoka does not load in Play.
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
  `ServerStorage.DevCommand:Invoke(player, "/boss 1")`): `/cash <n>`, `/xp <n>`, `/level <n>`, `/setxp <n>` (XP total, down too), `/levelfx [level]` (the level-up pillar; 10, 20... the rainbow one), `/beastlevelfx` (on your summoned creature), `/levelsound <rise|beam|chime|fanfare> <n> [volume]`, `/testpack` (foil legendary),
  `/beastxp <n>`, `/givecard <number> <amount>` (plain copies for testing the Condenser), `/room <2-4>` (Dungeon window),
  `/jobslot` (toggle the Extra Job Slot pass in Studio), `/wild` (go to the wild map), `/rest` (wake resting
  cards), `/tire` (rest every party card but the summoned one, to lose a boss fight), `/elite` (an elite monster next to you), `/arena` (go to the arena stands), `/frontierdrop` (a Star Shard and a Frontier card),
  `/raritypack [foil]` (a pack with one card of each rarity, to see every reveal), `/item <id> <n>` (any Config/Items
  item), `/boss <1-6> [fight|group]` (to boss n's gate: in the main game's Wild valley its portal, in the Frontier its ring; 1-3 in the main game, 4-6 in the Frontier; with fight or group, use that prompt; boss 7 is reached through the Dungeon run), `/crowd <0-60>` (players counted in every Wild valley biome on top of the real ones, to see its monsters grow), `/legendarys [foil]` (a Grade S
  copy of every Legendary, to see the lightning on display), `/maxcard <name or number> [foil]` (one copy at max level,
  max stars and Grade S, for testing fights), `/time <morning|afternoon|sunset|night|dawn>` (jump the town's day cycle),
  `/intro` (replay the first-visit welcome cinematic), `/swordpopup` (show the first-sword popup again), `/buttonnames` (the combat buttons' names again for 3 boss fights), `/music <n> [volume]` (loop town music option n
  from `Music.TOWN.options` over the ambience; `/music 0` for the normal tracks).
- Admin panel (Studio only): the "Admin" tile on the left opens every dev command as a button (`Config/AdminPanel`,
  `AdminPanelController`, remote `DevPanel` handled only in Studio), plus +1/+10 of every item and Go/Fight/Group per boss.
- Multiplayer: Test tab → Local Server, 2 players.
- Saving in Studio needs "Enable Studio access to API services", set on Creator Hub → Game details → API services.
- After I confirm a system works: tick it in DESIGN.md, commit, and push.
- Keep the Obsidian vault `C:/Users/Ben/Documents/obsidian/card-shop-tycoon` up to date as we go (Home.md is the
  index): creature roster, decisions log, lessons learned and the topic notes, written for reuse on future projects.
