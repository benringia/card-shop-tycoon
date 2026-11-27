# The live admin panel, Footage presets and the Creator title: design (2026-11-27)

Status: built 2026-11-27 on branch `live-admin` (plan `docs/superpowers/plans/2026-11-27-live-admin-creator.md`);
waiting for the owner's Studio check and a live check after publishing.

## Why
Owner 2026-11-27: "proper admin UI I can publish that only I can use. Dev exclusive title and aura. this will help me
record some footage for marketing without grinding as much." The late-game recording is planned for 2026-11-28.

On launch day (2026-11-21) the owner asked "make sure no admin commands is effective on the live version", and
`tests/DevGate` holds it: DevService leaves at once outside Studio, about 15 services refuse their dev functions
outside Studio, the admin tile is Studio only. This design keeps that promise for every player but one: the owner,
on the owner's test save (`/slot test`), in the published game.

## Goals, non-goals, anti-goals
- Goals: every admin panel button works in the published game (main place, Frontier, Dungeon) for the owner on their
  test save; a Footage section of one-tap setups at the top of the panel; the owner's own title (Creator) and aura
  (orbiting cards) on any save.
- Non-goals: chat commands in the live game (they would autocomplete for every player); faking game passes live
  (`/jobslot` stays Studio only); a new look for the panel (the same Admin window); the aura on the character window's
  stage.
- Anti-goals: anyone but the owner running a command (the server checks every call; the client's word counts for
  nothing); the owner's real save changed by a button (owner's pick A: test save only); another player's game changed
  while the owner isn't alone or in their own private server; the test save showing up in analytics; a silent refusal
  (Design rules: never fail silently: a locked card with the reason).

## Constraints
Server authoritative; one remote (`Remotes.DevPanel`), its text checked and rate-limited (RateLimiter,
`Config/AdminPanel` COMMAND_COOLDOWN and COMMAND_MAX_LENGTH). The owner is `SaveSlots.isOwner` (a user-owned game's
creator; a group-owned game has none). The test save is `DataService.IsTestSlot`. Saved data unchanged (no schema bump).

