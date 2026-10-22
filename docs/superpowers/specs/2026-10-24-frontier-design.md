# Battles, part 3a: the Frontier

Roadmap step 5 (DESIGN 5.8), third part. Part 1 (wild) and part 2 (PvP) are done. Part 3b (Dungeons: a third
place with late-game bosses for groups) comes next and plugs into the Dungeon portal built here.

## 1. Goal

A second Roblox place in the same experience, shared by players from every server: high-level monsters, the only
source of Star Shards (the first item in a new item inventory) and of a new set of Frontier-exclusive cards.
Players travel there and back with real teleports; their save goes with them.

## 2. Decisions (from brainstorming)

| Topic | Decision |
|---|---|
| Valuable drops | Star Shards (items) and Frontier-exclusive cards |
| Items | A general inventory (`items = { [itemId] = count }`) so later items (healing, revives...) slot in |
| Getting there | Plaza portal menu: Explore (any Frontier server with room) or Join friend (friends in a Frontier now) |
| Entry | Open to everyone; "Recommended Lv 15+" on the portal and zone signs |
| Code | One codebase, two places: a second Rojo project tags the Frontier place; the server starts only what that place needs |
| Shop while away | Paused: the plot is released on leaving; it rebuilds from the save on return (maybe another server/plot) |
| Dungeons | A Dungeon portal inside the Frontier, "Coming soon" until part 3b |
| Levels | Every level number in Config, retuned freely later |

## 3. Places and travel

- **Place kind.** `frontier.project.json` syncs the same `src` as `default.project.json` and sets the Workspace
  attribute `PlaceKind = "Frontier"`; without it the place is the main game. `Config/Places.luau` holds
  `MAIN_PLACE_ID` and `FRONTIER_PLACE_ID` (0 until the Frontier place is created and published; the portal then
  says "Coming soon").
- **Services per place.** Main: everything as now plus a FrontierTravel portal. Frontier: DataService (no plot
  claim), EconomyService, CardService, PartyService, BattleService, WildService (Frontier map), ItemService,
  FrontierService, DevService; no plots, shelves, stock, customers, register, packs, showcases, condenser, jobs,
  arena. Client controllers that need plots or shops check the place kind and stay idle.
- **Leaving for the Frontier.** Portal → menu: Explore / Join friend (friends whose presence is the Frontier place,
  via `Player:GetFriendsOnline`). The server ends any fight or match (as a run/forfeit), saves and releases the
  profile, then `TeleportService:TeleportAsync` (Explore: the Frontier place; friend: that friend's server via
  `TeleportOptions.ServerInstanceId`). Failure: message, the player stays, the profile is loaded again.
- **Coming back.** A "Return" portal at the Frontier entrance and a 🏠 HUD button teleport to the main place
  (Roblox picks a server). The plot is claimed and rebuilt from the save as on any join.
- **Studio.** Teleports don't work in Studio; the Frontier place is tested by opening it and pressing Play (the
  real save loads there too). The round trip is tested in the published game (Playtesters access).

## 4. The Frontier

- Placeholder map built in code (like the wild), swappable for a model later: entrance with the Return portal, a
  healing spring (same rules as the plaza spring), a Dungeon portal ("Coming soon"), and three zones:

| Zone | Monster Lv | Elements | Chases you |
|---|---|---|---|
| Frostwood | 15–25 | Tide, Shade | elites only |
| Stormpeak | 25–35 | Volt, Ember | elites only |
| The Rift | 35–50 | all five | all |

- 6 new species (2 per zone; placeholder shapes in code, models in `assets/monsters`), elites 1 in 6.
- Same combat as the wild: summoned leader + one call-in, solo fights, Run %, resting, no other penalty.
- Rewards: card XP and cash as in the wild (same formulas, higher levels), plus:

| Drop | Normal monster | Elite | Dungeon boss (3b) |
|---|---|---|---|
| Star Shard | 3% (1) | 10% (1) | 20% (2–3) |
| Frontier card | 3% | 10% | — (3b decides) |

- **Frontier cards**: a new set of 6 (2 Rare, 2 Epic, 2 Legendary) with Set 1-style stats, elements and values;
  the Epic and Legendary ones get signature abilities. Never in packs. Rolled by rarity on drop; grade rolled on
  the server. The binder gets a "Frontier" section.
- Numbers live in `Config/Frontier.luau` (zones, species, drop tables) and reuse the wild's code paths.

## 5. Items and Star Shards

- Saved `items = { [itemId] = count }` (schema v10). `Config/Items.luau` lists each item: id, name, emoji icon,
  description, max stack. First item: `starShard` — "✨ Star Shard: counts as one duplicate when condensing any card".
- `ItemService` is the only place items change: `GiveItem(player, id, n)`, `TakeItem(player, id, n): boolean`,
  `GetCount(player, id)`; sync to the client like the binder. Load drops unknown ids and clamps counts to whole
  numbers 0–9999 (max stack).
- **Bag**: a Bag tab in the binder lists items with counts and descriptions.
- **Condenser**: a "Use Star Shards" toggle. Real duplicates are always used first; shards cover the shortfall,
  but never more than half of a star's cost (`MAX_SHARD_SHARE = 0.5`, rounded down). The preview shows
  "Needs 8 · you have 5 duplicates + 3 Shards". Condensing takes the shards through ItemService in the same step.
  (The Condenser is in the main place only.)

## 6. Data and safety

- Schema v10 adds `items = {}`; migration with a Lune test.
- Before every teleport: end fights/matches/challenges (refunds and forfeits as in parts 1–2), save, release.
- Remotes for travel are rate-limited; the friend target is checked to be the player's friend and in a Frontier
  server; the destination place id comes from Config only.

## 7. Testing

Lune:
- Item rules (pure): sanitize (unknown ids, negatives, NaN, over max stack), give/take maths.
- Condense with shards (pure, extends CondenseRules): shards only cover the shortfall, at most half the cost,
  duplicates first; not enough even with shards → refused with the right numbers.
- Frontier drop tables and species config valid (every zone species exists, elements valid, cards exist).
- Migration v10.

Studio:
1. Main place: portal menu opens; with `FRONTIER_PLACE_ID = 0` it says "Coming soon".
2. Frontier place (open it, Play): your cards, party, cash load; no plots or shop UI; zones, monsters and the
   spring work; fights give XP; Star Shards and Frontier cards drop (dev command `/frontierdrop` forces a drop).
3. Bag tab shows shards; Condenser "Use Star Shards" fills the shortfall up to half.
Published game (Playtesters): Explore teleports in and back with the save intact; Join friend lands in the
friend's server.

## 8. Out of scope
Dungeons and bosses (part 3b); item uses beyond Star Shards; offline shop earnings; trading.
