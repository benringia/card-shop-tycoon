# Party & Summoning — Design

Status: approved in chat 2026-10-21. Roadmap step 3 (DESIGN 5.8). Battles (step 5) will use the party as
the battle team.

## 1. Goals

- A **party of 3** cards; **one summoned at a time**, following its owner around the world, visible to all.
- While summoned it gives its owner a small **element perk**, stronger with rarity and stars.
- Creature art from **free Creator Store models**, mapped to cards by name, with a placeholder fallback.

## 2. Party

- **Add to party** from the binder card view (levelled card, or a plain copy split off into its own card,
  like jobs). **Party** HUD button opens a panel: 3 slots (card face, grade, level, stars, perk text),
  **Summon / Unsummon**, **Remove**.
- Party cards are locked: no display, no job. They **can** be condensed (as the main copy). A working card
  can't join the party.
- Summoning another party card unsummons the current one. Unsummon leaves nobody out.
- Saved: schema v7 `party = { slots = { beastId? x3 }, summoned = slot? }`. Load drops missing cards,
  duplicates and cards that are working; the summoned beast respawns on join.

## 3. Following, motion and glow

Updated in chat 2026-10-21: pets walk on the ground with breathing/walking motion and glow by rarity.

**Server marker, client visuals** (standard Roblox pet setup): the server moves an invisible, anchored,
non-colliding **marker part** for each summoned creature (in `workspace.Creatures`) to a point
`FOLLOW_OFFSET` behind/beside its owner, snapped to the ground by a downward raycast, facing the owner's
movement. More than `TELEPORT_DISTANCE` away → it jumps next to the owner. The marker carries attributes
(OwnerUserId, CardId, Foil, Grade, Level, Stars). **Every client draws the creature itself**: it clones the
model, follows the marker smoothly, and adds the motion and glow below. Nothing per-frame is replicated.

**Motion kit** (`Util/CreatureMotion.luau`, pure, Lune-tested; used for every static model):
- Idle: breathing (slow squash-and-stretch, ~3%) and a slight sway.
- Walking (marker moving): a hop/bounce in step with speed, side-to-side waddle, lean into the direction of
  travel, a small squash on each landing. Settles back into breathing when stopped.
- Flyers (cards listed in `FLYING` or models with a `Flies` attribute): hover at `HOVER_HEIGHT` with a bob
  and gentle bank instead of the hop.
- Battle moves (lunge, hit shake, faint) are added in step 5 on the same kit.

**Rigged models**: if a model has an `AnimationController`/`Humanoid` and `Animation` objects named `Idle`
and `Walk` (in an `Animations` folder), the client plays those instead of the hop/waddle (breathing still off).

**Glow** (`Config/Party.luau`, by rarity; element sets the colour and particle style):
- Common none; Rare a faint light; Very Rare light + sparkles; Epic light, sparkles and an outline;
  Legendary a pulsing outline aura, stronger light and particles.
- Foil: the outline slowly cycles through rainbow colours. Grade S and each star: a few extra sparkles.
- Outline uses Roblox Highlight, max 31 on a screen: each client gives outlines to the nearest/rarest
  creatures and the rest keep light and particles.

Name tag (client): name and `Grade · Lv · stars`. Size by rarity (`SIZE_BY_RARITY`, Common 0.7 … Legendary 1.4).

## 4. Perks (`Config/Party.luau`)

| Element | Perk | Effect | Common → Legendary |
|---|---|---|---|
| Ember | Hype | customers arrive more often (spawn interval ÷ (1 + p)) | +5% → +15% |
| Tide | Calm | customers wait longer in the queue (patience × (1 + p)) | +10% → +30% |
| Bloom | Express | deliveries arrive faster (delivery time × (1 − p)) | −10% → −30% |
| Volt | Hustle | you walk faster (WalkSpeed × (1 + p)) | +5% → +15% |
| Shade | Haggle | customers more willing to buy at your price (buy chance × (1 + p), capped at 1) | +5% → +15% |

- Rarity steps: Common, Rare, Very Rare, Epic, Legendary = base × 1, 1.5, 2, 2.5, 3 (where Common = the
  first number above). Each star adds +10% of that value.
- `Util/PartyRules.luau` (pure, Lune-tested): `getPerk(config, element, rarity, stars) -> { kind, value }`.
- Server applies perks through small hooks: CustomerService (spawn interval, queue patience, buy chance),
  StockService (delivery time), the owner's Humanoid WalkSpeed (restored on unsummon).

## 5. Creature art

- Repo folder `assets/creatures/`, mapped by Rojo to `ReplicatedStorage.CreatureModels` (clients draw the
  creatures, so they need the models).
- Workflow: Toolbox → insert → (delete any scripts) → right-click → **Save to File** →
  `assets/creatures/<CardName>.rbxm` (exact card name, spaces kept). Commit. Swap any time; saves never
  store models.
- Safety: on server start, every Script/LocalScript/ModuleScript inside `CreatureModels` is destroyed (before
  players join), and the client strips its clone again. Models over `MAX_MODEL_PARTS` (200) use the placeholder.
- Several cards may share one model: `MODEL_FOR_CARD` in `Config/Party.luau` maps a card name to another
  model name (e.g. Ashbeak → Cindercub), tinted to its element and sized by rarity.
- No model → placeholder: a rounded body in the element colour with two eyes.
- Candidate pack: "Pet 3D Pack - 98 Pets" (63 elemental creatures, static). Shortlist page:
  https://claude.ai/artifact/QYhJeTpNjW3QMhotWcJa5o
- DESIGN 5.5 caveat: Glimmerbeasts are an original IP; store models are stand-ins until own/commissioned art.

## 6. Server and remotes

- `PartyService`: party state per player, load/save/unload (registered after CardService and JobService),
  creature spawning and following, perks. CardService `SetPartied`/`IsPartied` lock (like working);
  `TakeBeast` refuses partied cards; JobService refuses partied cards.
- Remotes: `SetPartySlot(slot, target?)` (target = beastId or `{cardId, foil, grade}`; nil = remove),
  `Summon(slot?)` (nil = unsummon), `PartyChanged` (server → owner: slots + summoned + perk). Validated,
  rate-limited.

## 7. Studio tests

1. Binder → Add to party (plain copy becomes its own card) → Party panel shows it; up to 3.
2. Summon: the creature appears and follows you around the shop and street; others see it; Summon another
   card swaps it; Unsummon removes it.
3. Perk shown in the panel; Volt card: you walk faster; Ember: customers come more often (watch the spawn rate).
4. Party cards can't be displayed or given a job; can be condensed (the creature keeps following).
5. Drop a Creator Store model as `assets/creatures/<CardName>.rbxm`: that card's creature uses it, sized by
   rarity, with no scripts left inside; others still use the placeholder.
7. Walking: the pet hops and waddles behind you on the ground, leans into turns, breathes when you stop.
   A Legendary glows and pulses; a Common has no glow; a foil cycles rainbow. Two players see each other's pets.
6. Die / respawn / teleport: the creature comes back to you. Stop → Play: party and summon restored.
