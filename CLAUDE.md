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
  The Wild valley's scenery props (glow mushrooms, ruins, ember tree, dragon skeleton) come from
  `tools/blender/build_valley_props.py` (background Blender only; docs/props.md "Valley scenery props"); its giant
  trees and far mountain ranges from `tools/blender/build_valley_backdrop.py` ("Valley backdrop props").
- `assets/npcs` → ReplicatedStorage.NpcModels: Chikin, the combat tutorial's guide (`Chikin.rbxm`, the owner's other
  dog: Meshy, `tools/blender/prep_chikin.py`, `rig_chikin.py`, Pish's clips via `anim_pish.py` with `DOG=Chikin`; DESIGN
  7.7), and Pish, the tutorial's guide (`Pish.rbxm`, the owner's dog: Meshy, then
  `tools/blender/prep_pish.py` (straighten, scale, head turn, back patch) and `rig_pish.py` (bones, jaw, stiffened
  head and ears; saves `assets/blender/Pish/Pish.fbx`), his 16 clips by `anim_pish.py` into
  `assets/monster-animations/Pish`, checked by `tools/blender/check_stretch.py`; DESIGN.md 7.6). Mapped in the main
  project only. Studio saves the mesh as `MeshContent`, which Lune can't read: a Lune rewrite keeps it, but a model added
  while Rojo is live arrives without its mesh until Rojo reconnects.
- `assets/props` → ReplicatedStorage.PropModels (clients build placement ghosts from them): town prop models saved as `<Slot>.rbxm` (docs/props.md). Missing
  ones get a code-built stand-in; the same script test applies.
  The town portals (`PortalWild`, `PortalFrontier`, `PortalArena`) are built by `tools/blender/build_portal_<world>.py` on
  `portal_kit.py` (sources in `assets/blender/Portal<World>/`); until one is saved today's `Portal` frame stands in. The
  caldera's `Volcano`, `CharredTree` and `ObsidianShards` come from `build_volcano.py`, `build_charred_tree.py`,
  `build_obsidian_shards.py` (docs/props.md). The Wild boss arenas' `StandingStone`, `Stalagmite`, `Web`, `Cocoon`,
  `Bones`, `CaveDome` and `LavaCliff` come from `build_arena_props.py`.
- `assets/fx-models` → ReplicatedStorage.FxModels (mapped in all three project files): models effects summon, moved by
  code: the Grim Reaper of the Rift Reaper's Thousand Cuts (`GrimReaper.rbxm`, Meshy from
  `assets/blender/GrimReaper/concept_B.png`, cleaned by `tools/blender/build_grim_reaper.py`); the same script rule.
- The Frontier valley (spec `docs/superpowers/specs/2026-11-10-frontier-valley-design.md`, DESIGN "The Frontier
  valley"): its world is `Config/FrontierValley` on the Wild valley's engine (`Util/Place.getValley`). Its props
  (`tools/blender/build_frontier_props.py`) come as ONE pack FBX the owner imports once and saves as
  `assets/props-import/FrontierProps.rbxm` (gitignored), split by `lune run tools/props/split_pack <pack>` into
  `assets/props/<Name>.rbxm` (docs/props.md "Frontier scenery props"). Its six monsters and three bosses: Meshy,
  `tools/blender/prep_frontier_model.py`, `rig_frontier_monsters.py` / `rig_frontier_bosses.py`, clips
  `anim_frontier.py`; imported once, finished through the Studio MCP, saved as one folder
  (`assets/props-import/FrontierModels.rbxm`) and split by `lune run tools/monsters/split_models <file>` into
  `assets/monsters` (docs/creatures.md "Frontier monsters and bosses"). `assets/ui/loading`: the Frontier loading
  screen's picture (id in `Config/LoadingScreen LOOKS.Frontier`), not synced.
- `assets/place-props`: prop models that contain unions (Rojo live sync drops union shapes). Not synced: inserted
  into the place file's `ReplicatedStorage.PlaceProps` with Insert from File (docs/props.md).
- `assets/town` → Workspace.TownDecor: hand-placed town scenery saved from Studio as `TownDecor.rbxm` (docs/props.md).
- `assets/ui/card-art` (one painting per card, `docs/card-art.md`; half-size copies in `assets/ui/card-art-small`, ids for both in `Config/CardArt`), `assets/ui/card-scenes` (one JPEG per element; ids for both in `Config/CardDesign`) and `assets/ui/packs` (pack fronts, ids in
  `Config/Packs`): art made with Figma's image generator, uploaded as images. Not synced by Rojo.
- `assets/ui/covers`: the binder's set cover paintings (creature-free, Figma-generated, 680 wide; ids in
  `Config/BinderCovers`). Not synced by Rojo.