## Approaches
- **A, one gate in front of the existing panel (picked; the build is Claude's call):** the same 81 commands and the
  same window; one server check decides, per command, whether it runs. Everything the owner already uses in Studio works
  live. Cost: the ~15 services' Studio checks change to the same gate.
- B, a separate, smaller footage-only panel and service: a smaller surface, but duplicate code and far fewer tools.
- C, a third-party admin system: code we don't control that doesn't know our services. Out.

## Design (owner's picks: test save only; title 3 "Creator"; aura C "orbiting cards"; Footage section yes)

### The gate
- `src/server/Util/DevRules.luau` (pure, Lune-tested) takes facts `{ studio, owner, testSlot, players, privateOwner }`:
  - `allowed(facts)`: `studio or (owner and testSlot)`
  - `serverWide(facts)`: `allowed(facts) and (studio or players == 1 or privateOwner)`
  - `scope(alias)`: the command's scope from `Config/AdminPanel` SCOPE, "own" by default
- `src/server/Util/DevAccess.luau` builds the facts (RunService, `SaveSlots.isOwner(game.CreatorId, game.CreatorType)`,
  `DataService.IsTestSlot`, the player count, `game.PrivateServerId` / `PrivateServerOwnerId`) and answers
  `DevAccess.can(player, scope)` plus the refusal's words.
- Scopes. "server" (it changes other players' game): event, time, crowd, room, winroom, puzzle, tap, dungeonfx, pish,
  townchikin, turts, elite, ko, bosshp. "studio": jobslot. Every other command: "own".

### DevService
- In Studio, as today: chat commands, the `ServerStorage.DevCommand` bindable, the panel remote.
- Live: no chat commands and no DevCommand. Only the panel remote, whose handler checks `DevAccess.can(player, scope)`
  before anything else. A refusal is a big locked card (server `Util/Blocked`): "Admin works on your test save. Type
  /slot test, then rejoin." or "Only when you're alone or in your own private server."
- Anyone else's panel request (only an exploiter can send one) is dropped with no reply.
- Each live command is printed to the server log (`[Admin] <name>: /cash 1000000`): the Developer Console shows them.
- The dev functions in other services take the same check in place of `RunService:IsStudio()`: BattleService
  SetBossHpShare, BossService DevSetBeaten, DecorService SetLookForDev, EventService Dev, MainQuestService Dev,
  PlacementService DevPlace, RoomService DevSet, WindowService DevPlace, WildService SetPhantomPlayers,
  DungeonPuzzleService Solve and Tap, DungeonService WinRoom, SolvePuzzle, TapGate, SkipToPuzzle and SkipTo. The ones
  without a player argument get the caller's.
- Untouched: FrontierService's and DungeonGateService's Studio teleport stand-ins (not dev tools), MonetizationService's
  dev passes.

### The panel (client)
- The server marks the owner with an `AdminAccess` attribute: "open" on the test save, "mainSave" on the real one.
  AdminPanelController builds the Admin tile for either (Studio as today). On the real save the tile opens the locked
  card with the /slot test line instead of the panel. The window's title: "🛠 Admin" live, "🛠 Admin (Studio)" in Studio.

### The Footage section (top of the panel)
Three buttons, each one new server command (`/footage late | shop | golden`), built from the existing ones:
- **Late game:** shop Lv 60; $1,000,000; a Grade S copy of every Legendary (`/legendarys`); three maxed Legendaries
  (max level, 5 stars, Grade S) put in the party (Config/AdminPanel FOOTAGE.party); every boss beaten and opened
  (1-7); every weapon at Grade S, level 10, each with a Legendary mutation (so every creature's ultimate can be unlocked
  by switching to its element's weapon).
- **Full shop:** both rooms open; the shop filled with racks to its cap; every Products shelf stocked; the storage racks
  full; every decor piece; a shop look.
- **Golden hour:** the town's sky to sunset ("server" scope).
- The party needs one new dev function, `PartyService.SetSlotsForTesting(player, beastIds)`, behind the same gate.

### The Creator title
- `Config/Titles`: `creator`, name "Creator", icon 👑, a five-colour rainbow (red, yellow, green, cyan, violet),
  shimmer, `check = { kind = "owner" }`, `hidden = true`, first in ORDER.
- TitleRules: the "owner" kind (`progress.owner`); a hidden title is left out of the list until it's earned, so no
  other player sees "Make this game" as a goal.
- TitleService: `progress.owner` from `SaveSlots.isOwner`, on any save.
- TitleController: a gradient of any number of colours (keypoints spread evenly); two-colour gradients look as before.

### The Creator aura (orbiting cards)
- It follows the title: while the owner wears Creator, the server sets the player's `CreatorAura` attribute (any save,
  every place). Picking another title takes it off, so a clean shot needs no extra button.
- Every client draws it for any player with the attribute: three card backs (Config/CardDesign BACK.IMAGE) circling the
  character at chest height, about 3 studs out, a lap in about 9 s, bobbing a little, a gold glow behind each, a little
  bigger and brighter in front, dimmer behind. BillboardGuis on Attachments in the HumanoidRootPart, moved each frame
  (client `Util/CreatorAura`, numbers in `Config/CreatorAura`, the orbit maths pure and Lune-tested). It goes with the
  character (death, respawn, leaving) and when the attribute clears.

### Analytics
`src/server/Util/AnalyticsGate.allowed(player)` is false on the owner's test save. `Util/Funnel` and the seven direct
AnalyticsService calls (CombatTutorialService, PishService, TownChikinService, TutorialService) check it.

### Tests (Lune)
- DevRules: a non-owner live: never; the owner on the real save live: never; the owner on the test save: yes; Studio:
  yes. "server" scope: the owner alone or in their own private server yes, with others no. "studio" scope live: no. The
  SCOPE map names only real commands.
- DevGate, rewritten: DevService.Start's live path makes no chat command and no DevCommand; the panel remote's handler
  checks DevAccess first; no other file handles `Remotes.DevPanel` or makes a DevCommand; each listed dev function
  checks DevAccess, never a bare `RunService:IsStudio()`.
- TitleRules: the owner kind, hidden titles, a five-colour gradient.
- CreatorAura: orbit positions, front and back, a full lap's time.

### Docs
DESIGN.md (dev tools; Titles), CLAUDE.md (the admin panel line: "Studio only" becomes "Studio, and the owner's test
save in the published game"; DevGate's test line), the vault's decisions log.

## Calls made without the owner (Claude's, to check)
- Late game is shop Lv 60, not 100: it still looks earned on camera.
- Each weapon's Legendary mutation is rolled at random (`/mutation set legendary`).
- Full shop stocks each Products shelf with the first product it takes, and uses the prettiest shop look.
- The aura follows the Creator title instead of having its own switch.
- A non-owner's panel request gets no reply (it can only come from an exploit).

## Left to the builder
The refusal words' exact wording; which three Legendaries go in the Footage party (the ultimates that read best on
camera); the orbit's numbers after seeing it in Studio.
