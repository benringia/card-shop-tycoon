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
  `<bossId>.rbxm` (`prismHydra.rbxm`, built by `tools/blender/build_prismHydra.py`; the prologue's young one-headed
  `prismHydraYoung.rbxm`, Meshy, `rig_prismHydraYoung.py`, docs/creatures.md; the Wild bosses `meadowWarden`,
  `caveBroodQueen`, `emberColossus` from Meshy, rigged by `rig_<boss>.py`, docs/creatures.md "Wild bosses"), same rules.
  The Wild valley's scenery props (glow mushrooms, ruins, ember tree, dragon skeleton) come from
  `tools/blender/build_valley_props.py` (background Blender only; docs/props.md "Valley scenery props"); its giant
  trees and far mountain ranges from `tools/blender/build_valley_backdrop.py` ("Valley backdrop props").
- `assets/npcs` → ReplicatedStorage.NpcModels: Turts, the plaza shopkeeper (`Turts.rbxm`, the owner's dog: Meshy from
  `assets/blender/Turts/concept_A3.png`, `tools/blender/prep_turts.py` (his face kept dense), `rig_turts.py`, Pish's
  `sit` and `celebrate` via `anim_pish.py` with `DOG=Turts`; DESIGN 7.9; Chikin stands in until it's saved); Chikin, the combat tutorial's guide (`Chikin.rbxm`, the owner's other
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
  `Bones`, `CaveDome` and `LavaCliff` come from `build_arena_props.py`. The Dungeon's crystal ruins and puzzle pieces
  (`DungeonPillar`, `DungeonGate`, `CrystalMirror`, `StonePlate`...) come from `build_dungeon_props.py` as one pack FBX
  the owner imports once (`assets/props-import/DungeonProps.rbxm`, split by `lune run tools/props/split_pack`);
  stand-ins until then (docs/props.md "Dungeon props"). The Crystal Abyss's world pieces (`DungeonIslandGate`,
  `DungeonHydraDoor`, `DungeonBridge`, `DungeonChain`, `DungeonSigil`) come from `build_dungeon_world.py` the same way
  (`assets/props-import/DungeonWorld.rbxm`), the Frontier's Dungeon portal from `build_portal_dungeon.py`
  (`assets/props/PortalDungeon.rbxm`), the Hydra's castle from `build_castle.py` (its own pack,
  `assets/props-import/DungeonCastle.rbxm`, split the same way; Terrain walls stand in until then); the cave and the
  islands' rock are Terrain built by `DungeonBuilder`.
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
  `assets/monsters` (docs/creatures.md "Frontier monsters and bosses"). `assets/ui/loading`: the loading
  screens' pictures (the binder, spec `docs/superpowers/specs/2026-11-13-loading-screen-binder-design.md`): Frostwood and
  the Crystal Abyss (`dungeon_abyss.jpg`, Figma) behind the binder, the nine dog cards (`dog_cards/cards`: Pish, Chikin
  and Turts painted with Figma like the card art, sources 680 wide in `dog_cards/art`, prompts in docs/card-art.md, their
  names put on by `tools/ui-art/make_dog_cards.py`), Pish's trot sheet (`pish_walk.png`, `build_pish_walk_sheet.py`, Pish trotting under the step: `TROT`);
  ids in `Config/LoadingScreen`, not synced.
- `assets/place-props`: prop models that contain unions (Rojo live sync drops union shapes). Not synced: inserted
  into the place file's `ReplicatedStorage.PlaceProps` with Insert from File (docs/props.md).
- `assets/town` → Workspace.TownDecor: hand-placed town scenery saved from Studio as `TownDecor.rbxm` (docs/props.md),
  kept out of the 50 x 60 shops and its gaps dressed as garden alleys by `lune run tools/town/fit_town_decor [apply |
  place <before.rbxm>]` (tests/TownDecorFit).
- The shop rooms (spec `docs/superpowers/specs/2026-11-23-shop-rooms-design.md`, DESIGN 4.1 "Shop rooms"): every shop is
  one 50 x 60 building, the hall open, the Back Room and the Gallery behind locked doors (`Config/ShopRooms`,
  `Util/ShopRooms`, `RoomService`, `ShopRoomController`, `PlotService.SetRooms`). Placeholder levels and prices until
  table card battles.
- Storage racks (spec `docs/superpowers/specs/2026-11-24-storage-racks-design.md`, DESIGN 4.2 "Storage racks"): the
  Storage Rack (Config/Shelves kind `"Storage"`, drawn from parts by `Util/StorageRackLook`) holds 9 delivery boxes as
  plain data on the placed rack (PlacementService `stored`, saved on its layout entry, v43), drawn by server
  `Util/BoxLook`; StockService stores and takes them (`StoreBox`, `TakeStoredBox`), client `StorageController` draws the
  stock clipboard and the box hop, restockers haul boxes to and from racks (JobService); rules in `Util/StorageRules`,
  numbers and words in `Config/Storage`.
- `assets/ui/card-art` (one painting per card, `docs/card-art.md`; half-size copies in `assets/ui/card-art-small`, ids for both in `Config/CardArt`), `assets/ui/card-scenes` (one JPEG per element; ids for both in `Config/CardDesign`) and `assets/ui/packs` (pack fronts, ids in
  `Config/Packs`): art made with Figma's image generator, uploaded as images. Not synced by Rojo. The Frontier Booster
  Pack's front (`assets/ui/packs/Frontier.jpg`) is the Stormking painting under an aurora sky,
  `tools/ui-art/make_frontier_pack_art.py`; its textures in `assets/blender/Pack/Frontier`, baked into the pack
  models as `Looks/Frontier` by `lune run tools/packs/add_look` (docs/packs.md "A new set's look").
- `assets/ui/covers`: the binder's set cover paintings (creature-free, Figma-generated, 680 wide; ids in
  `Config/BinderCovers`). Not synced by Rojo.