- `assets/ui/card-back` (the card back: Pish and Chikin's medallion; id in `Config/CardDesign` BACK.IMAGE) and
  `assets/ui/opening` (the pack opening's backdrop: their shop at night; id in `Config/PackOpening` BACKDROP.IMAGE):
  Figma-generated, uploaded as images. Not synced by Rojo. Pish and Chikin are the face of the game (owner 2026-11-10).
- `assets/ui/mascot`: the HUD mascot's stickers (Pish, the Pish button) (peek and tail; ids in `Config/HudMascot`), Figma-generated on flat green
  and cut out by `tools/ui-art/cutout.py`; swapping the mascot: `docs/hud-mascot.md`. Not synced by Rojo.
- `assets/ui/product-pictures`: the menus' pack and deck box pictures (Order Stock, Prices; ids in
  `Config/ProductPictures`): the real models rendered big in a ViewportFrame on magenta, captured with the Studio MCP and
  cut out by `tools/ui-art/cut_product_picture.py <capture> <out.png> [box]`, uploaded as images. Not synced by Rojo.
- `assets/ui/icons`: UI icon PNGs (ids in `Config/UIIcons`), cut from Figma-generated sheets by
  `tools/ui-icons/slice_icons.py <sheet> <1-9>` (needs Pillow); white glyph sheets (5, 6, 8, 9) then
  `tools/ui-icons/clean_glyphs.py <Name>[:open] ...` (rebuilds the outline the magenta keying eats). Not synced by Rojo.
- `assets/packs` → ReplicatedStorage.PackModels: the pack, deck box and display box (`Pack.rbxm`, `DeckBox.rbxm`,
  `DisplayBox.rbxm`, each with `Looks/<look>` SurfaceAppearances), built by `tools/blender/build_pack.py`,
  `build_deckbox.py`, `build_displaybox.py` on `pack_kit.py`, textures by `tools/textures/make_pack_textures.py`;
  sources in `assets/blender/Pack/`. `Util/PackModels` falls back to code-built stand-ins while they're missing
  (docs/packs.md: rebuilding, importing, the Rojo mapping).
- `assets/ui/fx`: the pack opening's effect sheets (rip burst, shards, glints, mote, rays, leak), rendered by
  `tools/blender/build_pack_fx.py` and cut into flipbooks by `tools/textures/make_flipbooks.py`; ids in
  `Config/PackFx`. Uploaded as images, not synced by Rojo.
- `assets/weapons` → ReplicatedStorage.WeaponModels: sword models (`StarterSword.rbxm`, built by
  `tools/blender/build_starter_sword.py`; `ForgeSword_<Element>`, `VerdantBlade`, `SunforgedBlade`, `PrismBlade` from
  Meshy, cleaned by `tools/blender/build_weapon_<id>.py` on `weapon_kit.py`, the Forge Sword's elements made by
  `lune run tools/weapons/forge_variants` from `assets/weapons-source/ForgeSword.rbxm`, not synced; docs/weapons.md; the spears
  `ForgeSpear_<Element>`, `MagmaHalberd`, `TidalTrident`, `TitansLance` from Meshy, cleaned by `weapon_kit.build_spear`
  (`build_weapon_<id>.py`), the Forge Spear's copies by `forge_variants ForgeSpear`; the scythes `ForgeScythe_<Element>`,
  `WidowsReaper`, `StormReaper`, `RiftReaper` the same way by `weapon_kit.build_scythe`, `forge_variants ForgeScythe`), imported in Studio, finished by
  `lune run tools/weapons/finish_sword`: the FBX importer drops colours and turns pivots).
  `assets/ui/weapon-glow-maps`: each sword's glow map (its painted runes, gems, crystal), made by
  `tools/textures/make_glow_maps.py`, uploaded (ids in `Config/WeaponLooks` GLOW_MAPS) and baked into the models'
  SurfaceAppearances by `lune run tools/weapons/add_glow_maps` (after any re-import or forge_variants; game scripts
  can't set them).
  `assets/ui/weapon-portraits`: the swords' card pictures, rendered on magenta in Studio and cut out by
  `tools/ui-art/cut_product_picture.py` (`--key 0,255,0` for a model shot on green), uploaded (ids in
  `Config/WeaponLooks` portrait), not synced. `assets/animations` → ReplicatedStorage.SwordAnimations: the sword moves as
  KeyframeSequences (`<Sword>/<move>.rbxm`), keyed in Blender by `tools/blender/anim_<sword>.py` on `anim_kit.py`,
  converted by `lune run tools/anim/build_kfs` (the sword moves exported in a background Blender by
  `tools/blender/run_sword_moves.py`, `--sword <name>` for a round 1 sword's own skill, `--sword spear` for the spear
  moveset, `anim_spear.py`, into `assets/animations/Spear`; `--sword titans_lance` for the Titan's Lance's skill,
  `anim_titans_lance.py`, into `assets/animations/TitansLance`; `--sword magma_halberd` / `tidal_trident` for the
  Halberd's and Trident's skills, `anim_magma_halberd.py` / `anim_tidal_trident.py`, into `assets/animations/MagmaHalberd`
  / `TidalTrident`; `--sword scythe` for the scythe moveset, `anim_scythe.py`, into `assets/animations/Scythe`); published ids go in
  `Config/Swords` (docs/animations.md). The round 1 swords' effects: `Config/SwordSkillFx`, client `Util/SwordSkillFx`
  and `Util/SkillCinematic` (DESIGN.md 5.11 "Sword skills").
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
  `tools/textures/make_attack_fx.py`, uploaded as images (ids in `Config/AttackFx` TEXTURES), not synced.
  `assets/ui/fx-moves`: the Pet button moves' textures (raindrop, vine, bark, rune, sigil), made by
  `tools/textures/make_move_fx.py`, uploaded as images (ids in `Config/MoveFx` TEXTURES), not synced.
  `assets/ui/fx-portal`: the Wild loading screen's spiral (white), made by `tools/textures/make_portal_swirl.py`,
  uploaded as an image (id in `Config/WildLoading` SWIRL), not synced.
  `assets/ui/fx-super`: the super moves' white textures (firestrip, crack, waterstrip), made by
  `tools/textures/make_super_fx.py`, uploaded as images (ids in `Config/SuperFx` TEXTURES), not synced.
  `assets/ui/fx-sword`: the sword effects' white textures (crescent, burst flipbook, line, star), made by
  `tools/textures/make_sword_fx.py`, uploaded as images (ids in `Config/SwordFx` TEXTURES), not synced. Particle
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
  Legendary with 1 star, from the real odds, pity, grading costs and shop profit (Monte Carlo); kid offers bought and a
  4-star shop's customer flow by default (`NO_KIDS=1` without the offers, `RATING=3` at today's flow)
