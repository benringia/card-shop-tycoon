--!strict
-- Teams in the same world (spec 2026-11-15-teams-design; owner: "players can only team on the same world for the
-- boss. not necessarily at the portal ... if they are in a party while killing normal monster, it will have party
-- bonus"): up to MAX players in one server, made with a "Team up" prompt on other players; a teammate's boss fight
-- calls the others; each teammate near you adds to the XP and cash of the monsters you defeat. Util/TeamRules,
-- TeamService (server), TeamController (client). Plain data: tests/TeamRules.
return {
	MAX = 4,
	INVITE_SECONDS = 15, -- an invite card's time to answer
	BONUS_PER_MATE = 0.15, -- each teammate within BONUS_RANGE studs: +15% XP and cash from your own monster wins
	BONUS_MAX = 0.45,
	BONUS_RANGE = 150,
	TRAVEL_WAIT = 8, -- seconds a starting boss group waits for teammates still on their way to its gate
	-- The "Team up" prompt on every other player, shown beside Challenge (UIOffset keeps them apart)
	PROMPT = { key = "Y", text = "Team up", range = 12, offset = { 0, -72 } },
	-- The team strip (client): top right on a computer, under the cash row on a phone
	STRIP = {
		face = 46, -- px, each teammate's headshot
		gap = 10,
		right = 16, -- px from the screen's right edge
		top = 70, -- px from the top on a computer
		near = { 109, 224, 143 }, -- the near-you dot
		fill = { 40, 20, 70 }, -- the strip's see-through backing
		transparency = 0.55,
	},
	TEXT = {
		invite = "{name} wants to team up!",
		inviteLine = "Fight bosses together and hunt monsters for +15% XP and cash per teammate nearby.",
		joined = "{name} joined your team!",
		left = "{name} left your team.",
		fight = "{name} is fighting the {boss}!",
		bonus = "Team bonus", -- then "+30%"
	},
	REFUSALS = {
		self = "That's you!",
		sameTeam = "You're already on a team together.",
		theirTeam = "{name} is already on another team.",
		full = "Your team is full (4 players).",
		expired = "That invite ran out. Ask them to invite you again.",
		gone = "They left the game.",
	},
}
