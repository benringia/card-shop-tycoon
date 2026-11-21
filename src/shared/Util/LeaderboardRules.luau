--!strict
-- The plaza leaderboard's rules (Config/Leaderboard, server LeaderboardService): who's on each list and in what order,
-- when a player's lifetime packs-opened total goes to the shared store, and how counts read. Pure, Lune-tested.
local LeaderboardRules = {}

export type Entry = { userId: number, name: string, count: number }

local function before(a: Entry, b: Entry): boolean
	if a.count ~= b.count then
		return a.count > b.count
	end
	if a.name ~= b.name then
		return a.name < b.name
	end
	return a.userId < b.userId
end

-- Who is left off both lists, by user id: the game's owner (`creatorId` of a user-owned game; a group's id is no
-- player's, 0 isn't published) while `hideOwner` is on (Config/Leaderboard HIDE_OWNER)
function LeaderboardRules.hidden(creatorId: number, creatorType: string, hideOwner: boolean): { [number]: boolean }
	if hideOwner and creatorType == "User" and creatorId ~= 0 then
		return { [creatorId] = true }
	end
	return {}
end

-- `entries` without the hidden players
function LeaderboardRules.without(entries: { Entry }, hidden: { [number]: boolean }): { Entry }
	local list: { Entry } = {}
	for _, entry in entries do
		if not hidden[entry.userId] then
			table.insert(list, entry)
		end
	end
	return list
end

-- How many to read from the store so `size` still show once the hidden players are taken out
function LeaderboardRules.readSize(size: number, hidden: { [number]: boolean }): number
	local extra = 0
	for _ in hidden do
		extra += 1
	end
	return size + extra
end

-- The top `size` of `entries`, most packs first (ties by name); `keepZero`: players who haven't opened any stay on
-- (this server's list, so a new player sees themselves), else they're left off (the all-time list)
function LeaderboardRules.rank(entries: { Entry }, size: number, keepZero: boolean): { Entry }
	local list: { Entry } = {}
	for _, entry in entries do
		if keepZero or entry.count > 0 then
			table.insert(list, entry)
		end
	end
	table.sort(list, before)
	while #list > size do
		table.remove(list)
	end
	return list
end

-- The all-time list: the store's top (`stored`, read every few minutes) with the players here now (`live`) counted as
-- they open packs; each player once, at their higher total under their live name
function LeaderboardRules.merge(stored: { Entry }, live: { Entry }, size: number): { Entry }
	local byId: { [number]: Entry } = {}
	for _, entry in stored do
		byId[entry.userId] = { userId = entry.userId, name = entry.name, count = entry.count }
	end
	for _, entry in live do
		local known = byId[entry.userId]
		byId[entry.userId] = {
			userId = entry.userId,
			name = entry.name,
			count = if known then math.max(known.count, entry.count) else entry.count,
		}
	end
	local all: { Entry } = {}
	for _, entry in byId do
		table.insert(all, entry)
	end
	return LeaderboardRules.rank(all, size, false)
end

-- Whether a player's total goes to the store: above zero (0 is also what a save that hasn't loaded reads) and not what
-- was written last (`written`, nil before the first write: a total from before the board existed goes up too); never a
-- hidden player's (`hide`: the owner)
function LeaderboardRules.shouldWrite(count: number, written: number?, hide: boolean?): boolean
	return not hide and count > 0 and count ~= written
end

-- A count with thousands separators: 1,234,567
-- Which ranking the cards show `now` (seconds on any steady clock): each of `count` in turn for `every` seconds
function LeaderboardRules.shownBoard(now: number, every: number, count: number): number
	if now ~= now or count <= 1 or every <= 0 then
		return 1
	end
	return math.floor(math.max(0, now) / every) % count + 1
end

function LeaderboardRules.countText(count: number): string
	local digits = tostring(math.max(0, math.floor(count)))
	local out = ""
	while #digits > 3 do
		out = "," .. string.sub(digits, -3) .. out
		digits = string.sub(digits, 1, -4)
	end
	return digits .. out
end

return LeaderboardRules