- `lune run tools/balance/bosses [fights] [players] [boss]` — boss balance: win rates per boss for parties at 0.8x / 1x /
  1.3x the recommended Power, a typical party (best card at it, two at 60%) and one maxed Legendary with two Lv 1 cards,
  each for a player who stands still and one who fights well with the sword (targets: well 85% at 1x / 50% at 0.8x,
  still 60% / 15%); with players > 1 every row is a group of that many players against the scaled boss. Every creature
  fights with its fight perk; `NO_PERKS=1` in front runs without them, to compare (`NO_DEBUFFS=1`: without the
  bosses' ring debuffs). Epic and Legendary cards fire their supers when ready (`NO_SUPERS=1`: without,
  `ONLY_SUPER="<card>"`: that one alone); `SET="Voidmaw.healCap=0.05"` / `BOSS_SET="prismHydra.atk=40"` try numbers
  without editing the configs
- `lune run tools/audio/sound_ids` — every super / Pet move / attack sound id; measure new ones in Studio with
  `tools/audio/measure_loudness.luau` into `Config/SoundLevels` (skill sounds louder than its TARGET are turned down,
  `Util/SoundLevel`; `tests/SoundLevel` fails for an unmeasured skill sound)
- `lune run tools/balance/wild [fights] [wild|frontier|both]` — wild monster balance: win rate and fight length per
  species at its zone's lowest, middle and highest level, normal and elite, against the card nearest the zone boss's
  recommended Power, three ways: no sword yet, standing still, fighting well (targets: normal about 12.5 s, well ~90%,
  still ~75%, the Meadow ~75% with no sword; elite 25-35 s, well ~65%)
