--!strict
-- Teams in the same world (spec 2026-11-15-teams-design, Config/Teams): a team's members (user ids, the leader first
-- in charge), who may invite whom, and the hunting bonus from teammates nearby. TeamService keeps the teams and decides
-- with these; the client only previews. Pure (no requires, no Roblox APIs): callers pass Config/Teams in.
local TeamRules = {}

export type Team = { leader: number, members: { number } }
export type Config = { MAX: number, BONUS_PER_MATE: number, BONUS_MAX: number }
export type Point = { x: number, y: number, z: number }

function TeamRules.new(leader: number): Team
	return { leader = leader, members = { leader } }
end

function TeamRules.has(team: Team, userId: number): boolean
	return table.find(team.members, userId) ~= nil
end

-- `userId` joins; false (the team as it was) when it's full or they're in it already
function TeamRules.add(team: Team, userId: number, cfg: Config): (Team, boolean)
	if TeamRules.has(team, userId) or #team.members >= cfg.MAX then
		return team, false
	end
	local members = table.clone(team.members)
	table.insert(members, userId)
	return { leader = team.leader, members = members }, true
end

-- `userId` leaves: the next member leads if they led; nil once fewer than two are left (the team ends)
function TeamRules.remove(team: Team, userId: number): Team?
	local members = table.clone(team.members)
	local at = table.find(members, userId)
	if at then
		table.remove(members, at)
	end
	if #members < 2 then
		return nil
	end
	return { leader = if team.leader == userId then members[1] else team.leader, members = members }
end

-- Whether `fromId` (on `fromTeam`, or alone) may invite `toId` (on `toTeam`, or alone), and why not: "self",
-- "sameTeam", "theirTeam" (they're on another team), "full"
function TeamRules.canInvite(fromTeam: Team?, toTeam: Team?, fromId: number, toId: number, cfg: Config): (boolean, string?)
	if fromId == toId then
		return false, "self"
	end
	if fromTeam and TeamRules.has(fromTeam, toId) then
		return false, "sameTeam"
	end
	if toTeam then
		return false, "theirTeam"
	end
	if fromTeam and #fromTeam.members >= cfg.MAX then
		return false, "full"
	end
	return true, nil
end

-- The hunting bonus for `near` teammates within range: a share added to XP and cash
function TeamRules.bonus(near: number, cfg: Config): number
	return math.min(math.max(near, 0) * cfg.BONUS_PER_MATE, cfg.BONUS_MAX)
end

-- How many of `mates` stand within `range` studs of `me`
function TeamRules.nearCount(me: Point, mates: { Point }, range: number): number
	local count = 0
	for _, mate in mates do
		local dx, dy, dz = mate.x - me.x, mate.y - me.y, mate.z - me.z
		if dx * dx + dy * dy + dz * dz <= range * range then
			count += 1
		end
	end
	return count
end

-- XP with the bonus, whole
function TeamRules.boostXp(xp: number, bonus: number): number
	return math.floor(xp * (1 + bonus) + 0.5)
end

-- Cash with the bonus, to the cent
function TeamRules.boostCash(cash: number, bonus: number): number
	return math.floor(cash * (1 + bonus) * 100 + 0.5) / 100
end

-- "+30%"
function TeamRules.percent(bonus: number): string
	return `+{math.floor(bonus * 100 + 0.5)}%`
end

return TeamRules
