# Teams in the same world

Owner 2026-11-15: "what if for now, players can only team on the same world for the boss. not necessarily at the
portal. example: when both parties are in the wild they can team up and they can go to any boss in the wild together.
normal monsters stay the same BUT if they are in a party while killing normal monster, it will have party bonus while
hunting for monster ... you will not get an EXP for normal monsters that your teammate killed. only the monster you
kills + party bonus." Then "yes go" to the defaults below, and the team strip "at the right side".
Mockups: `.superpowers/brainstorm/.../teams.html`. Teams across worlds (teleporting together to the Frontier or the
Dungeon) wait until after launch.

## What it is

- **A team**: up to 4 players in the same server (world). Made by a "Team up" prompt (key Y) on every other player,
  next to Challenge; the other player gets an invite card for 15 s (Join team / No thanks). Joining someone already in
  a team joins that team; the first player is its leader (a crown); leaving passes the lead on; a team of one ends.
  A team lasts while its players stay in that server: leaving the game or the world (a teleport) leaves the team.
  Town and the Wild valley are one world (the main game); the Frontier is another; the Dungeon keeps its own run groups.
- **Bosses together**: a teammate who presses Fight at a boss's portal opens the gate's group (the same group as
  "Start group", so others at the gate can still join) and every other teammate in the world gets "<name> is fighting
  the <boss>!" for the group's 15 s, with who's joined, the recommended Power and theirs, Join the fight! / Not now.
  Join takes them to the gate (the Wild's loading screen covers the trip) and into the group; the group waits for
  joiners still on their way (up to a few seconds) when it starts. The usual checks apply (boss open or its keys, a
  rested creature, not in a fight or knocked out); a refusal says why. The leader can start at once with Fight or F.
- **Hunting bonus**: wild monsters stay solo: you get XP and cash only for monsters you defeat. Each teammate within
  150 studs of you then adds 15% to that XP and cash, up to +45% (3 teammates). The win screen shows "+30% team".
- **Look**: the team strip at the top right (under the cash row on a phone): "Team", each teammate's face (Roblox
  headshot) with a crown on the leader and a green dot when they're near enough for the bonus, their name on hover or
  tap, and a Leave button. A "Team bonus +30%" chip by the XP bar while the bonus is on.

## Rules

- Server authoritative (`TeamService`, pure `Util/TeamRules`, Lune-tested): invites expire, a target already in a
  team or a full team is refused (through `Util/Blocked`), everything rate-limited. The bonus is computed on the server
  from characters' positions at the win; the client's chip and dots only preview it.
- Nothing is saved (a team ends with the server).

## Built from

`Config/Teams`, `Util/TeamRules`, `TeamService` (server; BossService and BattleService ask it), `TeamController`
(client), remotes `TeamInvite`, `TeamAnswer`, `TeamState`, `TeamFight`. Studio: two players (Test → Local Server).

## Calls made by Claude

- Key Y for Team up; the bonus range 150 studs; the invite and join windows 15 s.
- A teammate's own Fight opens the team's group; Start group still works for anyone.