- `assets/ui/card-back` (the card back: Pish and Chikin's medallion; id in `Config/CardDesign` BACK.IMAGE) and
  `assets/ui/opening` (the pack opening's backdrop: their shop at night; id in `Config/PackOpening` BACKDROP.IMAGE):
  Figma-generated, uploaded as images. Not synced by Rojo. Pish and Chikin are the face of the game (owner 2026-11-10).
- `assets/ui/decor-wallpapers`: the six shop looks' wallpapers (ids in `Config/Decor` LOOKS), Figma-generated, made
  seamless by `tools/textures/make_seamless.py <in> <out> [size]`, uploaded as images. Not synced by Rojo. The decor
  pieces' models: one pack from `tools/blender/build_decor_props.py` (`assets/blender/DecorProps/`), imported once as
  `assets/props-import/DecorProps.rbxm` and split by `lune run tools/props/split_pack` (docs/props.md "Decor props");
  code-built stand-ins (`Util/DecorLooks`) until then.
- The four delivery boxes (Products `boxProp`): one pack from `tools/blender/build_delivery_props.py`
  (`assets/blender/Delivery/`), imported once as `assets/props-import/DeliveryProps.rbxm` and split by
  `lune run tools/props/split_pack` (docs/props.md "Delivery boxes"); `Util/BrandBox` cases until then. The Frontier
  Pack's snow-capped `BoxFrontier` comes from the same script as its own pack (`PROPS=BoxFrontier PACK=DeliveryFrontier`,
  `assets/props-import/DeliveryFrontier.rbxm`), so the first four aren't imported again.
- The seven boss trophies (`assets/props/Trophy<Boss>.rbxm`, slots `Town.SLOTS` Trophy<Boss>): one pack from
  `tools/blender/build_trophies.py` (`assets/blender/Trophies/`), imported once as `assets/props-import/Trophies.rbxm`
  and split by `lune run tools/props/split_pack` (docs/props.md "Trophies"); their Gem and Glow parts lit Neon by
  `Util/TrophyLooks`; the code stand-in (`Util/Props`) until then.
- The packenship.co delivery van (`assets/props/DeliveryVan.rbxm`, client-only, the orderer's alone): a pack of one from
  `tools/blender/build_delivery_van.py` (`assets/blender/DeliveryVan/`), imported once as
  `assets/props-import/DeliveryVan.rbxm` and split by `lune run tools/props/split_pack` (docs/props.md "The delivery
  van"); `Util/DeliveryVan` builds a stand-in from parts until then.
- `assets/ui/game-page`: the Creator Hub game page's icon (`icon_512.png`, concept F: shop, summon, fight) and thumbnails (`thumb_<n>_<name>.png`,
  1920x1080): scenes from Figma's image generator with no text (`thumb_<name>_raw.png`), titles put on by
  `tools/ui-art/make_thumbnail.py` (Fredoka Bold in `tools/ui-art/fonts`, SIL OFL; `--cards` fans real card paintings;
  DESIGN 1 "The game page"). Uploaded on Creator Hub, not synced.
- The register's body (`assets/props/RegisterBody.rbxm` once imported): Meshy from
  `assets/blender/Register/concept_B_shop.png`, cleaned by `tools/blender/build_register.py` (docs/props.md "The
  register's body"); `Util/RegisterBuild` builds the screen, drawer and card machine on it.
- `assets/ui/money`: the register drawer's notes and coins (our own play money: `note_<cents>.png`, `drawer_<cents>.png`
  (the portrait drawer notes), `coin_<cents>.png`),
  drawn by `tools/ui-art/make_money.py` (Fredoka Bold), uploaded as images (ids in `Config/RegisterStation`
  MONEY_IMAGES). Not synced by Rojo.
- `assets/ui/bag`: the shop bag's face (customers carry it out after paying; id in `Config/Customers` BAG), drawn by
  `tools/ui-art/make_shop_bag.py <A|B|C>` from the card back's seal or the Support sticker, uploaded as an image. Not
  synced by Rojo.
- `assets/ui/support`: the Support card's picture (Pish and Chikin holding a golden heart; id in `Config/Support`
  CARD.picture), Figma-generated on flat green and cut out by `tools/ui-art/cutout.py`. Not synced by Rojo.
- `assets/ui/mascot`: the HUD mascot's stickers (Pish, the Pish button) (peek and tail; ids in `Config/HudMascot`), Figma-generated on flat green
  and cut out by `tools/ui-art/cutout.py`; swapping the mascot: `docs/hud-mascot.md`. Not synced by Rojo.
- `assets/ui/product-pictures`: the menus' pack and deck box pictures (Order Stock, Prices; ids in
  `Config/ProductPictures`): the real models rendered big in a ViewportFrame on magenta, captured with the Studio MCP and
  cut out by `tools/ui-art/cut_product_picture.py <capture> <out.png> [box]`, uploaded as images. Not synced by Rojo. The
  sleeve packets and the sealed booster box (their looks are SurfaceGuis, which a ViewportFrame can't draw) are shot in
  Play in front of a plain magenta part and cut with `--lit` (ids in `ProductPictures.PRODUCTS`).
- `assets/ui/icons`: UI icon PNGs (ids in `Config/UIIcons`), cut from Figma-generated sheets by
  `tools/ui-icons/slice_icons.py <sheet> <1-10>` (needs Pillow); white glyph sheets (5, 6, 8, 9) then
  `tools/ui-icons/clean_glyphs.py <Name>[:open] ...` (rebuilds the outline the magenta keying eats); the recipes' gold
  arrow (`ArrowGold`) drawn by `tools/ui-icons/make_arrow.py`. Not synced by Rojo.
- `assets/ui/grade`: the grade you notice (DESIGN "The grade you notice"): the four grade medals, the A and S cards' glow
  and the S sparkle, drawn by `tools/ui-art/make_grade_look.py` (Fredoka Bold), uploaded as images (ids in
  `Config/GradeLook` IMAGES). Not synced by Rojo.
- `assets/packs` → ReplicatedStorage.PackModels: the boss chest (`Chest.rbxm`: Body and Lid, built by
  Meshy from pick A, cleaned and cut into Body and Lid by `tools/blender/build_chestA.py` (sources in `assets/blender/ChestA/`), docs/packs.md "The boss chest"; the older code-built `build_chest.py`; a parts stand-in until it's there) and the pack, deck box and display box (`Pack.rbxm`, `DeckBox.rbxm`,
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
  `assets/ui/posters`: the five funny shop window posters (`poster_<id>.png`, ids in `Config/Windows` poster styles: decor placed like a window on inside walls or the front's outer glass panes, WindowRules): scenes from
  Figma's image generator with no text (`art/<id>.png`), their jokes put on by `tools/ui-art/make_posters.py`;
  uploaded as images, not synced (DESIGN 7.18).
  `assets/ui/fx-town`: the town's falling leaf (white, tinted in game), made by `tools/textures/make_leaf.py`,
  uploaded as an image (id in `Config/TownDress` LEAVES.texture), not synced.
  `assets/ui/fx-luck`: the lucky aura's white four-leaf clover (bought luck, Config/Luck AURA), made by
  `tools/textures/make_luck_clover.py`, uploaded as an image, not synced.
  `assets/ui/fx-case`: the glass cases' floor glow (white, brightest at the pedestal's foot), made by
  `tools/textures/make_case_glow.py`, uploaded as an image (id in `Town.CASE_LOOK` FLOOR_GLOW), not synced.
  `assets/ui/fx-portal`: the Wild loading screen's spiral (white), made by `tools/textures/make_portal_swirl.py`,
  uploaded as an image (id in `Config/WildLoading` SWIRL), not synced.
  `assets/ui/fx-super`: the super moves' white textures (firestrip, crack, waterstrip), made by
  `tools/textures/make_super_fx.py`, uploaded as images (ids in `Config/SuperFx` TEXTURES), not synced.
  `assets/ui/fx-sword`: the sword effects' white textures (crescent, burst flipbook, line, star), made by
  `tools/textures/make_sword_fx.py`, uploaded as images (ids in `Config/SwordFx` TEXTURES), not synced. Particle
  textures must be square; a beam runs a texture's height along its length (the bolt is upright).
- Files use `.luau`. `init.server.luau` / `init.client.luau` are entry points and set service start order.
- Tools via Rokit (`rokit.toml`): rojo, wally. Published (private) as "One More Pack" (once "Cardshop Simulator") on GitHub `benringia/card-shop-tycoon`.

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
  4-star shop's customer flow by default (`NO_KIDS=1` without the offers, `RATING=3` at today's flow; `LEVEL=<n>` the shop level for the customers, default past a new shop's boost; `ROOMS=<0-2>` the shop rooms open: the flow then capped by the 4 + ROOMS customers that fit inside at `VISIT=<seconds>` a visit, default 59, measured)
- `lune run tools/balance/bosses [fights] [players] [boss]` — boss balance: win rates per boss for parties at 0.8x / 1x /
  1.3x the recommended Power, a typical party (best card at it, two at 60%) and one maxed Legendary with two Lv 1 cards,
  each for a player who stands still and one who fights well with the sword (targets: well 85% at 1x / 50% at 0.8x,
  still 60% / 15%); with players > 1 every row is a group of that many players against the scaled boss. Every creature
  fights with its fight perk; `NO_PERKS=1` in front runs without them, to compare (`NO_DEBUFFS=1`: without the
  bosses' ring debuffs). Epic and Legendary cards fire their supers when ready (`NO_SUPERS=1`: without,
  `ONLY_SUPER="<card>"`: that one alone); supers need a weapon of their creature's element: `WEAPON=match:<level>:<grade>` gives each player the Forge Sword of their leader's element, `FREE_SUPERS=1` the old rule (every super, no weapon); `SET="Voidmaw.healCap=0.05"` / `BOSS_SET="prismHydra.atk=40"` try numbers
  without editing the configs (`BOSS_SET` paths reach inside: `frostTyrant.mechanics.shield.fraction=0.04`);
  `MUTATION="<id>:<rarity>"` gives every player that weapon mutation, `MUTATION_SIZE=<share>` another size for it;
  `PARTY_RARITY=<rarity>` builds the parties from that rarity only (the closest Power can be a maxed Common)
- `python tools/video/make_trailer.py <recording.mp4> <out.mp4> [--mute]` — the game page's 30 s gameplay video cut
  from one recording (its CLIPS list: start, end, caption; needs Pillow and imageio-ffmpeg; Roblox's video rules in its
  header)
- `python tools/video/make_short.py <recordings folder> <out folder> [--clip loop|story] [--voice <kokoro folder>]
  [--speaker <voice>] [--reuse-video]` — vertical clips for TikTok, Shorts and Reels (CLIPS: `loop`, ~21 s full screen,
  a 608 x 1080 slice of each shot zoomed to 1080 x 1920; `story`, ~26 s, a square over a blurred copy of the frame;
  each with words, the PLAY FREE badge and the end card), with the game's sound and silent; `--voice` adds an AI
  voice-over said offline by Kokoro (kokoro-onnx; model files in `Documents/clipping/tts/kokoro`; each shot's `say`
  line, in the clip's own voice), over the ducked game sound and alone; `--reuse-video` redoes only the sound (spec
  `docs/superpowers/specs/2026-11-27-short-clip-design.md`)
- `lune run tools/audio/sound_ids` — every super / Pet move / attack sound id; measure new ones in Studio with
  `tools/audio/measure_loudness.luau` into `Config/SoundLevels` (skill sounds louder than its TARGET are turned down,
  `Util/SoundLevel`; `tests/SoundLevel` fails for an unmeasured skill sound)
- `lune run tools/balance/wild [fights] [wild|frontier|both]` — wild monster balance: win rate and fight length per
  species at its zone's lowest, middle and highest level, normal and elite, against the card nearest the zone boss's
  recommended Power, three ways: no sword yet, standing still, fighting well (targets: normal about 12.5 s, well ~90%,
  still ~75%, the Meadow ~75% with no sword; elite 25-35 s, well ~65%)
- `lune run tests/run` — unit tests for pure modules (BeastMath (and a starred or levelled card never worth more than the cards inside it; a grade's big part of a card's price by rarity, added once, and grading never paying for itself), Migrations (and v40: saved shop XP moved onto the harder curve past Lv 20 at the same level; v41: boss kills starting at the bosses a save has cleared; v45: a Forge roll's mark on a waiting mutation), PriceTaps: a tapped price showing until the server's comes back, CaseWindow: the card cases' window (a price as money, the grade across a card, how it sells in two words, the bar's lines, the slots' size), StockHint: the shelves that glow while you carry a box (the same product with room, else the empty ones that take it), SaleRules, CheckoutLayout: the movable register's box (the counter, its step behind and the queue in front; the ghost's pieces; the hall only), CondenseRules (and the Condenser's and Grading Station's picture recipes: their one sentence, spots, row tags and two-line buttons; a star or a grade-up never using a copy better than the card; the copies sorted best grade first and the copy picker's words; a finished star or grade waiting to be shown; the put-a-card-in windows: their tabs and words, "Filled in for you", a few copies in one wide row, the Grading Station's USE tiles and "Upgrade $2,500" the only place its cost shows, the grade swap gone), JobRules, LevelMath (and an opened pack's shop XP: 3, 2 from shop Lv 30), PartyRules (and the first pal from Pish's present; a perk's effect as a sentence for the Party window's perk box; a resting creature's refused summon in words),
  CreatureMotion, CombatMath, BattleSim (and Chikin's tutorial fights' guarded creatures; a weapon's mutation in a fight: Sharp, Critical, Element Edge, Boss Hunter, Guard, Thorns, Second Wind, Lifesteal (a share of the player's own HP a landed sword hit), Quick Step, Ultimate Charge, and none drawing the same fight as before; the mutation audit: Tough, Pet Boost and Rally following the weapon in hand and leaving with their player, a Thorns reflect through shields and only what landed, the Dungeon's HP carried as the creature's own), SwordsConfig, SwordRules (and a longer hit-stop never cut short by a shorter one's release; the prologue's quicker swings, `quicken`), SwordSkillFx: the round 1 swords' looks, beats and shakes and the skill camera's side and zoom-out past the boss, ScreenSlashRules: Thousand Cuts' slashes across your screen, SwordArcRules, SwingGate, RingRules, HpBarRules, CombatPreload, LoadingRules: the loading screens' steps, pockets filled, each place's look (the binder), Pish's trot and the step's counting dots, AttackTiming, FightMotion, FightFxRules (and a boss's normal hit: what each strike throws, when it leaves, how it lands; creatures' basic attacks toned down in boss fights, their size and flair by rarity and grade; thrown attacks' own trail and landing, never the bolt's), MonsterMoves, BossStatusRules: a boss's states under its bar (order, chip numbers, tooltips), ElementNames: the plain element names (and no raw element key in player text), DefenseRules / DangerRules: Defense from party Power and the Wild's dangerous places (contact, knockouts), TitleRules: earned / shown / equippable titles (and Creator: the game's owner's, hidden from everyone else's list), how far a locked one is, new ones and kept ones, your own tag hidden in your own fight, CharacterStats: the character window's Power, Attack, Defense and progress tiles, ElementWheel: its element wheel's arrows and names, SoundVary: attack sounds never the same clip or pitch twice in a row, RegisterBell: when the register's bell rings, CameraLimits: how far the camera zooms out (and a phone's fight camera: out into open space, a wild fight looking down), ShakeRules, DamagePop (and a Thorns reflect's green THORNS number with subtle thorns, fewer and smaller than a Bloom hit's; a boss's hit on a creature, big in its colour; a strong hit you land popping like a crit over a gold burst whose rays fan round the middle, one your side takes and a Dungeon pylon's hit keeping the old pop), MatchupRules: the fight's matchup chip (weak red, strong green, none when even, Electric and Dark strong both ways, its "1.5x" tag), VictoryRules, MarkerNames, BoughtLuck: luck bought with Robux (strongest first, its time, the guide's odds), UnlockRules: one-time unlocks sold as developer products (the Extra Job Slot), PaidRandomRules: luck and Turts' paid re-roll not sold where chance-based purchases are restricted, PrologueRules: the prologue's pacing (its HP between the 35 s and 60 s curves), each player's lair, the lent maxed cards and the Hydra's leash on the lair's floor, act 3's knock-back (on the floor), crawl and stolen cards, and your eyelids opening in town, CreatureTag: a summoned creature's name tag (stars over the name, element, level, grade; the owner only on others'), DebuffRules, SwapKeys (and a fight's 1 and 3: the creatures left and right of the one fighting, the strip in carousel order), SummonMotion (and the card's summon: its beats, the creature a speck until the burst, the arc, the size by rarity, the unsummon's card), DefeatRules, PetVoice, MusicRules, XpPill, SparkPath, HudMascotRules, ContrastRules, StationLook: the put-a-card-in windows' and the Bulk Bin window's words reading on their colours, their bands, finger-sized taps, the gold arrow icon's sizes and room and the copy tiles, GradeLook: the grade you notice (the medal bigger the better the grade, inside the card's top-right corner, the name and the Level chip clear of it; only A and S glowing, S brighter, breathing and twinkling; the glow and ring as shares of the card; the pull's "GRADE S!" words reading on its pill; a drop's "Voidmaw · Grade A!" tag), SoftColors, ScreenEdges: covers over the whole screen past a phone's safe area and the spotlight's four dims, AvatarRules: a weapon worn on the back taken off (wings, capes stay), SquishRules, PvpRules, Frontier, Dungeon, WildPopulation, DungeonRules, ItemRules: items (and Mutation Essence's own icon, and their words a child understands, the Bag's XP Tonic picker's party cards, trophies placed from the Bag, the First Spark pack's real picture, how many Open 10 opens, Bag packs and deck boxes back to the shop a box at a time, never a gift), ListingHold: a new card in a case waits for its price until Done, its window closed, the owner walking away or the hold running out, TownLayout, TownPreload: the town's pictures before you walk in, PropFit (and every product lying on the register's counter as itself, a sealed booster box's words), HudGrow: HUD pieces growing on a desktop's bigger screens (never on touch), CardViewRules: the binder's card view (what shows first, what waits behind More, its plain words and matchup chips), SoftFilter: the soft colour filter over every sky look, CueShape: the tutorial ring's and spotlight hole's shape from the button, the ping ring, bigger paws, the paw beside a left-column tile, ShelfStock (and every booster box stocked showing as one more box on the shelf, side by side and stacked on a wide shelf so a full one shows all it holds), PhoneNotice: the Phone tile's red count of what waits in its apps and its ping or nudge when something inside changes (quiet through a tour), EarlyRules: a new shop's short waits (an order's delivery, a fainted creature's rest, the stations' timers), BrokeRules: a shop can always restock (the cash kept for a rack and a box, orders and other spends and opening your own last packs refused when they would eat it, the last rack kept, Pish's help for a stuck shop and that it can't be farmed), SpringRules: what the healing spring says when asked (nobody hurt, one, several, the time beside it), QuestRemind: the idle quest reminder (only after standing idle, minutes apart, what it says first), DesktopHud: a computer's HUD (which layout is in use: C, the cash on top of the right column; A's top row and bottom bar, its narrow-window fallback), DevGate: dev commands only through DevAccess (chat commands and DevCommand in Studio only, the panel's remote checked before it runs anything, every service's dev function asking DevAccess, the Admin mark the owner's alone, AnalyticsGate before every analytics call, /slot the owner's alone), DevRules: who may run a dev command in the published game (the owner's test save only; "server" commands alone or in their own private server; "studio" ones never; the scope table names real commands), CreatorAura: the Creator aura's orbit (three cards a third of a lap apart, a lap in LAP seconds), PadRules: the delivery pad's stacks (one product a stack, only the top box picked up, its prompt's words), EditBarRules: the Edit bar on what you placed (its own use first, the Recycler's "Use", Move, Sell held down and locked until empty, a resting tile's reason, short plain words), DeliveryRules: the packenship.co van (its stop past the curb, where it is by the server's clock: slowing in, standing, speeding away, never jumping; the street's ends and its fade; a quick trip still on time), the boxes' hop times and arcs, a stocked box's units as a few hopping packs, the waiting chip's words, ShelfStock, ShelfLayout, PetRig, KeyframeTiming (and a clip let go fading out), BeastFxRules: the creatures' pack auras, their tiers and the budget (others' in your boss fight, low graphics), RigGuess, CellSearch (and a new shelf's start: the nearest free cell within reach), ShelvesConfig, ShopTips: what each Shop window item holds and does (its tooltip), RecycleRules: the Recycler (each rarity's material, fair costs held to about a tenth of the cards' worth, what a card keeps for its stars and grades, a creature keeping the copies it can use, never more than the confirmed list, the extras, a pile's whole materials, coins instead with a pack's cards never paying half the pack back, every conversion's time, the window's words), BulkRules: the Bulk Bin's extras (2 kept of each, never foils, A or S), whole handfuls of 5, the plainest first, who asks for a handful, its window: a card kept out giving none, the tiles most first, the keep-out list read from the client (anything but a short list of ids refused), the footer and button words, RevealRules: the heavy pack's tell, which pulls come alive, the Frontier show only outside a Frontier Pack, which tear the sky (a Legendary, Open 1 and Open 10) and Open 10's best pulls (Very Rare and up), ElementFxRules, BinderSpreads, OddsRules, NewPulls, PityRules, BossRules (a beaten Frontier or Dungeon boss a teleport away and where it lands; Take me there to a gate only once beaten, a walk before; a key's fragments catching up at the next boss's level: every loot win, two at a time; loot every 7 minutes a boss, no daily limit; the Robux reset of every boss timer; the loot timers that ran out told in one message, only ones you started; cash in full with loot and 25% between; the board's Power as the party's average; boss cash doubled with the shop XP unchanged; Gold Seals a rare drop; the Frontier's three bosses dropping Frontier cards), ShopTileRules: the Shop window's row tiles on phones and a tile's NEW tag, three tiles to a row on a computer, a tile's chips, its coin on prices and "You have N", CreatureCull, AdminPanel, UiLayout (and the Forge's Mutate tab on a phone: the slim mutation row in the pill's place), CompareRules, LevelRemap, LevelUpRules: level-up packs and the shop bar's next unlock line, BinderCovers, OrderRules: the order computer's store (money words, each card's lines and Add button, the cart and Order now, the pad's room, the shelves tag and "Customers want this!", the pallet deal (6+ boxes of a product 10% off, its meter words, the deal's price and profit, the savings), a client's cart read on the server, the trip time; the tablet's fit above the bottom tiles), VarietyRules: shop variety ("Found it all!": a plain customer with 2+ products all found pays 10% to the cent, its toast, a missed product's word), FrontierPack: the Frontier Booster Pack (only Frontier rarities, about one Epic in two packs and a Legendary in twenty, priced like a First Spark pack, locked on the tablet until the Frost Tyrant is beaten, its Bag item), PetRewardRules: petting Pish or Chikin (the pop-up's words, "Lucky again in m:ss!"), LevelUpFxConfig: the level-up pillar's numbers and the creature's level chip, PageCurl, BinderFit, BinderGesture, ShowcaseLayout, OpeningFlow, OpeningLayout (and Open 10's grid fitting every row), PackFxConfig, HoverRules, ProductPictureRules (and every ordered product's picture, on its menu row and its delivery box), ShopDetail: every shop screen sets a draw distance, PortalTrails,
  TownTerrain, DayCycle, FrameWatchdog, Wander, PlazaLayout (and the Support corner: the dog house, beds and jar, the dogs' homes, an open ring round the gazebo; the leaderboard's four cards, a pair for each ranking with a wider gap between the pairs and a plaque under each, the emptiest list at the end the signpost hides from the spawn), PortalLooks, LavaCracks, ModelPreload, CardArt, WildValley, MonsterLooks, BossMoments, MoveFx: the Pet button moves' looks by grade (and a Grade S rain's look on its player) and MoveFxRules, SkillText: a card's skills in words and the sword skill buttons (and no string in `src` calling a creature's ultimate a super: players say Ultimate since 2026-11-26), WildLoadingRules: the Wild's loading screen, SuperFx: the super moves' looks by grade, beats and camera, SoundLevel: skill sounds brought to one level, DeckBox: a Deck Box is worth three packs to open (always a Very Rare or better, its Epic and Legendary chances at least three packs'), CustomerTypes (and the buy chance sliding inside a price band: no free steps, the Prices window's "33% buy"; a new shop's boost: 3 or 4 things, kids 2 or 3, 1.4x the customers, fewer over market, fading by shop level 15), CoinSoundRules: the coin sound on every cash rise, ShelfSearch: where a customer looks when their list isn't on the shelves (an empty shop's racks, not the middle), CustomerLook: grown-up customers (Roblox's Man and
  Woman bodies, catalog hair and outfits per type; kids blocky), PaymentRules: the register's payment step (card or cash
  by type, the bill handed over, the card machine's keys, the change counted), RegisterStationRules: manning the register in
  first person (what its screen shows, the drawer's slots, money given on the counter as real notes and coins, the card machine awake only for a card payment, a tapped piece's flight, climbing pitch and place in the row; looking around: a drag's turn and limits, a finger's tap vs drag), CollectorRules, OfferRules (and the owner's toast for a kid's big pull), HaggleRules, ReturnRules: stock a customer took that fits on no shelf is refunded (and the toast and shelf tag for what went back), ChatRules: what customers say in their speech bubbles (each type's lines for each moment, how often, the Say attribute), OfferWords: the register's offer panel in plain words (a bargain hunter's and a kid's), ReactionRules, RatingRules (Stocked half products in stock, its tip naming what's missing; foundAll good, partial bad), WalkerRules: the customers round, StageRules: the binder, card view and pack opening stages right above the player, WalkStep: NPCs following a path smoothly, TiredRules: shop workers' tired spells, CreatureFlight: which creatures fly, ToastRules: toasts as speech bubbles over the cash (a row along the top when Pish is on the quest strip; plain bubbles with no tail when he's off the HUD; under the foe's bar in a fight), MutationRules: weapon mutations (the roll's rarity and kind, words a child reads, each one's fight stats, Treasure, Scholar and Pet Boost at half, the Essence for the one you don't keep (none for a Forge roll's: Essence only from drops), a saved one read back, the Forge's Mutate check, Treasure and Scholar weighted by each weapon's time in hand, a boss's intro never counted), WeaponsConfig, WeaponRules (your first Forge weapon's special price; boss weapons almost every loot win, the material every win by rarity, a drop you have giving nothing by itself (its mutation roll) unless its grade is better: then yours takes it, level and mutation kept, its NEW GRADE reveal first (WeaponText.gradeUp, WeaponLookRules.dropSteps), a mutation kept through a reforge and a load; and supers: locked without a weapon of the creature's element, no exceptions since weapons round 4 (the Prism Blade bonds with nobody and unlocks none; its shown Power counts its always-strong hit), a stronger weapon a stronger super), WeaponText (and the Forge's picture recipe: its one sentence, its spots, its two-line button; the mutation choice's CURRENT and NEW! cards with "You get" on the button that gives Essence, none for a Forge roll; the Forge's current mutation row and list chips; round 4's Attack, the multiplier x 100 rounded, never truncated; the weapon window's layout A rows; every skill's short line; the Prism Blade's gold tip line), WeaponLookRules: weapons round 1 (and a mutated weapon's card: its glowing edge and badge, none on a tiny card), WeaponSwitch: the quick weapon switch's order, steps and the medallion dial's track, roll and spots, TutorialRules / LuckRules / LessonRules: Pish's tutorial steps (inside the shop or out, for his rack step's "Let's go inside!"; the tour's box arriving at once, summoning your first pal and the calm HUD until then, no To Bag on its stock step and its tip after it), his luck (and how much of a timed buff is left), the gift's floor and the luck badge's timer, his lesson visits (one for every town and shop unlock; a thing added after launch, the Recycler, brought to saves already past its level; jobs the moment they unlock: first in line, no breather, 45 s for an introduction) and the stuck helper (never to order what you can't pay for, quiet after Got it) and his pacing (never while you're busy: the register, boxes, placing, a window, a fight or a popup; a breather between visits; stepping back, then leaving with the lesson kept), PishPath: a town dog's walk round the fountain and the plaza's other solid things, and its next stop (Town Chikin's), TalkRules: which of Pish's lines shows, that every line is short and drawable, his talk card's place (the first spot, top then bottom, that leaves what he points at and his paw clear, Skip's tap area counted; the phone's Bag lines through the Phone; "Let's go inside!" and the rack's "Tap Place!"), its size on a computer, a new line's gold flash, a plain Next pressing itself after time to read and a request the server didn't answer sent again, OpeningSounds: the rip's volume and the lineup's sounds never the boss victory's, RevealSounds: each rarity's riser and layered hit (the riser peaking on the landing, measured loudness climbing with rarity), PishWalk: his walk's tempo, ArrivalShot: his arrival's camera and its magic (the circle calling him, the poof, his name card) and his run kept on the ground, ChikinRules: Chikin's combat tutorial steps, lines and focus mode (the HUD pieces each step keeps; the fights where creatures can't faint; his goodbye: hunt to shop level 4 or tap the town button, faster; Got it! on his level 4 visit and the quest strip kept there), FrontierValley: the Frontier valley's layout, budget, props, arenas and models, FrontierFxRules: its fog eyes, lightning and tremors, IceFxRules: the Frost Tyrant's falling spikes, shield shards and shatter, StormFxRules: the Storm Sovereign's thunderclap (its bolts, circle and crackles), SummonRules: the Rift Devourer's summons (their corners, run and rising out of the rift), FootstepRules: footsteps by floor material, GreetRules: whom Town Chikin greets and his line, ChestRules: the boss chests' contents (the material every loot win, the weapon's chest too), pick and timeout, ChestMotion: their drop, rattle and tension shake, SoundscapeRules: the worlds' spot sounds, night share and gusts, BeamRules / PlateRules / LockRules: the Dungeon's prism beams, weight plates and element lock, ObjectiveRules / AmbienceRules: the Dungeon's objective line and its roars, glimpses and heartbeat, AbyssLayout: the Crystal Abyss's winding way (stops, regions, spires, the castle, the lair), bridges, gates, ruined walls, far scenery and the fall, SkyDressing: the town's aurora, WelcomePath: the welcome flight's path, place cards, cues and lens, ItemPopupRules: picked-up items' cards, UpgradeRules / ReceiptRules / KnockoutRules: the stations' timed jobs (waits,
  Finish now tiers, saved jobs), receipts granted once and the knockout countdown with its pause, MonsterKOMotion: a beaten monster's knockout flight (launched away from the winner, bounces, wall bumps, resting on its back, the same at any frame rate, over before the server lets it go), CardLootRules: a dropped card on the ground (picked up once seen, comes to you, fades when you're gone; its landing), ReviewRules: the phone's Reviews (a visit's post, the feed, unseen; no count on the app; a missed product named in a partial or noStock post), CompactHud: the phone's slim HUD (the Phone lying on its side on a short screen so its app tiles stay finger-sized, cash words, where each HUD button sits, when the Phone shows, the weapon chip's count, a timed buff's ring, the quest strip under the top-right column and clear of the jump button, what a phone shows: only the important stuff, the rest where and when it matters), PairRules: the phone's creature and weapon pair (hidden in a fight, a swipe's step, the next party creature, its count, its spot over the jump button, the hold column's rows), PartyDock: the party dock's carousel and XP words (and a keyboard's keys: 1 and 3 turn it, E calls the middle one, three key caps that stay still round it), TurtsRules: Turts' restock clock, roll, buy check, saved state, spots and price rule, one of each thing sold (and his chip under the quest strip), DecorRules: shop decor (a look bought and used, a save cleaned, the decor score, the piece cap, shelves standing off the walls clear of the look's pieces), BadgeRules: the shop's Empty badges (the nearest few, none overlapping), CaseSwirl: the glass cases' spiral lights, WindowRules: shop windows (where one fits on the shop's wall stretches, buying, the cap, achievements, a saved list cleaned: a piece that no longer fits moved to the nearest free spot before it's paid back, a wall cut round holes), ShopLod: other players' shop screens drawn from closer (a visitor in a hall's middle still reads every tag), a far shop's shelf stock hidden and shown again near with no flicker, StorageRules: storage racks (a stored box next to its own kind, a half-used box taken first, the rack's attribute round-tripped, a saved rack cleaned with extras returned never lost, the stock clipboard's lines, tallies and unit words, its away-selling stamp, the prompt's Store / Rack full / Open words, the "counted by" line, a restocker's rack-to-low-shelf pick and nearest rack with room, each spot on its deck; with JobRules' worker walk 8 to 14 under the player's 16, EditBarRules' rack bar, ShopTips' rack tooltip, StockHint's racks with room, ShelvesConfig's rack numbers), ShopRooms: the shop rooms (the hall and its two rooms in cells, the doors (two leaves sliding apart into the wall, the wooden frame, the name plate over it), inner walls and wall faces, window stretches, the customer and shelf caps, the unlock checks and words, Pish's room lessons), TownDecorFit: no hand-placed town decor in a shop and no tree the game would take away, BinderPoseRules: reading your binder in the world (the pose's ease and angles, refused mid-fight, page turns), LeaderboardRules: the plaza leaderboard's lists (packs opened and boss kills both up at once, each with its plaque words and icon; all time merged with live totals, this server; the game's owner on neither), store writes and counts, ScreenClearRules: cinematics wait for a clear screen (no purchase dialog or Roblox menu), SupportRules: "Support the dev" (gifts, the best
  tier, when Pish asks, the dogs' thank-you's beats and when only its glow plays; GreetRules: the town dogs'
  thank-yous to supporters), BossIdleRules: a boss walking, roaring and stomping between its moves (and turning to what it goes for), HitFeel: a monster's reaction to a hit (a jolt away from the hitter, a lean, a pop, its clip frozen; big hits further, a boss's share) and a wild monster's calm steps, lunge into a strike and 3-stud drift cap, FinishingBlowRules: the finishing blow (only your running fight's monster; its felt numbers, beats not stalls; a knockout's beat, launch and kick with it, an elite's extra on top; the knockout still over 0.1 s before the server lets the monster go; your animations held only while moving and never put back to a stop), FxToneRules: effects toned to the scene's brightness, GiftRules: the daily, weekly and monthly gifts (UTC days, Monday weeks, months, play time, the 7-day round, the chests earned and kept, the gifts in words), MainQuestRules: main quests (the Build menu items open at the shop's level and never built, a quest staying done after its item is sold, the one shown, its cash bar, the next unlock's level once all is built, a first build's shop XP once, the saved list), QuestRules: the daily quests (one per kind for the shop's level, counting play, claims and the Quest Chest, a saved state cleaned, what the strip animates between two states; the window's rows: count, pay chips, what a row offers, a goal of one in plain words) and the weekly ones (goals a week long, the Weekly Chest, Monday weeks, which part the strip shows; the band's pieces, a phone's chip by the cash), OfflineRules: welcome-back earnings (time away counted, the shelves' stock sold at their prices and buy chances; with a Restocker the racks' boxes refill them and each rack of boxes adds 30 min to 4 h, half-used boxes first), Funnel: the new player's onboarding funnel (the prologue, Pish's steps in order, levels), TeamRules: teams in the same world (growing to 4, the lead passing on, who may invite whom, the hunting bonus from teammates nearby), SoftLockRules: the fight soft lock (Tab cycling nearest first, a tap landing on an enemy, a tap vs a drag, letting go, the fight locking the nearest itself), SaveSlots: the owner's test save (keys, the stored choice, test/main/reset, owner only; Studio's fresh switch never outside Studio), TrailRules: the guides' paw trails spaced along the walking route, EventRules: the weekly events (Boss Rush on Saturday, Lucky Sunday; the weekday, the chip's words and that it shows only on the day and the hour before, the toast, the free luck once a day), CodeRules: the Store's codes (what's typed, once a player, ended ones, a small gift, a redeemed code's win moment), TownDressRules: the town's dressing (an event day's banners on the lamp posts, no string lights, leaves and shooting stars)) plus the model script gate (CreatureAssets), SourceOrder (no local function or file-level local used above its definition, no module used without a require, no call to a function its file never defines, no method call or field read on a name its file never declares) and RequireCycles (no server, client or shared module requiring itself back at load: the server wouldn't boot). Pure logic goes in Roblox-free modules so it can be tested here. Lune can't build Vector3 or Color3, so numbers a test reads live in plain-data configs (`CaseLayout`, `PackOpeningLayout`, `CardReveal`, `PackFx`), and pure modules don't require siblings (no `script` in Lune).
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
- Covers (letterbox bars, fades, dims, flashes) reach the screen's very edges (owner 2026-11-18): `IgnoreGuiInset` guis
  clip to a phone's safe area (62 px bands beside the notch). A gui of covers only sets `ScreenInsets = None`; in a gui
  with words and buttons, put covers in `Util/ScreenCover.layer(gui, zIndex)` and keep words and buttons where they are.