- `lune run tests/run` — unit tests for pure modules (BeastMath, Migrations, SaleRules, CondenseRules, JobRules, LevelMath, PartyRules,
  CreatureMotion, CombatMath, BattleSim, SwordsConfig, SwordRules, SwordSkillFx: the round 1 swords' looks, beats and shakes and the skill camera's side and zoom-out past the boss, ScreenSlashRules: Thousand Cuts' slashes across your screen, SwordArcRules, SwingGate, RingRules, HpBarRules, CombatPreload, LoadingRules, AttackTiming, FightMotion, FightFxRules, MonsterMoves, ShakeRules, DamagePop, VictoryRules, MarkerNames, DebuffRules, SwapKeys, SummonMotion, DefeatRules, PetVoice, MusicRules, XpPill, SparkPath, HudMascotRules, ContrastRules, SoftColors, SquishRules, PvpRules, Frontier, Dungeon, WildPopulation, DungeonRules, ItemRules, TownLayout, TownPreload: the town's pictures before you walk in, PropFit, ShelfStock, ShelfLayout, PetRig, KeyframeTiming, BeastFxRules, RigGuess, CellSearch, ShelvesConfig, RevealRules, ElementFxRules, BinderSpreads, OddsRules, NewPulls, PityRules, BossRules, CreatureCull, AdminPanel, UiLayout, CompareRules, LevelRemap, LevelUpRules, BinderCovers, OrderRules, LevelUpFxConfig, PageCurl, BinderFit, BinderGesture, ShowcaseLayout, OpeningFlow, OpeningLayout, PackFxConfig, HoverRules, ProductPictureRules, ShopDetail: every shop screen sets a draw distance, PortalTrails,
  TownTerrain, DayCycle, FrameWatchdog, Wander, WelcomePath, PlazaLayout, PortalLooks, LavaCracks, ModelPreload, CardArt, WildValley, MonsterLooks, BossMoments, MoveFx: the Pet button moves' looks by grade and MoveFxRules, SkillText: a card's skills in words and the sword skill buttons, WildLoadingRules: the Wild's loading screen, SuperFx: the super moves' looks by grade, beats and camera, SoundLevel: skill sounds brought to one level, CustomerTypes, CollectorRules, OfferRules, HaggleRules, ReactionRules, RatingRules, WalkerRules: the customers round, StageRules: the binder, card view and pack opening stages right above the player, WalkStep: NPCs following a path smoothly, TiredRules: shop workers' tired spells, CreatureFlight: which creatures fly, ToastRules: toasts as speech bubbles over the cash, WeaponsConfig, WeaponRules, WeaponText, WeaponLookRules: weapons round 1, WeaponSwitch: the quick weapon switch's order and steps, TutorialRules / LuckRules / LessonRules: Pish's tutorial steps, his luck, the gift's floor and the luck badge's timer, his lesson visits (one for every town and shop unlock) and the stuck helper, PishPath: Town Pish's walk round the fountain, TalkRules: which of Pish's lines shows, that every line is short and drawable and his talk card's place (top unless it covers what he points at), OpeningSounds: the rip's volume and the lineup's sounds never the boss victory's, PishWalk: his walk's tempo, ArrivalShot: his arrival's camera, ChikinRules: Chikin's combat tutorial steps, lines and focus mode (the HUD pieces each step keeps), FrontierValley: the Frontier valley's layout, budget, props, arenas and models, FrontierFxRules: its fog eyes, lightning and tremors, IceFxRules: the Frost Tyrant's falling spikes, shield shards and shatter, StormFxRules: the Storm Sovereign's thunderclap (its bolts, circle and crackles), SummonRules: the Rift Devourer's summons (their corners, run and rising out of the rift), ItemPopupRules: picked-up items' cards, BossIdleRules: a boss walking, roaring and stomping between its moves, FxToneRules: effects toned to the scene's brightness) plus the model script gate (CreatureAssets) and SourceOrder (no local function or file-level local used above its definition, no module used without a require). Pure logic goes in Roblox-free modules so it can be tested here. Lune can't build Vector3 or Color3, so numbers a test reads live in plain-data configs (`CaseLayout`, `PackOpeningLayout`, `CardReveal`, `PackFx`), and pure modules don't require siblings (no `script` in Lune).
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
  `ServerStorage.DevCommand:Invoke(player, "/boss 1")`): `/cash <n>`, `/xp <n>`, `/level <n>`, `/setxp <n>` (XP total, down too), `/levelfx [level]` (the level-up pillar; 10, 20... the rainbow one), `/beastlevelfx` (on your summoned creature), `/levelsound <1-3> [volume]` (a level-up sound set, played once; 0: the default), `/victorysound <1-3>` (a boss win's sting, played once and on your next wins; 0: the default), `/testpack` (foil legendary),
  `/beastxp <n>`, `/givecard <number> <amount>` (plain copies for testing the Condenser), `/room <2-4>` (Dungeon window),
  `/jobslot` (toggle the Extra Job Slot pass in Studio), `/jobtired` (every shop worker tired now, or rested again), `/wild` (go to the wild map), `/rest` (wake resting
  cards), `/tire` (rest every party card but the summoned one, to lose a boss fight), `/bosshp <1-100>` (your boss fight's boss down to that % of its HP: its summons, phases and heals), `/elite` (an elite monster next to you), `/arena` (go to the arena stands), `/frontierdrop` (a Star Shard and a Frontier card),
  `/raritypack [foil]` (a pack with one card of each rarity, to see every reveal), `/item <id> <n>` (any Config/Items
  item), `/weapon <id> [C|B|A|S] [0-10]` (that weapon at exactly that grade and level; the admin panel's Weapons
  section), `/material <boss id> <n>` (a boss's weapon material; Wild Ore is `/item wildOre <n>`), `/weapondrop <boss id> [preview [C|B|A|S] | beacon]` (that boss's weapon
  drops for you now: the drop cinematic, a refund when you have it; preview: only a new drop's cinematic, nothing given; beacon: the light column others nearby see, in front of you), `/boss <1-6> [fight|group]` (to boss n's gate: its portal in the main game's Wild valley or in the Frontier valley; 1-3 in the main game, 4-6 in the Frontier; with fight or group, use that prompt; boss 7 is reached through the Dungeon run), `/crowd <0-60>` (players counted in every Wild valley biome on top of the real ones, to see its monsters grow), `/customer <plain|kid|collector|bargain|bigSpender> [card id or number | rarity] [hand]` (a customer of that type now; a collector wanting that card; a kid whose rip has that rarity (rare, veryrare, epic, legendary) and who offers it if Very Rare or better; with hand it arrives holding its list, so empty shelves don't matter and nothing is taken from or put back on them), `/serve` (scan everything on the counter and press Charge as the owner, who must stand behind the register), `/legendarys [foil]` (a Grade S
  copy of every Legendary, to see the lightning on display), `/maxcard <name or number> [foil]` (one copy at max level,
  max stars and Grade S, for testing fights), `/time <morning|afternoon|sunset|night|dawn>` (jump the town's day cycle),
  `/intro` (replay the first-visit welcome cinematic), `/tutorial reset` (Pish's first visit as a new player's, gifts
  not given yet), `/tutorial step <1-8>` (jump to a step), `/tutorial lesson <id>` (that lesson visit again: sleeves,
  sword, condenser, forge, expand, boosterBox, grading, jobs), `/pish` (Town Pish comes to you), `/chikin reset | step <1-11>` (Chikin's combat tutorial), `/pishluck` (petting him
  gives luck again now), `/swordpopup` (show the first-sword popup again), `/buttonnames` (the combat buttons' names again for 3 boss fights), `/movefx <rain|vine|orbs|curse> [C|B|A|S] [big]` (a Pet button move at a grade on your summoned creature against a dummy, a 14-stud one with big; the admin panel's "Pet moves" buttons), `/superfx <move> [C|B|A|S]` (a super move's look and the caster's cinematic at a grade on your summoned creature against a dummy, a 14-stud one for Legendary moves; moves: inferno, magmaslam, tidalshield, tidalblessing, stampede, eclipse, riftstep, supernova, thunderstorm, devour; the admin panel's "Super moves" buttons), `/attackfx [C|B|A|S]` (three basic attacks from your summoned creature at a dummy), `/skillfx <sword> [cut1|cut2|cut3|skill] [level]` (your character swings a round 1 sword's cut or skill at a dummy with its effects, sounds, hold and camera moment; sword: sunforged, verdant, prism, forge, or an element name for that Forge Sword; spear, halberd, trident, lance for the spears; the admin panel's "Sword skills" buttons), `/music [place] <n> [volume]` (loop music option n of a place anywhere: no place the town's `Music.TOWN.options`, or meadow, gorge, ridge, warden, brood, colossus from `Music.WILD`, or frostwood, stormpeak, rift, tyrant, sovereign, devourer from `Music.FRONTIER`, or opening (the pack opening's `Music.OPENING`); `/music [place] 0` for the normal tracks).
- Admin panel (Studio only): the "Admin" tile on the left opens every dev command as a button (`Config/AdminPanel`,
  `AdminPanelController`, remote `DevPanel` handled only in Studio), plus +1/+10 of every item and Go/Fight/Group per boss.
- Multiplayer: Test tab → Local Server, 2 players.
- Saving in Studio needs "Enable Studio access to API services", set on Creator Hub → Game details → API services.
- After I confirm a system works: tick it in DESIGN.md, commit, and push.
- Keep the Obsidian vault `C:/Users/Ben/Documents/obsidian/card-shop-tycoon` up to date as we go (Home.md is the
  index): creature roster, decisions log, lessons learned and the topic notes, written for reuse on future projects.
