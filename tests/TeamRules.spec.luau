--!strict
-- Teams in the same world (spec 2026-11-15-teams-design; owner: "players can only team on the same world for the boss
-- ... if they are in a party while killing normal monster, it will have party bonus ... you will not get an EXP for
-- normal monsters that your teammate killed. only the monster you kills + party bonus")
local TeamRules = require("../src/shared/Util/TeamRules")
local Teams = require("../src/shared/Config/Teams")
local expect = require("./lib/expect")

local BEN, MIA, KAI, ZOE, MAX = 1, 2, 3, 4, 5

return {
	["the agreed numbers"] = function()
		expect.equal(Teams.MAX, 4)
		expect.equal(Teams.INVITE_SECONDS, 15)
		expect.equal(Teams.BONUS_PER_MATE, 0.15)
		expect.equal(Teams.BONUS_MAX, 0.45)
		expect.equal(Teams.BONUS_RANGE, 150)
	end,

	["a team grows to 4, the first player leading"] = function()
		local team = TeamRules.new(BEN)
		expect.equal(team.leader, BEN)
		local added
		team, added = TeamRules.add(team, MIA, Teams)
		expect.equal(added, true)
		team = TeamRules.add(team, KAI, Teams)
		team = TeamRules.add(team, ZOE, Teams)
		expect.equal(#team.members, 4)
		local _, full = TeamRules.add(team, MAX, Teams)
		expect.equal(full, false, "a fifth doesn't fit")
		local _, again = TeamRules.add(team, MIA, Teams)
		expect.equal(again, false, "already in")
		expect.equal(TeamRules.has(team, KAI), true)
		expect.equal(TeamRules.has(team, MAX), false)
	end,

	["leaving passes the lead on, a team of one ends"] = function()
		local team = TeamRules.add(TeamRules.add(TeamRules.new(BEN), MIA, Teams), KAI, Teams)
		local left = TeamRules.remove(team, BEN)
		expect.equal(left ~= nil, true)
		expect.equal((left :: TeamRules.Team).leader, MIA, "the next one leads")
		expect.equal(#(left :: TeamRules.Team).members, 2)
		local pair = TeamRules.add(TeamRules.new(BEN), MIA, Teams)
		expect.isNil(TeamRules.remove(pair, MIA), "Ben alone: no team")
		local same = TeamRules.remove(team, MAX)
		expect.equal(#(same :: TeamRules.Team).members, 3, "someone not in it changes nothing")
	end,

	["who can invite whom"] = function()
		local ours = TeamRules.add(TeamRules.new(BEN), MIA, Teams)
		local theirs = TeamRules.add(TeamRules.new(KAI), ZOE, Teams)
		local ok, why = TeamRules.canInvite(nil, nil, BEN, BEN, Teams)
		expect.equal(ok, false)
		expect.equal(why, "self")
		expect.equal((TeamRules.canInvite(nil, nil, BEN, MIA, Teams)), true, "two players alone")
		expect.equal((TeamRules.canInvite(ours, nil, MIA, MAX, Teams)), true, "any teammate can invite")
		ok, why = TeamRules.canInvite(ours, ours, BEN, MIA, Teams)
		expect.equal(ok, false)
		expect.equal(why, "sameTeam")
		ok, why = TeamRules.canInvite(ours, theirs, BEN, KAI, Teams)
		expect.equal(ok, false)
		expect.equal(why, "theirTeam")
		local full = TeamRules.add(TeamRules.add(ours, KAI, Teams), ZOE, Teams)
		ok, why = TeamRules.canInvite(full, nil, BEN, MAX, Teams)
		expect.equal(ok, false)
		expect.equal(why, "full")
	end,

	["the hunting bonus: 15% a teammate nearby, at most 45%"] = function()
		expect.equal(TeamRules.bonus(0, Teams), 0)
		expect.near(TeamRules.bonus(1, Teams), 0.15, 1e-9)
		expect.near(TeamRules.bonus(2, Teams), 0.30, 1e-9)
		expect.near(TeamRules.bonus(3, Teams), 0.45, 1e-9)
		expect.near(TeamRules.bonus(5, Teams), 0.45, 1e-9, "never past the cap")
	end,

	["only teammates within range count"] = function()
		local me = { x = 0, y = 0, z = 0 }
		local mates = { { x = 100, y = 0, z = 0 }, { x = 0, y = 10, z = 149 }, { x = 151, y = 0, z = 0 } }
		expect.equal(TeamRules.nearCount(me, mates, Teams.BONUS_RANGE), 2)
		expect.equal(TeamRules.nearCount(me, {}, Teams.BONUS_RANGE), 0)
	end,

	["a reward with the bonus: whole XP, cash to the cent"] = function()
		expect.equal(TeamRules.boostXp(20, 0.3), 26)
		expect.equal(TeamRules.boostXp(7, 0.15), 8)
		expect.equal(TeamRules.boostXp(20, 0), 20)
		expect.near(TeamRules.boostCash(4.4, 0.45), 6.38, 1e-9)
		expect.equal(TeamRules.boostCash(4.4, 0), 4.4)
	end,

	["the bonus in words"] = function()
		expect.equal(TeamRules.percent(0.3), "+30%")
		expect.equal(TeamRules.percent(0.45), "+45%")
	end,
}