- Fonts: FredokaOne (titles, buttons) and Montserrat Bold (body; Nunito before 2026-11-03), applied by `Util/FontStyle` (code may keep naming Gotham). Fredoka does not load in Play.
- Text: plain ASCII plus `·` and emoji only. Gotham/FredokaOne draw symbols like ✦ − ★ as empty boxes.
- Never fail silently (owner 2026-11-12, every project): a requirement refusal goes through server `Util/Blocked`
  (a big locked card, client `BlockedController`), never a bare `return` or only a toast; a prompt that needs a shop
  level carries a `RequireLevel` attribute (it shows the lock and the level before you press). Town-only HUD (the
  Phone, once the Manage tray) shows only in town (`Util/Hud`).
- HUD buttons go through `Util/Hud` (the Phone on the left: `Hud.fanButton` adds an app, `Hud.phonePage` a page inside
  it; tiles at the bottom centre, context tiles for
  Drop/Rip), clear of the mobile thumbstick and jump button. Look and motion: `Util/UIKit`, `Util/Motion`.
- A computer's HUD (owner 2026-11-21; `Config/DesktopHud`, `Util/DesktopHud`, drawn by UIController): top left under
  Roblox's buttons the gift then the Phone; top right your face (the coin's size) beside the cash (level with Roblox's
  pills) with your buffs, shop level and XP bar under them, then the team strip and the Turts and event pills when they have something to say;
  bottom left your creatures (keys 1, E, 3 fixed round them); bottom centre the tiles; bottom right the weapon dial
  with plain toasts over it. No Pish, no rating chip, no quest strip: the quests are the Phone's first app, and the
  Phone's tile shows a red count of what waits in its apps and pings when that rises (`Util/PhoneNotice`,
  `Hud.setBadge`, `Hud.notice`). A new desktop HUD piece joins the corner its kind already lives in; a thing inside a
  Phone app reports what waits with `Hud.setBadge`; phones keep `CompactHud`; the fight HUD is its own. Anything
  drawn at the top right starts under the cash and level rows: ask `UIController.GetColumnStart(default)` and listen
  to `UIController.OnPlaced` (the Dungeon's objective, the team strip, pick-up cards do). The older
  arrangements stay behind config switches (LAYOUT "bar", QUESTS "strip", PISH true).
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
- 3D generations (Meshy or any other platform) and their concept pictures are fully neutral (owner 2026-11-16: "models
  should not have poses. neutral everything"): body straight, quadrupeds square on four straight legs, bipeds in a
  T-pose, the head in line with the body and level (never turned, tilted or looking at the viewer), mouth closed,
  perfectly symmetrical. Check front and top renders before rigging; a turned model is generated again, not patched in
  code (docs/creatures.md "Neutral everything").
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
  `ServerStorage.DevCommand:Invoke(player, "/boss 1")`): `/cash <n>`, `/setxp` and `/level` use today's curve (levels past 20 cost up to 3x: Config/Levels LATE), `/broke [cash]` (your shelves and boxes emptied and your cash set, default $8: Pish's help for a stuck shop comes within 10 s; `/broke 60`: spends and opening your last packs refused; Config/Broke), `/xp <n>`, `/level <n>`, `/setxp <n>` (XP total, down too), `/levelfx [level]` (the level-up pillar; 10, 20... the rainbow one), `/beastlevelfx` (on your summoned creature), `/levelsound <1-4> [volume]` (a level-up sound set, played once; 0: the default), `/victorysound <1-3>` (a boss win's sting, played once and on your next wins; 0: the default), `/testpack` (foil legendary),
  `/beastxp <n>`, `/givecard <number> <amount>` (plain copies for testing the Condenser), `/bulk [cards]` (a free Bulk Bin in your shop and that many plain Commons to put in it), `/room <2-4>` (Dungeon window), `/winroom` (Dungeon window: the room the run is at, won; the next puzzle then waits for the group), `/puzzle solve` (Dungeon window: the puzzle the run is at, solved with its chest), `/puzzle <beams|plates|lock>` (to
  that puzzle with every step before it done), `/tap <piece>` (what pressing that piece's prompt does, every check
  included: Mirror1, Plate2, SecretWall, LockCrystal_Tide, Chest_beams, RoomGate3; the Studio MCP can't fire prompts),
  `/dungeonfx <intro|introshort|roar|glimpse>` (Dungeon window: the Hydra's welcome, full or short, a distant roar, its
  eyes glimpsed),
  `/jobslot` (toggle the Extra Job Slot pass in Studio), `/coinsound <1-3>` (a coin sound option played once and on every earning; 0: the default), `/mainquest reset` (every main quest's first build pays its shop XP again: sell one and place it), `/quests done | new | week | newweek` (every daily quest done, ready to claim; a new day's quests; every weekly quest done, the Weekly Chest ready; a new week's), `/away <minutes>` (welcome-back earnings as if away that long: the shelves' stock really sells), `/luck <x2|x3> [minutes]` / `/luck clear` (luck as if bought from the Store), `/jobtired` (every shop worker tired now, or rested again), `/wild` (go to the wild map), `/rest` (wake resting
  cards), `/tire` (rest every party card but the summoned one, to lose a boss fight), `/bosshp <1-100>` (your boss fight's boss down to that % of its HP: its summons, phases and heals), `/elite` (an elite monster next to you), `/ko [elite]` (the nearest monster not in a fight, or elite, knocked flying away from you: Config/MonsterKO), `/carddrop` (your next monster win drops a card: its loot beam, Config/CardLoot), `/bosscard` (your next boss loot win drops a Frontier card: the gold tile, the reveal, then the chests; any boss), `/bossbeaten <1-7> on|off` (boss n beaten and opened, to see its Take me there teleport; off puts back what it was), `/stock <product id> [units]` (your Products shelves filled with that product: FirstSparkPack, FirstSparkBox...), `/knockout` (knocked out on the spot in the Wild: the countdown and Revive here), `/review <outcome>` (a customer's post in the phone's Reviews: paid, happyMoment, annoyed, gaveUp, noStock), `/titles forget` (every title earned so far is new again: its "New title!" card and the dot), `/support <0-3>` (a "Support the dev"
  gift as if bought: the dogs' thank-you, its aura, titles and toast; 0: none again), `/arena` (go to the arena stands), `/frontierdrop` (a Star Shard and a Frontier card),
  `/raritypack [foil]` (a pack with one card of each rarity, to see every reveal), `/item <id> <n>` (any Config/Items
  item), `/weapon <id> [C|B|A|S] [0-10]` (that weapon at exactly that grade and level; the admin panel's Weapons
  section), `/material <boss id> <n>` (a boss's weapon material; Wild Ore is `/item wildOre <n>`), `/chests <boss id> [drop|miss]` (that boss's three chests after a win, on your screen now, nothing given; the admin panel's "Boss chests"), `/bossreset` (what buying the boss timer reset does: every running boss loot timer ends, its toast; free), `/bosstimer <1-7> <seconds>` (that boss's loot timer runs out then: its "loot is ready again" toast, the Bosses tile's count, the Phone ping), `/event <bossRush|luckySunday|off|auto|luck>` (that weekly event on now for everyone here with its toast, none, or the calendar again; luck: Lucky Sunday's free luck can be given again today; DESIGN 7.15), `/codes reset` (your Store codes can be used again; DESIGN 7.16), `/weapondrop <boss id> [preview [C|B|A|S] | beacon]` (that boss's weapon
  drops for you now: the drop cinematic, a mutation roll when you have it; preview: only a new drop's cinematic, nothing given; beacon: the light column others nearby see, in front of you), `/mutation <offer|set|clear> [common|rare|veryrare|epic|legendary] [mutation id]` (on the weapon in hand: offer plays a mutation's reveal and choice, set puts one on, clear takes it off with any choice waiting; rolled when not named; Essence: `/item mutationEssence <n>`; the admin panel's "Mutations"; DESIGN 5.11 "Mutations"), `/boss <1-6> [fight|group]` (to boss n's gate: its portal in the main game's Wild valley or in the Frontier valley; 1-3 in the main game, 4-6 in the Frontier; with fight or group, use that prompt; boss 7 is reached through the Dungeon run), `/crowd <0-60>` (players counted in every Wild valley biome on top of the real ones, to see its monsters grow), `/customer <plain|kid|collector|bargain|bigSpender> [card id or number | rarity | all | stocked] [hand]` (plain all: one of every product the shop can stock, misses what it doesn't; plain stocked: one of each product on its shelves, finds it all) (a customer of that type now; a collector wanting that card; a kid whose rip has that rarity (rare, veryrare, epic, legendary) and who offers it if Very Rare or better; with hand it arrives holding its list, so empty shelves don't matter and nothing is taken from or put back on them), `/serve` (scan everything on the counter and press Charge as the owner, who must stand behind the register), `/decor <look id | pieces>` (that shop look owned and in use; pieces: one of every decor piece in your shop, as many as fit; the admin panel's "Decor"), `/window <Square|Wide|Arched|Porthole|Stained> <left|right> <at>` (that window put in your shop for free where it fits; the admin panel's "Windows"), `/shoproom <open|lock|fill> [backRoom|gallery|all]` (the shop rooms opened or locked for free, no lesson, locking moves what stood inside out; fill: Small Pack Racks to the shelf cap; the admin panel's "Shop rooms"; DESIGN 4.1), `/storage <place | fill [product id] | clear>` (a free Storage Rack in your shop, your racks filled with full boxes of that product or a few of each orderable kind, or emptied; `/broke` empties racks too; the admin panel's "Storage"; DESIGN 4.2), `/loading <main|wild|frontier|dungeon>` (that place's binder loading screen played on your screen; the admin panel's "Loading screens"), `/legendarys [foil]` (a Grade S
  copy of every Legendary, to see the lightning on display), `/maxcard <name or number> [foil]` (one copy at max level,
  max stars and Grade S, for testing fights), `/time <morning|afternoon|sunset|night|dawn>` (jump the town's day cycle),
  `/intro` (play the first-visit welcome flight, off for players since 2026-11-20: Config/Welcome PLAY), `/prologue [reset]` (the prologue now, or on your next join), `/tutorial reset` (Pish's first visit as a new player's, gifts
  not given yet), `/tutorial step <1-9>` (jump to a step), `/tutorial lesson <id>` (that lesson visit again: titles, trophy, spring, recycler, sleeves,
  sword, condenser, forge, expand, boosterBox, grading, jobs), `/pish` (Town Pish comes to you), `/townchikin` (Town Chikin comes to you, his Courage ready again), `/turts restock | move | offer <id>` (Turts' rug shop: a new roll for you now, he moves now, that offer in your stock; DESIGN 7.9), `/gift ready | day <1-7> | week <n> | month <n> | reset | tutorial | win <daily|big|weekly|monthly>` (the gifts: today's ready, that day's ready, days claimed this week or month, fresh, play time counting on or off, only a win moment; DESIGN 7.10), `/chikin reset | step <1-11>` (Chikin's combat tutorial), `/pishluck` (petting him
  gives luck again now), `/swordpopup` (show the first-sword popup again), `/buttonnames` (the combat buttons' names again for 5 fights), `/movefx <rain|vine|orbs|curse> [C|B|A|S] [big]` (a Pet button move at a grade on your summoned creature against a dummy, a 14-stud one with big; the admin panel's "Pet moves" buttons), `/superfx <move> [C|B|A|S]` (a super move's look and the caster's cinematic at a grade on your summoned creature against a dummy, a 14-stud one for Legendary moves; moves: inferno, magmaslam, tidalshield, tidalblessing, stampede, eclipse, riftstep, supernova, thunderstorm, devour; the admin panel's "Super moves" buttons), `/attackfx [C|B|A|S]` (three basic attacks from your summoned creature at a dummy), `/skillfx <sword> [cut1|cut2|cut3|skill] [level]` (your character swings a round 1 sword's cut or skill at a dummy with its effects, sounds, hold and camera moment; sword: sunforged, verdant, prism, forge, or an element name for that Forge Sword; spear, halberd, trident, lance for the spears; the admin panel's "Sword skills" buttons), `/music [place] <n> [volume]` (loop music option n of a place anywhere: no place the town's `Music.TOWN.options`, or meadow, gorge, ridge, warden, brood, colossus from `Music.WILD`, or frostwood, stormpeak, rift, tyrant, sovereign, devourer from `Music.FRONTIER`, or opening (the pack opening's `Music.OPENING`), or welcome (the first-visit flight's `Music.WELCOME`), or prologue, prologuefight, prologuetaken, prologuewake (the prologue's parts, `Music.PROLOGUE`); `/music [place] 0` for the normal tracks).
- The owner's test save (live game too, owner only: SaveSlotService): `/slot test` plays a separate fresh save, `/slot
  main` the real one, `/slot reset` another fresh test save; rejoin to switch (DESIGN 10.4). Studio's fresh switch:
  `Config/Data.STUDIO_FRESH = true` (locally, never committed on) makes every Studio Play a brand-new player's save in
  memory (ProfileStore's Mock), never written: the prologue, Pish's tour, as a new player sees them.
- Admin panel (Studio, and in the published game for the game's owner on their test save, `/slot test`): the "Admin"
  tile on the left opens every dev command as a button (`Config/AdminPanel`, `AdminPanelController`, remote `DevPanel`,
  run by DevService only after `Util/DevAccess` says yes; "server" commands only when the owner is alone or in their
  own private server; refusals are locked cards; DESIGN "The admin panel in the published game"), plus +1/+10 of every
  item and Go/Fight/Group per boss. Its first section, Footage (`/footage <late|shop|golden>`, `AdminPanel.FOOTAGE`):
  a late-game save, a full shop, a golden-hour sky in one tap each, for recording. Chat commands stay Studio-only. The
  owner's Creator title (any save) brings its orbiting-cards aura (`CreatorAuraController`).
- Multiplayer: Test tab → Local Server, 2 players.
- Saving in Studio needs "Enable Studio access to API services", set on Creator Hub → Game details → API services.
- Developer products (Revive, Finish now SkipS / SkipM / SkipL, DESIGN 7.8; Support1-3, DESIGN 8 "Support the dev";
  Luck15 / Luck30 / SuperLuck30, DESIGN 8 "Luck for Robux"; BossReset, DESIGN 8 "Boss timer reset"; ExtraJobSlot, a
  one-time unlock (`Monetization.UNLOCKS`);
  managed pricing: show prices live, `Util/ProductPrice`):
  Creator Hub → the experience → Monetization → Developer Products → Create, then paste each id into
  `Config/Monetization` PRODUCTS (0 shows "Coming soon").
  PurchaseService holds the one ProcessReceipt; a new product registers with `PurchaseService.OnProduct(key, grant)`.
- After I confirm a system works: tick it in DESIGN.md, commit, and push.
- Keep this game's Obsidian notes, `C:/Users/Ben/Documents/obsidian/Ben/Game dev/One More Pack`, up to date
  as we go (`One More Pack.md` is the index): creature roster, decisions log, lessons learned and the topic notes,
  written for reuse on future projects. Lessons for any game go in `Game dev/Roblox playbook`.
